<?php
/**
 * ════════════════════════════════════════════════════════════════════
 * Zooboxi_Cart_Shelf — one basket belongs to one storefront
 *
 * إكسبريس and زوبكسي are two shops. A customer cannot walk out of both
 * with one bag: an order is either the 2-hour branch's or the main
 * warehouse's, never a mixture that quietly becomes two deliveries and two
 * promises on one receipt.
 *
 * So the cart carries the shelf it was started on. Adding from the other
 * storefront is refused with `shelf_conflict` — the app then offers the
 * switch, and switching does not destroy anything: the basket that steps
 * aside is **stashed**, and the one being stepped into is restored. Two
 * baskets, one at a time, and nothing typed twice.
 *
 * Gift lines are not stashed. A reward that is claimed into a basket is
 * released back to the customer's grants when its line goes, which is what
 * removing it through WooCommerce's own path does — so it returns to the
 * rewards screen rather than being duplicated into both baskets.
 *
 * The rule is enforced in ONE place — WooCommerce's own add-to-cart
 * validation — because a basket has many doors: the app, the website, «اطلب
 * مجددًا», a subscription's order-now, a claimed gift, and the merge that
 * happens when a guest signs in. A guard on the app's route alone would be a
 * rule the store keeps only when asked politely.
 *
 * A signed-in customer shares one WooCommerce session between the app and the
 * website, so the shelf and the stash are kept in user meta for them: a
 * session that expires after two idle days must not leave a basket whose
 * lines survive but whose storefront is forgotten.
 * ════════════════════════════════════════════════════════════════════
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Cart_Shelf
{
    /** The shelf this cart belongs to, in the customer's session. */
    private const SHELF_KEY = 'zb_cart_shelf';

    /** The other basket, waiting: ['express' => [lines], 'all' => [lines]]. */
    private const STASH_KEY = 'zb_cart_stash';

    public const EXPRESS = 'express';
    public const ALL     = 'all';

    private static function session()
    {
        return (function_exists('WC') && WC()->session) ? WC()->session : null;
    }

    /** Signed-in baskets outlive their session, so their shelf must too. */
    private static function user_id(): int
    {
        return function_exists('get_current_user_id') ? (int) get_current_user_id() : 0;
    }

    private static function read(string $key, $fallback)
    {
        $uid = self::user_id();
        if ($uid > 0) {
            $value = get_user_meta($uid, '_' . $key, true);
            if ($value !== '') {
                return $value;
            }
        }
        $session = self::session();
        return $session === null ? $fallback : $session->get($key, $fallback);
    }

    private static function write(string $key, $value): void
    {
        $uid = self::user_id();
        if ($uid > 0) {
            update_user_meta($uid, '_' . $key, $value);
        }
        $session = self::session();
        if ($session !== null) {
            $session->set($key, $value);
        }
    }

    private static function cart()
    {
        return (function_exists('WC') && WC()->cart) ? WC()->cart : null;
    }

    /** The shelf the current basket belongs to; '' when the basket is empty. */
    public static function current(): string
    {
        $cart = self::cart();
        $session = self::session();
        if ($cart === null || $session === null || $cart->is_empty()) {
            return '';
        }
        $shelf = (string) self::read(self::SHELF_KEY, '');
        if (self::valid($shelf)) {
            return $shelf;
        }

        // A basket with lines but no shelf is a basket from before this rule,
        // or one whose session expired under it. Read it back from where its
        // lines can actually come from rather than letting the next add
        // relabel the whole thing.
        return self::infer_from_cart();
    }

    public static function valid(string $shelf): bool
    {
        return $shelf === self::EXPRESS || $shelf === self::ALL;
    }

    /** The other storefront's name, given one. */
    public static function other(string $shelf): string
    {
        return $shelf === self::EXPRESS ? self::ALL : self::EXPRESS;
    }

    public static function remember(string $shelf): void
    {
        if (self::valid($shelf)) {
            self::write(self::SHELF_KEY, $shelf);
        }
    }

    /**
     * Which storefront a basket's lines belong to, when nothing recorded it.
     *
     * زوبكسي unless only the branch could have filled it. The core the branch
     * carries is also the catalogue's best-selling thousand, so "every line
     * fits the branch" is true of most ordinary baskets — reading that as an
     * express basket would quietly put the website's customers on the 2-hour
     * shelf and then refuse their next main-warehouse item.
     */
    private static function infer_from_cart(): string
    {
        $cart = self::cart();
        if ($cart === null || $cart->is_empty()) {
            return '';
        }

        $ids = [];
        foreach ($cart->get_cart() as $item) {
            $pid = (int) ($item['product_id'] ?? 0);
            if ($pid) {
                $ids[] = $pid;
            }
        }
        if (empty($ids)) {
            return '';
        }

        $all = self::codes_for(self::ALL);
        if (empty($all)) {
            return self::ALL;
        }
        $fits_all = true;
        foreach ($ids as $pid) {
            if (!self::held_by($pid, $all)) {
                $fits_all = false;
                break;
            }
        }
        if ($fits_all) {
            return self::ALL;
        }

        $express = self::codes_for(self::EXPRESS);
        if (empty($express)) {
            return self::ALL;
        }
        foreach ($ids as $pid) {
            if (!self::held_by($pid, $express)) {
                return self::ALL;
            }
        }
        return self::EXPRESS;
    }

    /**
     * The warehouses a shelf may be filled from, for this customer's point.
     *
     * إكسبريس is the nearest express branch, open or shut — a basket does not
     * change storefront because the clock passed eleven. زوبكسي is the city's
     * central warehouse, or the national hub when the city has none: the same
     * single anchor the catalogue's زوبكسي shelf is built from, so what the
     * customer was shown and what the basket accepts cannot disagree.
     *
     * @return string[] warehouse codes; empty when the point is unknown.
     */
    public static function codes_for(string $shelf): array
    {
        if (!class_exists('Zooboxi_Warehouse_Manager')) {
            return [];
        }
        [$lat, $lng] = self::point();
        if (!$lat && !$lng) {
            return [];
        }

        // Every line of a cart read asks this, and the answer cannot change
        // between them: without the memo a fifteen-line cart scans the
        // warehouse table forty-odd times.
        $memo_key = $shelf . '|' . round($lat, 4) . '|' . round($lng, 4);
        if (array_key_exists($memo_key, self::$codes_memo)) {
            return self::$codes_memo[$memo_key];
        }

        if ($shelf === self::EXPRESS) {
            // The NEAREST covering branch, not the first row the database
            // happens to return — the same branch the catalogue's إكسبريس
            // shelf and the fulfilment resolver pick, or the basket would
            // accept what the shelf never showed.
            $best = null;
            $best_km = null;
            foreach (Zooboxi_Warehouse_Manager::get_active() as $wh) {
                if (empty($wh['is_express_enabled'])) continue;
                if (empty($wh['latitude']) || empty($wh['longitude'])) continue;
                if (!Zooboxi_Warehouse_Manager::is_within_express_zone($wh, $lat, $lng)) continue;
                if (!class_exists('Zooboxi_Geo_Helper')) continue;
                $km = Zooboxi_Geo_Helper::distance($lat, $lng, (float) $wh['latitude'], (float) $wh['longitude']);
                if ($best_km === null || $km < $best_km) {
                    $best_km = $km;
                    $best = (string) ($wh['warehouse_code'] ?? '');
                }
            }
            return self::$codes_memo[$memo_key] = (($best === null || $best === '') ? [] : [$best]);
        }

        $city = '';
        if (class_exists('Zooboxi_Fulfillment')) {
            $city = (string) Zooboxi_Fulfillment::detect_city($lat, $lng);
        }
        $central = $city !== '' ? Zooboxi_Warehouse_Manager::find_central($city) : null;
        $anchor = !empty($central['warehouse_code'])
            ? $central
            : Zooboxi_Warehouse_Manager::get_main_hub();
        $code = (string) ($anchor['warehouse_code'] ?? '');
        return self::$codes_memo[$memo_key] = ($code === '' ? [] : [$code]);
    }

    /** Per-request answers to codes_for(), keyed by shelf and point. */
    private static array $codes_memo = [];

    /** Does any of [$codes] actually hold this product? */
    public static function held_by(int $product_id, array $codes): bool
    {
        if (empty($codes) || !class_exists('Zooboxi_Stock_Manager')) {
            return true;
        }
        foreach (Zooboxi_Stock_Manager::get_warehouse_stock($product_id) as $row) {
            $code = (string) ($row['warehouse_code'] ?? '');
            if (in_array($code, $codes, true) && (int) ($row['in_stock'] ?? 0) > 0) {
                return true;
            }
        }
        return false;
    }

    /**
     * Whether a product may join the basket of [$shelf].
     *
     * Unknown location, or a store with no warehouse data, answers yes: a rule
     * that cannot be evaluated must not block a sale.
     */
    public static function fits(int $product_id, string $shelf): bool
    {
        $codes = self::codes_for($shelf);
        return empty($codes) ? true : self::held_by($product_id, $codes);
    }

    private static function point(): array
    {
        if (class_exists('Zooboxi_V2_Bootstrap')) {
            [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();
            if ($lat || $lng) {
                return [(float) $lat, (float) $lng];
            }
        }
        $lat = isset($_COOKIE['zooboxi_lat']) ? (float) $_COOKIE['zooboxi_lat'] : 0.0;
        $lng = isset($_COOKIE['zooboxi_lng']) ? (float) $_COOKIE['zooboxi_lng'] : 0.0;
        return [$lat, $lng];
    }

    /** How many lines are waiting in the stashed basket of [$shelf]. */
    /** How many LINES wait in the stashed basket of [$shelf] — «3 منتجات». */
    public static function stashed_count(string $shelf): int
    {
        $stash = self::stash();
        return count(self::lines_of($stash[$shelf] ?? []));
    }

    /**
     * Moves the customer to the other basket: what is in the cart now is put
     * away under its own shelf, and whatever was waiting under [$target] is
     * put back.
     *
     * @return array{restored:int, stashed:int}
     */
    public static function switch_to(string $target): array
    {
        $cart = self::cart();
        if ($cart === null || !self::valid($target)) {
            return ['restored' => 0, 'stashed' => 0, 'lost' => 0];
        }

        // Switching to the basket already open is not a switch. Without this
        // a double tap would unclaim the gifts and rebuild the same cart.
        $from = self::current();
        if ($from === $target) {
            return ['restored' => 0, 'stashed' => 0, 'lost' => 0];
        }

        // A non-empty basket whose shelf was forgotten still belongs to
        // somebody — it goes to the other side rather than into the bin.
        if ($from === '' && !$cart->is_empty()) {
            $from = self::other($target);
        }

        $stash = self::stash();

        // Put the current basket away — real lines only.
        $lines = [];
        if ($from !== '') {
            foreach ($cart->get_cart() as $key => $item) {
                if (class_exists('Zooboxi_Loyalty_Rewards')
                    && Zooboxi_Loyalty_Rewards::line_grant_id($item) > 0) {
                    // Through WooCommerce's own path, so the reward is
                    // unclaimed and waits on the rewards screen instead of
                    // vanishing with the basket.
                    $cart->remove_cart_item($key);
                    continue;
                }
                $lines[] = [
                    'product_id'   => (int) ($item['product_id'] ?? 0),
                    'variation_id' => (int) ($item['variation_id'] ?? 0),
                    'quantity'     => max(1, (int) ($item['quantity'] ?? 1)),
                    'variation'    => is_array($item['variation'] ?? null) ? $item['variation'] : [],
                ];
            }
            $stash[$from] = [
                'lines'   => $lines,
                // «كما هي» has to include the code they typed.
                'coupons' => array_values($cart->get_applied_coupons()),
            ];
        }

        $cart->empty_cart();

        $restore = self::lines_of($stash[$target] ?? []);
        $coupons = self::coupons_of($stash[$target] ?? []);
        self::remember($target);

        $result = self::restore_lines($restore, $coupons);

        // Only what actually came back leaves the stash. A product that went
        // out of stock while it waited stays waiting instead of vanishing
        // with no record.
        if (empty($result['left'])) {
            unset($stash[$target]);
        } else {
            $stash[$target] = ['lines' => $result['left'], 'coupons' => []];
        }
        self::save_stash($stash);

        return [
            'restored' => $result['restored'],
            'stashed'  => count($lines),
            'lost'     => count($result['left']),
        ];
    }

    /**
     * Puts a stashed basket back into the cart.
     *
     * @return array{restored:int, left:array} what returned, and what could not.
     */
    private static function restore_lines(array $lines, array $coupons): array
    {
        $cart = self::cart();
        if ($cart === null) {
            return ['restored' => 0, 'left' => $lines];
        }

        $restored = 0;
        $left = [];
        self::$restoring = true;
        foreach ($lines as $line) {
            $pid = (int) ($line['product_id'] ?? 0);
            if (!$pid) {
                continue;
            }
            try {
                $added = $cart->add_to_cart(
                    $pid,
                    max(1, (int) ($line['quantity'] ?? 1)),
                    (int) ($line['variation_id'] ?? 0),
                    is_array($line['variation'] ?? null) ? $line['variation'] : []
                );
            } catch (\Throwable $e) {
                $added = false;
            }
            if ($added) {
                $restored++;
            } else {
                $left[] = $line;
            }
        }

        self::$restoring = false;

        foreach ($coupons as $code) {
            try {
                $cart->apply_coupon((string) $code);
            } catch (\Throwable $e) {
                // A code that expired while the basket waited simply does not
                // come back; WooCommerce's own notice says why.
            }
        }

        return ['restored' => $restored, 'left' => $left];
    }

    /**
     * The basket waiting for [$shelf], put back into an empty cart.
     *
     * An order empties the cart, which would otherwise orphan the other
     * basket: the customer would see nothing, add a line, and the next switch
     * would overwrite what was waiting.
     */
    public static function resume(string $shelf): int
    {
        $cart = self::cart();
        if ($cart === null || !$cart->is_empty() || !self::valid($shelf)) {
            return 0;
        }
        $stash = self::stash();
        if (empty($stash[$shelf])) {
            return 0;
        }

        $result = self::restore_lines(self::lines_of($stash[$shelf]), self::coupons_of($stash[$shelf]));
        if (empty($result['left'])) {
            unset($stash[$shelf]);
        } else {
            $stash[$shelf] = ['lines' => $result['left'], 'coupons' => []];
        }
        self::save_stash($stash);
        self::remember($shelf);
        return $result['restored'];
    }

    private static function lines_of($entry): array
    {
        if (isset($entry['lines']) && is_array($entry['lines'])) {
            return $entry['lines'];
        }
        // A stash written before coupons were kept is a bare list of lines.
        return is_array($entry) ? $entry : [];
    }

    private static function coupons_of($entry): array
    {
        return isset($entry['coupons']) && is_array($entry['coupons']) ? $entry['coupons'] : [];
    }

    /** What the app needs to draw "you are in this basket, the other holds N". */
    public static function payload(): array
    {
        $shelf = self::current();
        // Reported even when the cart is empty — an order just emptied it, and
        // the other basket is still waiting to be told about.
        $other = $shelf === '' ? '' : self::other($shelf);
        $waiting = [];
        foreach ([self::EXPRESS, self::ALL] as $side) {
            $count = self::stashed_count($side);
            if ($count > 0 && $side !== $shelf) {
                $waiting[$side] = $count;
            }
        }
        if ($other === '' && !empty($waiting)) {
            $other = array_key_first($waiting);
        }

        return [
            'shelf'       => $shelf,
            'other_shelf' => $other,
            'other_count' => $other === '' ? 0 : ($waiting[$other] ?? 0),
            // False when there is no basket yet: the app then asks «this
            // product is from the other store» rather than «your basket is».
            'started'     => $shelf !== '',
        ];
    }

    /* ── The one door ───────────────────────────────────────────────── */

    /**
     * WooCommerce asks every add — the app's route, the website, «اطلب
     * مجددًا», a subscription, a claimed gift, the guest→customer merge —
     * whether the line may join the cart. That is the only honest place for
     * this rule; a guard on the app's route would be a rule the store keeps
     * only when asked politely.
     */
    public static function hooks(): void
    {
        add_filter('woocommerce_add_to_cart_validation', [__CLASS__, 'validate'], 20, 3);
        add_action('woocommerce_add_to_cart', [__CLASS__, 'on_added'], 20, 3);
        add_action('woocommerce_cart_emptied', [__CLASS__, 'on_emptied'], 20);
    }

    /**
     * @param bool $passed
     * @param int  $product_id
     * @param int  $quantity
     */
    public static function validate($passed, $product_id, $quantity)
    {
        if (!$passed) {
            return $passed;
        }
        $shelf = self::current();
        if ($shelf === '' || self::$restoring) {
            return $passed;
        }
        // A gift is claimed into whatever basket is open; it is not a purchase
        // and it does not change where the order is picked from.
        if (self::$claiming_gift) {
            return $passed;
        }
        if (self::fits((int) $product_id, $shelf)) {
            return $passed;
        }

        if (function_exists('wc_add_notice')) {
            wc_add_notice(
                sprintf(
                    /* translators: %s: the storefront the basket belongs to. */
                    __('سلتك من متجر %s، والطلب الواحد يكون من متجر واحد.', 'zooboxi'),
                    self::label($shelf)
                ),
                'error'
            );
        }
        return false;
    }

    /** The first line decides which storefront the basket belongs to. */
    public static function on_added($key, $product_id, $quantity = 1): void
    {
        $cart = self::cart();
        // The basket is this line's to name only if this line started it.
        $started = $cart !== null
            && (int) $cart->get_cart_contents_count() <= max(1, (int) $quantity);
        // The RECORDED shelf, not current(): by the time this hook runs the
        // line is already in the cart, so current() would infer one and this
        // would never label anything.
        $recorded = (string) self::read(self::SHELF_KEY, '');
        if (!$started || self::valid($recorded)) {
            return;
        }
        $requested = class_exists('Zooboxi_V2_Bootstrap') ? Zooboxi_V2_Bootstrap::shelf() : '';
        if (self::valid($requested) && self::fits((int) $product_id, $requested)) {
            self::remember($requested);
            return;
        }
        // No tab said anything (the website, a subscription, a re-order): the
        // basket belongs to the storefront that can actually fill it. زوبكسي
        // when both can — the wider shelf keeps the most doors open — and
        // إكسبريس when only the branch holds it, because labelling that line
        // زوبكسي would make the very first product in the basket off-shelf.
        if (self::fits((int) $product_id, self::ALL)) {
            self::remember(self::ALL);
            return;
        }
        $express = self::codes_for(self::EXPRESS);
        $fits_express = !empty($express) && self::held_by((int) $product_id, $express);
        self::remember($fits_express ? self::EXPRESS : self::ALL);
    }

    /**
     * An empty basket belongs to nobody.
     *
     * Forgetting matters more than remembering: an order empties the cart, and
     * a shelf that outlives it would label the customer's NEXT basket — from
     * the website, from «اطلب مجددًا», from a subscription — with the
     * storefront of the order they already received, and then refuse
     * everything that does not fit it. `switch_to()` re-remembers after its
     * own `empty_cart()`, so nothing is lost there.
     */
    public static function on_emptied(): void
    {
        $uid = self::user_id();
        if ($uid > 0) {
            delete_user_meta($uid, '_' . self::SHELF_KEY);
        }
        $session = self::session();
        if ($session !== null) {
            $session->set(self::SHELF_KEY, '');
        }
    }

    /**
     * True while the class is putting a stashed basket back — or while the
     * store is merging a guest's basket into the customer they just signed in
     * as. Neither is a customer choosing to mix two storefronts, and judging
     * them would silently delete lines the customer already had.
     */
    public static bool $restoring = false;

    /** Hands a guest's waiting basket to the account they just signed into. */
    public static function adopt_stash(array $stash): void
    {
        if (empty($stash)) {
            return;
        }
        $mine = self::stash();
        foreach ($stash as $shelf => $entry) {
            if (!self::valid((string) $shelf) || empty($entry)) {
                continue;
            }
            // The customer's own waiting basket wins: it is the older promise.
            if (empty($mine[$shelf])) {
                $mine[$shelf] = $entry;
            }
        }
        self::save_stash($mine);
    }

    public static function stash_key(): string
    {
        return self::STASH_KEY;
    }

    /** Re-reads the shelf from the lines actually in the cart. */
    public static function relabel(): void
    {
        $uid = self::user_id();
        if ($uid > 0) {
            delete_user_meta($uid, '_' . self::SHELF_KEY);
        }
        $session = self::session();
        if ($session !== null) {
            $session->set(self::SHELF_KEY, '');
        }
        $inferred = self::infer_from_cart();
        if ($inferred !== '') {
            self::remember($inferred);
        }
    }

    /** True while the loyalty module is claiming a gift into the basket. */
    public static bool $claiming_gift = false;

    public static function label(string $shelf): string
    {
        return $shelf === self::EXPRESS
            ? __('إكسبريس', 'zooboxi')
            : __('زوبكسي', 'zooboxi');
    }

    private static function stash(): array
    {
        $stash = self::read(self::STASH_KEY, []);
        return is_array($stash) ? $stash : [];
    }

    private static function save_stash(array $stash): void
    {
        // Through write(), so a signed-in customer's waiting basket survives
        // the session expiring — «تقدر ترجع لها في أي وقت» has to be true.
        self::write(self::STASH_KEY, $stash);
    }
}
