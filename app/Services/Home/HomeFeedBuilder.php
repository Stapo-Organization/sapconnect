<?php

namespace App\Services\Home;

use Carbon\Carbon;

/**
 * Builds the deterministic "Action Center" priority feed for the home screen.
 *
 * Takes the already-serialized module summaries (the exact arrays returned by
 * the existing /zooboxi-orders/summary, /quality-tasks/summary,
 * /inventory-countings/schedule, /dashboard-stats and /promotions/summary
 * endpoints) and folds every actionable item into one ranked list scored by
 * urgency. Pure functions of the input — same input always yields the same
 * ordering (see sort tie-breakers). Weights live in config/home.php.
 */
class HomeFeedBuilder
{
    private array $base;
    private array $aging;
    private array $bands;
    private int $dueCycleWindow;
    private int $limit;

    public function __construct()
    {
        $cfg = config('home');
        $this->base = $cfg['base'];
        $this->aging = $cfg['aging'];
        $this->bands = $cfg['zooboxi_bands'];
        $this->dueCycleWindow = (int) $cfg['due_cycle_window_days'];
        $this->limit = (int) $cfg['feed_limit'];
    }

    /**
     * @param  bool  $singleBranch  When the user manages exactly one warehouse,
     *                              the branch name is redundant (shown in the
     *                              header) so it is omitted from item text.
     * @return array{feed: array, module_order: array}
     */
    public function build(array $modules, bool $isOwner, bool $singleBranch = false): array
    {
        $items = array_merge(
            $this->zooboxiItems($modules['zooboxi'] ?? []),
            $this->qualityItems($modules['quality'] ?? [], $singleBranch),
            $this->countingItems($modules['counting'] ?? [], $singleBranch),
            $this->transferItems($modules['transfers'] ?? []),
            $isOwner ? $this->promoItems($modules['promotions'] ?? []) : [],
        );

        // Deterministic ordering: score desc, then base-type priority desc,
        // then stable id asc — identical across reloads (no randomness).
        usort($items, function ($a, $b) {
            return [$b['score'], $this->base[$b['type']] ?? 0, $a['_seq']]
                <=> [$a['score'], $this->base[$a['type']] ?? 0, $b['_seq']];
        });

        $feed = array_map(fn ($i) => array_diff_key($i, ['_seq' => 0]),
            array_slice($items, 0, $this->limit));

        return [
            'feed' => array_values($feed),
            'module_order' => $this->moduleOrder($items, $isOwner),
        ];
    }

    // ─── Per-domain candidate builders ──────────────────────────

    private function zooboxiItems(array $zb): array
    {
        $out = [];
        foreach ($zb['orders'] ?? [] as $i => $o) {
            $minutes = (int) ($o['minutes_since_created'] ?? 0);
            $bonus = min($minutes, $this->aging['zooboxi_sla_minutes']) * $this->aging['zooboxi_factor'];
            $ref = $o['woo_order_number'] ?? $o['id'] ?? '';
            $city = $o['customer']['city'] ?? null;
            $out[] = $this->item(
                seq: 1000 + $i,
                id: 'zooboxi-' . ($o['id'] ?? $i),
                type: 'zooboxi_order',
                domain: 'zooboxi',
                title: 'طلب عاجل #' . $ref,
                subtitle: trim(($city ? $city . ' · ' : '') . 'بانتظار ' . $minutes . ' دقيقة'),
                score: $this->base['zooboxi_order'] + $bonus,
                urgency: $this->zooboxiBand($minutes),
                route: 'zooboxi_order',
                meta: ['order_id' => $o['id'] ?? null, 'minutes' => $minutes],
            );
        }
        return $out;
    }

    private function qualityItems(array $qc, bool $singleBranch = false): array
    {
        $out = [];
        foreach ($qc['due'] ?? [] as $i => $t) {
            $overdue = (bool) ($t['is_overdue'] ?? false);
            $days = $this->daysOverdue($t['scheduled_date'] ?? null);
            // Branch is redundant for a single-warehouse user (it is in the header).
            $prefix = $singleBranch ? '' : trim((string) ($t['warehouse_name'] ?? $t['warehouse_code'] ?? '')) . ' · ';
            if ($overdue) {
                $out[] = $this->item(
                    seq: 2000 + $i,
                    id: 'quality-' . ($t['id'] ?? $i),
                    type: 'overdue_quality',
                    domain: 'quality',
                    title: ($t['title'] ?? 'مهمة جودة') . ' — متأخرة',
                    subtitle: trim($prefix . 'متأخرة ' . $days . ' يوم'),
                    score: $this->base['overdue_quality'] + min($days, $this->aging['overdue_days_cap']) * $this->aging['overdue_factor'],
                    urgency: 'critical',
                    route: 'quality_task',
                    meta: ['task_id' => $t['id'] ?? null, 'days_overdue' => $days],
                );
            } else {
                $out[] = $this->item(
                    seq: 2000 + $i,
                    id: 'quality-' . ($t['id'] ?? $i),
                    type: 'due_quality',
                    domain: 'quality',
                    title: $t['title'] ?? 'مهمة جودة',
                    subtitle: trim($prefix . 'مستحقة اليوم'),
                    score: $this->base['due_quality'],
                    urgency: 'warning',
                    route: 'quality_task',
                    meta: ['task_id' => $t['id'] ?? null],
                );
            }
        }
        return $out;
    }

    private function countingItems(array $counting, bool $singleBranch = false): array
    {
        $out = [];
        foreach ($counting['overdue'] ?? [] as $i => $c) {
            $days = $this->daysOverdue($c['scheduled_date'] ?? null);
            $wh = trim((string) ($c['warehouse_name'] ?? $c['warehouse_code'] ?? ''));
            $suffix = ($singleBranch || $wh === '') ? '' : ' — ' . $wh;
            $out[] = $this->item(
                seq: 3000 + $i,
                id: 'cycle-' . ($c['id'] ?? $i),
                type: 'overdue_cycle',
                domain: 'counting',
                title: 'جرد دوري متأخر' . $suffix,
                subtitle: 'متأخر ' . $days . ' يوم',
                score: $this->base['overdue_cycle'] + min($days, $this->aging['overdue_days_cap']) * $this->aging['overdue_factor'],
                urgency: 'critical',
                route: 'cycle_count',
                meta: ['session_id' => $c['id'] ?? null, 'days_overdue' => $days],
            );
        }
        foreach ($counting['upcoming'] ?? [] as $i => $c) {
            $days = $this->daysUntil($c['scheduled_date'] ?? null);
            if ($days === null || $days > $this->dueCycleWindow) {
                continue;
            }
            $wh = trim((string) ($c['warehouse_name'] ?? $c['warehouse_code'] ?? ''));
            $suffix = ($singleBranch || $wh === '') ? '' : ' — ' . $wh;
            $out[] = $this->item(
                seq: 3500 + $i,
                id: 'cycle-' . ($c['id'] ?? $i),
                type: 'due_cycle',
                domain: 'counting',
                title: 'جرد دوري مجدول' . $suffix,
                subtitle: $days <= 0 ? 'مجدول اليوم' : 'مجدول غداً',
                score: $this->base['due_cycle'],
                urgency: 'info',
                route: 'cycle_count',
                meta: ['session_id' => $c['id'] ?? null],
            );
        }
        return $out;
    }

    private function transferItems(array $t): array
    {
        $out = [];
        $cap = $this->aging['transfer_count_cap'];

        $receive = (int) ($t['pending_receive'] ?? 0);
        if ($receive > 0) {
            $out[] = $this->item(
                seq: 4000,
                id: 'transfer-receive',
                type: 'pending_receive',
                domain: 'transfers',
                title: 'تحويلات بانتظار الاستلام',
                subtitle: $receive . ' تحويل بحاجة لاستلام',
                score: $this->base['pending_receive'] + min($receive, $cap),
                urgency: 'warning',
                route: 'transfers',
                meta: ['count' => $receive],
            );
        }

        $send = (int) ($t['pending_send'] ?? 0);
        if ($send > 0) {
            $out[] = $this->item(
                seq: 4001,
                id: 'transfer-send',
                type: 'pending_send',
                domain: 'transfers',
                title: 'تحويلات بانتظار الإرسال',
                subtitle: $send . ' تحويل بحاجة لإرسال',
                score: $this->base['pending_send'] + min($send, $cap),
                urgency: 'info',
                route: 'transfers',
                meta: ['count' => $send],
            );
        }
        return $out;
    }

    private function promoItems(?array $promos): array
    {
        $pending = (int) ($promos['pending_count'] ?? 0);
        if ($pending <= 0) {
            return [];
        }
        return [$this->item(
            seq: 5000,
            id: 'promo-approval',
            type: 'promo_approval',
            domain: 'promotions',
            title: 'عروض بانتظار موافقتك',
            subtitle: $pending . ' عرض مقترح',
            score: $this->base['promo_approval'],
            urgency: 'info',
            route: 'promotions',
            meta: ['count' => $pending],
        )];
    }

    // ─── Helpers ────────────────────────────────────────────────

    private function item(int $seq, string $id, string $type, string $domain, string $title, string $subtitle, float $score, string $urgency, string $route, array $meta): array
    {
        return [
            '_seq' => $seq,
            'id' => $id,
            'type' => $type,
            'domain' => $domain,
            'title' => $title,
            'subtitle' => $subtitle,
            'score' => (int) round($score),
            'urgency' => $urgency,
            'route' => $route,
            'meta' => $meta,
        ];
    }

    private function zooboxiBand(int $minutes): string
    {
        if ($minutes > $this->bands['critical']) {
            return 'critical';
        }
        if ($minutes >= $this->bands['warning']) {
            return 'warning';
        }
        return 'info';
    }

    private function daysOverdue(?string $date): int
    {
        if (!$date) {
            return 0;
        }
        $d = Carbon::parse($date)->startOfDay();
        return (int) max(0, $d->diffInDays(now()->startOfDay(), false));
    }

    private function daysUntil(?string $date): ?int
    {
        if (!$date) {
            return null;
        }
        $d = Carbon::parse($date)->startOfDay();
        return (int) now()->startOfDay()->diffInDays($d, false);
    }

    /**
     * Order module sections by the strongest feed item in each domain
     * (descending). Domains with nothing urgent fall back to a stable
     * default order; gamification is always pinned last.
     */
    private function moduleOrder(array $items, bool $isOwner): array
    {
        $default = ['zooboxi', 'counting', 'quality', 'transfers'];
        if ($isOwner) {
            $default[] = 'promotions';
        }

        $maxByDomain = [];
        foreach ($items as $it) {
            $d = $it['domain'];
            $maxByDomain[$d] = max($maxByDomain[$d] ?? 0, $it['score']);
        }

        // Capture the default rank up-front so the comparator is stable even
        // as usort reorders the array in place.
        $defaultRank = array_flip($default);
        usort($default, function ($a, $b) use ($maxByDomain, $defaultRank) {
            $sa = $maxByDomain[$a] ?? 0;
            $sb = $maxByDomain[$b] ?? 0;
            if ($sa === $sb) {
                return $defaultRank[$a] <=> $defaultRank[$b];
            }
            return $sb <=> $sa;
        });

        $default[] = 'gamification';
        return $default;
    }
}
