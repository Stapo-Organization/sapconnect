<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MuntajatCustomer;
use App\Services\ShipGo\MuntajatSapService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * READ-ONLY customer accounts of منتجات (company PPTC_V5_PROD) for the ShipGo WMS —
 * lets ShipGo link each store to its customer CardCode and show the SAP balance.
 * Reads the nightly mirror (muntajat_customers); `?live=1` on one account asks
 * the Service Layer directly (GET BusinessPartners('code') — never a write).
 * Bearer token: SHIPGO_API_TOKEN (same as /catalog).
 */
class ShipGoCustomerController extends Controller
{
    private const FIELDS = [
        'card_code', 'card_name', 'card_foreign_name', 'group_code', 'currency', 'federal_tax_id', 'city',
        'credit_limit', 'current_account_balance', 'open_orders_balance', 'open_delivery_notes_balance',
        'valid', 'frozen', 'sap_update_date', 'synced_at',
    ];

    /** ?q= (code / name / foreign name / VAT, ≥2 chars) or ?codes=C1,C2 (≤200) */
    public function index(Request $request): JsonResponse
    {
        $query = MuntajatCustomer::query()->select(self::FIELDS);
        $codes = array_values(array_filter(array_map('trim', explode(',', (string) $request->query('codes', '')))));
        $q = trim((string) $request->query('q', ''));

        if ($codes) {
            $query->whereIn('card_code', array_slice($codes, 0, 200));
        } elseif (mb_strlen($q) >= 2) {
            $like = '%' . str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $q) . '%';
            $query->where(function ($w) use ($like, $q) {
                $w->where('card_code', 'like', $like)
                  ->orWhere('card_name', 'like', $like)
                  ->orWhere('card_foreign_name', 'like', $like)
                  ->orWhere('federal_tax_id', 'like', $like);
            })->orderByRaw('card_code = ? desc', [$q])->orderBy('card_code')->limit(30);
        } else {
            return response()->json(['message' => 'Pass ?q= (2+ characters) or ?codes='], 422);
        }

        return response()->json(['company' => $this->company(), 'data' => $query->get()->map(fn ($c) => $this->row($c))->values()])
            ->header('X-Company', $this->company());
    }

    /** one account; ?live=1 reads the Service Layer now instead of last night's mirror */
    public function show(Request $request, string $cardCode, MuntajatSapService $sap): JsonResponse
    {
        $mirror = MuntajatCustomer::query()->select(self::FIELDS)->where('card_code', $cardCode)->first();
        if ($request->boolean('live')) {
            try {
                $bp = $sap->fetchCustomer($cardCode);
            } catch (\Throwable $e) {
                Log::warning('shipgo customer live read failed', ['card_code' => $cardCode, 'error' => $e->getMessage()]);
                $bp = null;
                if (! $mirror) {
                    return response()->json(['message' => 'SAP unreachable and no mirror row'], 502);
                }
            }
            if ($bp) {
                return response()->json(['company' => $this->company(), 'source' => 'live', 'data' => [
                    'card_code' => $bp['CardCode'] ?? $cardCode,
                    'card_name' => $bp['CardName'] ?? null,
                    'card_foreign_name' => $bp['CardForeignName'] ?? null,
                    'group_code' => $bp['GroupCode'] ?? null,
                    'currency' => $bp['Currency'] ?? null,
                    'federal_tax_id' => $bp['FederalTaxID'] ?? null,
                    'city' => $bp['City'] ?? null,
                    'credit_limit' => (float) ($bp['CreditLimit'] ?? 0),
                    'balance' => (float) ($bp['CurrentAccountBalance'] ?? 0),
                    'open_orders' => (float) ($bp['OpenOrdersBalance'] ?? 0),
                    'open_delivery_notes' => (float) ($bp['OpenDeliveryNotesBalance'] ?? 0),
                    'valid' => ($bp['Valid'] ?? 'tYES') === 'tYES',
                    'frozen' => ($bp['Frozen'] ?? 'tNO') === 'tYES',
                    'sap_update_date' => $bp['UpdateDate'] ?? null,
                    'as_of' => now()->toIso8601String(),
                ]])->header('X-Company', $this->company());
            }
        }
        if (! $mirror) {
            return response()->json(['message' => "Customer {$cardCode} not found"], 404);
        }

        return response()->json(['company' => $this->company(), 'source' => 'mirror', 'data' => $this->row($mirror)])
            ->header('X-Company', $this->company());
    }

    private function row(MuntajatCustomer $c): array
    {
        return [
            'card_code' => $c->card_code,
            'card_name' => $c->card_name,
            'card_foreign_name' => $c->card_foreign_name,
            'group_code' => $c->group_code,
            'currency' => $c->currency,
            'federal_tax_id' => $c->federal_tax_id,
            'city' => $c->city,
            'credit_limit' => (float) $c->credit_limit,
            'balance' => (float) $c->current_account_balance,
            'open_orders' => (float) $c->open_orders_balance,
            'open_delivery_notes' => (float) $c->open_delivery_notes_balance,
            'valid' => (bool) $c->valid,
            'frozen' => (bool) $c->frozen,
            'sap_update_date' => $c->sap_update_date ? (string) $c->sap_update_date : null,
            'as_of' => $c->synced_at ? \Illuminate\Support\Carbon::parse($c->synced_at)->toIso8601String() : null,
        ];
    }

    private function company(): string
    {
        return (string) config('sap.muntajat_company_db', 'PPTC_V5_PROD');
    }
}
