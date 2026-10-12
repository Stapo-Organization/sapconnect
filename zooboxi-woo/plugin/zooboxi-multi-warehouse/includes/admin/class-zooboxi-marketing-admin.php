<?php
/**
 * «📈 التسويق» — the admin page for the paid-launch seams: pixel ids and
 * conversion-API tokens per platform, the first-order offer, and the log of
 * the last server-side sends with a test button.
 */

if (!defined('ABSPATH')) exit;

final class Zooboxi_Marketing_Admin
{
    public const SLUG = 'zooboxi-marketing';
    private const CAP = 'manage_woocommerce';

    public function register_hooks(): void
    {
        add_action('admin_menu', [$this, 'register_menu'], 30);
    }

    public function register_menu(): void
    {
        add_submenu_page('zooboxi', __('التسويق', 'zooboxi'), __('📈 التسويق', 'zooboxi'), self::CAP, self::SLUG, [__CLASS__, 'render']);
    }

    private static function fields(): array
    {
        return [
            'meta' => ['title' => 'ميتا (إنستقرام + فيسبوك)', 'rows' => [
                'meta_pixel_id'   => ['Pixel ID', 'من Events Manager → Data sources'],
                'meta_capi_token' => ['Conversions API token', 'Events Manager → Settings → Generate access token'],
                'meta_test_code'  => ['Test event code', 'اختياري — من تبويب Test events، يُستخدم بزرّ الاختبار فقط'],
            ]],
            'tiktok' => ['title' => 'تيك توك', 'rows' => [
                'tiktok_pixel_id'  => ['Pixel code', 'Events Manager → Web events → Pixel code'],
                'tiktok_token'     => ['Events API access token', 'Events Manager → Settings → Generate access token'],
                'tiktok_test_code' => ['Test event code', 'اختياري — من Test events'],
            ]],
            'snap' => ['title' => 'سناب شات', 'rows' => [
                'snap_pixel_id' => ['Pixel ID', 'Ads Manager → Events Manager'],
                'snap_token'    => ['Conversions API token', 'Business Details → Conversions API tokens'],
            ]],
            'google' => ['title' => 'قوقل', 'rows' => [
                'ga4_id'                => ['GA4 Measurement ID', 'مثل G-XXXXXXX'],
                'gads_conversion_id'    => ['Google Ads conversion ID', 'مثل AW-123456789'],
                'gads_conversion_label' => ['Conversion label', 'من إعداد إجراء التحويل «شراء»'],
            ]],
        ];
    }

    public static function render(): void
    {
        if (!current_user_can(self::CAP)) wp_die(__('غير مصرّح', 'zooboxi'));
        $notice = self::handle_post();
        $d = Zooboxi_Marketing::defaults();
        $log = Zooboxi_Marketing_Conversions::recent_log();
        ?>
<style>
.zbm{max-width:1100px}.zbm .card{background:#fff;border:1px solid #dcdcde;border-radius:10px;padding:18px 22px;margin:14px 0}
.zbm h2{margin:0 0 10px;font-size:16px}.zbm table.form-table th{width:220px}.zbm input[type=text]{width:420px;max-width:100%;direction:ltr}
.zbm .hint{color:#646970;font-size:12px}.zbm .ok{color:#1a7f37;font-weight:700}.zbm .fail{color:#b32d2e;font-weight:700}
.zbm .toggle{display:flex;gap:10px;align-items:center;padding:8px 0}.zbm .badge{display:inline-block;padding:1px 8px;border-radius:999px;background:#eef3f2;font-size:12px}
.zbm table.log{width:100%;border-collapse:collapse;font-size:13px}.zbm table.log th,.zbm table.log td{padding:6px 8px;border-bottom:1px solid #eee;text-align:start}
</style>
<div class="wrap zbm">
  <h1>📈 التسويق</h1>
  <p class="hint">بنية القياس للإطلاق المدفوع: تحويلات من الخادم لكل منصة (نفس معرّف الحدث مع بكسل المتصفح فلا يُحسب الطلب مرتين)، وعرض الطلب الأول.</p>
  <?php if ($notice) echo '<div class="notice notice-info is-dismissible"><p>' . wp_kses_post($notice) . '</p></div>'; ?>

  <form method="post">
    <?php wp_nonce_field('zbm_save'); ?>
    <input type="hidden" name="zbm_action" value="save">

    <div class="card">
      <h2>المفاتيح العامة</h2>
      <label class="toggle"><input type="checkbox" name="enabled" value="yes" <?php checked(Zooboxi_Marketing::opt('enabled'), 'yes'); ?>> <b>الوحدة مفعّلة</b> <span class="hint">إيقافها يوقف الإرسال والبكسلات والعرض معًا</span></label>
      <label class="toggle"><input type="checkbox" name="pixels_enabled" value="yes" <?php checked(Zooboxi_Marketing::opt('pixels_enabled'), 'yes'); ?>> <b>بكسلات المتصفح على المتجر</b> <span class="hint">تُطبع فقط للمنصات التي لها معرّف</span></label>
      <label class="toggle"><input type="checkbox" name="first_express_free" value="yes" <?php checked(Zooboxi_Marketing::opt('first_express_free'), 'yes'); ?>> <b>عرض الطلب الأول: توصيل إكسبريس مجاني</b> <span class="hint">للعميل المسجّل الذي لا يملك أي طلب سابق، بلا حدّ أدنى، في التطبيق والويب</span></label>
    </div>

    <?php foreach (self::fields() as $key => $group) : ?>
    <div class="card">
      <h2><?php echo esc_html($group['title']); ?></h2>
      <table class="form-table"><tbody>
      <?php foreach ($group['rows'] as $opt => [$label, $hint]) : ?>
        <tr><th><?php echo esc_html($label); ?></th>
          <td><input type="text" name="<?php echo esc_attr($opt); ?>" value="<?php echo esc_attr((string) Zooboxi_Marketing::opt($opt)); ?>" autocomplete="off"><br><span class="hint"><?php echo esc_html($hint); ?></span></td></tr>
      <?php endforeach; ?>
      </tbody></table>
    </div>
    <?php endforeach; ?>

    <p><button class="button button-primary">حفظ</button></p>
  </form>

  <div class="card">
    <h2>اختبار الإرسال من الخادم</h2>
    <form method="post" style="display:flex;gap:10px;align-items:center">
      <?php wp_nonce_field('zbm_test'); ?>
      <input type="hidden" name="zbm_action" value="test">
      <label>رقم طلب موجود <input type="number" name="order_id" min="1" style="width:120px" required></label>
      <button class="button">أرسل كحدث اختبار</button>
      <span class="hint">يظهر في Test events لدى ميتا وتيك توك خلال ثوانٍ، ولا يُعلَّم الطلب كمُرسَل.</span>
    </form>
  </div>

  <div class="card">
    <h2>آخر الإرسالات <span class="badge"><?php echo count($log); ?></span></h2>
    <?php if (!$log) : ?><p class="hint">لا إرسالات بعد. تُرسل التحويلات عند دفع الطلب (أو قبوله للدفع عند الاستلام).</p>
    <?php else : ?>
    <table class="log"><thead><tr><th>الوقت</th><th>الطلب</th><th>المنصة</th><th>النتيجة</th><th>الرد</th></tr></thead><tbody>
    <?php foreach ($log as $row) : ?>
      <tr><td><?php echo esc_html(wp_date('Y-m-d H:i', (int) $row['t'])); ?></td>
          <td>#<?php echo (int) $row['order']; ?><?php echo !empty($row['test']) ? ' <span class="badge">اختبار</span>' : ''; ?></td>
          <td><?php echo esc_html($row['platform']); ?></td>
          <td class="<?php echo !empty($row['ok']) ? 'ok' : 'fail'; ?>"><?php echo !empty($row['ok']) ? 'نجح' : 'فشل'; ?> <span class="hint"><?php echo (int) $row['status']; ?></span></td>
          <td class="hint" style="direction:ltr"><?php echo esc_html($row['msg']); ?></td></tr>
    <?php endforeach; ?>
    </tbody></table>
    <?php endif; ?>
  </div>
</div>
        <?php
    }

    private static function handle_post(): string
    {
        if (empty($_POST['zbm_action']) || !current_user_can(self::CAP)) return '';
        $action = sanitize_key($_POST['zbm_action']);
        if (!check_admin_referer('zbm_' . $action)) return '';

        if ($action === 'save') {
            foreach (['enabled', 'pixels_enabled', 'first_express_free'] as $k) {
                update_option(Zooboxi_Marketing::OPT_PREFIX . $k, (isset($_POST[$k]) && $_POST[$k] === 'yes') ? 'yes' : 'no', false);
            }
            foreach (self::fields() as $group) {
                foreach ($group['rows'] as $opt => $_) {
                    $v = isset($_POST[$opt]) ? trim(sanitize_text_field(wp_unslash((string) $_POST[$opt]))) : '';
                    update_option(Zooboxi_Marketing::OPT_PREFIX . $opt, $v, false);
                }
            }
            return 'تم الحفظ.';
        }

        if ($action === 'test') {
            $order_id = (int) ($_POST['order_id'] ?? 0);
            if ($order_id <= 0 || !wc_get_order($order_id)) return 'الطلب غير موجود.';
            if (!Zooboxi_Marketing_Conversions::any_configured()) return 'لا توجد منصة مُعدّة بعد (معرّف + رمز).';
            $r = Zooboxi_Marketing_Conversions::send($order_id, true);
            $parts = [];
            foreach ($r as $platform => $res) {
                $parts[] = $platform . ': ' . ($res['ok'] ? 'نجح' : 'فشل') . ' (' . (int) $res['status'] . ')';
            }
            return 'أُرسل حدث اختبار للطلب #' . $order_id . ' — ' . implode(' · ', $parts);
        }
        return '';
    }
}
