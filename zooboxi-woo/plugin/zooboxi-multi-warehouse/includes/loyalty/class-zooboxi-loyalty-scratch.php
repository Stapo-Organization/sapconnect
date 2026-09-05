<?php
/**
 * Zooboxi_Loyalty_Scratch — «اخدش واربح»: one card per app order.
 *
 * THE HONESTY RULE: the prize is drawn when the card is CREATED, not when the finger
 * rubs it. The reveal is theatre over a decision already made — which means the app can
 * animate freely, a lost connection cannot change the outcome, and the same card can
 * never pay twice.
 *
 * THE SETTLEMENT RULE: revealing is not winning. A prize becomes real only when the
 * order is delivered (`settled = 1`): paws are written to the ledger then, and a reward
 * grant sits `pending` on that order until it completes. Cancel the order and the prize
 * evaporates — no card can be farmed by ordering and refunding.
 *
 * Cards are app-only and never issued to the holdout group: they are the measured
 * variable of the whole program.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Scratch
{
    /** The default prize table. Reward rows name a key; the admin editor writes ids. */
    public const DEFAULT_TABLE = [
        ['kind' => 'paws',   'paws' => 50,  'weight' => 60],
        ['kind' => 'reward', 'reward_key' => 'express_free', 'weight' => 22],
        ['kind' => 'reward', 'reward_key' => 'small_gift',   'weight' => 12],
        ['kind' => 'paws',   'paws' => 300, 'weight' => 5],
        ['kind' => 'reward', 'reward_key' => 'mystery_box',  'weight' => 1],
    ];

    /* ══════════════════════════════════════════════════════════════
       CREATE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Issue the card for a freshly placed order — if it qualifies.
     *
     * @return int the card id, 0 when this order does not get one
     */
    public static function create_for_order(\WC_Order $order): int
    {
        if (!Zooboxi_Loyalty::is_enabled() || Zooboxi_Loyalty::opt('scratch_enabled') !== 'yes') {
            return 0;
        }

        $user_id = (int) $order->get_customer_id();
        if ($user_id <= 0) {
            return 0;
        }
        if (!self::is_app_order($order)) {
            return 0; // the game is the app's, on purpose
        }

        Zooboxi_Loyalty_Schema::maybe_install();
        Zooboxi_Loyalty_Members::ensure($user_id);

        if (Zooboxi_Loyalty_Members::is_holdout($user_id)) {
            return 0;
        }

        $prize = self::roll();
        if ($prize === null) {
            return 0; // an empty/impossible table — better no card than a broken one
        }

        $order_id = (int) $order->get_id();
        $grant_id = null;

        if ($prize['kind'] === 'reward') {
            // pending until this order is delivered
            $grant_id = Zooboxi_Loyalty_Rewards::grant($user_id, (int) $prize['reward_id'], 'scratch', 0, $order_id);
            if ($grant_id <= 0) {
                return 0;
            }
        }

        global $wpdb;

        $prev_show     = $wpdb->hide_errors();
        $prev_suppress = $wpdb->suppress_errors(true);

        $ok = $wpdb->insert(Zooboxi_Loyalty_Schema::scratch(), [
            'user_id'         => $user_id,
            'order_id'        => $order_id,
            'prize_kind'      => (string) $prize['kind'],
            'prize_paws'      => (int) ($prize['paws'] ?? 0),
            'prize_reward_id' => $prize['kind'] === 'reward' ? (int) $prize['reward_id'] : null,
            'grant_id'        => $grant_id ?: null,
            'state'           => 'sealed',
            'settled'         => 0,
            'created_at'      => Zooboxi_Loyalty::now(),
        ], ['%d', '%d', '%s', '%d', '%d', '%d', '%s', '%d', '%s']);

        $error = (string) $wpdb->last_error;
        $wpdb->suppress_errors($prev_suppress);
        if ($prev_show) {
            $wpdb->show_errors();
        }

        if (!$ok) {
            // UNIQUE(order_id): the hook fired twice. Undo the grant we just minted.
            if ($grant_id) {
                Zooboxi_Loyalty_Rewards::set_state($grant_id, 'cancelled');
            }
            if ($error !== '' && stripos($error, 'duplicate') === false) {
                error_log('[Zooboxi Loyalty] scratch insert failed: ' . $error);
            }
            return 0;
        }

        $card_id = (int) $wpdb->insert_id;

        // The grant now points back at the card that produced it.
        if ($grant_id) {
            Zooboxi_Loyalty_Rewards::set_state($grant_id, 'pending', ['source_ref' => $card_id]);
        }

        return $card_id;
    }

    /** Was this order placed from the app? (`_zooboxi_app_order`, or the older source stamp) */
    public static function is_app_order(\WC_Order $order): bool
    {
        if ((string) $order->get_meta(Zooboxi_Loyalty::APP_ORDER_META) === '1') {
            return true;
        }
        return (string) $order->get_meta('_zooboxi_source') === 'app';
    }

    /* ══════════════════════════════════════════════════════════════
       THE DRAW
       ══════════════════════════════════════════════════════════════ */

    /** The configured prize table, with unusable rows dropped and ids resolved. */
    public static function table(): array
    {
        $raw = Zooboxi_Loyalty::opt_json('scratch_table', self::DEFAULT_TABLE);

        $out = [];
        foreach ($raw as $row) {
            if (!is_array($row)) {
                continue;
            }
            $weight = (float) ($row['weight'] ?? 0);
            if ($weight <= 0) {
                continue;
            }
            $kind = (string) ($row['kind'] ?? '');

            if ($kind === 'paws') {
                $paws = (int) ($row['paws'] ?? 0);
                if ($paws <= 0) {
                    continue;
                }
                $out[] = ['kind' => 'paws', 'paws' => $paws, 'weight' => $weight, 'reward' => null];
                continue;
            }

            if ($kind !== 'reward') {
                continue;
            }

            // Ids win; keys are how the shipped defaults survive a fresh install.
            $reward = null;
            if (!empty($row['reward_id'])) {
                $reward = Zooboxi_Loyalty_Rewards::reward((int) $row['reward_id']);
            } elseif (!empty($row['reward_key'])) {
                $reward = Zooboxi_Loyalty_Rewards::reward_by_key((string) $row['reward_key']);
            }
            if ($reward === null || (int) $reward['is_active'] !== 1) {
                continue; // missing or switched off → the row simply is not drawn
            }
            // Never promise a gift with no product behind it.
            if ((string) $reward['kind'] === 'gift_product' && Zooboxi_Loyalty_Rewards::reward_product($reward) === null) {
                continue;
            }

            $out[] = [
                'kind'      => 'reward',
                'reward_id' => (int) $reward['id'],
                'weight'    => $weight,
                'reward'    => $reward,
            ];
        }

        return $out;
    }

    /**
     * One weighted draw. Returns null when nothing is drawable.
     *
     * `random_int` (CSPRNG) rather than mt_rand: this decides money, and a predictable
     * sequence would be farmable by anyone who could watch a few cards.
     */
    public static function roll(?array $table = null): ?array
    {
        $table = $table ?? self::table();
        if (empty($table)) {
            return null;
        }

        $total = 0.0;
        foreach ($table as $row) {
            $total += (float) $row['weight'];
        }
        if ($total <= 0) {
            return null;
        }

        // Integer arithmetic over a scaled total keeps the distribution exact.
        $scale  = 1000;
        $target = random_int(1, (int) round($total * $scale));
        $acc    = 0;

        foreach ($table as $row) {
            $acc += (int) round((float) $row['weight'] * $scale);
            if ($target <= $acc) {
                return $row;
            }
        }

        return $table[count($table) - 1];
    }

    /** Probability + expected cost per card, for the admin preview. */
    public static function odds(): array
    {
        $table = self::table();
        $total = 0.0;
        foreach ($table as $row) {
            $total += (float) $row['weight'];
        }

        $paw_value = Zooboxi_Loyalty::opt_float('paw_value_sar');
        $rows      = [];
        $expected  = 0.0;

        foreach ($table as $row) {
            $p    = $total > 0 ? (float) $row['weight'] / $total : 0.0;
            $cost = $row['kind'] === 'paws'
                ? (float) $row['paws'] * $paw_value
                : (float) ($row['reward']['cost_sar'] ?? 0);
            $expected += $p * $cost;

            $rows[] = [
                'kind'        => (string) $row['kind'],
                'label'       => $row['kind'] === 'paws'
                    ? sprintf('%d %s', (int) $row['paws'], Zooboxi_Loyalty::pick('بصمة', 'paws'))
                    : Zooboxi_Loyalty::pick((string) ($row['reward']['title_ar'] ?? ''), (string) ($row['reward']['title_en'] ?? '')),
                'weight'      => (float) $row['weight'],
                'probability' => round($p * 100, 2),
                'cost_sar'    => round($cost, 2),
            ];
        }

        return ['rows' => $rows, 'expected_cost_sar' => round($expected, 3), 'total_weight' => $total];
    }

    /* ══════════════════════════════════════════════════════════════
       READ
       ══════════════════════════════════════════════════════════════ */

    public static function find(int $card_id, int $user_id = 0): ?array
    {
        if ($card_id <= 0) {
            return null;
        }
        global $wpdb;
        $sql  = 'SELECT * FROM ' . Zooboxi_Loyalty_Schema::scratch() . ' WHERE id = %d';
        $args = [$card_id];
        if ($user_id > 0) {
            $sql   .= ' AND user_id = %d';
            $args[] = $user_id;
        }
        $row = $wpdb->get_row($wpdb->prepare($sql . ' LIMIT 1', $args), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    public static function by_order(int $order_id): ?array
    {
        if ($order_id <= 0) {
            return null;
        }
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::scratch() . ' WHERE order_id = %d LIMIT 1',
            $order_id
        ), ARRAY_A);
        return is_array($row) ? $row : null;
    }

    /** Sealed cards plus anything revealed in the last 30 days. */
    public static function recent_for_user(int $user_id, int $limit = 20): array
    {
        if ($user_id <= 0) {
            return [];
        }
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . Zooboxi_Loyalty_Schema::scratch()
            . " WHERE user_id = %d AND (state = 'sealed' OR created_at >= %s) ORDER BY id DESC LIMIT %d",
            $user_id,
            gmdate('Y-m-d H:i:s', time() - 30 * DAY_IN_SECONDS),
            $limit
        ), ARRAY_A);
        return is_array($rows) ? $rows : [];
    }

    /**
     * Paws that are revealed but not yet real (their order has not been delivered) —
     * the `paws.pending` number in the summary.
     */
    public static function pending_paws(int $user_id): int
    {
        if ($user_id <= 0) {
            return 0;
        }
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            'SELECT COALESCE(SUM(prize_paws), 0) FROM ' . Zooboxi_Loyalty_Schema::scratch()
            . " WHERE user_id = %d AND prize_kind = 'paws' AND settled = 0",
            $user_id
        ));
    }

    /* ══════════════════════════════════════════════════════════════
       REVEAL + SETTLE
       ══════════════════════════════════════════════════════════════ */

    /**
     * Rub the foil off. Idempotent — a second reveal returns the same card unchanged,
     * so a retried request never looks like a second win.
     */
    public static function reveal(int $card_id, int $user_id): ?array
    {
        $card = self::find($card_id, $user_id);
        if ($card === null) {
            return null;
        }
        if ((string) $card['state'] === 'revealed') {
            return $card;
        }

        global $wpdb;
        $wpdb->update(
            Zooboxi_Loyalty_Schema::scratch(),
            ['state' => 'revealed', 'revealed_at' => Zooboxi_Loyalty::now()],
            ['id' => $card_id, 'user_id' => $user_id],
            ['%s', '%s'],
            ['%d', '%d']
        );

        return self::find($card_id, $user_id);
    }

    /**
     * The order was delivered: the prize becomes real, exactly once.
     *
     * Paws go through the ledger (whose UNIQUE key on `scratch:{id}` is the guard), a
     * reward grant flips `pending` → `active` and starts its validity clock.
     */
    public static function settle_for_order(\WC_Order $order): bool
    {
        $card = self::by_order((int) $order->get_id());
        if ($card === null || (int) $card['settled'] === 1) {
            return false;
        }

        $user_id = (int) $card['user_id'];

        if ((string) $card['prize_kind'] === 'paws') {
            $paws = (int) $card['prize_paws'];
            if ($paws > 0) {
                Zooboxi_Loyalty_Ledger::add(
                    $user_id,
                    $paws,
                    'scratch',
                    'scratch',
                    (int) $card['id'],
                    Zooboxi_Loyalty::pick('اخدش واربح', 'Scratch card')
                );
            }
        } elseif (!empty($card['grant_id'])) {
            Zooboxi_Loyalty_Rewards::activate((int) $card['grant_id']);
        }

        global $wpdb;
        $wpdb->update(
            Zooboxi_Loyalty_Schema::scratch(),
            ['settled' => 1],
            ['id' => (int) $card['id']],
            ['%d'],
            ['%d']
        );

        return true;
    }

    /** The order died before delivery: the grant is cancelled and no paws are written. */
    public static function cancel_for_order(int $order_id): void
    {
        Zooboxi_Loyalty_Rewards::cancel_pending_for_order($order_id);
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    public static function dto(array $card, int $user_id = 0): array
    {
        $order    = function_exists('wc_get_order') ? wc_get_order((int) $card['order_id']) : null;
        $revealed = (string) $card['state'] === 'revealed';

        $prize = null;
        if ($revealed) {
            if ((string) $card['prize_kind'] === 'paws') {
                $prize = ['kind' => 'paws', 'paws' => (int) $card['prize_paws']];
            } else {
                $reward = Zooboxi_Loyalty_Rewards::reward((int) $card['prize_reward_id']);
                $prize  = [
                    'kind'     => 'reward',
                    'reward'   => $reward ? Zooboxi_Loyalty_Rewards::reward_dto($reward, $user_id) : null,
                    'grant_id' => (int) ($card['grant_id'] ?? 0),
                ];
            }
        }

        return [
            'id'    => (int) $card['id'],
            'order' => [
                'id'     => (int) $card['order_id'],
                'number' => $order instanceof \WC_Order ? (string) $order->get_order_number() : (string) $card['order_id'],
            ],
            'state'               => (string) $card['state'],
            'prize'               => $prize,
            'settled'             => (int) $card['settled'] === 1,
            'revealed_at'         => Zooboxi_Loyalty::iso($card['revealed_at'] ?? null),
            'created_at'          => Zooboxi_Loyalty::iso((string) $card['created_at']),
            'activation_hint_ar'  => 'تُفعَّل عند تسليم الطلب',
            'activation_hint_en'  => 'Activates when your order is delivered',
        ];
    }

    /** @return array<int,array> */
    public static function dtos(array $cards, int $user_id = 0): array
    {
        $out = [];
        foreach ($cards as $card) {
            $out[] = self::dto($card, $user_id);
        }
        return $out;
    }
}
