<?php

namespace App\Services;

use App\Models\LandedCost;
use App\Models\LandedCostLine;
use Illuminate\Support\Facades\Log;

/**
 * Landed Cost Calculator — replicates the Excel "Master Landing Cost" formulas.
 *
 * Formulas (matching Excel columns):
 * 1. total_value_foreign         = qty × unit_price_foreign
 * 2. value_participate_pct       = total_value / SUM(all total_values)
 * 3. shipping_per_unit           = (total_shipping × participate_pct) / qty
 * 4. total_per_unit_foreign      = unit_price + shipping_per_unit
 * 5. unit_cost_sar               = total_per_unit_foreign × exchange_rate
 * 6. unit_cost_sar_with_vat      = unit_cost_sar × (1 + vat_pct)
 * 7. po_unit_price_with_vat      = po_unit_price × (1 + vat_pct)
 * 8. gross_profit_pct            = (wholesale_price - unit_cost_sar) / wholesale_price
 * 9. profit_per_unit_sar         = wholesale_price - unit_cost_sar
 */
class LandedCostCalculator
{
    /**
     * Recalculate all lines for a given LandedCost record.
     */
    public function calculate(LandedCost $landedCost): void
    {
        $lines = $landedCost->lines()->get();
        if ($lines->isEmpty()) {
            Log::info("LandedCostCalculator: No lines to calculate for ID {$landedCost->id}");
            return;
        }

        $exchangeRate = (float) $landedCost->exchange_rate;
        $vatPct = (float) $landedCost->vat_percentage / 100; // e.g. 15 → 0.15
        $totalShippingForeign = (float) $landedCost->shipping_cost_foreign;

        // ─── Step 1: Calculate total_value_foreign for each line ───
        $grandTotal = 0;
        $lineValues = [];
        foreach ($lines as $line) {
            $totalValue = (float) $line->quantity * (float) $line->unit_price_foreign;
            $lineValues[$line->id] = $totalValue;
            $grandTotal += $totalValue;
        }

        // ─── Step 2-9: Calculate all derived fields ───
        foreach ($lines as $line) {
            $totalValue = $lineValues[$line->id];
            $qty = max(1, (int) $line->quantity); // Prevent division by zero

            // 1. Total value in foreign currency
            $line->total_value_foreign = $totalValue;

            // 2. Participation percentage
            $participatePct = $grandTotal > 0 ? $totalValue / $grandTotal : 0;
            $line->value_participate_pct = $participatePct;

            // 3. Shipping allocation per unit
            $shippingPerUnit = ($totalShippingForeign * $participatePct) / $qty;
            $line->shipping_per_unit = $shippingPerUnit;

            // 4. Total cost per unit (foreign)
            $totalPerUnitForeign = (float) $line->unit_price_foreign + $shippingPerUnit;
            $line->total_per_unit_foreign = $totalPerUnitForeign;

            // 5. Unit cost in SAR
            $unitCostSar = $totalPerUnitForeign * $exchangeRate;
            $line->unit_cost_sar = $unitCostSar;

            // 6. Unit cost in SAR + VAT
            $line->unit_cost_sar_with_vat = $unitCostSar * (1 + $vatPct);

            // 7. PO unit price with VAT
            $line->po_unit_price_with_vat = (float) $line->po_unit_price * (1 + $vatPct);

            // 8. Gross profit percentage (only if wholesale_price > 0)
            $wholesalePrice = (float) $line->wholesale_price;
            if ($wholesalePrice > 0) {
                $line->gross_profit_pct = ($wholesalePrice - $unitCostSar) / $wholesalePrice;
            } else {
                $line->gross_profit_pct = 0;
            }

            // 9. Profit per unit in SAR
            $line->profit_per_unit_sar = $wholesalePrice - $unitCostSar;

            // Wholesale with VAT (if wholesale_price set manually)
            if ($wholesalePrice > 0 && (float) $line->wholesale_price_with_vat == 0) {
                $line->wholesale_price_with_vat = $wholesalePrice * (1 + $vatPct);
            }

            $line->save();
        }

        // ─── Update header totals ───
        $landedCost->shipping_cost_sar = $totalShippingForeign * $exchangeRate;
        $landedCost->total_additional_costs =
            $landedCost->shipping_cost_sar +
            (float) $landedCost->customs_cost +
            (float) $landedCost->broker_cost;
        $landedCost->save();

        Log::info("LandedCostCalculator: Calculated {$lines->count()} lines for LandedCost #{$landedCost->id}");
    }

    /**
     * Import lines from a PurchaseOrder's line items.
     */
    public function importFromPurchaseOrder(LandedCost $landedCost): int
    {
        $po = $landedCost->purchaseOrder;
        if (!$po) return 0;

        $poLines = $po->lines()->with('product')->get();
        $count = 0;

        foreach ($poLines as $poLine) {
            LandedCostLine::updateOrCreate(
                [
                    'landed_cost_id' => $landedCost->id,
                    'purchase_order_line_id' => $poLine->id,
                ],
                [
                    'product_id' => $poLine->product_id,
                    'quantity' => $poLine->quantity,
                    'unit_price_foreign' => $poLine->unit_price,
                    'po_unit_price' => $poLine->unit_price,
                    'country_of_origin' => $po->supplier?->country,
                ]
            );
            $count++;
        }

        return $count;
    }
}
