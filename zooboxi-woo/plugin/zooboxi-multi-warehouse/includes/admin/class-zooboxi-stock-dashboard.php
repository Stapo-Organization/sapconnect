<?php
/**
 * Warehouse Stock Dashboard — premium visual overview.
 */
class Zooboxi_Stock_Dashboard
{
    public static function render(): void
    {
        if (!current_user_can('manage_woocommerce')) return;

        global $wpdb;

        $warehouses = self::get_warehouse_summary();
        $total_products = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->posts} WHERE post_type = 'product' AND post_status = 'publish'");
        $with_stock = (int) $wpdb->get_var("SELECT COUNT(DISTINCT post_id) FROM {$wpdb->postmeta} WHERE meta_key = '_stock' AND meta_value > 0");
        $out_of_stock = $total_products - $with_stock;
        $managed = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->postmeta} WHERE meta_key = '_manage_stock' AND meta_value = 'yes'");
        $last_sync = get_option('zooboxi_last_stock_sync', '—');
        $total_units = array_sum(array_column($warehouses, 'total_stock'));

        // Search
        $search = isset($_GET['s']) ? sanitize_text_field($_GET['s']) : '';
        $wh_filter = isset($_GET['warehouse']) ? sanitize_text_field($_GET['warehouse']) : '';
        $stock_filter = isset($_GET['stock_status']) ? sanitize_text_field($_GET['stock_status']) : '';
        $results = ($search || $wh_filter || $stock_filter) ? self::search_products($search, $wh_filter, $stock_filter) : [];

        self::render_styles();
        ?>
        <div class="wrap zbx-dash">

            <!-- Header -->
            <div class="zbx-header">
                <div class="zbx-header-text">
                    <h1>لوحة المخزون</h1>
                    <p>نظرة شاملة على المخزون حسب المستودعات والفروع</p>
                </div>
                <div class="zbx-header-actions">
                    <span class="zbx-sync-badge">آخر مزامنة: <strong><?php echo esc_html($last_sync); ?></strong></span>
                </div>
            </div>

            <!-- Search Section (TOP) -->
            <div class="zbx-section">
                <div class="zbx-section-head">
                    <h2>بحث المخزون</h2>
                </div>
                <form method="get" class="zbx-search-box">
                    <input type="hidden" name="page" value="zooboxi-stock">
                    <div class="zbx-search-row">
                        <input type="text" name="s" value="<?php echo esc_attr($search); ?>"
                               placeholder="ابحث بالاسم أو كود المنتج..." class="zbx-input">
                        <select name="warehouse" class="zbx-select">
                            <option value="">كل المستودعات</option>
                            <?php foreach ($warehouses as $wh): ?>
                            <option value="<?php echo esc_attr($wh['code']); ?>" <?php selected($wh_filter, $wh['code']); ?>>
                                <?php echo esc_html($wh['name']); ?>
                            </option>
                            <?php endforeach; ?>
                        </select>
                        <select name="stock_status" class="zbx-select">
                            <option value="">كل الحالات</option>
                            <option value="instock" <?php selected($stock_filter, 'instock'); ?>>متوفر</option>
                            <option value="outofstock" <?php selected($stock_filter, 'outofstock'); ?>>غير متوفر</option>
                        </select>
                        <button type="submit" class="zbx-btn">بحث</button>
                    </div>
                </form>

                <?php if ($search || $wh_filter || $stock_filter): ?>
                <div class="zbx-results-info">
                    عدد النتائج: <strong><?php echo count($results); ?></strong>
                    <?php if ($search): ?> | بحث: <strong><?php echo esc_html($search); ?></strong><?php endif; ?>
                </div>
                <div class="zbx-table-wrap">
                    <table class="zbx-table">
                        <thead>
                            <tr>
                                <th class="th-img"></th>
                                <th class="th-name">المنتج</th>
                                <th class="th-code">الكود</th>
                                <th class="th-total">الإجمالي</th>
                                <?php foreach ($warehouses as $wh): ?>
                                <th class="th-wh" title="<?php echo esc_attr($wh['name']); ?>"><?php echo esc_html($wh['code']); ?></th>
                                <?php endforeach; ?>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($results)): ?>
                            <tr><td colspan="<?php echo 4 + count($warehouses); ?>" class="zbx-empty">لا توجد نتائج</td></tr>
                            <?php else: ?>
                            <?php foreach ($results as $row): ?>
                            <tr>
                                <td class="td-img">
                                    <?php if ($row['image']): ?>
                                    <img src="<?php echo esc_url($row['image']); ?>">
                                    <?php else: ?>
                                    <div class="zbx-no-img">📦</div>
                                    <?php endif; ?>
                                </td>
                                <td class="td-name">
                                    <a href="<?php echo get_edit_post_link($row['id']); ?>">
                                        <?php echo esc_html(mb_strimwidth($row['title'], 0, 50, '...')); ?>
                                    </a>
                                </td>
                                <td class="td-code"><code><?php echo esc_html($row['item_code']); ?></code></td>
                                <td class="td-total">
                                    <span class="zbx-stock-pill <?php echo $row['total'] > 0 ? 'in' : 'out'; ?>">
                                        <?php echo number_format($row['total']); ?>
                                    </span>
                                </td>
                                <?php foreach ($warehouses as $wh):
                                    $qty = $row['wh_stock'][$wh['code']] ?? 0;
                                ?>
                                <td class="td-wh <?php echo $qty > 0 ? 'has' : 'zero'; ?>"><?php echo $qty > 0 ? number_format($qty) : '—'; ?></td>
                                <?php endforeach; ?>
                            </tr>
                            <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
                <?php endif; ?>
            </div>

            <!-- KPI Row -->
            <div class="zbx-kpi-row">
                <div class="zbx-kpi">
                    <div class="zbx-kpi-icon" style="background:linear-gradient(135deg,#0d9488,#14b8a6);">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M3 21h18M3 7v14M21 7v14M6 21V10h4v11M14 21V10h4v11M10 7l2-4 2 4"/></svg>
                    </div>
                    <div class="zbx-kpi-data">
                        <span class="zbx-kpi-val"><?php echo count($warehouses); ?></span>
                        <span class="zbx-kpi-lbl">مستودع / فرع</span>
                    </div>
                </div>
                <div class="zbx-kpi">
                    <div class="zbx-kpi-icon" style="background:linear-gradient(135deg,#3b82f6,#60a5fa);">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/></svg>
                    </div>
                    <div class="zbx-kpi-data">
                        <span class="zbx-kpi-val"><?php echo number_format($total_products); ?></span>
                        <span class="zbx-kpi-lbl">إجمالي المنتجات</span>
                    </div>
                </div>
                <div class="zbx-kpi">
                    <div class="zbx-kpi-icon" style="background:linear-gradient(135deg,#10b981,#34d399);">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg>
                    </div>
                    <div class="zbx-kpi-data">
                        <span class="zbx-kpi-val"><?php echo number_format($with_stock); ?></span>
                        <span class="zbx-kpi-lbl">منتجات متوفرة</span>
                    </div>
                </div>
                <div class="zbx-kpi">
                    <div class="zbx-kpi-icon" style="background:linear-gradient(135deg,#ef4444,#f87171);">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>
                    </div>
                    <div class="zbx-kpi-data">
                        <span class="zbx-kpi-val"><?php echo number_format($out_of_stock); ?></span>
                        <span class="zbx-kpi-lbl">نفدت الكمية</span>
                    </div>
                </div>
                <div class="zbx-kpi">
                    <div class="zbx-kpi-icon" style="background:linear-gradient(135deg,#8b5cf6,#a78bfa);">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/></svg>
                    </div>
                    <div class="zbx-kpi-data">
                        <span class="zbx-kpi-val"><?php echo number_format($total_units); ?></span>
                        <span class="zbx-kpi-lbl">إجمالي الوحدات</span>
                    </div>
                </div>
            </div>

            <!-- Warehouse Cards -->
            <div class="zbx-section">
                <div class="zbx-section-head">
                    <h2>الفروع والمستودعات</h2>
                    <span class="zbx-section-sub"><?php echo count($warehouses); ?> مستودع نشط</span>
                </div>
                <div class="zbx-wh-grid">
                    <?php
                    $max = max(array_column($warehouses, 'total_stock') ?: [1]);
                    foreach ($warehouses as $wh):
                        $pct = $max > 0 ? round(($wh['total_stock'] / $max) * 100) : 0;
                        $is_retail = $wh['is_pickup'];
                    ?>
                    <div class="zbx-wh-card">
                        <div class="zbx-wh-top">
                            <span class="zbx-wh-badge <?php echo $is_retail ? 'retail' : 'ship'; ?>">
                                <?php echo $is_retail ? 'فرع تجزئة' : 'مستودع شحن'; ?>
                            </span>
                            <span class="zbx-wh-code"><?php echo esc_html($wh['code']); ?></span>
                        </div>
                        <h3 class="zbx-wh-name"><?php echo esc_html($wh['name']); ?></h3>
                        <div class="zbx-wh-city"><?php echo esc_html($wh['city']); ?></div>
                        <div class="zbx-wh-metrics">
                            <div class="zbx-metric">
                                <span class="zbx-metric-val"><?php echo number_format($wh['product_count']); ?></span>
                                <span class="zbx-metric-lbl">منتج</span>
                            </div>
                            <div class="zbx-metric">
                                <span class="zbx-metric-val"><?php echo number_format($wh['total_stock']); ?></span>
                                <span class="zbx-metric-lbl">وحدة</span>
                            </div>
                        </div>
                        <div class="zbx-wh-bar-wrap">
                            <div class="zbx-wh-bar" style="width:<?php echo $pct; ?>%"></div>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>
        </div>
        <?php
    }

    private static function render_styles(): void
    {
        ?>
        <style>
        /* ─── Zooboxi Stock Dashboard ─── */
        .zbx-dash{max-width:1500px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;direction:rtl}

        /* Header */
        .zbx-header{display:flex;justify-content:space-between;align-items:center;margin:0 0 24px;padding:24px 28px;background:linear-gradient(135deg,#0f766e 0%,#0d9488 50%,#14b8a6 100%);border-radius:16px;color:#fff}
        .zbx-header h1{font-size:26px;font-weight:700;margin:0 0 4px;color:#fff}
        .zbx-header p{margin:0;opacity:.85;font-size:14px}
        .zbx-sync-badge{display:inline-flex;align-items:center;gap:6px;background:rgba(255,255,255,.15);backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,.2);padding:8px 16px;border-radius:10px;font-size:13px;color:#fff}
        .zbx-sync-badge strong{color:#fff}

        /* KPI Row */
        .zbx-kpi-row{display:grid;grid-template-columns:repeat(5,1fr);gap:14px;margin-bottom:28px}
        @media(max-width:1200px){.zbx-kpi-row{grid-template-columns:repeat(3,1fr)}}
        @media(max-width:768px){.zbx-kpi-row{grid-template-columns:repeat(2,1fr)}}
        .zbx-kpi{display:flex;align-items:center;gap:14px;background:#fff;padding:18px 20px;border-radius:14px;border:1px solid #e5e7eb;box-shadow:0 1px 3px rgba(0,0,0,.04);transition:all .2s}
        .zbx-kpi:hover{transform:translateY(-2px);box-shadow:0 8px 24px rgba(0,0,0,.08)}
        .zbx-kpi-icon{width:48px;height:48px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
        .zbx-kpi-data{display:flex;flex-direction:column}
        .zbx-kpi-val{font-size:24px;font-weight:700;color:#111827;line-height:1.2}
        .zbx-kpi-lbl{font-size:12px;color:#6b7280;margin-top:2px}

        /* Section */
        .zbx-section{background:#fff;border-radius:16px;border:1px solid #e5e7eb;padding:24px;margin-bottom:24px;box-shadow:0 1px 3px rgba(0,0,0,.04)}
        .zbx-section-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;padding-bottom:14px;border-bottom:1px solid #f3f4f6}
        .zbx-section-head h2{font-size:18px;font-weight:600;color:#111827;margin:0}
        .zbx-section-sub{font-size:13px;color:#9ca3af;background:#f9fafb;padding:4px 12px;border-radius:20px}

        /* Warehouse Grid */
        .zbx-wh-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px}
        .zbx-wh-card{padding:18px;border-radius:12px;border:1px solid #e5e7eb;background:#fafbfc;transition:all .2s;position:relative;overflow:hidden}
        .zbx-wh-card:hover{border-color:#0d9488;box-shadow:0 4px 16px rgba(13,148,136,.1);transform:translateY(-2px)}
        .zbx-wh-card::before{content:'';position:absolute;top:0;right:0;width:4px;height:100%;border-radius:0 4px 4px 0}
        .zbx-wh-card:has(.retail)::before{background:linear-gradient(180deg,#0d9488,#14b8a6)}
        .zbx-wh-card:has(.ship)::before{background:linear-gradient(180deg,#f59e0b,#fbbf24)}
        .zbx-wh-top{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}
        .zbx-wh-badge{font-size:11px;padding:3px 10px;border-radius:20px;font-weight:500}
        .zbx-wh-badge.retail{background:#d1fae5;color:#065f46}
        .zbx-wh-badge.ship{background:#fef3c7;color:#92400e}
        .zbx-wh-code{font-size:11px;color:#9ca3af;font-family:'SF Mono',Monaco,monospace;background:#f3f4f6;padding:2px 8px;border-radius:4px}
        .zbx-wh-name{font-size:15px;font-weight:600;color:#1f2937;margin:0 0 2px}
        .zbx-wh-city{font-size:12px;color:#9ca3af;margin-bottom:14px}
        .zbx-wh-metrics{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:12px}
        .zbx-metric{text-align:center;background:#fff;padding:8px;border-radius:8px;border:1px solid #f3f4f6}
        .zbx-metric-val{display:block;font-size:18px;font-weight:700;color:#0d9488}
        .zbx-metric-lbl{display:block;font-size:11px;color:#9ca3af;margin-top:1px}
        .zbx-wh-bar-wrap{height:5px;background:#f3f4f6;border-radius:3px;overflow:hidden}
        .zbx-wh-bar{height:100%;background:linear-gradient(90deg,#0d9488,#14b8a6);border-radius:3px;transition:width .6s ease}

        /* Search */
        .zbx-search-box{margin-bottom:16px}
        .zbx-search-row{display:flex;gap:10px;flex-wrap:wrap}
        .zbx-input{flex:1;min-width:250px;padding:10px 16px;border:1px solid #d1d5db;border-radius:10px;font-size:14px;outline:none;transition:border .2s}
        .zbx-input:focus{border-color:#0d9488;box-shadow:0 0 0 3px rgba(13,148,136,.1)}
        .zbx-select{padding:10px 14px;border:1px solid #d1d5db;border-radius:10px;font-size:13px;background:#fff;min-width:160px;outline:none}
        .zbx-select:focus{border-color:#0d9488}
        .zbx-btn{padding:10px 24px;background:linear-gradient(135deg,#0d9488,#14b8a6);color:#fff;border:none;border-radius:10px;font-size:14px;font-weight:600;cursor:pointer;transition:all .2s}
        .zbx-btn:hover{transform:translateY(-1px);box-shadow:0 4px 12px rgba(13,148,136,.3)}
        .zbx-results-info{font-size:13px;color:#6b7280;margin-bottom:12px;padding:8px 14px;background:#f9fafb;border-radius:8px}

        /* Table */
        .zbx-table-wrap{overflow-x:auto;border-radius:12px;border:1px solid #e5e7eb}
        .zbx-table{width:100%;border-collapse:collapse;font-size:13px}
        .zbx-table thead{background:#f8fafc;position:sticky;top:0}
        .zbx-table th{padding:12px 10px;font-weight:600;color:#374151;text-align:center;border-bottom:2px solid #e5e7eb;white-space:nowrap;font-size:11px;text-transform:uppercase;letter-spacing:.5px}
        .zbx-table th.th-name{text-align:right;min-width:200px}
        .zbx-table th.th-wh{font-size:10px;min-width:60px}
        .zbx-table th.th-img{width:44px}
        .zbx-table td{padding:8px 10px;border-bottom:1px solid #f3f4f6;text-align:center;vertical-align:middle}
        .zbx-table tbody tr:hover{background:#f0fdfa}
        .td-img img{width:40px;height:40px;object-fit:cover;border-radius:8px;border:1px solid #e5e7eb}
        .zbx-no-img{width:40px;height:40px;display:flex;align-items:center;justify-content:center;background:#f3f4f6;border-radius:8px;font-size:18px}
        .td-name{text-align:right !important}
        .td-name a{color:#1f2937;text-decoration:none;font-weight:500}
        .td-name a:hover{color:#0d9488}
        .td-code code{font-size:11px;background:#f3f4f6;padding:2px 6px;border-radius:4px;color:#6b7280}
        .zbx-stock-pill{display:inline-block;padding:4px 12px;border-radius:20px;font-size:12px;font-weight:600}
        .zbx-stock-pill.in{background:#d1fae5;color:#065f46}
        .zbx-stock-pill.out{background:#fee2e2;color:#991b1b}
        .td-wh{font-size:12px}
        .td-wh.has{color:#065f46;font-weight:600;background:#ecfdf5}
        .td-wh.zero{color:#d1d5db}
        .zbx-empty{text-align:center !important;padding:40px !important;color:#9ca3af;font-size:14px}
        </style>
        <?php
    }

    private static function get_warehouse_summary(): array
    {
        global $wpdb;
        $rows = $wpdb->get_results("SELECT meta_value FROM {$wpdb->postmeta} WHERE meta_key = '_zooboxi_warehouse_stock' AND meta_value IS NOT NULL AND meta_value != ''");

        $warehouses = [];
        foreach ($rows as $row) {
            $data = json_decode($row->meta_value, true);
            if (!is_array($data)) continue;
            foreach ($data as $wh) {
                $code = $wh['warehouse_code'] ?? '';
                if (!$code) continue;
                if (!isset($warehouses[$code])) {
                    $warehouses[$code] = ['code' => $code, 'name' => $code, 'city' => '', 'is_pickup' => false, 'product_count' => 0, 'total_stock' => 0];
                }
                $warehouses[$code]['product_count']++;
                $warehouses[$code]['total_stock'] += (int)($wh['in_stock'] ?? 0);
            }
        }

        $names = [
            'RUH002' => ['فرع النصر - الرياض', 'الرياض', true],
            'RUH004' => ['فرع الربيع - الرياض', 'الرياض', true],
            'RUH005' => ['فرع قرطبة - الرياض', 'الرياض', true],
            'RUH006' => ['فرع السليمانية - الرياض', 'الرياض', true],
            'RUH007' => ['فرع الروابي - الرياض', 'الرياض', true],
            'RUH008' => ['فرع السويدي - الرياض', 'الرياض', true],
            'JED002' => ['فرع جدة', 'جدة', true],
            'DMM001' => ['فرع الدمام', 'الدمام', true],
            'MED001' => ['فرع المدينة المنورة', 'المدينة المنورة', true],
            'ABH001' => ['فرع أبها', 'أبها', true],
            'UZH001' => ['فرع عنيزة', 'عنيزة', true],
            'RUH003' => ['مستودع الشحن - الرياض', 'الرياض', false],
            'JED001' => ['مستودع الشحن - جدة', 'جدة', false],
        ];

        foreach ($warehouses as $code => &$wh) {
            if (isset($names[$code])) {
                [$wh['name'], $wh['city'], $wh['is_pickup']] = $names[$code];
            }
        }

        uasort($warehouses, function ($a, $b) {
            if ($a['is_pickup'] !== $b['is_pickup']) return $b['is_pickup'] <=> $a['is_pickup'];
            return $b['total_stock'] <=> $a['total_stock'];
        });

        return $warehouses;
    }

    private static function search_products(string $search, string $wh_filter, string $stock_filter): array
    {
        global $wpdb;
        $where = "p.post_type = 'product' AND p.post_status = 'publish'";

        if ($search) {
            $like = '%' . $wpdb->esc_like($search) . '%';
            $where .= $wpdb->prepare(" AND (p.post_title LIKE %s OR EXISTS (SELECT 1 FROM {$wpdb->postmeta} pm_s WHERE pm_s.post_id = p.ID AND pm_s.meta_key = '_zooboxi_item_code' AND pm_s.meta_value LIKE %s))", $like, $like);
        }

        if ($stock_filter === 'instock') {
            $where .= " AND EXISTS (SELECT 1 FROM {$wpdb->postmeta} pm_st WHERE pm_st.post_id = p.ID AND pm_st.meta_key = '_stock' AND CAST(pm_st.meta_value AS DECIMAL) > 0)";
        } elseif ($stock_filter === 'outofstock') {
            $where .= " AND NOT EXISTS (SELECT 1 FROM {$wpdb->postmeta} pm_st WHERE pm_st.post_id = p.ID AND pm_st.meta_key = '_stock' AND CAST(pm_st.meta_value AS DECIMAL) > 0)";
        }

        $products = $wpdb->get_results("SELECT p.ID, p.post_title FROM {$wpdb->posts} p WHERE $where ORDER BY p.post_title ASC LIMIT 50");

        $results = [];
        foreach ($products as $p) {
            $item_code = get_post_meta($p->ID, '_zooboxi_item_code', true);
            $stock = (float)get_post_meta($p->ID, '_stock', true);
            $wh_data = json_decode(get_post_meta($p->ID, '_zooboxi_warehouse_stock', true), true) ?: [];
            $thumb = get_the_post_thumbnail_url($p->ID, 'thumbnail');

            $wh_stock = [];
            foreach ($wh_data as $wh) $wh_stock[$wh['warehouse_code']] = (int)($wh['in_stock'] ?? 0);

            if ($wh_filter && ($wh_stock[$wh_filter] ?? 0) <= 0) continue;

            $results[] = ['id' => $p->ID, 'title' => $p->post_title, 'item_code' => $item_code, 'total' => $stock, 'wh_stock' => $wh_stock, 'image' => $thumb];
        }
        return $results;
    }
}
