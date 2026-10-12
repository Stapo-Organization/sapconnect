<?php

namespace App\Services\Zooboxi;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * The store's live `product_cat` tree, read through the WooCommerce REST API
 * with the consumer key already in `.env`. The copywriter must place a new
 * product inside categories shoppers already browse — inventing a fresh
 * «طعام القطط» next to the existing «قطط > طعام رطب» would fork the catalogue.
 *
 * Returns paths like "قطط > طعام رطب > أكياس". Cached 6h; an unreachable store
 * yields [] and the caller falls back to brand-only placement.
 */
class WooCategoryTree
{
    public const CACHE_KEY = 'zooboxi.woo.category_paths';

    /** @return string[] */
    public function paths(): array
    {
        return Cache::remember(self::CACHE_KEY, now()->addHours(6), fn () => $this->fetchPaths());
    }

    public function forget(): void
    {
        Cache::forget(self::CACHE_KEY);
    }

    private function fetchPaths(): array
    {
        $base = rtrim((string) config('services.woo.store_url'), '/');
        $key = (string) config('services.woo.consumer_key');
        $secret = (string) config('services.woo.consumer_secret');
        if ($base === '' || $key === '' || $secret === '') {
            return [];
        }

        $terms = [];
        for ($page = 1; $page <= 30; $page++) {
            try {
                $res = Http::withBasicAuth($key, $secret)->acceptJson()->timeout(30)
                    ->get($base . '/wp-json/wc/v3/products/categories', [
                        'per_page' => 100, 'page' => $page, 'hide_empty' => false, '_fields' => 'id,name,parent',
                    ]);
            } catch (\Throwable $e) {
                Log::warning('Woo category tree fetch failed', ['error' => $e->getMessage()]);
                return [];
            }
            if (!$res->successful()) {
                Log::warning('Woo category tree HTTP error', ['status' => $res->status()]);
                return [];
            }
            $rows = $res->json();
            if (!is_array($rows) || empty($rows)) {
                break;
            }
            foreach ($rows as $r) {
                $terms[(int) $r['id']] = ['name' => html_entity_decode((string) $r['name']), 'parent' => (int) ($r['parent'] ?? 0)];
            }
            if (count($rows) < 100) {
                break;
            }
        }

        $paths = [];
        foreach ($terms as $id => $t) {
            $chain = [];
            $cur = $id;
            $guard = 0;
            while ($cur && isset($terms[$cur]) && $guard++ < 10) {
                array_unshift($chain, $terms[$cur]['name']);
                $cur = $terms[$cur]['parent'];
            }
            if ($chain && strcasecmp($chain[0], 'Uncategorized') !== 0 && $chain[0] !== 'غير مصنف') {
                $paths[] = implode(' > ', $chain);
            }
        }
        sort($paths, SORT_NATURAL);
        return array_values(array_unique($paths));
    }
}
