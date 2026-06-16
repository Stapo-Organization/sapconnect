<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Builds "Frequently Bought Together" associations (DB-only) from C0000001 retail
 * baskets — the richest cold-start signal (67% multi-item invoices). Computes
 * support/confidence/lift and keeps lift>=1.5 pairs, storing DIRECTED rows so the
 * store can look up "given item A, recommend B".
 */
class BuildAssociations extends Command
{
    protected $signature = 'intelligence:build-associations {--window=180 : Basket window in days} {--min-co=20 : Min co-occurrence}';
    protected $description = 'Build FBT product_associations from C0000001 baskets — DB only.';

    private const MIN_LIFT = 1.5;
    private const TOP_PER_ITEM = 16;

    public function handle(): int
    {
        ini_set('memory_limit', '1024M'); // scheduler runs without -d memory_limit
        DB::connection()->disableQueryLog();
        $window = max(30, (int) $this->option('window'));
        $minCo = max(2, (int) $this->option('min-co'));
        $this->info("Mining FBT (window={$window}d, min_co={$minCo})...");

        // Number of retail baskets in the window.
        $n = (int) DB::table('sap_invoices')
            ->where('card_code', 'C0000001')
            ->whereRaw('doc_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)', [$window])
            ->distinct()->count('id');
        if ($n === 0) {
            $this->warn('No retail baskets in window.');
            return self::SUCCESS;
        }

        // Per-item basket frequency (active items only).
        $freq = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->join('products as p', function ($j) {
                $j->on('p.item_code', '=', 'l.item_code')->where('p.zooboxi_active', 1);
            })
            ->where('i.card_code', 'C0000001')
            ->whereRaw('i.doc_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)', [$window])
            ->groupBy('l.item_code')
            ->selectRaw('l.item_code, COUNT(DISTINCT l.sap_invoice_id) f')
            ->pluck('f', 'item_code');

        // Co-occurrence pairs (a<b) over distinct (basket,item) of active items.
        $base = "SELECT DISTINCT l.sap_invoice_id sid, l.item_code ic
                 FROM sap_invoice_lines l
                 JOIN sap_invoices i ON i.id = l.sap_invoice_id
                 JOIN products p ON p.item_code = l.item_code AND p.zooboxi_active = 1
                 WHERE i.card_code = 'C0000001' AND i.doc_date >= DATE_SUB(CURDATE(), INTERVAL {$window} DAY)";
        $pairs = DB::select(
            "SELECT a.ic A, b.ic B, COUNT(*) co
             FROM ({$base}) a
             JOIN ({$base}) b ON a.sid = b.sid AND a.ic < b.ic
             GROUP BY a.ic, b.ic
             HAVING co >= {$minCo}"
        );
        $this->info('Candidate pairs: ' . count($pairs));

        // Build directed rows with lift gate.
        $now = now();
        $directed = [];
        foreach ($pairs as $p) {
            $fa = (float) ($freq[$p->A] ?? 0);
            $fb = (float) ($freq[$p->B] ?? 0);
            if ($fa <= 0 || $fb <= 0) {
                continue;
            }
            $lift = ($p->co * $n) / ($fa * $fb);
            if ($lift < self::MIN_LIFT) {
                continue;
            }
            $support = $p->co / $n;
            $directed[] = ['a' => $p->A, 'b' => $p->B, 'co' => $p->co, 'conf' => $p->co / $fa, 'lift' => $lift, 'support' => $support];
            $directed[] = ['a' => $p->B, 'b' => $p->A, 'co' => $p->co, 'conf' => $p->co / $fb, 'lift' => $lift, 'support' => $support];
        }

        // Keep top-N per source item by score (lift, tie-break confidence).
        $byA = [];
        foreach ($directed as $d) {
            $byA[$d['a']][] = $d;
        }
        DB::table('product_associations')->where('rule_type', 'fbt')->delete();

        $rows = [];
        $count = 0;
        foreach ($byA as $a => $list) {
            usort($list, fn ($x, $y) => $y['lift'] <=> $x['lift'] ?: $y['conf'] <=> $x['conf']);
            foreach (array_slice($list, 0, self::TOP_PER_ITEM) as $d) {
                $rows[] = [
                    'item_code_a' => $d['a'],
                    'item_code_b' => $d['b'],
                    'rule_type' => 'fbt',
                    'co_count' => $d['co'],
                    'support' => round($d['support'], 8),
                    'confidence' => round($d['conf'], 6),
                    'lift' => round($d['lift'], 4),
                    'score' => round($d['lift'], 6),
                    'computed_at' => $now,
                ];
                if (count($rows) >= 1000) {
                    DB::table('product_associations')->insert($rows);
                    $count += count($rows);
                    $rows = [];
                }
            }
        }
        if ($rows) {
            DB::table('product_associations')->insert($rows);
            $count += count($rows);
        }

        $this->info("Stored {$count} FBT associations.");
        return self::SUCCESS;
    }
}
