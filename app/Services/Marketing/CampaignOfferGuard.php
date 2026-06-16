<?php

namespace App\Services\Marketing;

use App\Models\Product;
use App\Models\ProductCost;
use App\Models\ZooboxiSetting;
use Illuminate\Validation\ValidationException;

/**
 * The ONE wholesale-channel-safety guard for campaign offers. Used at BOTH
 * suggestion and approval. Mirrors PlanClearance floor math exactly:
 *   floor_price = max(cost * 1.10, retail * 1.00)
 *
 * Hard rules enforced here (auditor fixes C1–C3, H4):
 *  - Coupons are validated as a PERCENT discount, per-line, against the CURRENT
 *    effective price (not bare retail) — never below floor.
 *  - The ceiling (mkt_coupon_ceiling_pct) is a blunt cap; the floor is the only
 *    real wholesale protection. Single source of truth = this guard + settings.
 *  - Any missing cost/retail collapses the safe discount to 0 (→ visibility).
 *  - This class NEVER writes _sale_price or SAP prices.
 */
class CampaignOfferGuard
{
    public const MIN_MARKUP_OVER_COST = 0.10; // cost * 1.10
    public const WHOLESALE_FLOOR_FACTOR = 1.0; // retail * 1.00

    public function floorPrice(?float $cost, ?float $retail): float
    {
        $costFloor = ($cost && $cost > 0) ? $cost * (1 + self::MIN_MARKUP_OVER_COST) : 0.0;
        $retailFloor = ($retail && $retail > 0) ? $retail * self::WHOLESALE_FLOOR_FACTOR : 0.0;
        return max($costFloor, $retailFloor);
    }

    public function couponCeilingPct(): float
    {
        $v = ZooboxiSetting::where('key', 'mkt_coupon_ceiling_pct')->value('value');
        return $v !== null ? (float) $v : 25.0;
    }

    /**
     * Build a price line for an item from SAP retail + cost proxy.
     *
     * @return array{item_code:string,retail:float,cost:float,base:float,floor:float}
     */
    public function lineFor(string $itemCode, ?float $base = null): array
    {
        $retail = $this->retailOf($itemCode);
        $cost = (float) (ProductCost::where('item_code', $itemCode)->value('cost_proxy_sar') ?? 0);
        $floor = $this->floorPrice($cost, $retail);

        return [
            'item_code' => $itemCode,
            'retail' => $retail,
            'cost' => $cost,
            'base' => $base ?? $retail, // current effective price (caller may pass a live sale price)
            'floor' => $floor,
        ];
    }

    /**
     * Evaluate an offer against every line. Visibility is always safe.
     *
     * @param array<int,array{item_code:string,retail:float,cost:float,base:float,floor:float}> $lines
     * @return array{safe:bool,max_discount_pct:float,effective_price_min:float,violations:array<int,string>}
     */
    public function evaluate(string $scope, ?float $discountPct, array $lines): array
    {
        if ($scope === 'visibility' || empty($lines)) {
            return ['safe' => true, 'max_discount_pct' => 0.0, 'effective_price_min' => 0.0, 'violations' => []];
        }

        $ceiling = $this->couponCeilingPct();
        $pct = (float) ($discountPct ?? 0);
        $violations = [];
        $maxSafe = 100.0;
        $minEffective = PHP_FLOAT_MAX;

        foreach ($lines as $line) {
            $base = (float) $line['base'];
            $floor = (float) $line['floor'];

            // Per-line max safe discount: keep base*(1-p) >= floor
            $lineMax = ($base > 0 && $floor < $base) ? (1 - $floor / $base) * 100 : 0.0;
            $maxSafe = min($maxSafe, $lineMax);

            $effective = $base * (1 - $pct / 100);
            $minEffective = min($minEffective, $effective);

            if ($pct > 0 && $effective < $floor - 0.001) {
                $violations[] = sprintf(
                    '%s: السعر الفعلي %.2f يقل عن الحد الأرضي %.2f',
                    $line['item_code'], $effective, $floor
                );
            }
        }

        $maxSafe = max(0.0, min($maxSafe, $ceiling));

        return [
            'safe' => empty($violations) && $pct <= $ceiling + 0.001,
            'max_discount_pct' => round($maxSafe, 2),
            'effective_price_min' => $minEffective === PHP_FLOAT_MAX ? 0.0 : round($minEffective, 4),
            'violations' => $violations,
        ];
    }

    /** Throw a 422 ValidationException if the offer is unsafe (used at approval). */
    public function assertSafe(string $scope, ?float $discountPct, array $lines): array
    {
        $result = $this->evaluate($scope, $discountPct, $lines);
        if (! $result['safe']) {
            throw ValidationException::withMessages([
                'offer' => $result['violations'] ?: ['العرض يتجاوز سقف الخصم المسموح.'],
            ]);
        }
        return $result;
    }

    private function retailOf(string $itemCode): float
    {
        $prices = Product::where('item_code', $itemCode)->value('prices');
        if (is_string($prices)) {
            $prices = json_decode($prices, true);
        }
        if (! is_array($prices)) {
            return 0.0;
        }
        foreach ($prices as $p) {
            if ((int) ($p['PriceList'] ?? 0) === 1) {
                return (float) ($p['Price'] ?? 0);
            }
        }
        return 0.0;
    }
}
