<?php

namespace App\Services\Zooboxi;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Store-scoped reads against ShipGo's channel API (`/v1/channel/*`), the same
 * surface the shipgo-connect plugin uses. Authenticated with the Zooboxi
 * WooCommerce connection's store key (sk_…), copied from the store's
 * «ShipGo Connect» settings into SHIPGO_STORE_KEY.
 *
 * The gate only needs one question answered here: does ShipGo hold sellable
 * stock (ATP) for these SKUs in RUH003, and what does its product master know
 * (name, picture, weight)? Absent key → every answer is "unknown", never "0".
 */
class ShipGoChannelClient
{
    public function __construct(
        private ?string $baseUrl = null,
        private ?string $storeKey = null,
    ) {
        $this->baseUrl = rtrim($baseUrl ?? (string) config('services.shipgo.base_url', 'https://wms.stapo.io'), '/');
        $this->storeKey = $storeKey ?? (string) config('services.shipgo.store_key', '');
    }

    public function configured(): bool
    {
        return $this->storeKey !== '';
    }

    /**
     * Batch lookup: SKU → ['atp' => int, 'name' => ?, 'name_ar' => ?, 'image_url' => ?, 'weight_g' => ?]
     * Missing SKUs are simply absent from the result; a transport failure
     * returns null so callers can tell "no stock" from "no answer".
     *
     * @param  string[] $skus
     * @return array<string, array>|null
     */
    public function lookup(array $skus): ?array
    {
        $skus = array_values(array_unique(array_filter(array_map('strval', $skus))));
        if (!$this->configured() || empty($skus)) {
            return $this->configured() ? [] : null;
        }

        $out = [];
        foreach (array_chunk($skus, 200) as $chunk) {
            try {
                $res = Http::withToken($this->storeKey)
                    ->acceptJson()
                    ->timeout(20)
                    ->post($this->baseUrl . '/v1/channel/catalog/lookup', ['skus' => $chunk]);
            } catch (\Throwable $e) {
                Log::warning('ShipGo catalog lookup failed', ['error' => $e->getMessage()]);
                return null;
            }
            if (!$res->successful()) {
                Log::warning('ShipGo catalog lookup HTTP error', ['status' => $res->status(), 'body' => mb_substr($res->body(), 0, 300)]);
                return null;
            }
            $rows = $res->json('data.results') ?? $res->json('results') ?? [];
            foreach ($rows as $row) {
                if (!empty($row['sku'])) {
                    $out[(string) $row['sku']] = [
                        'matched' => (bool) ($row['matched'] ?? false),
                        'atp' => (int) ($row['atp'] ?? 0),
                        'name' => $row['name'] ?? null,
                        'name_ar' => $row['name_ar'] ?? null,
                        'image_url' => $row['image_url'] ?? null,
                        'weight_g' => isset($row['weight_g']) ? (float) $row['weight_g'] : null,
                    ];
                }
            }
        }
        return $out;
    }
}
