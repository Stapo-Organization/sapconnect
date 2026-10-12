<?php
defined('ABSPATH') || exit;

/** The ShipGo Connect admin screen: configure, test connection, run a SKU-match report. */
class ShipGo_Settings_Page {

    private static ?ShipGo_Settings_Page $instance = null;
    public static function instance(): ShipGo_Settings_Page { return self::$instance ??= new self(); }

    public function register_hooks(): void {
        add_action('admin_menu', [$this, 'menu']);
        add_action('admin_post_shipgo_save', [$this, 'save']);
        add_action('wp_ajax_shipgo_test', [$this, 'ajax_test']);
        add_action('wp_ajax_shipgo_match', [$this, 'ajax_match']);
    }

    public function menu(): void {
        add_menu_page(
            __('ShipGo', 'shipgo'),
            __('ShipGo', 'shipgo'),
            'manage_woocommerce',
            'shipgo-connect',
            [$this, 'render'],
            'dashicons-store',
            56
        );
    }

    public function save(): void {
        if (!current_user_can('manage_woocommerce') || !check_admin_referer('shipgo_save')) {
            wp_die('forbidden');
        }
        $key = trim((string) ($_POST['api_key'] ?? ''));
        $patch = [
            'enabled'         => isset($_POST['enabled']) ? 'yes' : 'no',
            'base_url'        => esc_url_raw(trim((string) ($_POST['base_url'] ?? ''))),
            'webhook_secret'  => trim((string) ($_POST['webhook_secret'] ?? '')),
            'dispatch_status' => sanitize_key((string) ($_POST['dispatch_status'] ?? 'completed')),
        ];
        // only overwrite the key if a new one was typed (the field shows masked otherwise)
        if ($key !== '' && strpos($key, '•') === false) {
            $patch['api_key'] = $key;
        }
        ShipGo_Settings::update($patch);
        wp_safe_redirect(add_query_arg(['page' => 'shipgo-connect', 'saved' => '1'], admin_url('admin.php')));
        exit;
    }

    public function ajax_test(): void {
        check_ajax_referer('shipgo_admin');
        if (!current_user_can('manage_woocommerce')) {
            wp_send_json_error(['error' => 'forbidden']);
        }
        $res = ShipGo_Client::get('/v1/channel/health');
        $res['ok'] ? wp_send_json_success($res['data']) : wp_send_json_error(['error' => $res['error']]);
    }

    public function ajax_match(): void {
        check_ajax_referer('shipgo_admin');
        if (!current_user_can('manage_woocommerce')) {
            wp_send_json_error(['error' => 'forbidden']);
        }
        // sample the first N store SKUs and ask ShipGo which resolve
        $products = wc_get_products(['limit' => 50, 'status' => 'publish', 'return' => 'objects']);
        $skus = [];
        foreach ($products as $p) {
            $sku = $p->get_sku();
            if ($sku !== '') { $skus[] = $sku; }
        }
        if (empty($skus)) {
            wp_send_json_success(['total' => 0, 'matched' => 0, 'unmatched' => 0, 'results' => []]);
        }
        $res = ShipGo_Client::post('/v1/channel/orders/match-check', ['skus' => array_values(array_unique($skus))]);
        $res['ok'] ? wp_send_json_success($res['data']) : wp_send_json_error(['error' => $res['error']]);
    }

    public function render(): void {
        $base    = ShipGo_Settings::base_url();
        $masked  = ShipGo_Settings::masked_key();
        $secret  = ShipGo_Settings::webhook_secret();
        $enabled = ShipGo_Settings::get('enabled') === 'yes';
        $sandbox = ShipGo_Settings::is_sandbox();
        $dispatch= ShipGo_Settings::get('dispatch_status', 'completed');
        $callback = rest_url('shipgo/v1/order-status');
        $nonce   = wp_create_nonce('shipgo_admin');
        $statuses = wc_get_order_statuses();
        ?>
        <div class="wrap shipgo-wrap" dir="rtl">
          <h1 style="display:flex;align-items:center;gap:10px;">
            <span class="dashicons dashicons-store" style="font-size:28px;width:28px;height:28px;color:#7F54B3;"></span>
            <?php esc_html_e('ShipGo Connect — ربط المتجر بالمستودع', 'shipgo'); ?>
          </h1>

          <?php if (!empty($_GET['saved'])) : ?>
            <div class="notice notice-success is-dismissible"><p><?php esc_html_e('تم الحفظ.', 'shipgo'); ?></p></div>
          <?php endif; ?>

          <div id="shipgo-status" class="shipgo-card <?php echo $enabled ? 'on' : 'off'; ?>">
            <div class="shipgo-dot"></div>
            <div>
              <strong><?php echo $enabled ? esc_html__('مُفعّل', 'shipgo') : esc_html__('متوقّف', 'shipgo'); ?></strong>
              <?php if ($sandbox) : ?><span class="shipgo-badge sandbox"><?php esc_html_e('وضع المراقبة (Sandbox)', 'shipgo'); ?></span><?php endif; ?>
              <div class="shipgo-muted" id="shipgo-status-detail"><?php esc_html_e('اضغط «اختبار الاتصال» للتحقق.', 'shipgo'); ?></div>
            </div>
            <button type="button" class="button button-secondary" id="shipgo-test"><?php esc_html_e('اختبار الاتصال', 'shipgo'); ?></button>
          </div>

          <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" class="shipgo-card">
            <input type="hidden" name="action" value="shipgo_save" />
            <?php wp_nonce_field('shipgo_save'); ?>
            <table class="form-table" role="presentation">
              <tr>
                <th><?php esc_html_e('تفعيل الربط', 'shipgo'); ?></th>
                <td><label><input type="checkbox" name="enabled" <?php checked($enabled); ?> /> <?php esc_html_e('إرسال الطلبات الجديدة إلى ShipGo', 'shipgo'); ?></label></td>
              </tr>
              <tr>
                <th><label for="sg_base"><?php esc_html_e('رابط ShipGo', 'shipgo'); ?></label></th>
                <td><input type="url" id="sg_base" name="base_url" class="regular-text ltr" placeholder="https://wms.alofq.sa" value="<?php echo esc_attr($base); ?>" /></td>
              </tr>
              <tr>
                <th><label for="sg_key"><?php esc_html_e('مفتاح API', 'shipgo'); ?></label></th>
                <td>
                  <input type="text" id="sg_key" name="api_key" class="regular-text ltr" placeholder="sk_live_… / sk_test_…" value="<?php echo esc_attr($masked); ?>" autocomplete="off" />
                  <p class="description"><?php esc_html_e('انسخه من ShipGo (يُعرض مرّة واحدة عند إنشائه). اتركه كما هو لعدم التغيير.', 'shipgo'); ?></p>
                </td>
              </tr>
              <tr>
                <th><label for="sg_secret"><?php esc_html_e('سر التوقيع (Webhook)', 'shipgo'); ?></label></th>
                <td>
                  <input type="text" id="sg_secret" name="webhook_secret" class="regular-text ltr" placeholder="whsec_…" value="<?php echo esc_attr($secret); ?>" autocomplete="off" />
                  <p class="description"><?php esc_html_e('للتحقّق من تحديثات الحالة القادمة من ShipGo.', 'shipgo'); ?></p>
                </td>
              </tr>
              <tr>
                <th><label for="sg_dispatch"><?php esc_html_e('حالة الطلب عند الشحن', 'shipgo'); ?></label></th>
                <td>
                  <select id="sg_dispatch" name="dispatch_status">
                    <?php foreach ($statuses as $k => $label) { $k = str_replace('wc-', '', $k); printf('<option value="%s" %s>%s</option>', esc_attr($k), selected($dispatch, $k, false), esc_html($label)); } ?>
                  </select>
                  <p class="description"><?php esc_html_e('الحالة التي يُنقل إليها الطلب عند شحنه من المستودع.', 'shipgo'); ?></p>
                </td>
              </tr>
              <tr>
                <th><?php esc_html_e('رابط الاستدعاء (Webhook URL)', 'shipgo'); ?></th>
                <td><code class="ltr"><?php echo esc_html($callback); ?></code><p class="description"><?php esc_html_e('عنوان متجرك الذي يستقبل تحديثات الحالة من ShipGo.', 'shipgo'); ?></p></td>
              </tr>
            </table>
            <p><button type="submit" class="button button-primary"><?php esc_html_e('حفظ الإعدادات', 'shipgo'); ?></button></p>
          </form>

          <div class="shipgo-card">
            <h2><?php esc_html_e('تقرير مطابقة المنتجات', 'shipgo'); ?></h2>
            <p class="shipgo-muted"><?php esc_html_e('يفحص عيّنة من منتجات متجرك (حسب الـSKU/الباركود) ويُظهر المطابق مع كاتالوج ShipGo وغير المطابق.', 'shipgo'); ?></p>
            <button type="button" class="button" id="shipgo-match"><?php esc_html_e('فحص المطابقة', 'shipgo'); ?></button>
            <div id="shipgo-match-out" style="margin-top:12px;"></div>
          </div>
        </div>

        <style>
          .shipgo-card{background:#fff;border:1px solid #e2e4e9;border-radius:12px;padding:18px 20px;margin:16px 0;max-width:860px;box-shadow:0 1px 2px rgba(0,0,0,.03)}
          #shipgo-status{display:flex;align-items:center;gap:14px}
          #shipgo-status .shipgo-dot{width:12px;height:12px;border-radius:50%;background:#c9ced6}
          #shipgo-status.on .shipgo-dot{background:#1E9E5A;box-shadow:0 0 0 4px rgba(30,158,90,.15)}
          #shipgo-status.off .shipgo-dot{background:#9aa1ab}
          #shipgo-status button{margin-inline-start:auto}
          .shipgo-badge{display:inline-block;font-size:11px;padding:2px 8px;border-radius:999px;margin-inline-start:8px;background:#fff4e5;color:#a25b00;border:1px solid #f3d6a8}
          .shipgo-muted{color:#646970;font-size:12.5px;margin-top:4px}
          .shipgo-wrap .ltr{direction:ltr;text-align:left}
          .shipgo-pill{display:inline-block;font-size:12px;padding:2px 8px;border-radius:6px;margin:2px}
          .shipgo-pill.ok{background:#e6f6ec;color:#1E7A45}
          .shipgo-pill.no{background:#fdeaea;color:#b3261e}
        </style>
        <script>
        (function(){
          const ajax = '<?php echo esc_url(admin_url('admin-ajax.php')); ?>';
          const nonce = '<?php echo esc_js($nonce); ?>';
          const post = (action, body) => fetch(ajax, {method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'},
            body: new URLSearchParams(Object.assign({action, _ajax_nonce:nonce}, body||{}))}).then(r=>r.json());

          const test = document.getElementById('shipgo-test');
          if (test) test.addEventListener('click', function(){
            const out = document.getElementById('shipgo-status-detail');
            out.textContent = '<?php echo esc_js(__('جارٍ الفحص…', 'shipgo')); ?>';
            post('shipgo_test').then(r=>{
              if(r.success){const d=r.data; out.innerHTML = '<?php echo esc_js(__('متصل', 'shipgo')); ?> · ' +
                (d.is_sandbox ? '<?php echo esc_js(__('وضع المراقبة', 'shipgo')); ?>' : '<?php echo esc_js(__('مباشر', 'shipgo')); ?>') +
                (d.warehouse ? ' · <?php echo esc_js(__('المستودع', 'shipgo')); ?>: '+d.warehouse.code : '');}
              else { out.textContent = '<?php echo esc_js(__('فشل الاتصال:', 'shipgo')); ?> ' + (r.data&&r.data.error||''); }
            }).catch(e=>{ out.textContent = String(e); });
          });

          const match = document.getElementById('shipgo-match');
          if (match) match.addEventListener('click', function(){
            const out = document.getElementById('shipgo-match-out');
            out.textContent = '<?php echo esc_js(__('جارٍ الفحص…', 'shipgo')); ?>';
            post('shipgo_match').then(r=>{
              if(!r.success){ out.textContent = (r.data&&r.data.error)||'error'; return; }
              const d=r.data; let html = '<p><b>'+d.total+'</b> <?php echo esc_js(__('صنف — مطابق', 'shipgo')); ?> <b style="color:#1E7A45">'+d.matched+'</b> · <?php echo esc_js(__('غير مطابق', 'shipgo')); ?> <b style="color:#b3261e">'+d.unmatched+'</b></p>';
              html += '<div>'+(d.results||[]).map(x=>'<span class="shipgo-pill '+(x.matched?'ok':'no')+'" title="'+(x.name||'')+'">'+x.sku+'</span>').join('')+'</div>';
              out.innerHTML = html;
            });
          });
        })();
        </script>
        <?php
    }
}
