<?php

namespace App\Services\Inventory;

use App\Exceptions\SapException;
use App\Models\BranchGapTransferRequest;
use App\Models\User;
use App\Services\SAP\SapClient;
use App\Services\StockTransferService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Raises an inventory transfer REQUEST in SAP (InventoryTransferRequests,
 * OWTQ) from «عجز الفروع». A request moves no stock: the sending branch ships
 * it from the HUB app and SAP copies it into the real transfer.
 *
 * This is the one sanctioned SAP write of this feature (owner approved
 * 2026-10-18). Quantities are pieces: every line carries the item's inventory
 * UoM, because a line left on the default transfer UoM is read as cartons.
 */
class TransferRequestWriter
{
    public const COMPANY_DB = 'PPTC_V5_PROD';

    public const MAX_LINES = 150;

    private SapClient $sap;

    public function __construct(?SapClient $sap = null)
    {
        // Own client, so the request-scoped one is never switched.
        $this->sap = $sap ?? new SapClient();
        $this->sap->setCompanyDb(self::COMPANY_DB);
    }

    /**
     * @param  array<int, array{item_code: string, quantity: int|float|string}>  $lines
     *
     * @throws \InvalidArgumentException when the request itself is not valid
     */
    public function create(string $from, string $to, array $lines, ?User $user = null, ?string $note = null): BranchGapTransferRequest
    {
        $from = strtoupper(trim($from));
        $to = strtoupper(trim($to));
        if ($from === '' || $to === '' || $from === $to) {
            throw new \InvalidArgumentException('اختر مستودعين مختلفين للتحويل.');
        }

        $qty = [];
        foreach ($lines as $line) {
            $code = strtoupper(trim((string) ($line['item_code'] ?? '')));
            $q = (int) floor((float) ($line['quantity'] ?? 0));
            if ($code !== '' && $q > 0) {
                $qty[$code] = ($qty[$code] ?? 0) + $q;
            }
        }
        if (empty($qty)) {
            throw new \InvalidArgumentException('لا توجد أصناف بكميات صحيحة.');
        }
        if (count($qty) > self::MAX_LINES) {
            throw new \InvalidArgumentException('الحد الأعلى ' . self::MAX_LINES . ' صنفاً في الطلب الواحد.');
        }

        // Never ask the source for more than it holds right now.
        $available = DB::table('warehouse_item_stocks')
            ->where('warehouse_code', $from)
            ->whereIn('item_code', array_keys($qty))
            ->get(['item_code', 'in_stock', 'committed'])
            ->mapWithKeys(fn ($r) => [$r->item_code => max(0, (float) $r->in_stock - (float) $r->committed)]);
        $short = collect($qty)->filter(fn ($q, $code) => $q > ($available[$code] ?? 0))->keys();
        if ($short->isNotEmpty()) {
            throw new \InvalidArgumentException('الكمية أكبر من المتوفر في ' . BranchGapService::warehouseLabel($from) . ': ' . $short->take(8)->join('، '));
        }

        $uom = $this->inventoryUoms(array_keys($qty));

        $lock = Cache::lock("branch-gaps:post:$from:$to", 120);
        if (! $lock->get()) {
            throw new \InvalidArgumentException('يوجد طلب قيد الإرسال لنفس المسار، انتظر لحظات.');
        }

        try {
            $req = BranchGapTransferRequest::create([
                'reference' => 'GAP-' . now()->format('ymd-His') . '-' . Str::upper(Str::random(3)),
                'from_warehouse' => $from,
                'to_warehouse' => $to,
                'lines' => collect($qty)->map(fn ($q, $code) => ['item_code' => $code, 'quantity' => $q])->values()->all(),
                'total_quantity' => array_sum($qty),
                'status' => BranchGapTransferRequest::STATUS_PENDING,
                'note' => $note ? Str::limit($note, 480, '') : null,
                'user_id' => $user?->id,
            ]);

            try {
                $payload = $this->payload($req, $uom, $user);
                $res = $this->sap->post('InventoryTransferRequests', $payload);
                $req->update([
                    'status' => BranchGapTransferRequest::STATUS_POSTED,
                    'doc_entry' => $res['DocEntry'] ?? null,
                    'doc_num' => $res['DocNum'] ?? null,
                ]);
            } catch (SapException $e) {
                // SAP answered with an error: nothing was created.
                $req->update(['status' => BranchGapTransferRequest::STATUS_FAILED, 'error' => $e->getMessage()]);
            } catch (\Throwable $e) {
                // No answer (timeout, network): SAP may still have created it.
                $found = $this->findByReference($req->reference);
                $req->update($found
                    ? ['status' => BranchGapTransferRequest::STATUS_POSTED, 'doc_entry' => $found['DocEntry'], 'doc_num' => $found['DocNum']]
                    : ['status' => BranchGapTransferRequest::STATUS_FAILED, 'error' => $e->getMessage()]);
            }
        } finally {
            $lock->release();
        }

        if ($req->status === BranchGapTransferRequest::STATUS_POSTED) {
            Log::info("BranchGaps: SAP transfer request {$req->doc_num} ({$req->reference}) $from → $to, {$req->total_quantity} pcs.");
            $this->mirror();
        } else {
            Log::warning("BranchGaps: SAP refused {$req->reference}: {$req->error}");
        }

        return $req->refresh();
    }

    /** @param array<string, ?int> $uom item => inventory UoMEntry (null = manual UoM group) */
    public function payload(BranchGapTransferRequest $req, array $uom, ?User $user = null): array
    {
        $comment = 'سد عجز ' . BranchGapService::warehouseLabel($req->to_warehouse)
            . ' من ' . BranchGapService::warehouseLabel($req->from_warehouse)
            . ' · ' . $req->reference
            . ($user ? ' · ' . $user->name : '')
            . ($req->note ? ' · ' . $req->note : '');

        return [
            'DocDate' => now()->toDateString(),
            'FromWarehouse' => $req->from_warehouse,
            'ToWarehouse' => $req->to_warehouse,
            'JournalMemo' => $req->reference,
            'Comments' => Str::limit($comment, 250, ''),
            'StockTransferLines' => collect($req->lines)->map(fn ($l) => array_filter([
                'ItemCode' => $l['item_code'],
                'Quantity' => (int) $l['quantity'],
                'FromWarehouseCode' => $req->from_warehouse,
                'WarehouseCode' => $req->to_warehouse,
                'UoMEntry' => $uom[$l['item_code']] ?? null,
            ], fn ($v) => $v !== null))->values()->all(),
        ];
    }

    /**
     * item => inventory UoMEntry, read from SAP Items (GET). Null for items on
     * a manual UoM group, where quantities are already inventory units.
     *
     * @return array<string, ?int>
     */
    private function inventoryUoms(array $codes): array
    {
        $out = [];
        foreach (array_chunk($codes, 15) as $chunk) {
            $filter = collect($chunk)->map(fn ($c) => "ItemCode eq '" . str_replace("'", "''", $c) . "'")->join(' or ');
            $rows = $this->sap->get('Items', [
                '$filter' => $filter,
                '$select' => 'ItemCode,InventoryUoMEntry,UoMGroupEntry,InventoryItem',
                '$top' => 20,
            ])['value'] ?? [];
            foreach ($rows as $r) {
                if (($r['InventoryItem'] ?? 'tYES') !== 'tYES') {
                    throw new \InvalidArgumentException('صنف غير مخزني في ساب: ' . $r['ItemCode']);
                }
                $manual = (int) ($r['UoMGroupEntry'] ?? -1) === -1;
                $out[$r['ItemCode']] = $manual || empty($r['InventoryUoMEntry']) ? null : (int) $r['InventoryUoMEntry'];
            }
        }
        $missing = array_diff($codes, array_keys($out));
        if ($missing) {
            throw new \InvalidArgumentException('أصناف غير موجودة في ساب: ' . implode('، ', array_slice($missing, 0, 8)));
        }

        return $out;
    }

    private function findByReference(string $reference): ?array
    {
        try {
            $rows = $this->sap->get('InventoryTransferRequests', [
                '$filter' => "JournalMemo eq '" . str_replace("'", "''", $reference) . "'",
                '$select' => 'DocEntry,DocNum',
                '$top' => 1,
            ])['value'] ?? [];

            return $rows[0] ?? null;
        } catch (\Throwable $e) {
            Log::warning("BranchGaps: lookup of $reference failed: " . $e->getMessage());

            return null;
        }
    }

    /** Pull the new request into the transfer mirror now, so HUB shows it to the sender. */
    private function mirror(): void
    {
        try {
            (new StockTransferService($this->sap))->importFromSap();
        } catch (\Throwable $e) {
            Log::warning('BranchGaps: transfer mirror refresh failed, the scheduled sync will pick it up: ' . $e->getMessage());
        }
    }
}
