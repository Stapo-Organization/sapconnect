<?php

namespace App\Services\Zooboxi;

use App\Models\Product;
use App\Models\WarehouseItemStock;
use App\Models\ZooboxiWarehouse;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * بوابة كتالوج زوبوكسي.
 *
 * A production item goes live on store.zooboxi.com by itself the moment it is
 * ready — and "ready" is a checklist the owner can read, not a toggle someone
 * has to remember:
 *
 *   price      the store's price list carries a price > 0
 *   barcode    a piece barcode (it becomes the store SKU ShipGo matches on)
 *   brand      a brand row (the store files products under it)
 *   stock      sellable somewhere: an EXPRESS branch, the SAP mirror of the
 *              ShipGo warehouse, or ShipGo's own live ATP
 *   picture    at least one image URL that really answers (HEAD 200)
 *
 * Anything short is HELD with its reasons and re-checked next run; the queue
 * page shows the reasons so the fix is obvious (upload a picture, set a price).
 * Passing products get storefront copy (Claude → SAP fallback), the verified
 * picture list, and `zooboxi_active = true` — the existing product feed and
 * the store's hourly pull do the rest. The gate never de-activates: WooCommerce
 * already hides out-of-stock products, and a human decides a delisting.
 */
class CatalogGateService
{
    public const REASONS = [
        'not_production' => 'ليس صنف إنتاج',
        'no_price' => 'بدون سعر في قائمة المتجر',
        'no_barcode' => 'بدون باركود',
        'no_brand' => 'بدون براند',
        'no_stock' => 'لا مخزون (إكسبريس / ShipGo)',
        'no_image' => 'بدون صورة',
    ];

    public function __construct(
        private ShipGoChannelClient $shipgo,
        private ProductImageResolver $images,
        private CatalogCopywriter $copy,
        private WooCategoryTree $categories,
    ) {
    }

    /**
     * Evaluate a batch. Returns counters + per-item outcomes.
     *
     * @param  string[]|null $itemCodes  restrict to these items (the page's «تحقق الآن»)
     * @param  bool          $force      skip the stock rule (owner's «تفعيل الآن»)
     */
    public function run(bool $dryRun = false, int $limit = 150, ?array $itemCodes = null, bool $force = false): array
    {
        $q = Product::query()->production()
            ->where('zooboxi_active', false)
            ->where('zooboxi_gate_status', '<>', 'blocked')
            ->with('brand');
        if ($itemCodes) {
            $q->whereIn('item_code', $itemCodes);
        } else {
            // never-checked first, then the longest-ago
            $q->orderByRaw('zooboxi_gate_checked_at is null desc')->orderBy('zooboxi_gate_checked_at')->limit($limit);
        }
        /** @var Collection<int,Product> $products */
        $products = $q->get();

        $summary = ['checked' => 0, 'activated' => 0, 'held' => 0, 'errors' => 0, 'items' => []];
        if ($products->isEmpty()) {
            return $summary;
        }

        $codes = $products->pluck('item_code')->all();
        $express = $this->expressStock($codes);
        $hub = $this->shipgoWarehouseStock($codes);
        $live = $this->shipgo->lookup($products->pluck('piece_barcode')->filter()->values()->all());
        $tree = null; // fetched lazily — only when something actually passes

        foreach ($products as $p) {
            $summary['checked']++;
            try {
                $sku = (string) ($p->piece_barcode ?? '');
                $facts = ($sku !== '' && is_array($live)) ? ($live[$sku] ?? null) : null;

                $reasons = $this->reasons($p, $express, $hub, $facts, $force);
                $verified = [];
                if (!in_array('no_price', $reasons, true) && !in_array('no_barcode', $reasons, true)) {
                    // Only pay for image checks when the cheap rules already pass.
                    $verified = $this->images->resolve($p, array_filter([$facts['image_url'] ?? null]));
                    if (empty($verified)) {
                        $reasons[] = 'no_image';
                    }
                }

                if (!empty($reasons)) {
                    $summary['held']++;
                    $summary['items'][] = ['item_code' => $p->item_code, 'result' => 'held', 'reasons' => $reasons];
                    if (!$dryRun) {
                        $this->hold($p, $reasons);
                    }
                    continue;
                }

                $summary['activated']++;
                $summary['items'][] = ['item_code' => $p->item_code, 'result' => 'activated'];
                if ($dryRun) {
                    continue;
                }
                $tree ??= $this->categories->paths();
                $this->activate($p, $verified, $facts ?? [], $tree);
            } catch (\Throwable $e) {
                $summary['errors']++;
                $summary['items'][] = ['item_code' => $p->item_code, 'result' => 'error', 'error' => $e->getMessage()];
                Log::error('Zooboxi gate error', ['item' => $p->item_code, 'error' => $e->getMessage()]);
                if (!$dryRun) {
                    $this->event($p->item_code, 'error', null, mb_substr($e->getMessage(), 0, 480));
                }
            }
        }
        return $summary;
    }

    /** The checklist, minus the picture (checked separately because it costs HTTP calls). */
    public function reasons(Product $p, array $express, array $hub, ?array $facts, bool $force = false): array
    {
        $r = [];
        if ($p->source !== 'production') {
            $r[] = 'not_production';
        }
        if ($this->shelfPrice($p) === null) {
            $r[] = 'no_price';
        }
        if (trim((string) $p->piece_barcode) === '') {
            $r[] = 'no_barcode';
        }
        if (!$p->brand) {
            $r[] = 'no_brand';
        }
        if (!$force) {
            $exp = (float) ($express[$p->item_code] ?? 0);
            $hubQty = (float) ($hub[$p->item_code] ?? 0);
            $atp = (int) ($facts['atp'] ?? 0);
            if ($exp <= 0 && $hubQty <= 0 && $atp <= 0) {
                $r[] = 'no_stock';
            }
        }
        return $r;
    }

    public function shelfPrice(Product $p): ?float
    {
        $list = (int) config('services.zooboxi_gate.price_list', 1);
        foreach ((array) ($p->prices ?? []) as $key => $row) {
            if (!is_array($row)) {
                continue;
            }
            $pl = $row['PriceList'] ?? $row['priceList'] ?? $row['price_list'] ?? (is_numeric($key) ? (int) $key : null);
            if ($pl !== null && (int) $pl === $list) {
                $price = (float) ($row['Price'] ?? $row['price'] ?? 0);
                return $price > 0 ? $price : null;
            }
        }
        return null;
    }

    public function block(Product $p, ?string $note = null): void
    {
        $p->forceFill(['zooboxi_gate_status' => 'blocked', 'zooboxi_active' => false])->save();
        $this->event($p->item_code, 'blocked', null, $note);
    }

    public function unblock(Product $p): void
    {
        $p->forceFill(['zooboxi_gate_status' => 'pending', 'zooboxi_gate_checked_at' => null])->save();
        $this->event($p->item_code, 'unblocked');
    }

    // --- internals ---------------------------------------------------------

    private function hold(Product $p, array $reasons): void
    {
        $changed = $p->zooboxi_gate_status !== 'held' || $p->zooboxi_gate_reasons !== $reasons;
        $p->forceFill([
            'zooboxi_gate_status' => 'held',
            'zooboxi_gate_reasons' => $reasons,
            'zooboxi_gate_checked_at' => now(),
        ])->save();
        if ($changed) {
            $this->event($p->item_code, 'held', $reasons);
        }
    }

    private function activate(Product $p, array $verifiedImages, array $facts, array $tree): void
    {
        $fill = [
            'zooboxi_active' => true,
            'woo_sync' => true,
            'zooboxi_gate_status' => 'active',
            'zooboxi_gate_reasons' => null,
            'zooboxi_gate_checked_at' => now(),
            'zooboxi_activated_at' => now(),
            'zb_resolved_images' => $verifiedImages,
        ];
        if (empty($p->zb_images)) {
            $fill['zb_images'] = $verifiedImages;
        }

        // Storefront copy — only where the product has none (the Zid import is never overwritten).
        $contentSource = null;
        if (trim((string) $p->zb_name_ar) === '') {
            $copy = $this->copy->write($p, $tree, $facts);
            if ($copy) {
                $fill += [
                    'zb_name_ar' => $copy['name_ar'],
                    'zb_name_en' => $copy['name_en'] ?: ($facts['name'] ?? $p->item_name),
                    'zb_short_description_ar' => $copy['short_ar'],
                    'zb_short_description_en' => $copy['short_en'],
                    'zb_description_ar' => $copy['desc_ar'],
                    'zb_description_en' => $copy['desc_en'],
                    'zb_categories_ar' => $copy['category_path'] ?: null,
                    'zb_keywords' => $copy['keywords'],
                    'zb_seo_title_ar' => $copy['seo_title_ar'],
                    'zb_seo_description_ar' => $copy['seo_description_ar'],
                ];
                $contentSource = 'ai';
            } else {
                // Honest fallback: SAP carries an Arabic foreign name and an English item name.
                $ar = $this->looksArabic($p->foreign_name) ? $p->foreign_name : ($facts['name_ar'] ?? null);
                $fill += [
                    'zb_name_ar' => $ar ?: ($p->item_name ?: $p->item_code),
                    'zb_name_en' => $facts['name'] ?? ($p->item_name ?: null),
                ];
                $contentSource = 'sap';
            }
            if (!empty($facts['weight_g']) && empty($p->zb_weight)) {
                $fill['zb_weight'] = round(((float) $facts['weight_g']) / 1000, 3);
                $fill['zb_weight_unit'] = 'kg';
            }
            $fill['zb_content_source'] = $contentSource;
            $fill['zb_content_at'] = now();
        }

        DB::transaction(function () use ($p, $fill, $contentSource) {
            $p->forceFill($fill)->save();
            $this->event($p->item_code, 'activated', null, $contentSource ? "content:{$contentSource}" : null);
        });
    }

    private function event(string $itemCode, string $action, ?array $reasons = null, ?string $note = null): void
    {
        DB::table('zooboxi_gate_events')->insert([
            'item_code' => $itemCode,
            'action' => $action,
            'reasons' => $reasons ? json_encode($reasons) : null,
            'note' => $note,
            'created_at' => now(),
        ]);
    }

    /** item_code → units across the EXPRESS branches (active, delivering, not the shipping hub). */
    private function expressStock(array $itemCodes): array
    {
        $hubCode = (string) config('services.zooboxi_gate.shipgo_warehouse', 'RUH003');
        $codes = [];
        foreach (ZooboxiWarehouse::active()->where('express_radius_km', '>', 0)->get() as $wh) {
            $sap = is_array($wh->sap_warehouse_codes) ? $wh->sap_warehouse_codes : (json_decode((string) $wh->sap_warehouse_codes, true) ?: []);
            foreach ($sap as $c) {
                if ($c !== $hubCode) {
                    $codes[] = $c;
                }
            }
        }
        if (empty($codes)) {
            return [];
        }
        return WarehouseItemStock::whereIn('item_code', $itemCodes)->whereIn('warehouse_code', array_unique($codes))
            ->groupBy('item_code')->selectRaw('item_code, sum(in_stock) as q')->pluck('q', 'item_code')->all();
    }

    /** item_code → SAP mirror of the ShipGo warehouse (RUH003). */
    private function shipgoWarehouseStock(array $itemCodes): array
    {
        $hubCode = (string) config('services.zooboxi_gate.shipgo_warehouse', 'RUH003');
        return WarehouseItemStock::whereIn('item_code', $itemCodes)->where('warehouse_code', $hubCode)
            ->groupBy('item_code')->selectRaw('item_code, sum(in_stock) as q')->pluck('q', 'item_code')->all();
    }

    private function looksArabic(?string $s): bool
    {
        return $s !== null && preg_match('/\p{Arabic}/u', $s) === 1;
    }
}
