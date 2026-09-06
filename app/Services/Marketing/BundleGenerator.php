<?php

namespace App\Services\Marketing;

use App\Models\Brand;
use App\Models\ProductBundle;
use App\Models\ProductBundleItem;
use App\Models\WarehouseItemStock;
use App\Models\ZooboxiWarehouse;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * The nightly «حزم زوبوكسي» generator — the Mowkly playbook, automated.
 *
 * Four templates (seasonal is a skin, not a builder):
 *   stacking   — bulk of one fast item + free units («10 + 3 مجاناً»)
 *   variety    — top flavours of one brand/kind in one box («مشكل»)
 *   companion  — fast anchor + a small FBT partner as a gift
 *   smart_gift — fast anchor + an OVERSTOCK/DEAD item as the gift
 *                (clearance disguised as generosity: no public discount)
 *
 * Channel safety (owner-approved caps, 2026-09-07):
 *   - bundle_price >= Σcost * 1.10 — never below cost floor
 *   - free-value share <= 25% for healthy-stock bundles, 40% for smart_gift
 *   - no individual unit price is ever shown discounted; only the bundle sum
 *   - every bundle is a SUGGESTION until approved in the owner's app
 *
 * Stock awareness: a bundle carries stock_class express (every component held
 * by at least one express branch, K bundles deep) or central (city central /
 * main hub). A candidate no warehouse can build K times is dropped.
 */
class BundleGenerator
{
    public const CAP_HEALTHY = 25.0;
    public const CAP_GIFT = 40.0;
    public const MIN_MARKUP = 1.10;
    public const K_EXPRESS = 5;   // an express branch must cover 5 bundles
    public const K_CENTRAL = 3;

    private const MIN_PRICE = 60.0;   // bundle totals worth the name
    private const MAX_PRICE = 700.0;

    /** Names that mark hardware/services — never bundle anchors or gifts we can't feed. */
    private const HARDWARE = '/سرير|لعبة|ألعاب|كوخ|حامل|صحن|وعاء|مقص|فرشاة|قفص|بطانية|ناقل|شنطة|طوق|رسن|خدمة|شحن/u';

    private const SPECIES = [
        'cat' => '/قط|قطط|كيتن|هرر|\bcat|kitten|feline/iu',
        'dog' => '/كلب|كلاب|جرو|\bdog|puppy|canine/iu',
        'bird' => '/طيور|طائر|ببغاء|كناري|bird|parrot|canary/iu',
        'small_pet' => '/هامستر|أرنب|قوارض|hamster|rabbit|rodent|guinea/iu',
    ];

    private const KINDS = [
        'litter' => '/رمل|litter/iu',
        'treat' => '/مكاف|تريت|سناك|ستيك|treat|snack|stick|cream/iu',
        'wet' => '/رطب|باتيه|ظرف|أظرف|مرق|جيلي|شوربة|معلب|\bwet|pouch|pate|gravy|jelly|broth|canned|\bcan\b/iu',
        'dry' => '/جاف|دراي|\bdry|kibble/iu',
    ];

    /** @var array<string,array{express:array<string,array<int,string>>,central:array<string,array<int,string>>}> */
    private ?array $warehouses = null;

    /** @var array<string,array<string,float>> item_code => [sap_wh => stock] */
    private array $stockCache = [];

    /* ══════════════════════════════ entry ══════════════════════════════ */

    /**
     * @return array{created:int,skipped:int,by_template:array<string,int>}
     */
    public function generate(int $perTemplate = 12, ?string $species = null): array
    {
        $pool = $this->pool();
        if ($species !== null) {
            $pool = $pool->filter(fn ($it) => $it['species'] === $species)->values();
        }

        $openKeys = ProductBundle::whereIn('status', [
            ProductBundle::STATUS_SUGGESTED, ProductBundle::STATUS_APPROVED, ProductBundle::STATUS_LIVE,
        ])->pluck('anchor_item_code', 'bundle_key');

        $created = 0;
        $skipped = 0;
        $byTemplate = [];

        $builders = [
            'stacking' => fn () => $this->stackingCandidates($pool),
            'variety' => fn () => $this->varietyCandidates($pool),
            'companion' => fn () => $this->companionCandidates($pool),
            'smart_gift' => fn () => $this->smartGiftCandidates($pool),
        ];

        foreach ($builders as $template => $builder) {
            $count = 0;
            $usedAnchors = $openKeys->filter(fn ($v, $k) => str_starts_with($k, $template . ':'))
                ->values()->filter()->all();

            foreach ($builder() as $cand) {
                if ($count >= $perTemplate) {
                    break;
                }
                if ($openKeys->has($cand['bundle_key'])) {
                    $skipped++;
                    continue;
                }
                // One open bundle per anchor per template keeps the section varied.
                if (in_array($cand['anchor_item_code'], $usedAnchors, true)) {
                    $skipped++;
                    continue;
                }
                $scope = $this->viableScope($cand['items']);
                if ($scope === null) {
                    $skipped++;
                    continue;
                }
                if (! $this->guardOk($cand)) {
                    $skipped++;
                    continue;
                }

                $this->persist($cand, $scope);
                $openKeys->put($cand['bundle_key'], $cand['anchor_item_code']);
                $usedAnchors[] = $cand['anchor_item_code'];
                $created++;
                $count++;
            }
            $byTemplate[$template] = $count;
        }

        return ['created' => $created, 'skipped' => $skipped, 'by_template' => $byTemplate];
    }

    /** Expire suggestions nobody acted on. */
    public function expireStale(int $days = 14): int
    {
        return ProductBundle::where('status', ProductBundle::STATUS_SUGGESTED)
            ->where('created_at', '<', now()->subDays($days))
            ->update(['status' => ProductBundle::STATUS_REJECTED, 'rejected_reason' => 'انتهت صلاحية الاقتراح']);
    }

    /* ══════════════════════════════ pool ══════════════════════════════ */

    /**
     * Every bundle-eligible item with its economics, classified by species/kind.
     *
     * @return Collection<int,array<string,mixed>>
     */
    public function pool(): Collection
    {
        $rows = DB::table('product_intelligence as pi')
            ->join('products as p', function ($j) {
                $j->on('p.item_code', '=', 'pi.item_code')->where('p.source', 'production');
            })
            ->where('pi.warehouse_code', '')
            ->where('pi.unit_retail_sar', '>', 0)
            ->where('pi.unit_cost_sar', '>', 0)
            ->where('pi.current_stock', '>', 0)
            ->whereIn('pi.health_status', ['healthy', 'overstock', 'dead', 'low'])
            ->get([
                'pi.item_code', 'pi.velocity_blended', 'pi.health_status', 'pi.days_of_cover',
                'pi.unit_retail_sar', 'pi.unit_cost_sar', 'pi.excess_units', 'pi.capital_at_risk_sar',
                'p.zb_name_ar', 'p.item_name', 'p.piece_barcode', 'p.items_group_code',
            ]);

        return $rows->map(function ($r) {
            $name = $r->zb_name_ar ?: $r->item_name;
            if ($name === null || preg_match(self::HARDWARE, $name)) {
                return null;
            }

            return [
                'item_code' => $r->item_code,
                'name' => $name,
                'barcode' => (string) $r->piece_barcode,
                'brand_code' => (string) $r->items_group_code,
                'retail' => (float) $r->unit_retail_sar,
                'cost' => (float) $r->unit_cost_sar,
                'velocity' => (float) $r->velocity_blended,
                'health' => $r->health_status,
                'cover' => (float) ($r->days_of_cover ?? 0),
                'excess_units' => (float) $r->excess_units,
                'capital_at_risk' => (float) $r->capital_at_risk_sar,
                'species' => $this->speciesOf($name),
                'kind' => $this->kindOf($name),
            ];
        })->filter()->values();
    }

    public function speciesOf(string $name): string
    {
        foreach (self::SPECIES as $species => $re) {
            if (preg_match($re, $name)) {
                return $species;
            }
        }
        return 'mixed';
    }

    public function kindOf(string $name): ?string
    {
        foreach (self::KINDS as $kind => $re) {
            if (preg_match($re, $name)) {
                return $kind;
            }
        }
        return null;
    }

    /* ═══════════════════════════ templates ═══════════════════════════ */

    /**
     * Bulk one fast item + free units. Ladder by unit price so totals stay
     * shoppable and the free share never crosses the healthy cap.
     */
    private function stackingCandidates(Collection $pool): array
    {
        $out = [];
        $eligible = $pool->filter(fn ($it) => in_array($it['health'], ['healthy', 'overstock'], true)
            && $it['cover'] >= 45
            && in_array($it['kind'], ['wet', 'dry', 'treat', 'litter'], true)
            && $it['species'] !== 'mixed'
            && $it['velocity'] > 0)
            ->sortByDesc('velocity');

        foreach ($eligible as $it) {
            [$paid, $free] = $this->ladder($it['retail']);
            $sumRetail = ($paid + $free) * $it['retail'];
            $price = $paid * $it['retail'];
            if ($price < self::MIN_PRICE || $price > self::MAX_PRICE) {
                continue;
            }

            $out[] = $this->candidate('stacking', $it, [
                ['item' => $it, 'qty' => $paid + $free, 'role' => 'anchor'],
            ], [
                'name_ar' => sprintf('%d + %d مجاناً · %s', $paid, $free, $it['name']),
                'subtitle_ar' => sprintf('الإجمالي %d قطعة — تدفع ثمن %d فقط', $paid + $free, $paid),
                'free_label' => sprintf('%d+%d', $paid, $free),
                'sum_retail' => $sumRetail,
                'bundle_price' => $price,
                'cap' => self::CAP_HEALTHY,
                'score' => $it['velocity'] * 10,
                'rationale' => ['velocity' => $it['velocity'], 'cover' => $it['cover'], 'ladder' => "$paid+$free"],
            ]);
        }

        return $out;
    }

    /** «مشكل» — top flavours of one brand + kind + species, 20% off the sum. */
    private function varietyCandidates(Collection $pool): array
    {
        $out = [];
        $groups = $pool->filter(fn ($it) => $it['kind'] === 'wet'
            && in_array($it['health'], ['healthy', 'overstock'], true)
            && $it['species'] !== 'mixed'
            && $it['retail'] >= 3 && $it['retail'] <= 40)
            ->groupBy(fn ($it) => $it['brand_code'] . '|' . $it['species']);

        foreach ($groups as $key => $members) {
            $members = $members->sortByDesc('velocity')->take(5)->values();
            if ($members->count() < 3) {
                continue;
            }
            // Similar unit prices only — a 4 SAR can next to a 30 SAR can reads wrong.
            $prices = $members->pluck('retail');
            if ($prices->min() <= 0 || $prices->max() / $prices->min() > 1.6) {
                continue;
            }

            $n = $members->count();
            $qtyEach = (int) max(6, ceil(36 / $n));
            $total = $qtyEach * $n;
            $sumRetail = $members->sum(fn ($it) => $qtyEach * $it['retail']);
            $price = round($sumRetail * 0.80, 2);
            if ($price < self::MIN_PRICE || $price > self::MAX_PRICE) {
                continue;
            }
            $free = (int) floor($total * 0.20);

            [$brandCode, $species] = explode('|', $key);
            $brandName = Brand::where('code', $brandCode)->value('name') ?: '';
            $anchor = $members->first();

            $out[] = $this->candidate('variety', $anchor, $members->map(fn ($it, $i) => [
                'item' => $it, 'qty' => $qtyEach, 'role' => $i === 0 ? 'anchor' : 'member',
            ])->all(), [
                'name_ar' => sprintf('%d + %d مجاناً · مشكل %s %s', $total - $free, $free, $brandName, $this->speciesWord($species)),
                'subtitle_ar' => sprintf('%d نكهات × %d قطعة — تنويع لا يملّ', $n, $qtyEach),
                'free_label' => sprintf('%d+%d', $total - $free, $free),
                'sum_retail' => $sumRetail,
                'bundle_price' => $price,
                'cap' => self::CAP_HEALTHY,
                'score' => $members->sum('velocity') * 8,
                'rationale' => ['brand' => $brandName, 'flavours' => $n, 'qty_each' => $qtyEach],
            ]);
        }

        return $out;
    }

    /** Fast anchor + its best «يُشترى معاً» partner as a gift. */
    private function companionCandidates(Collection $pool): array
    {
        return $this->anchorPlusGift($pool, function (array $anchor, Collection $byCode) {
            $partners = DB::table('product_associations')
                ->where('item_code_a', $anchor['item_code'])
                ->where('rule_type', 'fbt')
                ->orderByDesc('lift')
                ->limit(10)
                ->get(['item_code_b', 'lift']);

            foreach ($partners as $p) {
                $gift = $byCode->get($p->item_code_b);
                if ($gift && in_array($gift['health'], ['healthy', 'overstock'], true)
                    && $this->speciesCompatible($anchor, $gift)) {
                    return [$gift, (float) $p->lift];
                }
            }
            return [null, 0.0];
        }, self::CAP_HEALTHY, 'companion');
    }

    /** Fast anchor + an OVERSTOCK/DEAD item as the gift — clearance in disguise. */
    private function smartGiftCandidates(Collection $pool): array
    {
        $giftPool = $pool->filter(fn ($it) => in_array($it['health'], ['overstock', 'dead'], true)
            && $it['kind'] !== null && $it['excess_units'] >= 10)
            ->sortByDesc('capital_at_risk')->values();

        return $this->anchorPlusGift($pool, function (array $anchor) use ($giftPool) {
            foreach ($giftPool as $gift) {
                if ($gift['item_code'] !== $anchor['item_code']
                    && $this->speciesCompatible($anchor, $gift)
                    && $gift['retail'] <= $anchor['retail'] * 0.5) {
                    return [$gift, 0.0];
                }
            }
            return [null, 0.0];
        }, self::CAP_GIFT, 'smart_gift');
    }

    /**
     * Shared shape of companion/smart_gift: customer pays the anchor's retail,
     * the partner rides along free, sized so the free share respects the cap.
     *
     * @param callable(array,Collection):array{0:?array,1:float} $pickGift
     */
    private function anchorPlusGift(Collection $pool, callable $pickGift, float $cap, string $template): array
    {
        $byCode = $pool->keyBy('item_code');
        $out = [];

        $anchors = $pool->filter(fn ($it) => in_array($it['health'], ['healthy', 'overstock'], true)
            && $it['retail'] >= self::MIN_PRICE
            && in_array($it['kind'], ['wet', 'dry', 'litter'], true)
            && $it['species'] !== 'mixed'
            && $it['velocity'] > 0)
            ->sortByDesc('velocity');

        foreach ($anchors as $anchor) {
            [$gift, $lift] = $pickGift($anchor, $byCode);
            if ($gift === null || $gift['retail'] <= 0) {
                continue;
            }

            // Largest gift qty that keeps the free share under the cap.
            $qty = (int) floor(($cap / 100) * $anchor['retail'] / ((1 - $cap / 100) * $gift['retail']));
            $qty = min($qty, 20);
            if ($qty < 1) {
                continue;
            }

            $giftVal = $qty * $gift['retail'];
            $sumRetail = $anchor['retail'] + $giftVal;
            $price = $anchor['retail'];
            if ($price > self::MAX_PRICE) {
                continue;
            }

            $score = $template === 'companion'
                ? $lift * 25
                : 20 + $gift['capital_at_risk'] / 1000 + $anchor['velocity'];

            $out[] = $this->candidate($template, $anchor, [
                ['item' => $anchor, 'qty' => 1, 'role' => 'anchor'],
                ['item' => $gift, 'qty' => $qty, 'role' => 'gift'],
            ], [
                'name_ar' => sprintf('%s + %s%s هدية', $anchor['name'], $qty > 1 ? $qty . ' × ' : '', $this->shortName($gift['name'])),
                'subtitle_ar' => $template === 'smart_gift'
                    ? sprintf('هدية بقيمة %s ريال معه مجاناً', number_format($giftVal, 0))
                    : 'يشتريان معاً دائماً — والثاني علينا',
                'free_label' => 'هدية',
                'sum_retail' => $sumRetail,
                'bundle_price' => $price,
                'cap' => $cap,
                'score' => $score,
                'rationale' => $template === 'companion'
                    ? ['lift' => $lift, 'gift' => $gift['item_code'], 'gift_qty' => $qty]
                    : ['gift_health' => $gift['health'], 'gift' => $gift['item_code'], 'gift_qty' => $qty,
                        'capital_at_risk' => $gift['capital_at_risk']],
            ]);
        }

        return $out;
    }

    /* ═══════════════════════════ mechanics ═══════════════════════════ */

    /** @return array{0:int,1:int} [paid, free] */
    public function ladder(float $retail): array
    {
        return match (true) {
            $retail <= 20 => [12, 3],
            $retail <= 60 => [10, 3],
            $retail <= 120 => [4, 1],
            default => [3, 1],
        };
    }

    private function speciesCompatible(array $a, array $b): bool
    {
        return $b['species'] === $a['species'] || $b['species'] === 'mixed';
    }

    private function speciesWord(string $species): string
    {
        return match ($species) {
            'cat' => 'للقطط', 'dog' => 'للكلاب', 'bird' => 'للطيور', 'small_pet' => 'للقوارض', default => '',
        };
    }

    private function shortName(string $name): string
    {
        $name = trim(preg_replace('/\s+/u', ' ', $name));
        $words = preg_split('/\s/u', $name) ?: [];
        return count($words) > 6 ? implode(' ', array_slice($words, 0, 6)) : $name;
    }

    private function candidate(string $template, array $anchor, array $lines, array $extra): array
    {
        $codes = collect($lines)->map(fn ($l) => $l['item']['item_code'] . 'x' . $l['qty'])->sort()->implode(',');

        $sumCost = collect($lines)->sum(fn ($l) => $l['qty'] * $l['item']['cost']);
        $species = collect($lines)->pluck('item.species')->filter(fn ($s) => $s !== 'mixed')->unique();

        return array_merge([
            'template' => $template,
            'bundle_key' => $template . ':' . md5($codes),
            'anchor_item_code' => $anchor['item_code'],
            'species' => $species->count() === 1 ? $species->first() : 'mixed',
            'kind' => $anchor['kind'],
            'sum_cost' => $sumCost,
            'floor_price' => $sumCost * self::MIN_MARKUP,
            'items' => $lines,
        ], $extra);
    }

    /** The two hard rules. A candidate that breaks either never reaches the owner. */
    public function guardOk(array $cand): bool
    {
        if ($cand['bundle_price'] < $cand['floor_price'] - 0.001) {
            return false;
        }
        if ($cand['sum_retail'] <= 0) {
            return false;
        }
        $savings = (1 - $cand['bundle_price'] / $cand['sum_retail']) * 100;

        return $savings <= ($cand['cap'] ?? self::CAP_HEALTHY) + 0.01 && $savings >= 5;
    }

    /**
     * Which warehouses can actually build this bundle K times over?
     * Returns ['class' => express|central, 'warehouses' => [...]] or null.
     */
    public function viableScope(array $lines): ?array
    {
        $map = $this->warehouseMap();
        $needs = collect($lines)->mapWithKeys(fn ($l) => [$l['item']['item_code'] => $l['qty']]);
        $this->primeStock($needs->keys()->all());

        $express = [];
        foreach ($map['express'] as $whCode => $sapCodes) {
            if ($this->covers($needs, $sapCodes, self::K_EXPRESS)) {
                $express[] = $whCode;
            }
        }
        if (! empty($express)) {
            return ['class' => 'express', 'warehouses' => $express];
        }

        $central = [];
        foreach ($map['central'] as $whCode => $sapCodes) {
            if ($this->covers($needs, $sapCodes, self::K_CENTRAL)) {
                $central[] = $whCode;
            }
        }

        return empty($central) ? null : ['class' => 'central', 'warehouses' => $central];
    }

    private function covers(Collection $needs, array $sapCodes, int $k): bool
    {
        foreach ($needs as $code => $qty) {
            $held = 0.0;
            foreach ($sapCodes as $sap) {
                $held += $this->stockCache[$code][$sap] ?? 0.0;
            }
            if ($held < $qty * $k) {
                return false;
            }
        }
        return true;
    }

    private function warehouseMap(): array
    {
        if ($this->warehouses !== null) {
            return $this->warehouses;
        }

        $express = [];
        $central = [];
        foreach (ZooboxiWarehouse::where('is_active', true)->get() as $wh) {
            $sap = $wh->sap_warehouse_codes;
            if (is_string($sap)) {
                $sap = json_decode($sap, true);
            }
            $sap = array_values(array_filter((array) ($sap ?: [$wh->warehouse_code])));
            if ($wh->is_central || $wh->is_main_hub) {
                $central[$wh->warehouse_code] = $sap;
            } else {
                $express[$wh->warehouse_code] = $sap;
            }
        }

        return $this->warehouses = ['express' => $express, 'central' => $central];
    }

    private function primeStock(array $codes): void
    {
        $missing = array_diff($codes, array_keys($this->stockCache));
        if (empty($missing)) {
            return;
        }
        $rows = WarehouseItemStock::whereIn('item_code', $missing)->get(['item_code', 'warehouse_code', 'in_stock']);
        foreach ($missing as $code) {
            $this->stockCache[$code] = [];
        }
        foreach ($rows as $r) {
            $this->stockCache[$r->item_code][$r->warehouse_code] = (float) $r->in_stock;
        }
    }

    private function persist(array $cand, array $scope): ProductBundle
    {
        return DB::transaction(function () use ($cand, $scope) {
            $savings = round((1 - $cand['bundle_price'] / $cand['sum_retail']) * 100, 2);

            $bundle = ProductBundle::create([
                'bundle_key' => $cand['bundle_key'],
                'template' => $cand['template'],
                'status' => ProductBundle::STATUS_SUGGESTED,
                'name_ar' => mb_substr($cand['name_ar'], 0, 250),
                'subtitle_ar' => $cand['subtitle_ar'] ?? null,
                'free_label' => $cand['free_label'] ?? null,
                'anchor_item_code' => $cand['anchor_item_code'],
                'species' => $cand['species'],
                'kind' => $cand['kind'],
                'sum_retail' => round($cand['sum_retail'], 4),
                'bundle_price' => round($cand['bundle_price'], 4),
                'sum_cost' => round($cand['sum_cost'], 4),
                'floor_price' => round($cand['floor_price'], 4),
                'savings_pct' => $savings,
                'stock_class' => $scope['class'],
                'warehouse_scope' => $scope['warehouses'],
                'score' => round($cand['score'], 3),
                'rationale' => $cand['rationale'] ?? null,
                'computed_at' => now(),
            ]);

            foreach ($cand['items'] as $line) {
                ProductBundleItem::create([
                    'product_bundle_id' => $bundle->id,
                    'item_code' => $line['item']['item_code'],
                    'item_name' => $line['item']['name'],
                    'barcode' => $line['item']['barcode'],
                    'qty' => $line['qty'],
                    'role' => $line['role'],
                    'unit_retail' => $line['item']['retail'],
                    'unit_cost' => $line['item']['cost'],
                ]);
            }

            return $bundle;
        });
    }
}
