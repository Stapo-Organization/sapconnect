<?php
/**
 * Zooboxi_V2_Events_Controller — the app's capture beacon.
 *
 * Forwards through Zooboxi_Intelligence::forward_event(), the exact validation +
 * forwarding path the website's beacon uses, so the intelligence backend receives one
 * consistent event stream. The Laravel token never leaves the server.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Events_Controller
{
    private const MAX_BATCH = 50;

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/events', 'POST', [$this, 'track']);
        // The search screen's «الأكثر بحثاً» chips — counted from the search
        // events this controller already receives.
        Zooboxi_V2_Bootstrap::route('/search/popular', 'GET', [$this, 'popular']);
    }

    /** Option holding per-day query counts: ['Y-m-d' => [query => count]]. */
    private const TRENDS_OPTION = 'zooboxi_search_trends';
    private const TRENDS_DAYS   = 30;
    private const TRENDS_PER_DAY = 300;

    /** A searched phrase as a chip: trimmed, single-spaced, 2–40 characters. */
    private static function normalize_query(string $q): string
    {
        $q = trim((string) preg_replace('/\s+/u', ' ', wp_strip_all_tags($q)));
        $len = mb_strlen($q);
        return ($len >= 2 && $len <= 40 && !preg_match('/^\d+$/', $q)) ? mb_strtolower($q) : '';
    }

    private static function record_search(string $query): void
    {
        $q = self::normalize_query($query);
        if ($q === '') {
            return;
        }
        $days  = get_option(self::TRENDS_OPTION, []);
        $days  = is_array($days) ? $days : [];
        $today = wp_date('Y-m-d');
        $bucket = $days[$today] ?? [];
        if (isset($bucket[$q]) || count($bucket) < self::TRENDS_PER_DAY) {
            $bucket[$q] = (int) ($bucket[$q] ?? 0) + 1;
        }
        $days[$today] = $bucket;
        $cut = wp_date('Y-m-d', time() - self::TRENDS_DAYS * DAY_IN_SECONDS);
        foreach (array_keys($days) as $day) {
            if ($day < $cut) {
                unset($days[$day]);
            }
        }
        update_option(self::TRENDS_OPTION, $days, false);
    }

    /**
     * Up to six chips. Real searches first — a phrase counts once two people
     * (or one person twice) have asked for it in 30 days — then the shelf's
     * biggest brands. `source` tells the app which title is honest:
     * «الأكثر بحثاً» only when searches carry the list.
     */
    public function popular(\WP_REST_Request $request): \WP_REST_Response
    {
        $days   = get_option(self::TRENDS_OPTION, []);
        $totals = [];
        foreach ((is_array($days) ? $days : []) as $bucket) {
            foreach ((array) $bucket as $q => $c) {
                $totals[(string) $q] = ($totals[(string) $q] ?? 0) + (int) $c;
            }
        }
        arsort($totals);
        $queries = [];
        foreach ($totals as $q => $c) {
            if ($c < 2 || count($queries) >= 6) {
                break;
            }
            $queries[] = (string) $q;
        }
        $from_searches = count($queries) >= 3;

        if (count($queries) < 6) {
            $terms = get_terms([
                'taxonomy'   => 'product_brand',
                'hide_empty' => true,
                'orderby'    => 'count',
                'order'      => 'DESC',
                'number'     => 12,
            ]);
            foreach (is_wp_error($terms) ? [] : $terms as $t) {
                $name = Zooboxi_V2_Bootstrap::term_name($t);
                if ($name !== '' && !in_array(mb_strtolower($name), $queries, true)) {
                    $queries[] = $name;
                }
                if (count($queries) >= 6) {
                    break;
                }
            }
        }

        return Zooboxi_V2_Bootstrap::ok([
            'queries' => array_values($queries),
            'source'  => $from_searches ? 'searches' : 'brands',
        ], Zooboxi_V2_Bootstrap::TTL_META);
    }

    public function track(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!class_exists('Zooboxi_Intelligence')) {
            return Zooboxi_V2_Bootstrap::fail('events_unavailable', __('التتبّع غير متاح', 'zooboxi'), 'Event capture is unavailable.', 503);
        }

        $batch = $request->get_param('events');
        $items = is_array($batch) ? $batch : [$request->get_params()];
        $items = array_slice(array_values(array_filter($items, 'is_array')), 0, self::MAX_BATCH);

        $anon_id      = Zooboxi_V2_Bootstrap::guest_id($request);
        $user_id      = get_current_user_id();
        $customer_ref = $user_id ? ('wp_' . $user_id) : null;

        $accepted = 0;
        foreach ($items as $event) {
            $input = [
                'event_type' => $event['event_type'] ?? '',
                'anon_id'    => $anon_id !== '' ? $anon_id : ($event['anon_id'] ?? null),
                'item_code'  => $event['item_code'] ?? null,
                'query'      => $event['query'] ?? null,
                'zone'       => $event['zone'] ?? null,
                'ab_variant' => $event['ab_variant'] ?? null,
                'payload'    => is_array($event['payload'] ?? null) ? $event['payload'] : null,
            ];
            if ($customer_ref !== null) {
                $input['customer_ref'] = $customer_ref;
            }

            if ((string) $input['event_type'] === 'search' && is_string($input['query']) && $input['query'] !== '') {
                self::record_search($input['query']);
            }
            if (Zooboxi_Intelligence::forward_event($input)) {
                $accepted++;
                // The app is in someone's hand right now: the hour counts
                // toward when their reminders should arrive.
                $type = (string) $input['event_type'];
                if (($type === 'app_open' || $type === 'push_open') && class_exists('Zooboxi_Push_STO')) {
                    Zooboxi_Push_STO::observe($user_id, $anon_id, time(), $type === 'push_open' ? 2.0 : 1.0);
                }
            }
        }

        $response = Zooboxi_V2_Bootstrap::ok(['accepted' => $accepted, 'received' => count($items)]);
        $response->set_status(202);
        return $response;
    }
}
