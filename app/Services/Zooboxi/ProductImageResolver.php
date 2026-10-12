<?php

namespace App\Services\Zooboxi;

use App\Models\Product;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Which pictures of this product actually exist on the internet?
 *
 * The store must never publish a card with a broken image (126 products were
 * hidden for exactly that at launch). Candidates in order of trust: the Zid
 * pictures we imported, the picture ShipGo's product master carries (which
 * includes what Zid stores such as Aleef uploaded), then the holeno gallery
 * guess by item code. Each URL is HEAD-checked once a day.
 */
class ProductImageResolver
{
    /**
     * @param  string[] $extra  candidate URLs discovered by the caller (ShipGo etc.)
     * @return string[]         verified URLs, best first
     */
    public function resolve(Product $product, array $extra = []): array
    {
        $candidates = [];
        foreach ((array) ($product->zb_images ?? []) as $u) {
            $candidates[] = $u;
        }
        foreach ($extra as $u) {
            $candidates[] = $u;
        }
        $candidates[] = 'https://gal.holeno.com/imghd/' . $product->item_code . '.png';
        $candidates[] = 'https://gal.holeno.com/img/' . $product->item_code . '.png';

        $ok = [];
        foreach (array_unique(array_filter(array_map('trim', $candidates))) as $url) {
            if (!preg_match('#^https?://#i', $url)) {
                continue;
            }
            if ($this->exists($url)) {
                $ok[] = $url;
            }
            if (count($ok) >= 6) {
                break;
            }
        }
        return $ok;
    }

    public function exists(string $url): bool
    {
        $key = 'zooboxi.img.' . md5($url);
        return (bool) Cache::remember($key, now()->addDay(), function () use ($url) {
            try {
                $res = Http::timeout(8)->withHeaders(['User-Agent' => 'Zooboxi-CatalogGate/1.0'])->head($url);
                if ($res->successful()) {
                    $type = strtolower((string) $res->header('Content-Type'));
                    return $type === '' || str_starts_with($type, 'image/');
                }
                // some galleries refuse HEAD — one small GET
                if (in_array($res->status(), [403, 405], true)) {
                    $get = Http::timeout(8)->withHeaders(['Range' => 'bytes=0-64'])->get($url);
                    return $get->successful() && str_starts_with(strtolower((string) $get->header('Content-Type')), 'image/');
                }
            } catch (\Throwable) {
            }
            return false;
        });
    }
}
