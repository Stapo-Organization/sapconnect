<?php
/**
 * Delivery Badge — shows per-product delivery type on product cards and detail pages.
 * Enhanced: each product gets its own badge based on actual stock + customer zone.
 */
class Zooboxi_Delivery_Badge
{
    public function __construct()
    {
        add_action('woocommerce_before_shop_loop_item_title', [$this, 'render_badge'], 9);
        add_action('woocommerce_single_product_summary', [$this, 'render_delivery_info'], 25);

        // Replace default "X in stock" with per-warehouse breakdown
        add_filter('woocommerce_get_stock_html', [$this, 'render_warehouse_stock_html'], 10, 2);
    }

    /**
     * Per-product badge on product cards in shop loop.
     */
    public function render_badge(): void
    {
        global $product;
        if (!$product) return;

        $session = WC()->session ?? null;
        $lat = (float) ($_COOKIE['zooboxi_lat'] ?? ($session ? $session->get('zooboxi_customer_lat') : 0));
        $lng = (float) ($_COOKIE['zooboxi_lng'] ?? ($session ? $session->get('zooboxi_customer_lng') : 0));

        if (!$lat && !$lng) return;

        $delivery = Zooboxi_Delivery_Engine::detect_product_delivery($product->get_id(), $lat, $lng);

        // SVG icons — immune to WordPress wp-emoji-release.min.js which destroys Unicode emoji
        $icon_express  = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg>';
        $icon_sameday  = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path><polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline><line x1="12" y1="22.08" x2="12" y2="12"></line></svg>';
        $icon_shipping = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="3" width="15" height="13"></rect><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"></polygon><circle cx="5.5" cy="18.5" r="2.5"></circle><circle cx="18.5" cy="18.5" r="2.5"></circle></svg>';

        $badges = [
            'express'  => ['icon' => $icon_express,  'label' => __('توصيل خلال ساعتين', 'zooboxi'), 'css' => 'express'],
            'same_day' => ['icon' => $icon_sameday,  'label' => __('توصيل خلال 24 ساعة', 'zooboxi'), 'css' => 'standard'],
            'shipping' => ['icon' => $icon_shipping, 'label' => __('شحن 4-5 أيام', 'zooboxi'), 'css' => 'shipping'],
        ];

        $type = $delivery['type'] ?? 'shipping';
        $badge = $badges[$type] ?? $badges['shipping'];

        printf(
            '<div class="zooboxi-delivery-badge zooboxi-delivery-badge--%s"><span class="zooboxi-badge-icon">%s</span><span class="zooboxi-badge-text">%s</span></div>',
            esc_attr($badge['css']),
            $badge['icon'],
            esc_html($badge['label'])
        );
    }

    /**
     * Detailed delivery info and local stock on single product page.
     */
    public function render_delivery_info(): void
    {
        global $product;
        if (!$product) return;

        $session = WC()->session ?? null;
        $lat  = (float) ($_COOKIE['zooboxi_lat'] ?? ($session ? $session->get('zooboxi_customer_lat') : 0));
        $lng  = (float) ($_COOKIE['zooboxi_lng'] ?? ($session ? $session->get('zooboxi_customer_lng') : 0));
        $city = sanitize_text_field($_COOKIE['zooboxi_city'] ?? ($session ? $session->get('zooboxi_customer_city', '') : ''));
        $district = sanitize_text_field($_COOKIE['zooboxi_district'] ?? ($session ? $session->get('zooboxi_customer_district', '') : ''));

        if (!$lat && !$lng && empty($city)) {
            echo '<div class="zooboxi-delivery-info">
                <button class="button alt zooboxi-change-location" style="width:100%;">📍 ' . esc_html__('حدد موقعك لعرض خيارات التوصيل', 'zooboxi') . '</button>
            </div>';
            return;
        }

        // Get per-product delivery info
        $delivery = Zooboxi_Delivery_Engine::detect_product_delivery($product->get_id(), $lat, $lng);
        // Get all available delivery options for the location
        $options = Zooboxi_Delivery_Engine::detect_options($lat, $lng);
        // Get stock breakdown
        $stockList = Zooboxi_Stock_Manager::get_warehouse_stock($product->get_id());

        // Build stock map: warehouse_code => qty
        $stockMap = [];
        if (!empty($stockList)) {
            foreach ($stockList as $ws) {
                $stockMap[$ws['warehouse_code']] = (float) $ws['in_stock'];
            }
        }

        // Filter pickup options: only show branches where this product has stock > 0
        if (!empty($options['pickup'])) {
            $options['pickup'] = array_values(array_filter($options['pickup'], function($p) use ($stockMap) {
                $code = $p['warehouse_code'];
                return isset($stockMap[$code]) && $stockMap[$code] > 0;
            }));
        }

        // Also filter standard: only show if product has stock at the standard warehouse
        if (!empty($options['standard'])) {
            $code = $options['standard']['warehouse_code'];
            if (!isset($stockMap[$code]) || $stockMap[$code] <= 0) {
                $options['standard'] = null;
            }
        }

        // Filter shipping: only show if product has stock at the hub
        if (!empty($options['shipping'])) {
            $code = $options['shipping']['warehouse_code'];
            if (!isset($stockMap[$code]) || $stockMap[$code] <= 0) {
                $options['shipping'] = null;
            }
        }

        // Location display
        $locationText = $city ?: __('موقعك', 'zooboxi');
        if (!empty($district)) {
            $locationText .= '، ' . $district;
        }

        // Check express working hours status
        $expressAvailable = ($delivery['type'] === 'express');
        $expressWarehouses = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);

        // Check if outside express hours but within zone (show "available tomorrow")
        $inZoneButClosed = false;
        if (!$expressAvailable && !empty($stockList)) {
            $allExpressShowrooms = Zooboxi_Warehouse_Manager::get_express_showrooms();
            foreach ($allExpressShowrooms as $showroom) {
                if (Zooboxi_Warehouse_Manager::is_within_express_zone($showroom, $lat, $lng)) {
                    // Check if product has stock there
                    foreach ($stockList as $ws) {
                        if ($ws['warehouse_code'] === $showroom['warehouse_code'] && (float)$ws['in_stock'] > 0) {
                            $inZoneButClosed = true;
                            break 2;
                        }
                    }
                }
            }
        }

        ?>
        <div class="zooboxi-delivery-info">
            <div class="zooboxi-delivery-info__header">
                <div class="zooboxi-delivery-info__location">
                    <span>📍</span>
                    <span><?php echo esc_html(sprintf(__('التوصيل إلى: %s', 'zooboxi'), $locationText)); ?></span>
                </div>
                <a href="#" class="zooboxi-change-location zooboxi-delivery-info__change"><?php esc_html_e('تغيير', 'zooboxi'); ?></a>
            </div>

            <div class="zooboxi-delivery-info__options">
                <?php if ($expressAvailable): ?>
                <div class="zooboxi-delivery-option zooboxi-delivery-option--express">
                    <div class="zooboxi-delivery-option__icon">⚡</div>
                    <div class="zooboxi-delivery-option__content">
                        <div class="zooboxi-delivery-option__title"><?php esc_html_e('توصيل سريع: خلال ساعتين', 'zooboxi'); ?></div>
                        <div class="zooboxi-delivery-option__meta">
                            <?php echo esc_html(sprintf(
                                __('متوفر في %s (%d حبة)', 'zooboxi'),
                                $delivery['warehouse_name'],
                                $delivery['stock_qty']
                            )); ?>
                        </div>
                        <div class="zooboxi-delivery-option__fee">
                            <?php echo $delivery['fee'] > 0
                                ? esc_html($delivery['fee'] . ' ' . __('ر.س', 'zooboxi'))
                                : '<span class="free">' . esc_html__('مجاناً', 'zooboxi') . '</span>'; ?>
                        </div>
                    </div>
                    <div class="zooboxi-delivery-option__badge"><?php esc_html_e('متاح الآن', 'zooboxi'); ?></div>
                </div>
                <?php elseif ($inZoneButClosed): ?>
                <div class="zooboxi-delivery-option zooboxi-delivery-option--express-closed">
                    <div class="zooboxi-delivery-option__icon">⚡</div>
                    <div class="zooboxi-delivery-option__content">
                        <div class="zooboxi-delivery-option__title"><?php esc_html_e('توصيل سريع: خلال ساعتين', 'zooboxi'); ?></div>
                        <div class="zooboxi-delivery-option__meta"><?php esc_html_e('خارج ساعات التوصيل السريع حالياً', 'zooboxi'); ?></div>
                    </div>
                    <div class="zooboxi-delivery-option__badge zooboxi-delivery-option__badge--closed"><?php esc_html_e('متاح غداً', 'zooboxi'); ?></div>
                </div>
                <?php endif; ?>

                <?php if (!empty($options['standard'])): ?>
                <div class="zooboxi-delivery-option zooboxi-delivery-option--standard">
                    <div class="zooboxi-delivery-option__icon">📦</div>
                    <div class="zooboxi-delivery-option__content">
                        <div class="zooboxi-delivery-option__title"><?php esc_html_e('توصيل عادي: خلال 24 ساعة', 'zooboxi'); ?></div>
                        <div class="zooboxi-delivery-option__meta">
                            <?php echo esc_html(sprintf(__('من %s', 'zooboxi'), $options['standard']['warehouse_name'])); ?>
                        </div>
                        <div class="zooboxi-delivery-option__fee">
                            <?php echo $options['standard']['fee'] > 0
                                ? esc_html($options['standard']['fee'] . ' ' . __('ر.س', 'zooboxi'))
                                : '<span class="free">' . esc_html__('مجاناً', 'zooboxi') . '</span>'; ?>
                        </div>
                    </div>
                </div>
                <?php endif; ?>

                <?php if (!empty($options['shipping'])): ?>
                <div class="zooboxi-delivery-option zooboxi-delivery-option--shipping">
                    <div class="zooboxi-delivery-option__icon">🚚</div>
                    <div class="zooboxi-delivery-option__content">
                        <div class="zooboxi-delivery-option__title"><?php esc_html_e('شحن عادي: 4-5 أيام عمل', 'zooboxi'); ?></div>
                        <div class="zooboxi-delivery-option__fee">
                            <?php echo $options['shipping']['fee'] > 0
                                ? esc_html($options['shipping']['fee'] . ' ' . __('ر.س', 'zooboxi'))
                                : '<span class="free">' . esc_html__('مجاناً', 'zooboxi') . '</span>'; ?>
                        </div>
                    </div>
                </div>
                <?php endif; ?>

                <?php if (!empty($options['pickup'])): ?>
                <div class="zooboxi-delivery-option zooboxi-delivery-option--pickup">
                    <div class="zooboxi-delivery-option__icon">🏬</div>
                    <div class="zooboxi-delivery-option__content">
                        <div class="zooboxi-delivery-option__title"><?php esc_html_e('استلام من الفرع', 'zooboxi'); ?></div>
                        <div class="zooboxi-delivery-option__meta">
                            <?php echo esc_html(sprintf(
                                __('%s (%.1f كم) — مجاناً', 'zooboxi'),
                                $options['pickup'][0]['warehouse_name'],
                                $options['pickup'][0]['distance_km']
                            )); ?>
                        </div>
                    </div>
                </div>
                <?php endif; ?>
            </div>
        </div>
        <?php
    }

    /**
     * Replace default "X in stock" with per-warehouse stock breakdown
     * filtered by customer location (express zone, same city, national hub).
     */
    public function render_warehouse_stock_html(string $html, \WC_Product $product): string
    {
        // Only on single product page
        if (!is_product()) return $html;

        $productId = $product->get_id();
        $warehouseStock = Zooboxi_Stock_Manager::get_warehouse_stock($productId);

        // No warehouse data → keep default
        if (empty($warehouseStock)) return $html;

        // Customer location
        $session = WC()->session ?? null;
        $lat  = (float) ($_COOKIE['zooboxi_lat'] ?? ($session ? $session->get('zooboxi_customer_lat') : 0));
        $lng  = (float) ($_COOKIE['zooboxi_lng'] ?? ($session ? $session->get('zooboxi_customer_lng') : 0));
        $city = sanitize_text_field($_COOKIE['zooboxi_city'] ?? ($session ? $session->get('zooboxi_customer_city', '') : ''));

        // Warehouse display names (from DB or fallback)
        $allWarehouses = Zooboxi_Warehouse_Manager::get_active();
        $whLookup = [];
        foreach ($allWarehouses as $wh) {
            $whLookup[$wh['warehouse_code']] = $wh;
        }

        // Build stock map: code => qty
        $stockMap = [];
        foreach ($warehouseStock as $ws) {
            $code = $ws['warehouse_code'] ?? '';
            $qty = (float) ($ws['in_stock'] ?? 0);
            if ($code) {
                $stockMap[$code] = $qty;
            }
        }

        // Determine which warehouses to show based on customer location
        $relevantWarehouses = [];

        if ($lat || $lng) {
            // 1. Express warehouses in zone
            $expressWHs = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
            foreach ($expressWHs as $ew) {
                $code = $ew['warehouse']['warehouse_code'];
                if (isset($stockMap[$code])) {
                    $relevantWarehouses[$code] = [
                        'type'     => 'express',
                        'icon'     => '⚡',
                        'label'    => __('توصيل سريع', 'zooboxi'),
                        'name'     => self::get_wh_display_name($whLookup[$code] ?? null, $code),
                        'qty'      => (int) $stockMap[$code],
                        'distance' => $ew['distance'],
                    ];
                }
            }

            // 2. Also check express showrooms outside working hours (in zone but closed)
            if (empty($relevantWarehouses)) {
                $allExpressShowrooms = Zooboxi_Warehouse_Manager::get_express_showrooms();
                foreach ($allExpressShowrooms as $showroom) {
                    $code = $showroom['warehouse_code'];
                    if (isset($stockMap[$code]) && $stockMap[$code] > 0
                        && Zooboxi_Warehouse_Manager::is_within_express_zone($showroom, $lat, $lng)
                        && !isset($relevantWarehouses[$code])) {
                        $relevantWarehouses[$code] = [
                            'type'     => 'express_closed',
                            'icon'     => '⚡',
                            'label'    => __('سريع (خارج الدوام)', 'zooboxi'),
                            'name'     => self::get_wh_display_name($whLookup[$code] ?? null, $code),
                            'qty'      => (int) $stockMap[$code],
                            'distance' => null,
                        ];
                    }
                }
            }

            // 3. Central warehouse (same city, 24H delivery)
            if ($city) {
                $central = Zooboxi_Warehouse_Manager::find_central($city);
                if ($central && isset($stockMap[$central['warehouse_code']]) && !isset($relevantWarehouses[$central['warehouse_code']])) {
                    $code = $central['warehouse_code'];
                    $relevantWarehouses[$code] = [
                        'type'  => 'standard',
                        'icon'  => '📦',
                        'label' => __('توصيل 24 ساعة', 'zooboxi'),
                        'name'  => self::get_wh_display_name($whLookup[$code] ?? null, $code),
                        'qty'   => (int) $stockMap[$code],
                        'distance' => null,
                    ];
                }
            }

            // 4. Main hub (national shipping)
            $hub = Zooboxi_Warehouse_Manager::get_main_hub();
            if ($hub && isset($stockMap[$hub['warehouse_code']]) && !isset($relevantWarehouses[$hub['warehouse_code']])) {
                $code = $hub['warehouse_code'];
                $relevantWarehouses[$code] = [
                    'type'  => 'shipping',
                    'icon'  => '🚚',
                    'label' => __('شحن 4-5 أيام', 'zooboxi'),
                    'name'  => self::get_wh_display_name($whLookup[$code] ?? null, $code),
                    'qty'   => (int) $stockMap[$code],
                    'distance' => null,
                ];
            }

            // 5. Nearest pickup branches with stock
            $pickups = Zooboxi_Warehouse_Manager::get_pickup_locations($lat, $lng);
            foreach (array_slice($pickups, 0, 3) as $p) {
                $code = $p['warehouse']['warehouse_code'];
                if (isset($stockMap[$code]) && $stockMap[$code] > 0 && !isset($relevantWarehouses[$code])) {
                    $relevantWarehouses[$code] = [
                        'type'     => 'pickup',
                        'icon'     => '🏬',
                        'label'    => __('استلام', 'zooboxi'),
                        'name'     => self::get_wh_display_name($whLookup[$code] ?? null, $code),
                        'qty'      => (int) $stockMap[$code],
                        'distance' => $p['distance'],
                    ];
                }
            }
        }

        // If no location or no relevant results, show all warehouses with stock
        if (empty($relevantWarehouses)) {
            foreach ($stockMap as $code => $qty) {
                if ($qty > 0) {
                    $relevantWarehouses[$code] = [
                        'type'     => 'default',
                        'icon'     => '📍',
                        'label'    => '',
                        'name'     => self::get_wh_display_name($whLookup[$code] ?? null, $code),
                        'qty'      => (int) $qty,
                        'distance' => null,
                    ];
                }
            }
        }

        // Nothing to show
        if (empty($relevantWarehouses)) return $html;

        // Calculate total available across relevant warehouses
        $totalRelevant = array_sum(array_column($relevantWarehouses, 'qty'));

        // Build output
        ob_start();
        ?>
        <div class="zooboxi-stock-breakdown">
            <div class="zooboxi-stock-breakdown__header">
                <span class="zooboxi-stock-breakdown__total">
                    <?php echo esc_html(sprintf(
                        __('متوفر: %d حبة', 'zooboxi'),
                        $totalRelevant
                    )); ?>
                </span>
                <?php if ($lat || $lng): ?>
                <span class="zooboxi-stock-breakdown__hint">
                    <?php esc_html_e('حسب موقعك', 'zooboxi'); ?>
                </span>
                <?php endif; ?>
            </div>
            <div class="zooboxi-stock-breakdown__list">
                <?php foreach ($relevantWarehouses as $code => $wh):
                    $cssType = esc_attr($wh['type']);
                    $distText = $wh['distance'] ? sprintf('%.1f كم', $wh['distance']) : '';
                ?>
                <div class="zooboxi-stock-row zooboxi-stock-row--<?php echo $cssType; ?>">
                    <span class="zooboxi-stock-row__icon"><?php echo $wh['icon']; ?></span>
                    <span class="zooboxi-stock-row__name"><?php echo esc_html($wh['name']); ?></span>
                    <?php if (!empty($wh['label'])): ?>
                    <span class="zooboxi-stock-row__tag zooboxi-stock-row__tag--<?php echo $cssType; ?>"><?php echo esc_html($wh['label']); ?></span>
                    <?php endif; ?>
                    <span class="zooboxi-stock-row__qty"><?php echo esc_html($wh['qty']); ?></span>
                    <?php if ($distText): ?>
                    <span class="zooboxi-stock-row__dist"><?php echo esc_html($distText); ?></span>
                    <?php endif; ?>
                </div>
                <?php endforeach; ?>
            </div>
        </div>

        <style>
        .zooboxi-stock-breakdown {
            margin: 10px 0 16px;
            background: #fafbf7;
            border: 1px solid #e2e8e0;
            border-radius: 12px;
            padding: 14px 16px;
            font-family: inherit;
        }
        .zooboxi-stock-breakdown__header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
            padding-bottom: 8px;
            border-bottom: 1px solid #e8ede6;
        }
        .zooboxi-stock-breakdown__total {
            font-size: 14px;
            font-weight: 700;
            color: #065f46;
        }
        .zooboxi-stock-breakdown__hint {
            font-size: 11px;
            color: #9ca3af;
            background: #f3f4f6;
            padding: 2px 8px;
            border-radius: 8px;
        }
        .zooboxi-stock-breakdown__list {
            display: flex;
            flex-direction: column;
            gap: 6px;
        }
        .zooboxi-stock-row {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 10px;
            background: #fff;
            border-radius: 8px;
            border: 1px solid #e8ede6;
            font-size: 13px;
            transition: all 0.15s;
        }
        .zooboxi-stock-row:hover {
            border-color: #c5d5c2;
            box-shadow: 0 1px 4px rgba(0,0,0,0.03);
        }
        .zooboxi-stock-row--express { border-right: 3px solid #3498db; }
        .zooboxi-stock-row--express_closed { border-right: 3px solid #e67e22; opacity: 0.75; }
        .zooboxi-stock-row--standard { border-right: 3px solid #27ae60; }
        .zooboxi-stock-row--shipping { border-right: 3px solid #95a5a6; }
        .zooboxi-stock-row--pickup { border-right: 3px solid #8e44ad; }
        .zooboxi-stock-row--default { border-right: 3px solid #e2e8e0; }

        html[dir="rtl"] .zooboxi-stock-row--express,
        html[dir="rtl"] .zooboxi-stock-row--express_closed,
        html[dir="rtl"] .zooboxi-stock-row--standard,
        html[dir="rtl"] .zooboxi-stock-row--shipping,
        html[dir="rtl"] .zooboxi-stock-row--pickup,
        html[dir="rtl"] .zooboxi-stock-row--default {
            border-right: none;
            border-left-width: 3px;
            border-left-style: solid;
        }
        html[dir="rtl"] .zooboxi-stock-row--express { border-left-color: #3498db; }
        html[dir="rtl"] .zooboxi-stock-row--express_closed { border-left-color: #e67e22; }
        html[dir="rtl"] .zooboxi-stock-row--standard { border-left-color: #27ae60; }
        html[dir="rtl"] .zooboxi-stock-row--shipping { border-left-color: #95a5a6; }
        html[dir="rtl"] .zooboxi-stock-row--pickup { border-left-color: #8e44ad; }
        html[dir="rtl"] .zooboxi-stock-row--default { border-left-color: #e2e8e0; }

        .zooboxi-stock-row__icon {
            font-size: 16px;
            flex-shrink: 0;
            width: 22px;
            text-align: center;
        }
        .zooboxi-stock-row__name {
            flex: 1;
            font-weight: 600;
            color: #2c3e2d;
            min-width: 0;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .zooboxi-stock-row__tag {
            font-size: 10px;
            font-weight: 700;
            padding: 2px 7px;
            border-radius: 8px;
            white-space: nowrap;
            flex-shrink: 0;
        }
        .zooboxi-stock-row__tag--express { background: rgba(52,152,219,0.1); color: #2980b9; }
        .zooboxi-stock-row__tag--express_closed { background: rgba(230,126,34,0.1); color: #e67e22; }
        .zooboxi-stock-row__tag--standard { background: rgba(39,174,96,0.1); color: #27ae60; }
        .zooboxi-stock-row__tag--shipping { background: rgba(149,165,166,0.1); color: #7f8c8d; }
        .zooboxi-stock-row__tag--pickup { background: rgba(142,68,173,0.1); color: #8e44ad; }

        .zooboxi-stock-row__qty {
            font-weight: 700;
            color: #065f46;
            font-size: 14px;
            min-width: 28px;
            text-align: center;
            flex-shrink: 0;
        }
        .zooboxi-stock-row__dist {
            font-size: 11px;
            color: #9ca3af;
            white-space: nowrap;
            flex-shrink: 0;
        }

        /* Hide default WooCommerce stock text since we replace it */
        .zooboxi-stock-breakdown + .stock { display: none; }

        @media (max-width: 480px) {
            .zooboxi-stock-row { font-size: 12px; padding: 6px 8px; }
            .zooboxi-stock-row__tag { font-size: 9px; padding: 1px 5px; }
        }
        </style>
        <?php
        return ob_get_clean();
    }

    /**
     * Get display name for a warehouse.
     */
    private static function get_wh_display_name(?array $warehouse, string $fallbackCode): string
    {
        if (!$warehouse) return $fallbackCode;
        if (is_rtl()) {
            return $warehouse['display_name_ar'] ?: $warehouse['display_name_en'] ?: $fallbackCode;
        }
        return $warehouse['display_name_en'] ?: $warehouse['display_name_ar'] ?: $fallbackCode;
    }
}
