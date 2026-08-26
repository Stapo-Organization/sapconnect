<?php
/**
 * Zooboxi Smart Shipments — quantity-aware split-shipment cart/checkout.
 *
 * Groups the cart into delivery "shipments" by the fastest tier that can fulfil each
 * line's FULL quantity (single-source per line): express (branch, open, has full qty)
 * → same-day (central) → shipping (hub). Each group becomes its own WooCommerce
 * shipping package, so it gets its own rate, promise and (per-package) free-shipping —
 * all under ONE order and ONE payment. Express-first by default.
 *
 * FEATURE-FLAGGED: does nothing unless option `zooboxi_smart_shipments` = 'yes'.
 * Fail-safe: any error falls back to the single default package (checkout never breaks).
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Smart_Shipments
{
    public const FLAG = 'zooboxi_smart_shipments';

    /**
     * Stamped onto every shipping package so its WooCommerce rate-cache hash changes when our
     * rate logic changes — WC caches rates by package hash and does NOT invalidate on code deploy,
     * so without this a customer keeps seeing stale (pre-gating) shipping options. Bump on changes.
     */
    private const RATE_VER = '2';

    public static function enabled(): bool
    {
        return get_option(self::FLAG, 'no') === 'yes';
    }

    public function __construct()
    {
        if (!self::enabled()) {
            return; // feature off → zero footprint
        }
        // Split into packages AFTER the GPS injector (priority 10) has run.
        add_filter('woocommerce_cart_shipping_packages', [$this, 'split_packages'], 20);
        // Name each shipment in the totals/checkout by its delivery tier (Arabic) instead of
        // WooCommerce's default English "Shipment 1/2".
        add_filter('woocommerce_shipping_package_name', [$this, 'shipment_name'], 10, 3);
        // Localize the few WooCommerce cart strings the theme leaves in English.
        add_filter('gettext', [$this, 'localize_cart_strings'], 20, 3);
        // Render the coupon ("كود الخصم") inside the LEFT summary column, next to the price details.
        add_action('woocommerce_before_cart_totals', [$this, 'render_left_coupon'], 20);
        // Route the cart's "Change address" link to the GPS/map popup (addresses are coordinate-based).
        add_action('wp_footer', [$this, 'cart_address_map_js'], 120);
        // Cart items are now grouped into branded shipment cards directly in the cart template
        // (woocommerce/cart/cart.php override) — the old totals-column preview box is retired
        // to avoid duplicating that information.
        add_action('wp_head', [$this, 'styles']);
    }

    /* ── Package splitting (the functional core) ───── */

    public function split_packages(array $packages): array
    {
        try {
            if (empty($packages) || !function_exists('WC') || !WC()->cart) {
                return $packages;
            }
            [$lat, $lng] = $this->customer_latlng();
            if (!$lat || !$lng) {
                return $packages; // no location → leave WooCommerce's single package
            }

            $base = $packages[0];
            $contents = $base['contents'] ?? [];
            if (count($contents) < 1) {
                return $packages;
            }

            $groups = self::build_tier_groups($contents, (float) $lat, (float) $lng);
            if (empty($groups)) {
                return $packages;
            }
            if (count($groups) === 1) {
                // Single tier — don't split, but TAG the package so the shipping methods can gate
                // to exactly one option (no "change delivery speed" choice).
                $tier = array_key_first($groups);
                $packages[0]['zooboxi_tier']      = $tier;
                $packages[0]['zooboxi_warehouse'] = $groups[$tier]['warehouse'];
                $packages[0]['zooboxi_v']         = self::RATE_VER;
                return $packages;
            }

            $out = [];
            foreach ($groups as $tier => $g) {
                $pkg = $base;
                $pkg['contents'] = $g['contents'];
                $pkg['contents_cost'] = $g['cost'];
                $pkg['zooboxi_tier'] = $tier;
                $pkg['zooboxi_warehouse'] = $g['warehouse'];
                $pkg['zooboxi_v'] = self::RATE_VER;
                $out[] = $pkg;
            }
            return $out;
        } catch (\Throwable $e) {
            error_log('Zooboxi smart shipments split failed: ' . $e->getMessage());
            return $packages; // fail-safe — never break checkout
        }
    }

    /**
     * On the cart page, intercept WooCommerce's "Change address" link and open the GPS/map popup
     * (the same `#zooboxi-location-modal` the header uses). After the customer confirms a new pin,
     * the popup reloads the page → the cart recomputes shipments/stock for the new coordinates.
     */
    public function cart_address_map_js(): void
    {
        if ((is_admin() && !wp_doing_ajax()) || !function_exists('is_cart') || !is_cart()) {
            return;
        }
        ?>
        <script>
        (function(){
            if (typeof jQuery === 'undefined') { return; }
            jQuery(function($){
                $(document).on('click', '.woocommerce-cart .shipping-calculator-button, .woocommerce-cart .woocommerce-shipping-destination a', function(e){
                    e.preventDefault();
                    var $m = $('#zooboxi-location-modal');
                    if ($m.length) { $m.stop(true, true).fadeIn(300); }
                });
            });
        })();
        </script>
        <?php
    }

    /** Coupon form rendered in the LEFT summary column (self-contained; WC processes apply_coupon). */
    public function render_left_coupon(): void
    {
        if (!function_exists('wc_coupons_enabled') || !wc_coupons_enabled()) {
            return;
        }
        if (!function_exists('WC') || !WC()->cart || WC()->cart->is_empty()) {
            return;
        }
        ?>
        <form class="zb-left-coupon" method="post" action="<?php echo esc_url(wc_get_cart_url()); ?>">
            <div class="zb-lc-title"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#0d9488" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg><?php esc_html_e('كود الخصم', 'zooboxi'); ?></div>
            <div class="zb-lc-row">
                <input type="text" name="coupon_code" class="input-text" autocomplete="off"
                       placeholder="<?php esc_attr_e('أدخل كود الخصم', 'zooboxi'); ?>" />
                <button type="submit" class="button" name="apply_coupon" value="apply"><?php esc_html_e('تطبيق', 'zooboxi'); ?></button>
            </div>
            <?php wp_nonce_field('woocommerce-cart', 'woocommerce-cart-nonce'); ?>
        </form>
        <?php
    }

    /** Localize the handful of WooCommerce cart strings that surface in English. */
    public function localize_cart_strings($translated, $text, $domain)
    {
        if ('woocommerce' !== $domain) {
            return $translated;
        }
        switch ($text) {
            case 'Shipping to %s.':
                return 'الشحن إلى %s.';
            case 'Change address':
                return 'تغيير العنوان';
            case 'Calculate shipping':
                return 'احسب الشحن';
            case 'Enter a different address':
                return 'أدخل عنواناً مختلفاً';
            case 'Update cart':
                return 'تحديث السلة';
            case 'Apply coupon':
                return 'تطبيق الكود';
            case 'Coupon code':
                return 'أدخل كود الخصم';
        }
        return $translated;
    }

    /** Name each split shipment by its delivery tier (Arabic), e.g. "🚀 شحنة التوصيل السريع". */
    public function shipment_name(string $name, int $i, $package): string
    {
        $tier = is_array($package) ? ($package['zooboxi_tier'] ?? '') : '';
        switch ($tier) {
            case Zooboxi_Delivery_Engine::TYPE_EXPRESS:
                return __('🚀 شحنة التوصيل السريع', 'zooboxi');
            case Zooboxi_Delivery_Engine::TYPE_STANDARD:
                return __('🚚 شحنة اليوم التالي', 'zooboxi');
            case Zooboxi_Delivery_Engine::TYPE_SHIPPING:
                return __('📦 شحنة الشحن العادي', 'zooboxi');
        }
        return sprintf(__('الشحنة %d', 'zooboxi'), (int) $i + 1);
    }

    /**
     * Group cart contents into delivery tiers via the SINGLE source of truth
     * (Zooboxi_Fulfillment), splitting a single line's quantity across tiers when the
     * nearest express branch can't serve the full qty (e.g. 3 express + 2 same-day of one
     * product). Returns tier => group, ordered fastest-first. Each split unit is a clone of
     * the cart item with partial quantity + proportional line costs, so WooCommerce charges
     * shipping correctly per package. Any unreachable remainder falls into the shipping tier
     * (never dropped — packages always sum to the full cart quantity).
     *
     * Public + static so the mobile API can project the SAME grouping into JSON without
     * booting this class (whose constructor is the web feature flag). Pure function.
     *
     * @return array<string, array{contents: array, cost: float, warehouse: string, lines: array}>
     */
    public static function build_tier_groups(array $contents, float $lat, float $lng): array
    {
        $order = [
            Zooboxi_Delivery_Engine::TYPE_EXPRESS  => 1,
            Zooboxi_Delivery_Engine::TYPE_STANDARD => 2,
            Zooboxi_Delivery_Engine::TYPE_SHIPPING => 3,
        ];
        $groups = [];

        foreach ($contents as $key => $item) {
            $pid = (int) ($item['product_id'] ?? 0);
            if (!$pid) {
                continue;
            }
            $qty = max(1, (int) ($item['quantity'] ?? 1));

            // Stock allocates in PIECES; a pack line (كرتون = N حبة) needs
            // qty×N of them. The allocation is then regrouped into WHOLE
            // packs — a carton cannot ship half from one warehouse.
            $units = class_exists('Zooboxi_Units') ? Zooboxi_Units::for_cart_item($item) : 1;

            $plan  = Zooboxi_Fulfillment::resolve($pid, $qty * $units, $lat, $lng);
            $alloc = $plan['allocation'];

            if ($units > 1) {
                $regrouped  = [];
                $carry      = 0;
                $used_units = 0;
                foreach ($alloc as $a) {
                    $pieces = (int) ($a['qty'] ?? 0) + $carry;
                    $whole  = min(intdiv($pieces, $units), $qty - $used_units);
                    $carry  = $pieces - $whole * $units;
                    if ($whole > 0) {
                        $a['qty']    = $whole;
                        $regrouped[] = $a;
                        $used_units += $whole;
                    }
                }
                $alloc = $regrouped;
            }

            // Guarantee the whole line is covered — any unreachable remainder ships nationally.
            $allocated = 0;
            foreach ($alloc as $a) {
                $allocated += (int) $a['qty'];
            }
            if ($allocated < $qty) {
                $alloc[] = [
                    'tier'           => Zooboxi_Delivery_Engine::TYPE_SHIPPING,
                    'qty'            => $qty - $allocated,
                    'warehouse_code' => '',
                ];
            }

            $product    = $item['data'] ?? null;
            $name       = $product ? $product->get_name() : '';
            $lineTotal  = (float) ($item['line_total'] ?? 0);
            $lineSub    = (float) ($item['line_subtotal'] ?? $lineTotal);
            $lineTax    = (float) ($item['line_tax'] ?? 0);
            $lineSubTax = (float) ($item['line_subtotal_tax'] ?? 0);
            $single     = count($alloc) === 1;

            foreach ($alloc as $a) {
                $tier = $a['tier'];
                $aqty = (int) $a['qty'];
                if ($aqty <= 0) {
                    continue;
                }

                if (!isset($groups[$tier])) {
                    $groups[$tier] = ['contents' => [], 'cost' => 0.0, 'warehouse' => $a['warehouse_code'] ?? '', 'lines' => []];
                }

                if ($single) {
                    // Whole line in one tier — keep the original item & key (no proportional math).
                    $groups[$tier]['contents'][$key] = $item;
                    $groups[$tier]['cost'] += $lineTotal + $lineTax;
                } else {
                    // Intra-line split — clone with partial qty + proportional costs.
                    $frac  = $aqty / $qty;
                    $clone = $item;
                    $clone['quantity']          = $aqty;
                    $clone['line_total']        = $lineTotal * $frac;
                    $clone['line_subtotal']     = $lineSub * $frac;
                    $clone['line_tax']          = $lineTax * $frac;
                    $clone['line_subtotal_tax'] = $lineSubTax * $frac;
                    $groups[$tier]['contents'][$key . '__' . $tier] = $clone;
                    $groups[$tier]['cost'] += $clone['line_total'] + $clone['line_tax'];
                }

                if (empty($groups[$tier]['warehouse']) && !empty($a['warehouse_code'])) {
                    $groups[$tier]['warehouse'] = $a['warehouse_code'];
                }
                $groups[$tier]['lines'][] = ['name' => $name, 'qty' => $aqty];
            }
        }

        uksort($groups, fn ($x, $y) => ($order[$x] ?? 9) <=> ($order[$y] ?? 9));
        return $groups;
    }

    /* ── Cart-page grouped preview ─────────────────── */

    public function render_cart_groups(): void
    {
        if (!function_exists('WC') || !WC()->cart) {
            return;
        }
        [$lat, $lng] = $this->customer_latlng();
        if (!$lat || !$lng) {
            return;
        }

        // Same source of truth as the actual shipping split (incl. intra-line splitting).
        $groups = self::build_tier_groups(WC()->cart->get_cart(), (float) $lat, (float) $lng);
        if (empty($groups)) {
            return;
        }

        // Order-level free shipping (owner decision): the WHOLE order qualifies or it does not —
        // a qualifying order shows EVERY shipment free, never a surprise per-basket charge.
        $freeMin   = (float) get_option('zooboxi_free_shipping_min', 200);
        $orderSub  = (float) WC()->cart->get_subtotal();
        $qualifies = $orderSub >= $freeMin;
        $remain    = max(0, $freeMin - $orderSub);

        $multi = count($groups) > 1;
        $head  = $multi
            ? esc_html__('سيصلك طلبك على دفعات حسب السرعة:', 'zooboxi')
            : esc_html__('توصيل طلبك:', 'zooboxi');

        echo '<div class="zb-shipments"><div class="zb-shipments-head">' . $head . '</div>';

        foreach ($groups as $tier => $g) {
            [$icon, $label, $fee] = $this->tier_meta($tier);

            $names = [];
            foreach ($g['lines'] as $ln) {
                $names[] = $ln['name'] . ' ×' . (int) $ln['qty'];
            }

            $feeText = $qualifies
                ? esc_html__('توصيل مجاني ✓', 'zooboxi')
                : esc_html(number_format($fee, 2) . ' ' . __('ر.س', 'zooboxi'));

            echo '<div class="zb-shipment zb-ship-' . esc_attr($tier) . '">';
            echo '<div class="zb-ship-top"><span class="zb-ship-title">' . esc_html($icon . ' ' . $label) . '</span>';
            echo '<span class="zb-ship-fee">' . $feeText . '</span></div>';
            echo '<div class="zb-ship-items">' . esc_html(implode('، ', array_filter($names))) . '</div>';
            echo '</div>';
        }

        // One ORDER-level free-shipping line (not per basket).
        if ($qualifies) {
            echo '<div class="zb-ship-freebar zb-ship-freebar--ok">' . esc_html__('🎉 شحن مجاني على كل شحناتك', 'zooboxi') . '</div>';
        } elseif ($remain > 0) {
            echo '<div class="zb-ship-freebar">' . sprintf(
                esc_html__('أضف %s ر.س للطلب لتحصل على شحن مجاني على كل الشحنات', 'zooboxi'),
                number_format($remain, 2)
            ) . '</div>';
        }

        echo '</div>';
    }

    /* ── Helpers ───────────────────────────────────── */

    private function customer_latlng(): array
    {
        $lat = $lng = 0.0;
        if (function_exists('WC') && WC()->session) {
            $lat = (float) WC()->session->get('zooboxi_customer_lat');
            $lng = (float) WC()->session->get('zooboxi_customer_lng');
        }
        if (!$lat && !empty($_COOKIE['zooboxi_lat'])) {
            $lat = (float) $_COOKIE['zooboxi_lat'];
        }
        if (!$lng && !empty($_COOKIE['zooboxi_lng'])) {
            $lng = (float) $_COOKIE['zooboxi_lng'];
        }
        return [$lat, $lng];
    }

    /** @return array{0:string,1:string,2:float} [icon, label, fee] */
    private function tier_meta(string $tier): array
    {
        switch ($tier) {
            case Zooboxi_Delivery_Engine::TYPE_EXPRESS:
                return ['⚡', __('توصيل خلال ساعتين', 'zooboxi'), (float) get_option('zooboxi_express_fee', 15)];
            case Zooboxi_Delivery_Engine::TYPE_STANDARD:
                return ['🚚', __('توصيل خلال 24 ساعة', 'zooboxi'), (float) get_option('zooboxi_standard_fee', 10)];
            default:
                return ['📦', __('توصيل خلال 2-4 أيام', 'zooboxi'), (float) get_option('zooboxi_shipping_fee', 25)];
        }
    }

    public function styles(): void
    {
        if (is_admin() || !is_cart()) {
            return;
        }
        ?>
        <style id="zb-smart-shipments">
        /* ════ noon-style shipment CARDS (real containers, not table rows) ════ */
        .zb-cart-groups{display:flex;flex-direction:column;gap:22px;margin:0 0 8px}
        .zb-scard{border:1px solid #ecedf0;border-radius:18px;overflow:hidden;background:#fff;
                  box-shadow:0 1px 4px rgba(17,24,39,.05)}
        .zb-scard-head{padding:14px 18px;background:var(--zb-bg);border-bottom:1px solid #f0f1f3;
                       border-right:5px solid var(--zb-c)}
        .zb-scard-row{display:flex;align-items:center;gap:10px;margin-bottom:5px}
        .zb-scard-name{font-weight:800;color:var(--zb-c);font-size:16px;line-height:1.2}
        .zb-scard-count{font-size:11.5px;color:#fff;background:var(--zb-c);border-radius:20px;
                        padding:3px 12px;font-weight:700;white-space:nowrap}
        .zb-scard-promise{font-weight:800;color:#1f8a4c;font-size:13.5px;line-height:1.4}
        .zb-scard-free{font-size:12.5px;font-weight:600;color:#6b7280;margin-top:3px}

        .zb-scard-items{padding:4px 0}
        .zb-line{display:flex;align-items:center;gap:14px;padding:14px 18px;border-top:1px solid #f4f5f7}
        .zb-scard-items .zb-line:first-child{border-top:none}
        .zb-line-thumb{flex:0 0 80px;width:80px}
        .zb-line-thumb img{width:80px;height:80px;object-fit:contain;border-radius:12px;
                           border:1px solid #f1f1f1;background:#fff;display:block}
        .zb-line-thumb a{display:block}
        .zb-line-info{flex:1 1 auto;min-width:0}
        .zb-line-name{display:block;font-weight:600;color:#1f2937;font-size:14px;line-height:1.5;text-decoration:none}
        .zb-line-name:hover{color:var(--zb-c)}
        .zb-line-price{font-weight:800;color:#111827;font-size:15px;margin-top:7px}
        .zb-line-actions{flex:0 0 auto;display:flex;flex-direction:column;align-items:center;gap:9px}
        .zb-line-remove{font-size:12px;color:#9aa0a6;text-decoration:none;white-space:nowrap}
        .zb-line-remove:hover{color:#ef4444}
        /* keep the theme's rounded -/+ stepper compact inside the card */
        .zb-line-qty .quantity{margin:0}
        .zb-line-qty .quantity input.qty{text-align:center}

        @media (max-width:600px){
            .zb-line{gap:11px;padding:13px 14px;align-items:flex-start}
            .zb-line-thumb{flex-basis:64px;width:64px}
            .zb-line-thumb img{width:64px;height:64px}
            .zb-line-actions{align-items:flex-end}
        }

        /* ════ Right column actions — keep the update_cart button in the DOM (the qty stepper
              triggers its click) but hidden off-screen; coupon now lives in the left summary. ════ */
        .zb-cart-actions{position:absolute;left:-9999px;width:1px;height:1px;overflow:hidden}

        /* ════ Kill the DOUBLE white card: the theme styles BOTH .cart-collaterals and
              .cart_totals as identical 360px white cards (nested). Make the outer transparent
              so only the inner .cart_totals is the single visible card. ════ */
        .woocommerce-cart .cart-collaterals{background:transparent !important;border:none !important;
                                            box-shadow:none !important;padding:0 !important}

        /* ════ Coupon = a clean SECTION inside the summary (not a nested white card) ════ */
        .zb-left-coupon{margin:4px 0 8px !important;padding:14px 0 2px !important;background:transparent !important;
                        border:none !important;border-top:1px solid #f0f1f3 !important;border-radius:0 !important;
                        box-shadow:none !important}
        .zb-lc-title{display:flex;align-items:center;gap:7px;font-weight:800;color:#0d4d4a;font-size:14px;margin-bottom:10px}
        .zb-lc-title svg{flex:0 0 auto}
        .zb-lc-row{display:flex;gap:8px;align-items:stretch}
        .zb-left-coupon .input-text{flex:1 1 auto !important;width:auto !important;min-width:0 !important;height:46px;
                                    border:1px solid #e3e6ea !important;border-radius:11px !important;padding:0 12px !important;
                                    font-size:13.5px;background:#fafbfc !important;margin:0 !important;box-shadow:none !important}
        .zb-left-coupon .input-text:focus{border-color:#0d9488 !important;background:#fff !important;outline:none}
        .zb-left-coupon button.button{flex:0 0 auto !important;width:auto !important;min-width:90px !important;
                                      height:46px !important;border-radius:11px !important;padding:0 22px !important;
                                      background:#0d9488 !important;color:#fff !important;border:none !important;
                                      font-weight:800 !important;font-size:13.5px !important;cursor:pointer;margin:0 !important}
        .zb-left-coupon button.button:hover{background:#0b7d72 !important}

        /* ════ Left summary — clean the per-shipment shipping rows ════ */
        .cart-collaterals .woocommerce-shipping-contents{display:none} /* redundant — items already in the cards */
        .cart-collaterals ul.woocommerce-shipping-methods{list-style:none;margin:8px 0 4px;padding:0}
        .cart-collaterals ul.woocommerce-shipping-methods li{display:flex;align-items:center;gap:9px;
                         padding:9px 11px;border:1px solid #ecedf0;border-radius:11px;margin-bottom:7px;
                         transition:border-color .15s,background .15s}
        .cart-collaterals ul.woocommerce-shipping-methods li:has(input:checked){border-color:#0d9488;background:#f0fdfa}
        .cart-collaterals ul.woocommerce-shipping-methods li label{margin:0;font-size:13px;font-weight:600;
                         color:#374151;line-height:1.4}
        .cart-collaterals .woocommerce-shipping-totals th{font-weight:800;color:#0d4d4a;font-size:13.5px;
                         vertical-align:top;padding-top:12px;white-space:nowrap}
        .cart-collaterals .woocommerce-shipping-destination{font-size:11px;color:#9aa0a6;margin:2px 0 0}
        .cart-collaterals .woocommerce-shipping-destination a{color:#0d9488;font-weight:600;cursor:pointer}
        /* Addresses come from the MAP popup, not a manual form — hide WC's address calculator fields. */
        .woocommerce-cart .shipping-calculator-form{display:none !important}
        </style>
        <?php
    }
}
