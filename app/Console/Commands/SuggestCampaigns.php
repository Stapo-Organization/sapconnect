<?php

namespace App\Console\Commands;

use App\Jobs\GenerateAdCreative;
use App\Models\MarketingCampaign;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Daily campaign suggester (DB-only reads of the existing intelligence). Picks a
 * small, diverse, defensible queue of candidates and writes them as
 * status='suggested', scope='visibility' (Phase 1 = zero price risk; the owner
 * turns a campaign into a coupon/bundle at approval, re-validated by the guard).
 * Dispatches GenerateAdCreative per campaign. Nothing publishes until approved.
 */
class SuggestCampaigns extends Command
{
    protected $signature = 'marketing:suggest-campaigns
        {--limit=60 : max campaigns to suggest this run}
        {--per-type=15 : max campaigns per campaign_type (keeps the queue diverse)}
        {--stale-days=7 : auto-expire un-reviewed suggestions older than this}
        {--generate : also render creatives now (default: defer — images are generated only after the owner approves + picks a placement)}';

    protected $description = 'Suggest channel-safe ad campaigns from the intelligence (suggest-only, owner-approved).';

    public function handle(): int
    {
        $limit = (int) $this->option('limit');
        $perType = (int) $this->option('per-type');

        $this->expireStale((int) $this->option('stale-days'));

        // Items the owner already has an open (non-terminal) campaign for — never duplicate.
        $openByItem = DB::table('marketing_campaigns')
            ->whereNotIn('status', ['rejected', 'ended'])
            ->pluck('campaign_type', 'item_code'); // item_code => type (last wins; fine for skip check)
        $openKeys = DB::table('marketing_campaigns')
            ->whereNotIn('status', ['rejected', 'ended'])
            ->get(['item_code', 'campaign_type'])
            ->map(fn ($r) => $r->item_code . '|' . $r->campaign_type)
            ->flip();

        // Items with an active owner-approved clearance markdown — mutual exclusion (auditor C2).
        $clearanceLocked = DB::table('clearance_campaigns')
            ->where('status', 'active')->where('recommended_discount_pct', '>', 0)
            ->pluck('item_code')->flip();

        $candidates = collect()
            ->merge($this->clearanceCandidates())
            ->merge($this->spotlightCandidates())
            ->merge($this->bundleCandidates())
            ->merge($this->newArrivalCandidates())
            ->merge($this->expressCandidates());

        $perTypeCount = [];
        $seenItems = [];
        $created = 0;

        foreach ($candidates->sortByDesc('score') as $cand) {
            if ($created >= $limit) {
                break;
            }
            $item = $cand['item_code'];
            $type = $cand['campaign_type'];

            if ($item && isset($seenItems[$item])) continue;                 // ≤1 per item
            if (($perTypeCount[$type] ?? 0) >= $perType) continue;            // ≤N per type
            if ($item && isset($openKeys[$item . '|' . $type])) continue;     // already open
            if ($item && isset($clearanceLocked[$item])) continue;           // clearance markdown live

            $campaign = $this->createSuggested($cand);
            $created++;
            $seenItems[$item] = true;
            $perTypeCount[$type] = ($perTypeCount[$type] ?? 0) + 1;

            // New flow: defer image generation until the owner approves + picks a
            // placement (saves cost; suggestions appear instantly). --generate forces it.
            if ($this->option('generate')) {
                GenerateAdCreative::dispatch($campaign->id);
            }
            $this->line("  + [{$type}] {$campaign->headline_ar}");
        }

        $this->info("Suggested {$created} campaign(s) (visibility, suggest-only).");
        return self::SUCCESS;
    }

    private function expireStale(int $days): void
    {
        if ($days <= 0) return;
        DB::table('marketing_campaigns')
            ->where('status', 'suggested')
            ->where('created_at', '<', now()->subDays($days))
            ->update(['status' => 'ended', 'rejected_reason' => 'expired_unreviewed', 'updated_at' => now()]);
    }

    /** OVERSTOCK/DEAD by LPS — promote via visibility (no inherited discount). */
    private function clearanceCandidates(): array
    {
        return DB::table('clearance_campaigns as c')
            ->leftJoin('products as p', 'p.item_code', '=', 'c.item_code')
            ->whereIn('c.status', ['suggested', 'active'])
            ->where('c.lps', '>=', 50)
            ->orderByDesc('c.lps')->limit(150)
            ->get(['c.item_code', 'c.lps', 'c.capital_tied_sar', 'c.days_of_cover', 'p.zb_name_ar'])
            ->map(fn ($r) => [
                'campaign_type' => 'clearance', 'item_code' => $r->item_code,
                'name' => $r->zb_name_ar, 'score' => (float) $r->lps,
                'reason' => 'فائض رأس مال محتجَز',
                'rationale' => ['lps' => (float) $r->lps, 'capital_at_risk' => (float) $r->capital_tied_sar, 'days_of_cover' => (float) $r->days_of_cover],
            ])->all();
    }

    /** Heroes / strong sellers — spotlight. */
    private function spotlightCandidates(): array
    {
        return DB::table('product_intelligence as pi')
            ->leftJoin('products as p', 'p.item_code', '=', 'pi.item_code')
            ->where('pi.warehouse_code', '')
            ->where('pi.is_hero', 1)
            ->whereIn('pi.health_status', ['healthy', 'overstock'])
            ->where('pi.composite_rank_score', '>=', 60)
            ->orderByDesc('pi.composite_rank_score')->limit(150)
            ->get(['pi.item_code', 'pi.composite_rank_score', 'pi.velocity_blended', 'pi.abc_class', 'p.zb_name_ar'])
            ->map(fn ($r) => [
                'campaign_type' => 'spotlight', 'item_code' => $r->item_code,
                'name' => $r->zb_name_ar, 'score' => (float) $r->composite_rank_score,
                'reason' => 'الأكثر طلباً',
                'rationale' => ['composite_rank_score' => (float) $r->composite_rank_score, 'velocity_blended' => (float) $r->velocity_blended, 'abc_class' => $r->abc_class],
            ])->all();
    }

    /** High-lift FBT pairs, both in stock — bundle idea (suggested as visibility). */
    private function bundleCandidates(): array
    {
        return DB::table('product_associations as a')
            ->join('product_intelligence as pia', function ($j) {
                $j->on('pia.item_code', '=', 'a.item_code_a')->where('pia.warehouse_code', '');
            })
            ->join('product_intelligence as pib', function ($j) {
                $j->on('pib.item_code', '=', 'a.item_code_b')->where('pib.warehouse_code', '');
            })
            ->leftJoin('products as pa', 'pa.item_code', '=', 'a.item_code_a')
            ->leftJoin('products as pb', 'pb.item_code', '=', 'a.item_code_b')
            ->where('a.rule_type', 'fbt')->where('a.lift', '>=', 2.0)
            ->where('pia.current_stock', '>', 0)->where('pib.current_stock', '>', 0)
            ->whereColumn('a.item_code_a', '<', 'a.item_code_b') // one row per unordered pair
            ->orderByDesc('a.lift')->limit(150)
            ->get(['a.item_code_a', 'a.item_code_b', 'a.lift', 'pa.zb_name_ar as name_a', 'pb.zb_name_ar as name_b'])
            ->map(fn ($r) => [
                'campaign_type' => 'bundle', 'item_code' => $r->item_code_a,
                'companion_item_codes' => [$r->item_code_b],
                'name' => $r->name_a, 'name_b' => $r->name_b, 'score' => (float) $r->lift * 25,
                'reason' => 'يُشترى عادةً معاً',
                'rationale' => ['fbt_lift' => (float) $r->lift],
            ])->all();
    }

    /** New arrivals — freshness. */
    private function newArrivalCandidates(): array
    {
        return DB::table('product_intelligence as pi')
            ->leftJoin('products as p', 'p.item_code', '=', 'pi.item_code')
            ->where('pi.warehouse_code', '')
            ->where('pi.demand_class', 'new')
            ->where('pi.current_stock', '>', 0)
            ->orderByDesc('pi.current_stock')->limit(150)
            ->get(['pi.item_code', 'pi.current_stock', 'p.zb_name_ar'])
            ->map(fn ($r) => [
                'campaign_type' => 'new_arrival', 'item_code' => $r->item_code,
                'name' => $r->zb_name_ar, 'score' => 55.0,
                'reason' => 'وصل حديثاً',
                'rationale' => ['demand_class' => 'new', 'current_stock' => (int) $r->current_stock],
            ])->all();
    }

    /** Strong sellers reliably in stock — express CTA. */
    private function expressCandidates(): array
    {
        return DB::table('product_intelligence as pi')
            ->leftJoin('products as p', 'p.item_code', '=', 'pi.item_code')
            ->where('pi.warehouse_code', '')
            ->where('pi.in_stock_rate', '>=', 0.8)
            ->where('pi.velocity_blended', '>=', 1.0)
            ->orderByDesc('pi.velocity_blended')->limit(150)
            ->get(['pi.item_code', 'pi.velocity_blended', 'pi.in_stock_rate', 'p.zb_name_ar'])
            ->map(fn ($r) => [
                'campaign_type' => 'express', 'item_code' => $r->item_code,
                'name' => $r->zb_name_ar, 'score' => (float) $r->velocity_blended * 10,
                'reason' => 'متوفّر دائماً — توصيل سريع',
                'rationale' => ['velocity_blended' => (float) $r->velocity_blended, 'in_stock_rate' => (float) $r->in_stock_rate],
            ])->all();
    }

    private function createSuggested(array $cand): MarketingCampaign
    {
        $copy = $this->copyFor($cand);
        $type = $cand['campaign_type'];

        return MarketingCampaign::create([
            'campaign_type' => $type,
            'scope' => 'visibility',
            'source' => 'auto_daily',
            'item_code' => $cand['item_code'] ?? null,
            'companion_item_codes' => $cand['companion_item_codes'] ?? null,
            'reason' => $cand['reason'] ?? null,
            'headline_ar' => $copy['headline'],
            'subheadline_ar' => $copy['subheadline'],
            'cta_ar' => $copy['cta'],
            'badge_ar' => $copy['badge'],
            'zones' => $this->zonesFor($type),
            'status' => 'suggested',
            'score' => round($cand['score'] ?? 0, 3),
            'rationale' => $cand['rationale'] ?? null,
            'brief' => ['visual_prompt' => $this->visualPrompt($cand)],
            'computed_at' => now(),
        ]);
    }

    private function copyFor(array $c): array
    {
        $name = $c['name'] ?: 'تشكيلة مختارة';
        return match ($c['campaign_type']) {
            'clearance' => ['headline' => "عرض خاص — {$name}", 'subheadline' => 'كمية محدودة · بادر بالطلب', 'cta' => 'تسوّق الآن', 'badge' => 'عرض'],
            'spotlight' => ['headline' => "الأكثر طلباً — {$name}", 'subheadline' => 'متوفّر في فرعك · توصيل خلال ساعتين', 'cta' => 'تسوّق الآن', 'badge' => 'الأكثر طلباً'],
            'bundle' => ['headline' => 'اشترِ معاً ووفّر', 'subheadline' => trim(($name) . ' + ' . ($c['name_b'] ?? '')), 'cta' => 'أضف الباقة', 'badge' => 'حزمة'],
            'new_arrival' => ['headline' => "وصل حديثاً — {$name}", 'subheadline' => 'اكتشف أحدث التشكيلات', 'cta' => 'اكتشف الآن', 'badge' => 'جديد'],
            'express' => ['headline' => "احصل عليه خلال ساعتين — {$name}", 'subheadline' => 'متوفّر الآن في فرعك', 'cta' => 'اطلب الآن', 'badge' => 'توصيل سريع'],
            default => ['headline' => $name, 'subheadline' => '', 'cta' => 'تسوّق الآن', 'badge' => ''],
        };
    }

    private function zonesFor(string $type): array
    {
        return match ($type) {
            'spotlight', 'new_arrival', 'express' => ['hero', 'shop_top'],
            'clearance' => ['shop_top', 'in_grid'],
            'bundle' => ['product_strip', 'cart_bundle'],
            default => ['shop_top'],
        };
    }

    private function visualPrompt(array $c): string
    {
        $theme = match ($c['campaign_type']) {
            'clearance' => 'warm gold and deep teal gradient, sense of value and urgency',
            'spotlight', 'express' => 'bright premium studio light, warm teal and gold bokeh, energetic',
            'new_arrival' => 'fresh clean bright background, soft pastel teal, airy and modern',
            'bundle' => 'cozy lifestyle scene, soft warm light, two-product arrangement space',
            default => 'soft studio gradient, warm teal and gold bokeh',
        };
        return "premium e-commerce banner background for a pet & home goods store, {$theme}, "
            . 'clean empty area for text on the right, modern minimal, photographic, high quality, no text, no words';
    }
}
