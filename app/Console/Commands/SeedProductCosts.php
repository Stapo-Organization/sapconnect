<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Zooboxi intelligence (DB-ONLY — never calls SAP): derive each item's actual unit
 * cost from the imported GRPO lines (`sap_goods_receipt_lines`) and upsert it into
 * `product_costs` with cost_confidence='actual'. Cost = average purchase price of
 * the item's most recent receipt date (latest cost reflects current buying price;
 * averaging collapses multiple same-day receipt lines).
 *
 * Items without GRPO cost are left for the brand/category proxy pass (Phase 1).
 */
class SeedProductCosts extends Command
{
    protected $signature = 'intelligence:seed-product-costs';

    protected $description = 'Seed product_costs (actual unit cost) from imported GRPO lines — DB only, no SAP.';

    public function handle(): int
    {
        $this->info('Seeding actual costs from sap_goods_receipt_lines...');

        // Latest receipt date per item, then average the unit_price on that date.
        $rows = DB::table('sap_goods_receipt_lines as l')
            ->join(DB::raw('(SELECT item_code, MAX(doc_date) AS md
                             FROM sap_goods_receipt_lines
                             WHERE unit_price > 0
                             GROUP BY item_code) as m'), function ($join) {
                $join->on('m.item_code', '=', 'l.item_code')
                     ->on('m.md', '=', 'l.doc_date');
            })
            ->where('l.unit_price', '>', 0)
            ->groupBy('l.item_code')
            ->selectRaw('l.item_code, AVG(l.unit_price) AS cost')
            ->get();

        if ($rows->isEmpty()) {
            $this->warn('No GRPO cost lines found. Run `sap:sync-goods-receipts` first.');
            return self::SUCCESS;
        }

        $now = now();
        $seeded = 0;

        foreach ($rows->chunk(1000) as $chunk) {
            $payload = $chunk->map(fn ($r) => [
                'item_code'           => $r->item_code,
                'cost_proxy_sar'      => round((float) $r->cost, 4),
                'cost_confidence'     => 'actual',
                'source'              => 'grpo',
                'brand_median_margin' => null,
                'computed_at'         => $now,
                'created_at'          => $now,
                'updated_at'          => $now,
            ])->all();

            // Upsert: refresh cost/confidence/source/computed_at on conflict of item_code.
            DB::table('product_costs')->upsert(
                $payload,
                ['item_code'],
                ['cost_proxy_sar', 'cost_confidence', 'source', 'computed_at', 'updated_at']
            );
            $seeded += count($payload);
        }

        $this->info("Seeded actual cost for {$seeded} items into product_costs.");
        return self::SUCCESS;
    }
}
