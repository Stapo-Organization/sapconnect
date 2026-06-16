<?php
/**
 * Zooboxi Fulfillment — the SINGLE source of truth for "how/when can we deliver this line".
 *
 * THE PROBLEM IT SOLVES: WooCommerce carries ONE stock number and ONE delivery promise per
 * product, but Zooboxi's reality is N warehouses × M delivery speeds. Every cart surface that
 * projected that reality on its own (per-item badge, summary banner, shipping methods, the WC
 * stock error) produced a DIFFERENT projection → contradictory promises on one cart line.
 *
 * THE FIX: one resolver computes, for (product, requested qty, customer location), an honest
 * allocation of the quantity across only the REACHABLE tiers, each capped by real SAP stock,
 * ordered fastest-first. It NEVER promises a tier whose warehouse holds zero. Every surface
 * (badge, summary, split baskets, qty cap, methods) MUST read from here and never re-derive.
 *
 * Reachability is intentionally identical to the live model (owner decision): only the single
 * NEAREST express branch + the city central + the national hub are reachable. Same-city
 * non-nearest branches are deliberately NOT counted.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Fulfillment
{
    /**
     * Resolve the honest delivery plan for ONE product line.
     *
     * @return array{
     *   product_id:int, requested_qty:int,
     *   tiers:array,            // reachable tiers (fastest first), each: tier,eta,warehouse_code,warehouse_name,stock,fee
     *   allocation:array,       // how requested_qty splits across tiers: tier,eta,...,qty
     *   reachable_total:int, fulfillable:int, shortfall:int,
     *   is_split:bool, fastest:string, slowest:string
     * }
     */
    public static function resolve(int $product_id, int $qty, float $lat, float $lng, ?string $city = null): array
    {
        $qty = max(1, $qty);

        // Per-warehouse SAP stock (the only stock source).
        $map = [];
        foreach (Zooboxi_Stock_Manager::get_warehouse_stock($product_id) as $s) {
            $code = $s['warehouse_code'] ?? '';
            if ($code !== '') {
                $map[$code] = max(0, (int) ($s['in_stock'] ?? 0));
            }
        }

        $tiers = [];   // reachable tiers, fastest first
        $used  = [];   // warehouse codes already taken by a faster tier (avoid double count)

        // 1) Express — nearest express branch ONLY (reachability unchanged, owner decision).
        if ($lat && $lng) {
            $express = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
            if (!empty($express)) {
                $wh   = $express[0]['warehouse'];
                $code = $wh['warehouse_code'] ?? '';
                $have = $code ? ($map[$code] ?? 0) : 0;
                if ($have > 0) {
                    $tiers[] = [
                        'tier'           => Zooboxi_Delivery_Engine::TYPE_EXPRESS,
                        'eta'            => __('خلال ساعتين', 'zooboxi'),
                        'icon'           => '⚡',
                        'warehouse_code' => $code,
                        'warehouse_name' => self::wh_name($wh),
                        'stock'          => $have,
                        'fee'            => (float) get_option('zooboxi_express_fee', 15),
                    ];
                    $used[$code] = true;
                }
            }
        }

        // 2) Same-day (24h) — city central warehouse.
        $city = $city ?: self::detect_city($lat, $lng);
        if ($city) {
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            if ($central) {
                $code = $central['warehouse_code'] ?? '';
                if ($code && empty($used[$code])) {
                    $have = $map[$code] ?? 0;
                    if ($have > 0) {
                        $tiers[] = [
                            'tier'           => Zooboxi_Delivery_Engine::TYPE_STANDARD,
                            'eta'            => __('خلال 24 ساعة', 'zooboxi'),
                            'icon'           => '🚚',
                            'warehouse_code' => $code,
                            'warehouse_name' => self::wh_name($central),
                            'stock'          => $have,
                            'fee'            => (float) get_option('zooboxi_standard_fee', 10),
                        ];
                        $used[$code] = true;
                    }
                }
            }
        }

        // 3) National shipping — main hub, ONLY if it actually holds stock (no phantom promise).
        $hub = Zooboxi_Warehouse_Manager::get_main_hub();
        if ($hub) {
            $code = $hub['warehouse_code'] ?? '';
            if ($code && empty($used[$code])) {
                $have = $map[$code] ?? 0;
                if ($have > 0) {
                    $tiers[] = [
                        'tier'           => Zooboxi_Delivery_Engine::TYPE_SHIPPING,
                        'eta'            => __('4-5 أيام عمل', 'zooboxi'),
                        'icon'           => '📦',
                        'warehouse_code' => $code,
                        'warehouse_name' => self::wh_name($hub),
                        'stock'          => $have,
                        'fee'            => (float) get_option('zooboxi_shipping_fee', 25),
                    ];
                    $used[$code] = true;
                }
            }
        }

        // Greedy allocation of the requested qty across reachable tiers, fastest first.
        $alloc = [];
        $remaining = $qty;
        foreach ($tiers as $t) {
            if ($remaining <= 0) {
                break;
            }
            $take = min($remaining, $t['stock']);
            if ($take > 0) {
                $alloc[] = array_merge($t, ['qty' => $take]);
                $remaining -= $take;
            }
        }

        $reachable_total = 0;
        foreach ($tiers as $t) {
            $reachable_total += $t['stock'];
        }

        return [
            'product_id'      => $product_id,
            'requested_qty'   => $qty,
            'tiers'           => $tiers,
            'allocation'      => $alloc,
            'reachable_total' => $reachable_total,
            'fulfillable'     => min($qty, $reachable_total),
            'shortfall'       => max(0, $qty - $reachable_total),
            'is_split'        => count($alloc) > 1,
            'fastest'         => $alloc[0]['tier'] ?? ($tiers[0]['tier'] ?? Zooboxi_Delivery_Engine::TYPE_SHIPPING),
            'slowest'         => !empty($alloc) ? end($alloc)['tier'] : Zooboxi_Delivery_Engine::TYPE_SHIPPING,
        ];
    }

    /**
     * One honest human sentence for a resolved plan (used by badges/summaries).
     * Examples:
     *   "⚡ خلال ساعتين"
     *   "⚡ 3 خلال ساعتين، 🚚 2 خلال 24 ساعة"
     *   "⚡ خلال ساعتين — المتاح 3 فقط في منطقتك"
     */
    public static function headline(array $plan): string
    {
        if (empty($plan['allocation'])) {
            return __('غير متوفر للتوصيل في منطقتك', 'zooboxi');
        }

        $single = count($plan['allocation']) === 1;
        $parts = [];
        foreach ($plan['allocation'] as $a) {
            if ($single && $plan['shortfall'] === 0) {
                $parts[] = $a['icon'] . ' ' . $a['eta'];
            } else {
                $parts[] = $a['icon'] . ' ' . self::ar_num($a['qty']) . ' ' . $a['eta'];
            }
        }
        $line = implode('، ', $parts);

        if ($plan['shortfall'] > 0) {
            $line .= ' — ' . sprintf(
                __('المتاح %s فقط في منطقتك', 'zooboxi'),
                self::ar_num($plan['fulfillable'])
            );
        }
        return $line;
    }

    /* ── Cart presentation helpers (noon-style grouped shipment cards) ───── */

    /** Customer location from session → cookies. @return array{0:float,1:float} [lat,lng] */
    public static function customer_location(): array
    {
        $lat = $lng = 0.0;
        if (function_exists('WC') && WC()->session) {
            $lat = (float) WC()->session->get('zooboxi_customer_lat');
            $lng = (float) WC()->session->get('zooboxi_customer_lng');
        }
        if (!$lat && !empty($_COOKIE['zooboxi_lat'])) $lat = (float) $_COOKIE['zooboxi_lat'];
        if (!$lng && !empty($_COOKIE['zooboxi_lng'])) $lng = (float) $_COOKIE['zooboxi_lng'];
        return [$lat, $lng];
    }

    /**
     * The single display tier for a whole cart line = the SLOWEST tier among its allocation,
     * i.e. when the LAST unit of the line arrives. Grouping by the slowest tier means the card's
     * promise ("احصل عليها اليوم/غداً") holds for every unit — a partially-split line never
     * overpromises (the faster units are a bonus, and the precise split still shows at checkout).
     */
    public static function line_tier(int $product_id, int $qty, float $lat, float $lng): string
    {
        $plan = self::resolve($product_id, $qty, $lat, $lng);
        return $plan['slowest'] ?? Zooboxi_Delivery_Engine::TYPE_SHIPPING;
    }

    /**
     * Branded header presentation for a delivery tier — name, icon, colour identity, and a
     * concrete delivery date PLUS a relative duration (owner chose "both").
     *
     * @return array{name:string,icon:string,color:string,bg:string,date:string,relative:string}
     */
    public static function tier_presentation(string $tier): array
    {
        switch ($tier) {
            case Zooboxi_Delivery_Engine::TYPE_EXPRESS:
                return [
                    'name'     => __('توصيل سريع', 'zooboxi'),
                    'icon'     => '⚡',
                    'color'    => '#d9480f',
                    'bg'       => '#fff4ec',
                    'date'     => self::day_label(0),
                    'relative' => __('خلال ساعتين', 'zooboxi'),
                ];
            case Zooboxi_Delivery_Engine::TYPE_STANDARD:
                return [
                    'name'     => __('توصيل اليوم التالي', 'zooboxi'),
                    'icon'     => '🚚',
                    'color'    => '#0d9488',
                    'bg'       => '#f0fdfa',
                    'date'     => self::day_label(1),
                    'relative' => __('خلال 24 ساعة', 'zooboxi'),
                ];
            default:
                return [
                    'name'     => __('شحن عادي', 'zooboxi'),
                    'icon'     => '📦',
                    'color'    => '#6b7280',
                    'bg'       => '#f9fafb',
                    'date'     => self::business_day_label(4),
                    'relative' => __('خلال 4-5 أيام عمل', 'zooboxi'),
                ];
        }
    }

    /** Arabic relative/absolute day label N days from today (0=اليوم, 1=غداً, else يوم d شهر). */
    private static function day_label(int $days): string
    {
        if ($days <= 0) return __('اليوم', 'zooboxi');
        if ($days === 1) return __('غداً', 'zooboxi');

        $ts = (function_exists('current_time') ? current_time('timestamp') : time()) + $days * 86400;
        return self::format_ar_date($ts);
    }

    /** Like day_label but skips KSA weekend (Fri/Sat) — used for the shipping ETA. */
    private static function business_day_label(int $days): string
    {
        $ts = (function_exists('current_time') ? current_time('timestamp') : time());
        $added = 0;
        while ($added < $days) {
            $ts += 86400;
            $dow = (int) date('w', $ts); // 0=Sun .. 6=Sat
            if ($dow !== 5 && $dow !== 6) { // skip Friday(5) & Saturday(6)
                $added++;
            }
        }
        return self::format_ar_date($ts);
    }

    private static function format_ar_date(int $ts): string
    {
        $dayNames = [
            'Sunday' => 'الأحد', 'Monday' => 'الاثنين', 'Tuesday' => 'الثلاثاء',
            'Wednesday' => 'الأربعاء', 'Thursday' => 'الخميس', 'Friday' => 'الجمعة', 'Saturday' => 'السبت',
        ];
        $months = [1 => 'يناير', 2 => 'فبراير', 3 => 'مارس', 4 => 'أبريل', 5 => 'مايو', 6 => 'يونيو',
                   7 => 'يوليو', 8 => 'أغسطس', 9 => 'سبتمبر', 10 => 'أكتوبر', 11 => 'نوفمبر', 12 => 'ديسمبر'];
        $dn = $dayNames[date('l', $ts)] ?? '';
        $d  = (int) date('j', $ts);
        $m  = (int) date('n', $ts);
        return trim($dn . ' ' . $d . ' ' . ($months[$m] ?? ''));
    }

    private static function wh_name(array $wh): string
    {
        if (function_exists('is_rtl') && is_rtl()) {
            return $wh['display_name_ar'] ?: ($wh['display_name_en'] ?? '');
        }
        return ($wh['display_name_en'] ?? '') ?: ($wh['display_name_ar'] ?? '');
    }

    private static function detect_city(float $lat, float $lng): ?string
    {
        if (!$lat && !$lng) {
            return null;
        }
        $nearest = Zooboxi_Warehouse_Manager::find_nearest($lat, $lng);
        return $nearest['warehouse']['city'] ?? null;
    }

    private static function ar_num(int $n): string
    {
        return (string) $n;
    }
}
