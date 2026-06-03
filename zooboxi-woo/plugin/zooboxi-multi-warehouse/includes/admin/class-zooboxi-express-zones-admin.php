<?php
/**
 * Express Zones Admin Page — manage express delivery settings per warehouse.
 * Includes Leaflet.js map for polygon zone drawing.
 */
class Zooboxi_Express_Zones_Admin
{
    public function __construct()
    {
        add_action('wp_ajax_zooboxi_save_warehouse_settings', [$this, 'ajax_save_warehouse']);
    }

    /**
     * Render the Express Zones admin page.
     */
    public function render(): void
    {
        $warehouses = Zooboxi_Warehouse_Manager::get_active();
        ?>
        <div class="wrap zooboxi-express-zones-wrap">
            <h1 class="wp-heading-inline">
                <span style="font-size: 28px; margin-left: 8px;">⚡</span>
                <?php esc_html_e('مناطق التوصيل السريع', 'zooboxi'); ?>
            </h1>
            <p class="description" style="margin-top: 8px; font-size: 14px;">
                <?php esc_html_e('إدارة مناطق التوصيل السريع وساعات العمل لكل فرع. ارسم المنطقة على الخريطة أو استخدم نطاق دائري.', 'zooboxi'); ?>
            </p>

            <div class="zooboxi-zones-layout">
                <!-- Map Container -->
                <div class="zooboxi-zones-map-container">
                    <div id="zooboxi-zones-map" style="height: 500px; border-radius: 12px; border: 2px solid #e2e8e0;"></div>
                    <div class="zooboxi-map-legend">
                        <span class="legend-item"><span class="legend-dot" style="background:#3498db"></span> <?php esc_html_e('توصيل سريع مفعّل', 'zooboxi'); ?></span>
                        <span class="legend-item"><span class="legend-dot" style="background:#95a5a6"></span> <?php esc_html_e('غير مفعّل', 'zooboxi'); ?></span>
                        <span class="legend-item"><span class="legend-dot legend-polygon" style="border-color:#3498db"></span> <?php esc_html_e('منطقة التغطية', 'zooboxi'); ?></span>
                    </div>
                </div>

                <!-- Warehouses List -->
                <div class="zooboxi-zones-list">
                    <?php foreach ($warehouses as $wh): 
                        $isExpress = !empty($wh['is_express_enabled']);
                        $polygonRaw = $wh['express_zone_polygon'] ?? '';
                        $polygon = !empty($polygonRaw) ? (is_string($polygonRaw) ? json_decode($polygonRaw, true) : $polygonRaw) : null;
                        $hasPolygon = !empty($polygon['coordinates']);
                        $hoursRaw = $wh['express_working_hours'] ?? '';
                        $hours = !empty($hoursRaw) ? (is_string($hoursRaw) ? json_decode($hoursRaw, true) : $hoursRaw) : [];
                        $whName = $wh['display_name_ar'] ?: $wh['display_name_en'] ?: $wh['warehouse_code'];
                        $whType = $wh['warehouse_type'] ?? 'showroom';
                        $isOnline = Zooboxi_Warehouse_Manager::is_within_working_hours($wh);
                    ?>
                    <div class="zooboxi-wh-card <?php echo $isExpress ? 'zooboxi-wh-card--active' : ''; ?>" 
                         data-code="<?php echo esc_attr($wh['warehouse_code']); ?>"
                         data-lat="<?php echo esc_attr($wh['latitude']); ?>"
                         data-lng="<?php echo esc_attr($wh['longitude']); ?>"
                         data-radius="<?php echo esc_attr($wh['express_radius_km']); ?>"
                         data-express="<?php echo $isExpress ? '1' : '0'; ?>"
                         data-polygon="<?php echo esc_attr($hasPolygon ? wp_json_encode($polygon) : ''); ?>"
                         data-type="<?php echo esc_attr($whType); ?>"
                         data-central="<?php echo !empty($wh['is_central']) ? '1' : '0'; ?>"
                         data-hub="<?php echo !empty($wh['is_main_hub']) ? '1' : '0'; ?>">
                        
                        <div class="zooboxi-wh-card__header">
                            <div class="zooboxi-wh-card__name">
                                <strong><?php echo esc_html($whName); ?></strong>
                                <span class="zooboxi-wh-card__code"><?php echo esc_html($wh['warehouse_code']); ?></span>
                            </div>
                            <div class="zooboxi-wh-card__status">
                                <?php if ($isExpress && $isOnline): ?>
                                    <span class="status-dot status-dot--online"></span>
                                    <span class="status-text status-text--online"><?php esc_html_e('متاح', 'zooboxi'); ?></span>
                                <?php elseif ($isExpress): ?>
                                    <span class="status-dot status-dot--offline"></span>
                                    <span class="status-text status-text--offline"><?php esc_html_e('خارج الدوام', 'zooboxi'); ?></span>
                                <?php else: ?>
                                    <span class="status-dot status-dot--disabled"></span>
                                    <span class="status-text status-text--disabled"><?php esc_html_e('معطّل', 'zooboxi'); ?></span>
                                <?php endif; ?>
                            </div>
                        </div>

                        <div class="zooboxi-wh-card__body">
                            <!-- ★ Location Coordinates -->
                            <div class="zooboxi-wh-field zooboxi-coords-field">
                                <label class="zooboxi-wh-field__label">📍 <?php esc_html_e('الإحداثيات', 'zooboxi'); ?></label>
                                <div class="zooboxi-coords-inputs">
                                    <div class="zooboxi-coord-group">
                                        <span class="zooboxi-coord-label">Lat</span>
                                        <input type="number" class="zooboxi-lat-input" step="0.00000001" 
                                               value="<?php echo esc_attr($wh['latitude']); ?>"
                                               placeholder="24.7136">
                                    </div>
                                    <div class="zooboxi-coord-group">
                                        <span class="zooboxi-coord-label">Lng</span>
                                        <input type="number" class="zooboxi-lng-input" step="0.00000001" 
                                               value="<?php echo esc_attr($wh['longitude']); ?>"
                                               placeholder="46.6753">
                                    </div>
                                    <button type="button" class="button button-small zooboxi-locate-btn" 
                                            data-code="<?php echo esc_attr($wh['warehouse_code']); ?>"
                                            title="<?php esc_attr_e('عرض على الخريطة', 'zooboxi'); ?>">
                                        🗺️
                                    </button>
                                </div>
                                <p class="zooboxi-coord-hint"><?php esc_html_e('اسحب الدبوس على الخريطة لتعديل الموقع بدقة', 'zooboxi'); ?></p>
                            </div>

                            <!-- Express Toggle -->
                            <div class="zooboxi-wh-field">
                                <label class="zooboxi-toggle">
                                    <input type="checkbox" class="zooboxi-express-toggle" 
                                           data-code="<?php echo esc_attr($wh['warehouse_code']); ?>"
                                           <?php checked($isExpress); ?>>
                                    <span class="zooboxi-toggle__slider"></span>
                                </label>
                                <span class="zooboxi-wh-field__label"><?php esc_html_e('تفعيل التوصيل السريع', 'zooboxi'); ?></span>
                            </div>

                            <!-- Warehouse Type -->
                            <div class="zooboxi-wh-field">
                                <label class="zooboxi-wh-field__label"><?php esc_html_e('نوع المستودع', 'zooboxi'); ?></label>
                                <select class="zooboxi-wh-type" data-code="<?php echo esc_attr($wh['warehouse_code']); ?>">
                                    <option value="showroom" <?php selected($whType, 'showroom'); ?>><?php esc_html_e('معرض (فرع)', 'zooboxi'); ?></option>
                                    <option value="shipping_hub" <?php selected($whType, 'shipping_hub'); ?>><?php esc_html_e('مستودع شحن', 'zooboxi'); ?></option>
                                    <option value="central" <?php selected($whType, 'central'); ?>><?php esc_html_e('مستودع مركزي', 'zooboxi'); ?></option>
                                </select>
                            </div>

                            <!-- Central / Hub Toggles -->
                            <div class="zooboxi-wh-field-row">
                                <label class="zooboxi-checkbox">
                                    <input type="checkbox" class="zooboxi-central-toggle" 
                                           data-code="<?php echo esc_attr($wh['warehouse_code']); ?>"
                                           <?php checked(!empty($wh['is_central'])); ?>>
                                    <span><?php esc_html_e('مستودع مركزي للمدينة (24 ساعة)', 'zooboxi'); ?></span>
                                </label>
                                <label class="zooboxi-checkbox">
                                    <input type="checkbox" class="zooboxi-hub-toggle"
                                           data-code="<?php echo esc_attr($wh['warehouse_code']); ?>"
                                           <?php checked(!empty($wh['is_main_hub'])); ?>>
                                    <span><?php esc_html_e('المستودع الرئيسي (شحن وطني)', 'zooboxi'); ?></span>
                                </label>
                            </div>

                            <!-- Radius Fallback -->
                            <div class="zooboxi-wh-field">
                                <label class="zooboxi-wh-field__label"><?php esc_html_e('نطاق التغطية (كم)', 'zooboxi'); ?></label>
                                <input type="number" class="zooboxi-radius-input" step="0.5" min="1" max="50"
                                       data-code="<?php echo esc_attr($wh['warehouse_code']); ?>"
                                       value="<?php echo esc_attr($wh['express_radius_km']); ?>">
                            </div>

                            <!-- Zone Actions -->
                            <div class="zooboxi-wh-field zooboxi-zone-actions">
                                <button type="button" class="button zooboxi-draw-zone" 
                                        data-code="<?php echo esc_attr($wh['warehouse_code']); ?>">
                                    🖊️ <?php esc_html_e('رسم المنطقة على الخريطة', 'zooboxi'); ?>
                                </button>
                                <?php if ($hasPolygon): ?>
                                <button type="button" class="button zooboxi-clear-zone" 
                                        data-code="<?php echo esc_attr($wh['warehouse_code']); ?>">
                                    🗑️ <?php esc_html_e('مسح المنطقة', 'zooboxi'); ?>
                                </button>
                                <span class="zooboxi-zone-status zooboxi-zone-status--set">✅ <?php esc_html_e('منطقة مرسومة', 'zooboxi'); ?></span>
                                <?php else: ?>
                                <span class="zooboxi-zone-status zooboxi-zone-status--radius">📐 <?php esc_html_e('نطاق دائري', 'zooboxi'); ?></span>
                                <?php endif; ?>
                            </div>

                            <!-- Working Hours -->
                            <div class="zooboxi-wh-field">
                                <label class="zooboxi-wh-field__label"><?php esc_html_e('ساعات التوصيل السريع', 'zooboxi'); ?></label>
                                <div class="zooboxi-hours-grid" data-code="<?php echo esc_attr($wh['warehouse_code']); ?>">
                                    <?php
                                    $days = [
                                        'sunday'    => __('الأحد', 'zooboxi'),
                                        'monday'    => __('الاثنين', 'zooboxi'),
                                        'tuesday'   => __('الثلاثاء', 'zooboxi'),
                                        'wednesday' => __('الأربعاء', 'zooboxi'),
                                        'thursday'  => __('الخميس', 'zooboxi'),
                                        'friday'    => __('الجمعة', 'zooboxi'),
                                        'saturday'  => __('السبت', 'zooboxi'),
                                    ];
                                    foreach ($days as $dayKey => $dayLabel):
                                        $dayHours = $hours[$dayKey] ?? ['open' => '09:00', 'close' => '22:00'];
                                        $isClosed = !empty($dayHours['closed']);
                                    ?>
                                    <div class="zooboxi-hours-row">
                                        <span class="zooboxi-hours-day"><?php echo esc_html($dayLabel); ?></span>
                                        <input type="time" class="zooboxi-hours-open" value="<?php echo esc_attr($dayHours['open'] ?? '09:00'); ?>" <?php echo $isClosed ? 'disabled' : ''; ?>>
                                        <span class="zooboxi-hours-sep">—</span>
                                        <input type="time" class="zooboxi-hours-close" value="<?php echo esc_attr($dayHours['close'] ?? '22:00'); ?>" <?php echo $isClosed ? 'disabled' : ''; ?>>
                                        <label class="zooboxi-hours-closed">
                                            <input type="checkbox" class="zooboxi-hours-closed-toggle" <?php checked($isClosed); ?>>
                                            <?php esc_html_e('مغلق', 'zooboxi'); ?>
                                        </label>
                                    </div>
                                    <?php endforeach; ?>
                                </div>
                            </div>

                            <!-- Save Button -->
                            <div class="zooboxi-wh-field">
                                <button type="button" class="button button-primary zooboxi-save-wh" 
                                        data-code="<?php echo esc_attr($wh['warehouse_code']); ?>">
                                    💾 <?php esc_html_e('حفظ الإعدادات', 'zooboxi'); ?>
                                </button>
                                <span class="zooboxi-save-status" data-code="<?php echo esc_attr($wh['warehouse_code']); ?>"></span>
                            </div>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>
        </div>

        <style>
        .zooboxi-express-zones-wrap { max-width: 100%; }
        .zooboxi-zones-layout { display: grid; grid-template-columns: 1fr 420px; gap: 24px; margin-top: 20px; }
        @media (max-width: 1200px) { .zooboxi-zones-layout { grid-template-columns: 1fr; } }

        .zooboxi-zones-list { display: flex; flex-direction: column; gap: 16px; max-height: 600px; overflow-y: auto; padding-left: 4px; }

        .zooboxi-wh-card { background: #fff; border: 1px solid #e2e8e0; border-radius: 12px; padding: 16px; transition: all .2s; }
        .zooboxi-wh-card:hover { border-color: #c5d5c2; box-shadow: 0 2px 8px rgba(0,0,0,0.04); }
        .zooboxi-wh-card--active { border-right: 4px solid #3498db; }

        .zooboxi-wh-card__header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
        .zooboxi-wh-card__name strong { font-size: 15px; color: #2c3e2d; }
        .zooboxi-wh-card__code { font-size: 11px; color: #9ca3af; font-family: monospace; background: #f3f4f6; padding: 2px 6px; border-radius: 4px; margin-right: 6px; }

        .zooboxi-wh-card__status { display: flex; align-items: center; gap: 4px; }
        .status-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; }
        .status-dot--online { background: #27ae60; box-shadow: 0 0 4px rgba(39,174,96,.5); animation: zooboxi-pulse-dot 2s infinite; }
        .status-dot--offline { background: #e67e22; }
        .status-dot--disabled { background: #bdc3c7; }
        .status-text { font-size: 12px; font-weight: 600; }
        .status-text--online { color: #27ae60; }
        .status-text--offline { color: #e67e22; }
        .status-text--disabled { color: #bdc3c7; }

        @keyframes zooboxi-pulse-dot { 0%, 100% { opacity: 1; } 50% { opacity: .5; } }

        .zooboxi-wh-card__body { display: flex; flex-direction: column; gap: 12px; }
        .zooboxi-wh-field { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
        .zooboxi-wh-field__label { font-size: 13px; font-weight: 600; color: #374151; min-width: 140px; }
        .zooboxi-wh-field-row { display: flex; flex-direction: column; gap: 6px; }

        /* Toggle Switch */
        .zooboxi-toggle { position: relative; width: 44px; height: 24px; display: inline-block; flex-shrink: 0; }
        .zooboxi-toggle input { opacity: 0; width: 0; height: 0; }
        .zooboxi-toggle__slider { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background: #ccc; border-radius: 24px; transition: .3s; }
        .zooboxi-toggle__slider:before { content: ''; position: absolute; height: 18px; width: 18px; left: 3px; bottom: 3px; background: #fff; border-radius: 50%; transition: .3s; }
        .zooboxi-toggle input:checked + .zooboxi-toggle__slider { background: #3498db; }
        .zooboxi-toggle input:checked + .zooboxi-toggle__slider:before { transform: translateX(20px); }

        .zooboxi-checkbox { display: flex; align-items: center; gap: 6px; font-size: 13px; color: #374151; cursor: pointer; }
        .zooboxi-checkbox input { accent-color: #0d9488; }

        .zooboxi-wh-type, .zooboxi-radius-input { padding: 6px 10px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 13px; }
        .zooboxi-radius-input { width: 80px; }

        .zooboxi-zone-actions { flex-wrap: wrap; gap: 6px; }
        .zooboxi-zone-status { font-size: 12px; font-weight: 600; }
        .zooboxi-zone-status--set { color: #27ae60; }
        .zooboxi-zone-status--radius { color: #e67e22; }

        .zooboxi-hours-grid { display: flex; flex-direction: column; gap: 4px; width: 100%; }
        .zooboxi-hours-row { display: flex; align-items: center; gap: 6px; font-size: 13px; }
        .zooboxi-hours-day { min-width: 70px; font-weight: 500; color: #374151; }
        .zooboxi-hours-sep { color: #9ca3af; }
        .zooboxi-hours-open, .zooboxi-hours-close { padding: 4px 6px; border: 1px solid #d1d5db; border-radius: 4px; font-size: 12px; width: 90px; }
        .zooboxi-hours-closed { display: flex; align-items: center; gap: 4px; font-size: 12px; color: #7f8c8d; }

        .zooboxi-save-status { font-size: 12px; font-weight: 600; transition: all .3s; }

        .zooboxi-map-legend { display: flex; gap: 16px; padding: 10px 0; font-size: 12px; color: #6b7c6e; }
        .legend-item { display: flex; align-items: center; gap: 4px; }
        .legend-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; }
        .legend-polygon { width: 14px; height: 10px; border-radius: 2px; border: 2px dashed; background: rgba(52,152,219,.1); }

        /* ★ Coordinate Fields */
        .zooboxi-coords-field { flex-direction: column; align-items: flex-start !important; }
        .zooboxi-coords-inputs { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
        .zooboxi-coord-group { display: flex; align-items: center; gap: 4px; }
        .zooboxi-coord-label { font-size: 11px; font-weight: 700; color: #6b7c6e; text-transform: uppercase; min-width: 24px; }
        .zooboxi-lat-input, .zooboxi-lng-input { width: 130px; padding: 5px 8px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 12px; font-family: monospace; }
        .zooboxi-lat-input:focus, .zooboxi-lng-input:focus { border-color: #3498db; outline: none; box-shadow: 0 0 0 2px rgba(52,152,219,0.15); }
        .zooboxi-locate-btn { min-width: 32px !important; padding: 4px 6px !important; font-size: 16px !important; line-height: 1 !important; }
        .zooboxi-coord-hint { font-size: 11px; color: #9ca3af; margin: 2px 0 0; font-style: italic; }

        /* ★ Changed indicator */
        .zooboxi-wh-card--changed { border-color: #f39c12 !important; box-shadow: 0 0 0 2px rgba(243,156,18,0.2); }
        .zooboxi-wh-card--changed::after { content: '⚠️ غير محفوظ'; position: absolute; top: 8px; left: 8px; font-size: 10px; color: #f39c12; font-weight: 700; }
        .zooboxi-wh-card { position: relative; }
        </style>
        <?php
    }

    /**
     * AJAX: Save warehouse express settings.
     */
    public function ajax_save_warehouse(): void
    {
        check_ajax_referer('zooboxi_admin_nonce', 'nonce');

        if (!current_user_can('manage_woocommerce')) {
            wp_send_json_error(['message' => 'Unauthorized']);
        }

        $code = sanitize_text_field($_POST['warehouse_code'] ?? '');
        if (empty($code)) {
            wp_send_json_error(['message' => 'Missing warehouse code']);
        }

        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_warehouses';

        $data = [
            'is_express_enabled'   => !empty($_POST['is_express_enabled']) ? 1 : 0,
            'express_radius_km'    => (float) ($_POST['express_radius_km'] ?? 10),
            'warehouse_type'       => sanitize_text_field($_POST['warehouse_type'] ?? 'showroom'),
            'is_central'           => !empty($_POST['is_central']) ? 1 : 0,
            'is_main_hub'          => !empty($_POST['is_main_hub']) ? 1 : 0,
        ];

        // ★ Handle latitude/longitude updates (from dragging marker or manual input)
        if (isset($_POST['latitude']) && $_POST['latitude'] !== '') {
            $data['latitude'] = (float) $_POST['latitude'];
        }
        if (isset($_POST['longitude']) && $_POST['longitude'] !== '') {
            $data['longitude'] = (float) $_POST['longitude'];
        }

        // Handle polygon zone (JSON)
        if (isset($_POST['express_zone_polygon'])) {
            $polygonInput = $_POST['express_zone_polygon'];
            if (empty($polygonInput) || $polygonInput === 'null') {
                $data['express_zone_polygon'] = null;
            } else {
                $polygon = is_string($polygonInput) ? json_decode(wp_unslash($polygonInput), true) : $polygonInput;
                if (is_array($polygon) && !empty($polygon['coordinates'])) {
                    $data['express_zone_polygon'] = wp_json_encode($polygon);
                }
            }
        }

        // Handle working hours (JSON)
        if (isset($_POST['express_working_hours'])) {
            $hoursInput = $_POST['express_working_hours'];
            $hours = is_string($hoursInput) ? json_decode(wp_unslash($hoursInput), true) : $hoursInput;
            if (is_array($hours)) {
                $data['express_working_hours'] = wp_json_encode($hours);
            }
        }

        $result = $wpdb->update($table, $data, ['warehouse_code' => $code]);

        if ($result === false) {
            wp_send_json_error(['message' => $wpdb->last_error]);
        }

        wp_send_json_success(['message' => __('تم حفظ الإعدادات بنجاح', 'zooboxi')]);
    }
}
