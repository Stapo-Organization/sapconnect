<?php

namespace App\Services\SAP;

use App\Models\ApiLog;
use App\Models\DraftInvoiceChunk;
use App\Models\DraftInvoiceRun;
use App\Services\SAP\SapClient;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use OpenSpout\Reader\XLSX\Reader as XlsxReader;

/**
 * Turns a flat sales-report file (one row = one sold line) into SAP **draft**
 * invoices (Service Layer `Drafts`, DocObjectCode=oInvoices).
 *
 * Pipeline: parse -> group by warehouse -> split each warehouse into chunks of
 * N document-lines -> one draft per chunk. For batch-managed items the nearest
 * expiry batches (FEFO) for that specific warehouse are attached. Freight is
 * summed per chunk and sent as a header Additional Expense.
 *
 * SAFETY:
 *  - Drafts never post to the ledger/inventory until a human opens them in SAP
 *    and clicks Add.
 *  - Idempotent: the (file_hash, warehouse, chunk_index) ledger guarantees a
 *    chunk is posted at most once; re-runs only fill gaps / retry failures.
 *  - UnitPrice is taken verbatim from the file (no SAP price-list recompute).
 *
 * Batch note: on-hand from `batchesitems` is a *current snapshot*, while the
 * file is historical sales, so we do NOT decrement batch balances across lines
 * — each batch-managed line is simply labelled with its warehouse's nearest
 * expiry batch(es). Lines whose qty exceeds current on-hand are flagged but
 * still produced (it is a draft for human review).
 */
class DraftInvoiceImportService
{
    public const DOC_OBJECT_CODE = 'oInvoices';

    /** Canonical column => list of accepted header aliases (lowercased). */
    protected array $headerAliases = [
        'card_code'    => ['bp code', 'cardcode', 'bp', 'customer'],
        'warehouse'    => ['wh code', 'warehousecode', 'whscode', 'warehouse'],
        'order_date'   => ['order date', 'docdate', 'date'],
        'order_number' => ['order number', 'order no', 'ordernumber', 'numatcard'],
        'item_code'    => ['item upc', 'itemcode', 'item code', 'sap code'],
        'barcode'      => ['seller sku', 'barcode', 'upc'],
        'item_name'    => ['item name', 'itemname', 'description'],
        'uom'          => ['uom', 'uomcode'],
        'qty'          => ['ordered quantity', 'quantity', 'qty'],
        'unit_price'   => ['unit price', 'unitprice', 'price'],
        'line_total'   => ['line total', 'linetotal', 'total'],
        'freight'      => ['freight', 'shipping'],
    ];

    /** Per-run caches (item-level), avoid hammering SAP. */
    protected array $batchRowCache = [];
    protected array $itemInfoCache = [];

    public function __construct(protected SapClient $sap)
    {
    }

    /**
     * Execute a run. $post=false => dry-run preview (no SAP writes at all).
     * $progress is an optional callable(string $message) for CLI/UI feedback.
     */
    public function run(DraftInvoiceRun $run, string $filePath, bool $post, ?callable $progress = null): array
    {
        $log = fn (string $m) => $progress ? $progress($m) : null;

        $this->sap->setCompanyDb($run->company_db);

        $fileHash = hash_file('sha256', $filePath);
        $run->forceFill(['file_hash' => $fileHash])->save();

        $log("Parsing file...");
        [$rows, $parseExceptions] = $this->parseAndMap($filePath);
        $log("Parsed " . count($rows) . " valid line(s); " . count($parseExceptions) . " row exception(s).");

        // Group by warehouse (respecting an optional single-warehouse filter).
        $byWarehouse = [];
        foreach ($rows as $r) {
            $wh = $r['warehouse'];
            if ($run->warehouse_filter && $wh !== $run->warehouse_filter) {
                continue;
            }
            $byWarehouse[$wh][] = $r;
        }
        ksort($byWarehouse);

        // Guard: a file already partially POSTED must keep the same chunk_size,
        // otherwise re-chunking would create duplicate drafts of the same sales.
        if ($post) {
            $this->assertChunkSizeStable($run, $fileHash);
        }

        $chunkSize = max(1, (int) $run->chunk_size);
        $cardCode  = $run->card_code;
        $docDate   = optional($run->doc_date)->format('Y-m-d') ?? now()->format('Y-m-d');

        $allExceptions = $parseExceptions;
        $results = [];
        $previews = [];
        $totals = [
            'rows' => count($rows),
            'drafts' => 0,
            'posted' => 0,
            'skipped' => 0,
            'failed' => 0,
            'lines' => 0,
            'freight_total' => 0.0,
            'exceptions' => 0,
            'warehouses' => [],
        ];

        foreach ($byWarehouse as $wh => $whRows) {
            $chunks = array_chunk($whRows, $chunkSize);
            $totals['warehouses'][$wh] = ['lines' => count($whRows), 'chunks' => count($chunks), 'posted' => 0, 'skipped' => 0, 'failed' => 0];
            $log("Warehouse $wh: " . count($whRows) . " line(s) -> " . count($chunks) . " draft(s).");

            foreach ($chunks as $idx => $chunkRows) {
                [$payload, $chunkExceptions, $freightTotal] = $this->buildDraftPayload(
                    $chunkRows, $wh, $idx, $cardCode, $docDate, $run, $log
                );

                $lineCount = count($payload['DocumentLines']);
                $payloadHash = hash('sha256', json_encode($payload));

                $totals['drafts']++;
                $totals['lines'] += $lineCount;
                $totals['freight_total'] += $freightTotal;
                $allExceptions = array_merge($allExceptions, $chunkExceptions);

                // Ledger row (idempotent on file_hash+warehouse+chunk_index).
                $chunk = DraftInvoiceChunk::firstOrNew([
                    'file_hash' => $fileHash,
                    'warehouse' => $wh,
                    'chunk_index' => $idx,
                ]);
                $chunk->fill([
                    'run_id' => $run->id,
                    'company_db' => $run->company_db,
                    'lines_count' => $lineCount,
                    'freight_total' => $freightTotal,
                    'payload_hash' => $payloadHash,
                    'exceptions' => $chunkExceptions ?: null,
                ]);

                if (!$post) {
                    // Dry-run: record structure only, never call SAP.
                    if (!$chunk->status || $chunk->status === 'built') {
                        $chunk->status = 'built';
                    }
                    $chunk->save();
                    $previews[] = ['warehouse' => $wh, 'chunk_index' => $idx, 'lines' => $lineCount, 'freight' => $freightTotal, 'payload' => $payload];
                    continue;
                }

                // Real post: skip chunks already posted (idempotency).
                if ($chunk->status === 'posted' && $chunk->doc_entry) {
                    $totals['skipped']++;
                    $totals['warehouses'][$wh]['skipped']++;
                    $chunk->save();
                    $log("  chunk $idx already posted (DocEntry {$chunk->doc_entry}) - skipped.");
                    $results[] = ['warehouse' => $wh, 'chunk_index' => $idx, 'status' => 'skipped', 'doc_entry' => $chunk->doc_entry];
                    continue;
                }

                try {
                    $response = $this->sap->post('Drafts', $payload);
                    $docEntry = $response['DocEntry'] ?? null;
                    $docNum = $response['DocNum'] ?? null;

                    if (!$docEntry) {
                        throw new \RuntimeException('SAP did not return DocEntry');
                    }

                    $chunk->fill(['status' => 'posted', 'doc_entry' => $docEntry, 'doc_num' => $docNum, 'posted_at' => now(), 'error' => null])->save();
                    $this->logActivity('Drafts', $payload, $response, 201);

                    $totals['posted']++;
                    $totals['warehouses'][$wh]['posted']++;
                    $log("  chunk $idx posted -> DocEntry $docEntry (DocNum $docNum), $lineCount line(s).");
                    $results[] = ['warehouse' => $wh, 'chunk_index' => $idx, 'status' => 'posted', 'doc_entry' => $docEntry, 'doc_num' => $docNum, 'lines' => $lineCount, 'freight' => $freightTotal];
                } catch (\Throwable $e) {
                    $chunk->fill(['status' => 'failed', 'error' => $e->getMessage()])->save();
                    $this->logActivity('Drafts', $payload, ['error' => $e->getMessage()], 500);

                    $totals['failed']++;
                    $totals['warehouses'][$wh]['failed']++;
                    $log("  chunk $idx FAILED: " . $e->getMessage());
                    $results[] = ['warehouse' => $wh, 'chunk_index' => $idx, 'status' => 'failed', 'error' => $e->getMessage(), 'lines' => $lineCount];
                }
            }
        }

        $totals['exceptions'] = count($allExceptions);
        $totals['freight_total'] = round($totals['freight_total'], 2);

        // Persist artifacts.
        $stamp = now()->format('Ymd_His');
        $exPath = "draft_invoices/run_{$run->id}_{$stamp}_exceptions.json";
        Storage::disk('local')->put($exPath, json_encode($allExceptions, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));

        $paths = ['exceptions_path' => $exPath];
        if (!$post) {
            $pvPath = "draft_invoices/run_{$run->id}_{$stamp}_preview.json";
            Storage::disk('local')->put($pvPath, json_encode($previews, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
            $paths['preview_path'] = $pvPath;
        } else {
            $rsPath = "draft_invoices/run_{$run->id}_{$stamp}_result.json";
            Storage::disk('local')->put($rsPath, json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
            $paths['result_path'] = $rsPath;
        }

        $run->forceFill(array_merge($paths, [
            'totals' => $totals,
            'status' => 'done',
            'finished_at' => now(),
        ]))->save();

        $log("Done. drafts={$totals['drafts']} posted={$totals['posted']} skipped={$totals['skipped']} failed={$totals['failed']} exceptions={$totals['exceptions']}.");

        return $totals;
    }

    /**
     * Build a single draft-invoice payload for one chunk of rows.
     * @return array{0: array, 1: array, 2: float} [payload, exceptions, freightTotal]
     */
    protected function buildDraftPayload(array $chunkRows, string $wh, int $idx, ?string $cardCode, string $docDate, DraftInvoiceRun $run, callable $log): array
    {
        $lines = [];
        $exceptions = [];
        $freightTotal = 0.0;

        // CardCode falls back to the first row's BP if the run has none set.
        $cardCode = $cardCode ?: ($chunkRows[0]['card_code'] ?? null);

        foreach ($chunkRows as $row) {
            $itemCode = $row['item_code'];
            $qty = (float) $row['qty'];
            $freightTotal += (float) ($row['freight'] ?? 0);

            $info = $this->itemInfo($itemCode);

            $line = [
                'ItemCode' => $itemCode,
                'Quantity' => $qty,
                'UnitPrice' => round((float) $row['unit_price'], 4), // verbatim from file
                'WarehouseCode' => $wh,
                // Cost center (Dimension 1) = warehouse code, so the sale books
                // against the right store/warehouse cost center in SAP.
                'CostingCode' => $wh,
                // Force the base inventory unit (PC / حبة) so qty & price are
                // per-piece, NOT the item's default sales carton.
                'UoMEntry' => (int) ($info['uom_entry'] ?? config('draft_invoices.uom_entry', 58)),
            ];
            if ($run->tax_code) {
                $line['TaxCode'] = $run->tax_code;
            }

            // Attach FEFO batches for batch-managed items (unless batches are
            // explicitly disabled for this run, e.g. the Panda upload).
            if (!$run->no_batches) {
                $alloc = $this->allocateBatches($itemCode, $wh, $qty);
                if ($alloc['is_batch_item']) {
                    if (!empty($alloc['batches'])) {
                        $line['BatchNumbers'] = $alloc['batches'];
                    }
                    if ($alloc['shortfall'] > 0) {
                        $exceptions[] = [
                            'type' => $alloc['available'] <= 0 ? 'no_batch_in_warehouse' : 'qty_over_onhand',
                            'warehouse' => $wh, 'chunk_index' => $idx, 'item_code' => $itemCode,
                            'item_name' => $row['item_name'] ?? null,
                            'requested_qty' => $qty, 'available_qty' => $alloc['available'],
                            'shortfall' => round($alloc['shortfall'], 3),
                        ];
                    }
                }
            }

            $lines[] = $line;
        }

        $payload = [
            'DocObjectCode' => self::DOC_OBJECT_CODE,
            'CardCode' => $cardCode,
            'DocDate' => $docDate,
            'DocDueDate' => $docDate,
            'Comments' => sprintf('Sales import | %s | %s | part %d | %s', $run->source_file, $wh, $idx + 1, $cardCode),
            'DocumentLines' => $lines,
        ];

        // Freight summed into the header as an Additional Expense.
        $freightTotal = round($freightTotal, 2);
        if ($run->expense_code && $freightTotal > 0) {
            $payload['DocumentAdditionalExpenses'] = [[
                'ExpenseCode' => (int) $run->expense_code,
                'LineTotal' => $freightTotal,
            ]];
        }

        return [$payload, $exceptions, $freightTotal];
    }

    /**
     * FEFO allocation of a line quantity across a warehouse's batches.
     * Returns batches summing to $qty when >=1 batch exists (remainder, if the
     * line exceeds current on-hand, is placed on the nearest-expiry batch so the
     * draft stays internally consistent; the shortfall is reported separately).
     *
     * @return array{batches: array, allocated: float, shortfall: float, available: float, is_batch_item: bool}
     */
    protected function allocateBatches(string $itemCode, string $whsCode, float $qty): array
    {
        $rows = $this->batchRowsForWarehouse($itemCode, $whsCode);

        if (empty($rows)) {
            $isBatch = $this->isBatchManaged($itemCode);
            return [
                'batches' => [], 'allocated' => $isBatch ? 0.0 : $qty,
                'shortfall' => $isBatch ? $qty : 0.0, 'available' => 0.0,
                'is_batch_item' => $isBatch,
            ];
        }

        $available = array_sum(array_column($rows, 'Quantity'));
        $batches = [];
        $remaining = $qty;

        foreach ($rows as $r) {
            if ($remaining <= 0) {
                break;
            }
            $take = min($remaining, (float) $r['Quantity']);
            if ($take <= 0) {
                continue;
            }
            $batches[] = ['BatchNumber' => (string) $r['BatchNumber'], 'Quantity' => $take];
            $remaining -= $take;
        }

        $shortfall = max(0.0, $remaining);
        // Keep BatchNumbers sum == line qty: dump any remainder on nearest-expiry batch.
        if ($shortfall > 0 && !empty($batches)) {
            $batches[0]['Quantity'] += $shortfall;
        }

        return [
            'batches' => $batches,
            'allocated' => $qty,
            'shortfall' => $shortfall,
            'available' => (float) $available,
            'is_batch_item' => true,
        ];
    }

    /** Batch rows for an item filtered to one warehouse, sorted FEFO (nearest expiry first). */
    protected function batchRowsForWarehouse(string $itemCode, string $whsCode): array
    {
        if (!array_key_exists($itemCode, $this->batchRowCache)) {
            try {
                $resp = $this->sap->get("SQLQueries('batchesitems')/List", ['ItemCode' => "'$itemCode'"]);
                $this->batchRowCache[$itemCode] = $resp['value'] ?? [];
            } catch (\Throwable $e) {
                Log::warning("DraftInvoiceImport: batch query failed for $itemCode: " . $e->getMessage());
                $this->batchRowCache[$itemCode] = [];
            }
        }

        $rows = array_values(array_filter($this->batchRowCache[$itemCode], function ($r) use ($whsCode) {
            return ($r['WhsCode'] ?? null) === $whsCode
                && !empty($r['BatchNumber'])
                && (float) ($r['Quantity'] ?? 0) > 0;
        }));

        usort($rows, fn ($a, $b) => strcmp((string) ($a['ExpiryDate'] ?? '99999999'), (string) ($b['ExpiryDate'] ?? '99999999')));

        return $rows;
    }

    /** Whether SAP manages this item by batch. */
    protected function isBatchManaged(string $itemCode): bool
    {
        return $this->itemInfo($itemCode)['batch'];
    }

    /**
     * Per-item master info needed for lines (cached): batch-managed flag and
     * the base inventory UoM AbsEntry (PC / حبة).
     *
     * @return array{batch: bool, uom_entry: int|null}
     */
    protected function itemInfo(string $itemCode): array
    {
        if (!array_key_exists($itemCode, $this->itemInfoCache)) {
            try {
                $d = $this->sap->get("Items('$itemCode')", ['$select' => 'ManageBatchNumbers,InventoryUoMEntry']);
                $this->itemInfoCache[$itemCode] = [
                    'batch' => ($d['ManageBatchNumbers'] ?? 'tNO') === 'tYES',
                    'uom_entry' => isset($d['InventoryUoMEntry']) ? (int) $d['InventoryUoMEntry'] : null,
                ];
            } catch (\Throwable $e) {
                $this->itemInfoCache[$itemCode] = ['batch' => false, 'uom_entry' => null];
            }
        }

        return $this->itemInfoCache[$itemCode];
    }

    /**
     * Parse the upload (.xlsx or .csv) and map columns to canonical keys.
     * @return array{0: array, 1: array} [validRows, exceptions]
     */
    protected function parseAndMap(string $filePath): array
    {
        $ext = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
        $raw = $ext === 'csv' ? $this->readCsv($filePath) : $this->readXlsx($filePath);

        if (empty($raw)) {
            throw new \RuntimeException('File is empty or unreadable.');
        }

        $headerRow = array_shift($raw);
        $colMap = $this->mapHeaders($headerRow);

        foreach (['item_code', 'warehouse', 'qty', 'unit_price'] as $required) {
            if (!isset($colMap[$required])) {
                throw new \RuntimeException("Required column for '$required' not found in header: " . implode(', ', $headerRow));
            }
        }

        $rows = [];
        $exceptions = [];
        foreach ($raw as $n => $cells) {
            $get = fn (string $key) => isset($colMap[$key]) ? trim((string) ($cells[$colMap[$key]] ?? '')) : null;

            // Skip fully empty rows.
            if (count(array_filter($cells, fn ($v) => trim((string) $v) !== '')) === 0) {
                continue;
            }

            $itemCode = $get('item_code');
            $wh = $get('warehouse');
            $qty = (float) $get('qty');

            if ($itemCode === '' || $wh === '') {
                $exceptions[] = ['type' => 'missing_key', 'row' => $n + 2, 'item_code' => $itemCode, 'warehouse' => $wh];
                continue;
            }
            if ($qty <= 0) {
                $exceptions[] = ['type' => 'non_positive_qty', 'row' => $n + 2, 'item_code' => $itemCode, 'qty' => $qty];
                continue;
            }

            $rows[] = [
                'card_code' => $get('card_code'),
                'warehouse' => $wh,
                'order_date' => $get('order_date'),
                'order_number' => $get('order_number'),
                'item_code' => $itemCode,
                'item_name' => $get('item_name'),
                'uom' => $get('uom'),
                'qty' => $qty,
                'unit_price' => (float) $get('unit_price'),
                'freight' => (float) $get('freight'),
            ];
        }

        return [$rows, $exceptions];
    }

    protected function readXlsx(string $filePath): array
    {
        $reader = new XlsxReader();
        $reader->open($filePath);
        $out = [];
        foreach ($reader->getSheetIterator() as $sheet) {
            foreach ($sheet->getRowIterator() as $row) {
                $out[] = array_map(fn ($v) => $v instanceof \DateTimeInterface ? $v->format('Y-m-d') : $v, $row->toArray());
            }
            break; // first sheet only
        }
        $reader->close();
        return $out;
    }

    protected function readCsv(string $filePath): array
    {
        $out = [];
        if (($h = fopen($filePath, 'r')) !== false) {
            while (($data = fgetcsv($h)) !== false) {
                $out[] = $data;
            }
            fclose($h);
        }
        // Strip BOM from first header cell.
        if (isset($out[0][0])) {
            $out[0][0] = preg_replace('/^\xEF\xBB\xBF/', '', $out[0][0]);
        }
        return $out;
    }

    /** Map a header row to canonical-key => column-index. */
    protected function mapHeaders(array $headerRow): array
    {
        $map = [];
        foreach ($headerRow as $idx => $name) {
            $norm = strtolower(trim((string) $name));
            foreach ($this->headerAliases as $canonical => $aliases) {
                if (in_array($norm, $aliases, true) && !isset($map[$canonical])) {
                    $map[$canonical] = $idx;
                }
            }
        }
        return $map;
    }

    /**
     * Refuse to post a file under a different chunk_size than the one already
     * used to post some of its chunks (would otherwise duplicate sales).
     */
    protected function assertChunkSizeStable(DraftInvoiceRun $run, string $fileHash): void
    {
        $priorPostedRun = DraftInvoiceRun::query()
            ->where('file_hash', $fileHash)
            ->where('mode', 'post')
            ->whereIn('status', ['running', 'done'])
            ->where('id', '!=', $run->id)
            ->whereHas('chunks', fn ($q) => $q->where('status', 'posted'))
            ->orderBy('id')
            ->first();

        if ($priorPostedRun && (int) $priorPostedRun->chunk_size !== (int) $run->chunk_size) {
            throw new \RuntimeException(
                "This file was already partially posted with chunk size {$priorPostedRun->chunk_size}. " .
                "Re-run with --chunk={$priorPostedRun->chunk_size} to stay idempotent (different chunking would duplicate drafts)."
            );
        }
    }

    protected function logActivity(string $resource, array $payload, $response, int $status): void
    {
        try {
            ApiLog::create([
                'user_id' => auth()->id(),
                'method' => 'POST (DraftInvoice)',
                'endpoint' => $resource,
                'status_code' => $status,
                'request_payload' => json_encode($payload),
                'response_body' => json_encode($response),
                'database_name' => $this->sap->getCompanyDb(),
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);
        } catch (\Throwable $e) {
            // best-effort logging
        }
    }
}
