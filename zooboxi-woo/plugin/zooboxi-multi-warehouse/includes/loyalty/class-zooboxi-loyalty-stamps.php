<?php
/**
 * Zooboxi_Loyalty_Stamps — «بطاقة المشتري الدائم» per brand.
 *
 * A program is a brand (`product_brand` term), a number of qualifying units, a minimum
 * pack size, and a reward from the catalogue. Buy N qualifying units in delivered
 * orders → the reward is granted, and the count starts over.
 *
 * NO PROGRAM IS ACTIVE BY DEFAULT. A free bag is a real discount (~14%), which is a
 * channel decision Muntajat makes with the brand — so the engine ships, the wallet
 * stays empty until the owner switches a program on in the admin tab.
 *
 * Stamps are keyed on the order LINE (UNIQUE program+order_item), so a replayed hook
 * cannot stamp twice, and the grant count is derived (floor(total/required) minus
 * grants already issued), so a crash between the two cannot lose or double a reward.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Stamps
{
    private static ?array $programs = null;

    /* ══════════════════════════════════════════════════════════════
       PROGRAMS
       ══════════════════════════════════════════════════════════════ */

    /** @return array<int,array> */
    public static function programs(bool $active_only = true): array
    {
        if ($active_only && self::$programs !== null) {
            return self::$programs;
        }
        global $wpdb;
        $sql  = 'SELECT * FROM ' . Zooboxi_Loyalty_Schema::stamp_programs();
        $sql .= $active_only ? ' WHERE is_active = 1' : '';
        $sql .= ' ORDER BY sort ASC, id ASC';
        $rows = $wpdb->get_results($sql, ARRAY_A);
        $rows = is_array($rows) ? $rows : [];
        if ($active_only) {
            self::$programs = $rows;
        }
        return $rows;
    }

    public static function program(int $id): ?array
    {
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::stamp_programs() . ' WHERE id = %d LIMIT 1',
            $id
        ), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    /** Admin create/update. */
    public static function save(array $input): int
    {
        Zooboxi_Loyalty_Schema::maybe_install();
        $now  = Zooboxi_Loyalty::now();
        $data = [
            'title_ar'       => mb_substr(sanitize_text_field((string) ($input['title_ar'] ?? '')), 0, 120),
            'title_en'       => mb_substr(sanitize_text_field((string) ($input['title_en'] ?? '')), 0, 120),
            'brand_term_id'  => absint($input['brand_term_id'] ?? 0),
            'units_required' => max(1, absint($input['units_required'] ?? 6)),
            'min_pack_kg'    => max(0, (float) ($input['min_pack_kg'] ?? 0)),
            'reward_id'      => absint($input['reward_id'] ?? 0),
            'is_active'      => !empty($input['is_active']) ? 1 : 0,
            'sort'           => (int) ($input['sort'] ?? 0),
            'updated_at'     => $now,
        ];
        global $wpdb;
        $id = absint($input['id'] ?? 0);
        if ($id > 0 && self::program($id) !== null) {
            $wpdb->update(Zooboxi_Loyalty_Schema::stamp_programs(), $data, ['id' => $id]);
        } else {
            $data['created_at'] = $now;
            $wpdb->insert(Zooboxi_Loyalty_Schema::stamp_programs(), $data);
            $id = (int) $wpdb->insert_id;
        }
        self::$programs = null;
        return $id;
    }

    public static function toggle(int $id, bool $active): void
    {
        global $wpdb;
        $wpdb->update(Zooboxi_Loyalty_Schema::stamp_programs(), ['is_active' => $active ? 1 : 0, 'updated_at' => Zooboxi_Loyalty::now()], ['id' => $id]);
        self::$programs = null;
    }

    /* ══════════════════════════════════════════════════════════════
       STAMPING
       ══════════════════════════════════════════════════════════════ */

    /** On delivery: stamp every qualifying line of every active program. */
    public static function on_order_completed(\WC_Order $order): int
    {
        $user_id  = (int) $order->get_customer_id();
        $programs = self::programs(true);
        if ($user_id <= 0 || empty($programs) || !taxonomy_exists('product_brand')) {
            return 0;
        }

        global $wpdb;
        $stamped = 0;
        $touched = [];

        foreach ($order->get_items() as $item) {
            if (!($item instanceof \WC_Order_Item_Product)) {
                continue;
            }
            if ((string) $item->get_meta(Zooboxi_Loyalty::ORDER_GRANT_META) !== '') {
                continue; // a gift never stamps
            }
            $pid = (int) $item->get_product_id();
            if ($pid <= 0) {
                continue;
            }
            $brands = array_map('intval', (array) wp_get_post_terms($pid, 'product_brand', ['fields' => 'ids']));
            if (empty($brands)) {
                continue;
            }

            foreach ($programs as $program) {
                if (!in_array((int) $program['brand_term_id'], $brands, true)) {
                    continue;
                }
                $min = (float) $program['min_pack_kg'];
                if ($min > 0) {
                    $product = $item->get_product();
                    $parent  = ($product instanceof \WC_Product && $product->is_type('variation')) ? wc_get_product($pid) : null;
                    $pack    = ($product instanceof \WC_Product && class_exists('Zooboxi_Loyalty_Supply'))
                        ? Zooboxi_Loyalty_Supply::pack_kg($product, $parent instanceof \WC_Product ? $parent : null)
                        : null;
                    if ($pack === null || $pack < $min) {
                        continue;
                    }
                }

                $prev_show     = $wpdb->hide_errors();
                $prev_suppress = $wpdb->suppress_errors(true);
                $ok = $wpdb->insert(Zooboxi_Loyalty_Schema::stamps(), [
                    'user_id'       => $user_id,
                    'program_id'    => (int) $program['id'],
                    'order_id'      => (int) $order->get_id(),
                    'order_item_id' => (int) $item->get_id(),
                    'units'         => max(1, (int) $item->get_quantity()),
                    'created_at'    => Zooboxi_Loyalty::now(),
                ], ['%d', '%d', '%d', '%d', '%d', '%s']);
                $wpdb->suppress_errors($prev_suppress);
                if ($prev_show) {
                    $wpdb->show_errors();
                }
                if ($ok) {
                    $stamped++;
                    $touched[(int) $program['id']] = $program;
                }
            }
        }

        foreach ($touched as $program) {
            self::settle($user_id, $program);
        }
        return $stamped;
    }

    /** Issue whatever full cards are owed and not yet granted. */
    private static function settle(int $user_id, array $program): void
    {
        $required = max(1, (int) $program['units_required']);
        $earned   = intdiv(self::units($user_id, (int) $program['id']), $required);
        $granted  = self::grants_issued($user_id, (int) $program['id']);
        while ($granted < $earned) {
            if ((int) $program['reward_id'] <= 0
                || Zooboxi_Loyalty_Rewards::grant($user_id, (int) $program['reward_id'], 'stamps', (int) $program['id'], null) <= 0) {
                break;
            }
            $granted++;
        }
    }

    public static function units(int $user_id, int $program_id): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COALESCE(SUM(units),0) FROM ' . Zooboxi_Loyalty_Schema::stamps() . ' WHERE user_id = %d AND program_id = %d',
            $user_id,
            $program_id
        ));
    }

    private static function grants_issued(int $user_id, int $program_id): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COUNT(*) FROM ' . Zooboxi_Loyalty_Schema::grants() . " WHERE user_id = %d AND source = 'stamps' AND source_ref = %d",
            $user_id,
            $program_id
        ));
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    /** @return array<int,array> the customer's cards, active programs only */
    public static function wallet(int $user_id): array
    {
        if ($user_id <= 0 || !Zooboxi_Loyalty::is_enabled()) {
            return [];
        }
        $out = [];
        foreach (self::programs(true) as $program) {
            $required = max(1, (int) $program['units_required']);
            $total    = self::units($user_id, (int) $program['id']);
            $reward   = (int) $program['reward_id'] > 0 ? Zooboxi_Loyalty_Rewards::reward((int) $program['reward_id']) : null;
            $term     = get_term((int) $program['brand_term_id'], 'product_brand');

            $out[] = [
                'program' => [
                    'id'             => (int) $program['id'],
                    'title'          => Zooboxi_Loyalty::pick((string) $program['title_ar'], (string) $program['title_en']),
                    'brand'          => ($term && !is_wp_error($term)) ? ['name' => $term->name, 'slug' => $term->slug] : null,
                    'units_required' => $required,
                    'min_pack_kg'    => (float) $program['min_pack_kg'],
                    'reward'         => $reward ? Zooboxi_Loyalty_Rewards::reward_dto($reward, $user_id) : null,
                ],
                'units'       => $total % $required,
                'cycles_done' => intdiv($total, $required),
                'remaining'   => $required - ($total % $required),
            ];
        }
        return $out;
    }
}
