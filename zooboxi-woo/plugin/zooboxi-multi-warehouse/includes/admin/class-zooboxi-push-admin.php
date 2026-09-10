<?php
/**
 * «📣 الإشعارات» — the owner's window onto the engine.
 *
 * Five tabs: the board (what went out, what was opened, what the gate held
 * and why, lift against the holdout), the journeys (on/off and how many
 * people are inside each), a campaign composer with an audience count, a
 * canary, a dry run and an approval gate, the raw log, and the knobs.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Push_Admin
{
    const SLUG = 'zooboxi-push';
    const CAP  = 'manage_woocommerce';

    public function register_hooks(): void
    {
        add_action('admin_menu', [$this, 'register_menu'], 25);
    }

    public function register_menu(): void
    {
        add_submenu_page('zooboxi', __('الإشعارات', 'zooboxi'), __('📣 الإشعارات', 'zooboxi'), self::CAP, self::SLUG, [__CLASS__, 'render']);
    }

    /* ══════════════════════════════════════════════════════════════
       LABELS
       ══════════════════════════════════════════════════════════════ */

    public static function sources(): array
    {
        return [
            'order_status' => 'حالة الطلب', 'courier' => 'المندوب', 'order_late' => 'يتأخّر قليلًا', 'engine_test' => 'تجربة',
            'reorder' => 'الطعام قبل أن يخلص', 'welcome' => 'رحلة الترحيب', 'post_first' => 'بعد أول طلب', 'winback' => 'الاستعادة',
            'cart' => 'السلة المنسية', 'rating' => 'قيّم توصيلتك', 'restock' => 'رجع للمخزون', 'price_drop' => 'نزل السعر',
            'closing_soon' => 'إكسبريس يغلق', 'birthday' => 'عيد ميلاد', 'gift' => 'هدية جاهزة', 'tier_risk' => 'مستواك في خطر',
            'mission' => 'مهمة على بُعد خطوة', 'bundles' => 'ملخّص البكجات', 'campaign' => 'حملة',
        ];
    }

    public static function reasons(): array
    {
        return [
            'quiet_hours' => 'ساعات الهدوء', 'marketing_window' => 'خارج نافذة التسويق', 'friday_pause' => 'هدنة الجمعة', 'ramadan' => 'وضع رمضان',
            'adhan_fajr' => 'أذان الفجر', 'adhan_dhuhr' => 'أذان الظهر', 'adhan_asr' => 'أذان العصر', 'adhan_maghrib' => 'أذان المغرب', 'adhan_isha' => 'أذان العشاء',
            'cap_daily' => 'سقف اليوم', 'cap_weekly' => 'سقف الأسبوع', 'cap_gap' => 'الفجوة الزمنية', 'repeat_text' => 'نص مكرّر',
            'control' => 'المجموعة الضابطة', 'no_device' => 'لا جهاز', 'topic_off' => 'الموضوع مغلق', 'expired' => 'انتهت صلاحيته',
            'engine_off' => 'المحرك متوقف', 'paused' => 'مصدر موقوف', 'converted' => 'اشترى قبل الإرسال', 'campaign_cancelled' => 'حملة أُلغيت',
            'retry' => 'إعادة محاولة', 'token_dead' => 'رمز ميت', 'fcm_error' => 'خطأ FCM', 'dry_run' => 'تجربة جافة', 'exception' => 'خطأ', '' => '—',
        ];
    }

    public static function statuses(): array
    {
        return ['sent' => 'أُرسل', 'pending' => 'ينتظر', 'inbox' => 'صندوق التطبيق', 'skipped' => 'تخطّاه الحارس', 'control' => 'ضابطة', 'failed' => 'فشل', 'cancelled' => 'أُلغي', 'dry' => 'جافة'];
    }

    private static function tiers(): array
    {
        return ['transactional' => 'معاملات', 'service' => 'خدمة', 'marketing' => 'تسويق'];
    }

    /* ══════════════════════════════════════════════════════════════
       ACTIONS
       ══════════════════════════════════════════════════════════════ */

    private static function handle(): array
    {
        $notice = null;
        if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_POST['zbp_action']) || !check_admin_referer('zooboxi_push_admin')) {
            return [null, null];
        }
        $action = sanitize_key((string) $_POST['zbp_action']);
        $tab    = null;
        try {
            switch ($action) {
                case 'settings':
                    self::save_settings();
                    $notice = ['ok', 'حُفظت الإعدادات.'];
                    $tab = 'settings';
                    break;
                case 'journeys':
                    $on = [];
                    foreach (array_keys(Zooboxi_Push_Journeys::all()) as $j) {
                        $on[$j] = isset($_POST['journey'][$j]) ? 'yes' : 'no';
                    }
                    update_option('zooboxi_push_journeys', $on, false);
                    foreach (['moments', 'bundles_digest', 'closing_soon', 'waitlist'] as $k) {
                        update_option('zooboxi_push_' . $k, isset($_POST['feature'][$k]) ? 'yes' : 'no', false);
                    }
                    $notice = ['ok', 'حُفظت الرحلات.'];
                    $tab = 'journeys';
                    break;
                case 'unpause':
                    Zooboxi_Push_Engine::set_paused(sanitize_key((string) $_POST['source']), false);
                    $notice = ['ok', 'أُعيد تشغيل المصدر.'];
                    $tab = 'journeys';
                    break;
                case 'tick':
                    $t = Zooboxi_Push_Engine::tick();
                    $notice = ['ok', sprintf('دورة: %d مأخوذة · %d أُرسلت · %d تنتظر · %d تخطّاها الحارس.', $t['claimed'], $t['sent'], $t['pending'], $t['skipped'])];
                    break;
                case 'daily':
                    Zooboxi_Push_Engine::daily();
                    $notice = ['ok', 'شغّلنا المهمة اليومية (التوقيت، الرحلات، اللحظات، الإيقاف التلقائي).'];
                    break;
                case 'campaign_save':
                    $id = Zooboxi_Push_Campaigns::save($_POST, (int) ($_POST['campaign_id'] ?? 0));
                    $c  = Zooboxi_Push_Campaigns::get($id);
                    $notice = ['ok', sprintf('حُفظت المسودة #%d — الجمهور %s.', $id, number_format_i18n((int) ($c['audience_count'] ?? 0)))];
                    $tab = 'campaign';
                    $_GET['campaign'] = $id;
                    break;
                case 'campaign_canary':
                    $ok = Zooboxi_Push_Campaigns::canary((int) $_POST['campaign_id'], (int) $_POST['device']);
                    $notice = $ok ? ['ok', 'أُرسلت نسخة تجريبية إلى الجهاز المختار.'] : ['err', 'رفض FCM الإرسال — راجع سجل الأخطاء.'];
                    $tab = 'campaign';
                    $_GET['campaign'] = (int) $_POST['campaign_id'];
                    break;
                case 'campaign_approve':
                    $r = Zooboxi_Push_Campaigns::approve((int) $_POST['campaign_id']);
                    $notice = [$r['ok'] ? 'ok' : 'err', $r['message']];
                    $tab = 'campaign';
                    break;
                case 'campaign_cancel':
                    Zooboxi_Push_Campaigns::cancel((int) $_POST['campaign_id']);
                    $notice = ['ok', 'أُلغيت الحملة وما كان ينتظر منها.'];
                    $tab = 'campaign';
                    break;
            }
        } catch (\Throwable $e) {
            $notice = ['err', 'خطأ: ' . $e->getMessage()];
        }
        return [$notice, $tab];
    }

    private static function save_settings(): void
    {
        update_option('zooboxi_push_engine_enabled', isset($_POST['zooboxi_push_engine_enabled']) ? 'yes' : 'no');
        foreach (['quiet_start', 'quiet_end', 'marketing_start', 'marketing_end', 'friday_pause_start', 'friday_pause_end',
                  'ramadan_start', 'ramadan_end', 'suhoor_start', 'suhoor_end'] as $knob) {
            $v = trim(sanitize_text_field(wp_unslash($_POST['zooboxi_push_' . $knob] ?? '')));
            update_option('zooboxi_push_' . $knob, preg_match('/^\d{1,2}:\d{2}$/', $v) ? $v : '', false);
        }
        foreach (['marketing_per_day', 'marketing_per_week', 'marketing_gap_h', 'service_per_day', 'service_gap_h', 'total_per_day', 'total_per_week', 'repeat_days', 'adhan_minutes'] as $knob) {
            $v = trim((string) wp_unslash($_POST['zooboxi_push_' . $knob] ?? ''));
            update_option('zooboxi_push_' . $knob, $v === '' ? '' : max(0, (int) $v), false);
        }
        foreach (['ramadan_from', 'ramadan_to'] as $knob) {
            $v = trim(sanitize_text_field(wp_unslash($_POST['zooboxi_push_' . $knob] ?? '')));
            update_option('zooboxi_push_' . $knob, preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) ? $v : '', false);
        }
        update_option('zooboxi_push_adhan', isset($_POST['zooboxi_push_adhan']) ? 'yes' : 'no', false);
        foreach (['adhan_lat', 'adhan_lng'] as $knob) {
            $v = trim((string) wp_unslash($_POST['zooboxi_push_' . $knob] ?? ''));
            update_option('zooboxi_push_' . $knob, is_numeric($v) ? (string) (float) $v : '', false);
        }
    }

    /* ══════════════════════════════════════════════════════════════
       RENDER
       ══════════════════════════════════════════════════════════════ */

    public static function render(): void
    {
        if (!current_user_can(self::CAP)) {
            wp_die(__('غير مسموح', 'zooboxi'));
        }
        Zooboxi_Push_Engine::maybe_install();
        [$notice, $forced_tab] = self::handle();
        $tab = $forced_tab ?: sanitize_key((string) ($_GET['tab'] ?? 'board'));
        if (!in_array($tab, ['board', 'journeys', 'campaign', 'log', 'settings'], true)) {
            $tab = 'board';
        }
        $base = admin_url('admin.php?page=' . self::SLUG);
        ?>
        <div class="wrap zbp" dir="rtl">
            <h1 style="display:flex;align-items:center;gap:10px">📣 <?php esc_html_e('الإشعارات', 'zooboxi'); ?>
                <span class="zbp-pill <?php echo Zooboxi_Push_Engine::engine_enabled() ? 'on' : 'off'; ?>"><?php echo Zooboxi_Push_Engine::engine_enabled() ? 'المحرك يعمل' : 'المحرك متوقف'; ?></span>
            </h1>
            <?php if ($notice): ?>
                <div class="notice notice-<?php echo $notice[0] === 'ok' ? 'success' : 'error'; ?> is-dismissible"><p><?php echo esc_html($notice[1]); ?></p></div>
            <?php endif; ?>
            <?php $paused = Zooboxi_Push_Engine::paused_sources(); if ($paused): ?>
                <div class="notice notice-warning"><p>⏸ مصادر موقوفة تلقائيًا لأن أرقامها تحت الحد: <strong><?php echo esc_html(implode('، ', array_map(fn ($s) => self::sources()[$s] ?? $s, $paused))); ?></strong> — أعد تشغيلها من تبويب الرحلات.</p></div>
            <?php endif; ?>
            <nav class="zbp-tabs">
                <?php foreach (['board' => 'اللوحة', 'journeys' => 'الرحلات', 'campaign' => 'حملة', 'log' => 'السجل', 'settings' => 'الإعدادات'] as $k => $label): ?>
                    <a class="<?php echo $tab === $k ? 'active' : ''; ?>" href="<?php echo esc_url($base . '&tab=' . $k); ?>"><?php echo esc_html($label); ?></a>
                <?php endforeach; ?>
            </nav>
            <?php
            switch ($tab) {
                case 'journeys': self::tab_journeys(); break;
                case 'campaign': self::tab_campaign(); break;
                case 'log':      self::tab_log(); break;
                case 'settings': self::tab_settings(); break;
                default:         self::tab_board();
            }
            self::styles();
            ?>
        </div>
        <?php
    }

    private static function form_open(string $action): void
    {
        echo '<form method="post">';
        wp_nonce_field('zooboxi_push_admin');
        echo '<input type="hidden" name="zbp_action" value="' . esc_attr($action) . '">';
    }

    /* ── اللوحة ─────────────────────────────────────────────────── */

    private static function tab_board(): void
    {
        $days = max(1, min(90, (int) ($_GET['days'] ?? 7)));
        $s    = Zooboxi_Push_Engine::stats($days);
        $lift = Zooboxi_Push_Engine::lift(30);
        $rate = $s['sent'] > 0 ? round(100 * $s['opened'] / $s['sent'], 1) : 0;
        $per_person_week = $s['persons'] > 0 ? round(($s['sent'] / max(1, $s['persons'])) * (7 / $days), 2) : 0;
        ?>
        <p class="zbp-range">
            <?php foreach ([7, 30, 90] as $d): ?>
                <a class="<?php echo $days === $d ? 'active' : ''; ?>" href="<?php echo esc_url(admin_url('admin.php?page=' . self::SLUG . '&tab=board&days=' . $d)); ?>">آخر <?php echo $d; ?> يومًا</a>
            <?php endforeach; ?>
        </p>
        <div class="zbp-tiles">
            <div class="zbp-tile"><b><?php echo number_format_i18n($s['sent']); ?></b><span>أُرسل</span></div>
            <div class="zbp-tile"><b><?php echo number_format_i18n($s['opened']); ?></b><span>فُتح · <?php echo esc_html((string) $rate); ?>%</span></div>
            <div class="zbp-tile"><b><?php echo number_format_i18n($s['inbox']); ?></b><span>في صندوق التطبيق بلا دفع</span></div>
            <div class="zbp-tile"><b><?php echo number_format_i18n($s['control']); ?></b><span>الضابطة (لم يُرسَل)</span></div>
            <div class="zbp-tile"><b><?php echo number_format_i18n($s['pending']); ?></b><span>ينتظر الآن</span></div>
            <div class="zbp-tile"><b><?php echo esc_html((string) $per_person_week); ?></b><span>إشعار / شخص / أسبوع</span></div>
            <div class="zbp-tile"><b><?php echo number_format_i18n($s['persons']); ?></b><span>أشخاص بأجهزة · <?php echo number_format_i18n($s['devices']); ?> جهاز</span></div>
            <div class="zbp-tile"><b><?php echo $s['tick_at'] > 0 ? esc_html(human_time_diff($s['tick_at'], time())) : '—'; ?></b><span>آخر دورة · اليومية <?php echo $s['daily_at'] > 0 ? esc_html(human_time_diff($s['daily_at'], time())) : 'لم تعمل'; ?></span></div>
        </div>

        <h2>حسب المصدر</h2>
        <table class="widefat striped zbp-table">
            <thead><tr><th>المصدر</th><th>الدرجة</th><th>أُرسل</th><th>فُتح</th><th>صندوق</th><th>تخطّاه</th><th>ضابطة</th><th>ينتظر</th><th>الرفع (30 يومًا)</th></tr></thead>
            <tbody>
            <?php if (!$s['by_source']): ?><tr><td colspan="9">لا شيء بعد.</td></tr><?php endif; ?>
            <?php foreach ($s['by_source'] as $r):
                $l = $lift[$r['source']] ?? null;
                $lift_txt = '—';
                if ($l) {
                    $lift_txt = sprintf('%s%% مقابل %s%%', round(100 * $l['treated_rate'], 1), round(100 * $l['control_rate'], 1));
                    if ($l['lift'] !== null) {
                        $lift_txt .= sprintf(' (%+d%%)', round(100 * $l['lift']));
                    }
                    if ($l['small_sample']) {
                        $lift_txt .= ' · عيّنة صغيرة';
                    }
                }
                ?>
                <tr>
                    <td><?php echo esc_html(self::sources()[$r['source']] ?? $r['source']); ?></td>
                    <td><?php echo esc_html(self::tiers()[$r['tier']] ?? $r['tier']); ?></td>
                    <td><?php echo (int) $r['sent']; ?></td>
                    <td><?php echo (int) $r['opened']; ?><?php if ((int) $r['sent'] > 0): ?> <small>(<?php echo round(100 * (int) $r['opened'] / (int) $r['sent']); ?>%)</small><?php endif; ?></td>
                    <td><?php echo (int) $r['inbox']; ?></td><td><?php echo (int) $r['skipped']; ?></td><td><?php echo (int) $r['control']; ?></td><td><?php echo (int) $r['pending']; ?></td>
                    <td><?php echo esc_html($lift_txt); ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>

        <h2>لماذا لم يُرسَل</h2>
        <p class="zbp-reasons">
            <?php
            $bits = [];
            foreach ($s['by_status'] as $r) {
                if ($r['status'] === 'sent') {
                    continue;
                }
                $label = self::statuses()[$r['status']] ?? $r['status'];
                if ((string) $r['reason'] !== '') {
                    $label .= ' · ' . (self::reasons()[$r['reason']] ?? $r['reason']);
                }
                $bits[] = '<span>' . esc_html($label) . ' <b>' . (int) $r['n'] . '</b></span>';
            }
            echo $bits ? implode(' ', $bits) : 'لا شيء.';
            ?>
        </p>
        <p>
            <?php self::form_open('tick'); ?><button class="button">شغّل دورة الآن</button></form>
            <?php self::form_open('daily'); ?><button class="button">شغّل المهمة اليومية الآن</button></form>
        </p>
        <?php
    }

    /* ── الرحلات ─────────────────────────────────────────────────── */

    private static function tab_journeys(): void
    {
        $s = Zooboxi_Push_Engine::stats(30);
        $active = [];
        foreach ($s['active_runs'] as $r) {
            $active[$r['journey']] = (int) $r['n'];
        }
        $sent_by = [];
        foreach ($s['by_source'] as $r) {
            $sent_by[$r['source']] = $r;
        }
        $paused = Zooboxi_Push_Engine::paused_sources();
        self::form_open('journeys');
        ?>
        <table class="widefat striped zbp-table">
            <thead><tr><th>الرحلة</th><th>مفعّلة</th><th>الدرجة · الموضوع</th><th>أشخاص بداخلها الآن</th><th>أُرسل / فُتح (30 يومًا)</th><th>الحالة</th></tr></thead>
            <tbody>
            <?php foreach (Zooboxi_Push_Journeys::all() as $key => $j):
                $sb = $sent_by[$j['source']] ?? null;
                $is_paused = in_array($j['source'], $paused, true);
                ?>
                <tr>
                    <td><strong><?php echo esc_html($j['name']); ?></strong><br><small><?php echo esc_html(self::journey_hint($key)); ?></small></td>
                    <td><input type="checkbox" name="journey[<?php echo esc_attr($key); ?>]" <?php checked(Zooboxi_Push_Journeys::enabled($key)); ?>></td>
                    <td><?php echo esc_html(self::tiers()[$j['tier']] . ' · ' . $j['topic']); ?></td>
                    <td><?php echo (int) ($active[$key] ?? 0); ?></td>
                    <td><?php echo $sb ? (int) $sb['sent'] . ' / ' . (int) $sb['opened'] : '—'; ?></td>
                    <td><?php if ($is_paused): ?><span class="zbp-pill off">موقوف تلقائيًا</span><?php else: ?><span class="zbp-pill on">يعمل</span><?php endif; ?></td>
                </tr>
            <?php endforeach; ?>
            <?php foreach ([
                'moments'        => ['لحظات العائلة', 'هدية جاهزة، عيد ميلاد، مستواك في خطر، مهمة على بُعد خطوة — موضوع العائلة، ≤1 أسبوعيًا عمليًا بالسقوف.'],
                'bundles_digest' => ['ملخّص البكجات', 'الخميس 19:00: بكجات هذا الأسبوع لنوع حيوانه — رسالة واحدة، لا رسالة لكل بكج.'],
                'closing_soon'   => ['إكسبريس يغلق خلال ساعة', 'فقط لمن سلة إكسبريس عنده غير فارغة؛ ينتهي مع الإغلاق.'],
                'waitlist'       => ['رجع للمخزون · نزل السعر', 'زر «نبّهني» والمفضلة؛ يُفحَص بعد كل مزامنة مخزون/أسعار.'],
            ] as $k => [$name, $hint]): ?>
                <tr>
                    <td><strong><?php echo esc_html($name); ?></strong><br><small><?php echo esc_html($hint); ?></small></td>
                    <td><input type="checkbox" name="feature[<?php echo esc_attr($k); ?>]" <?php checked(get_option('zooboxi_push_' . $k, 'yes'), 'yes'); ?>></td>
                    <td colspan="4"></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <p><button class="button button-primary">حفظ</button></p>
        </form>
        <?php if ($paused): ?>
            <h2>مصادر موقوفة تلقائيًا</h2>
            <?php foreach ($paused as $src): ?>
                <?php self::form_open('unpause'); ?>
                <input type="hidden" name="source" value="<?php echo esc_attr($src); ?>">
                <p><?php echo esc_html(self::sources()[$src] ?? $src); ?> <button class="button">أعد تشغيله</button></p>
                </form>
            <?php endforeach; ?>
        <?php endif;
    }

    private static function journey_hint(string $key): string
    {
        return [
            'welcome'          => '+24 س بلا حيوان → «عرّفنا على صديقك»؛ +3 أيام بلا طلب → أول طلب؛ +7 أيام رسالة أخيرة. ينتهي بأول طلب.',
            'post_first_order' => '+2 يوم بطاقة خدش مختومة؛ +10 أيام «اطلب مجددًا». ينتهي بالطلب الثاني.',
            'winback'          => 'على موعد العميل المتوقّع: +10 أيام، +45 (هدية أكبر)، +90 رسالة أخيرة ثم صمت. مرة كل 120 يومًا.',
            'supply'           => 'مقياس الطعام: −4 أيام في ساعته الشخصية، ثم −1 يوم. ينتهي بشراء المنتج. مرة/منتج/14 يومًا.',
            'cart'             => 'إكسبريس بعد 45 دقيقة (والفرع مفتوح)، زوبكسي بعد ساعتين؛ ثانٍ واحد بعد 24 س إن كانت السلة ≥100 ﷼.',
            'rating'           => 'إكسبريس بعد 90 دقيقة من التسليم، زوبكسي اليوم التالي 18:00. مرة واحدة.',
        ][$key] ?? '';
    }

    /* ── حملة ────────────────────────────────────────────────────── */

    private static function tab_campaign(): void
    {
        global $wpdb;
        $id = (int) ($_GET['campaign'] ?? 0);
        $c  = $id > 0 ? Zooboxi_Push_Campaigns::get($id) : null;
        $a  = $c['audience'] ?? [];
        $editable = $c === null || $c['status'] === Zooboxi_Push_Campaigns::S_DRAFT;
        $devices = $wpdb->get_results('SELECT id, user_id, guest_id, platform, app_version, last_seen_at FROM ' . Zooboxi_Push::table() . ' ORDER BY last_seen_at DESC LIMIT 50', ARRAY_A) ?: [];
        $tiers = class_exists('Zooboxi_Loyalty_Tiers') ? Zooboxi_Loyalty_Tiers::ladder() : [];
        ?>
        <div class="zbp-cols">
        <div>
        <h2><?php echo $c ? 'حملة #' . (int) $c['id'] : 'حملة جديدة'; ?> <?php if ($c): ?><span class="zbp-pill <?php echo $c['status'] === 'sent' ? 'on' : ''; ?>"><?php echo esc_html($c['status']); ?></span><?php endif; ?></h2>
        <?php self::form_open('campaign_save'); ?>
        <input type="hidden" name="campaign_id" value="<?php echo (int) $id; ?>">
        <fieldset <?php disabled(!$editable); ?>>
        <p><label>الاسم (داخلي)<br><input type="text" name="name" class="regular-text" value="<?php echo esc_attr($c['name'] ?? ''); ?>"></label></p>
        <h3>الجمهور</h3>
        <p>
            <?php foreach (['cat' => 'قطط', 'dog' => 'كلاب', 'bird' => 'طيور', 'small' => 'صغيرة'] as $k => $l): ?>
                <label style="margin-inline-end:12px"><input type="checkbox" name="species[]" value="<?php echo $k; ?>" <?php checked(in_array($k, (array) ($a['species'] ?? []), true)); ?>> <?php echo $l; ?></label>
            <?php endforeach; ?>
        </p>
        <p><label>المدن (افصل بفاصلة)<br><input type="text" name="cities" class="regular-text" value="<?php echo esc_attr(implode('، ', (array) ($a['cities'] ?? []))); ?>" placeholder="الرياض، جدة"></label></p>
        <p><label>طلبوا خلال آخر (أيام؛ 0 = الكل)<br><input type="number" name="last_order_days" min="0" value="<?php echo (int) ($a['last_order_days'] ?? 0); ?>"></label></p>
        <?php if ($tiers): ?>
        <p>المستوى:
            <?php foreach ($tiers as $t): ?>
                <label style="margin-inline-end:12px"><input type="checkbox" name="tiers[]" value="<?php echo esc_attr($t['key']); ?>" <?php checked(in_array($t['key'], (array) ($a['tiers'] ?? []), true)); ?>> <?php echo esc_html($t['name_ar'] ?? $t['key']); ?></label>
            <?php endforeach; ?>
        </p>
        <?php endif; ?>
        <p><label><input type="checkbox" name="guests" <?php checked(!empty($a['guests'])); ?>> شمل الضيوف (بلا حساب) — فقط حين لا توجد فلاتر أخرى</label></p>
        <h3>الرسالة</h3>
        <p><label>العنوان (عربي، ≤30)<br><input type="text" name="title_ar" class="regular-text" maxlength="60" value="<?php echo esc_attr($c['title_ar'] ?? ''); ?>"></label></p>
        <p><label>النص (عربي، ≤100)<br><textarea name="body_ar" class="large-text" rows="2" maxlength="180"><?php echo esc_textarea($c['body_ar'] ?? ''); ?></textarea></label></p>
        <p><label>Title (English)<br><input type="text" name="title_en" class="regular-text" value="<?php echo esc_attr($c['title_en'] ?? ''); ?>"></label></p>
        <p><label>Body (English)<br><textarea name="body_en" class="large-text" rows="2"><?php echo esc_textarea($c['body_en'] ?? ''); ?></textarea></label></p>
        <p><label>الوجهة في التطبيق<br><input type="text" name="route" class="regular-text" value="<?php echo esc_attr($c['route'] ?? '/home'); ?>" placeholder="/bundles أو /product/123 أو /brand/applaws"></label></p>
        <p><label>صورة (https)<br><input type="url" name="image_url" class="regular-text" value="<?php echo esc_attr($c['image_url'] ?? ''); ?>"></label></p>
        <p><label>الموضوع
            <select name="topic">
                <?php foreach (['offers' => 'العروض', 'family' => 'العائلة', 'reorder' => 'إعادة الطلب'] as $k => $l): ?>
                    <option value="<?php echo $k; ?>" <?php selected(($c['topic'] ?? 'offers'), $k); ?>><?php echo $l; ?></option>
                <?php endforeach; ?>
            </select></label></p>
        <h3>التوقيت</h3>
        <p><label>موعد (بتوقيت الرياض، فارغ = الآن)<br><input type="datetime-local" name="schedule_at" value="<?php echo esc_attr(!empty($c['schedule_at']) ? (new \DateTimeImmutable('@' . Zooboxi_Push_Engine::ts($c['schedule_at'])))->setTimezone(Zooboxi_Push_Gate::tz())->format('Y-m-d\TH:i') : ''); ?>"></label></p>
        <p><label><input type="checkbox" name="sto" <?php checked($c === null || !empty($c['sto'])); ?>> بالتوقيت الشخصي لكل عميل (داخل نافذة التسويق)</label></p>
        <p><label><input type="checkbox" name="dry_run" <?php checked(!empty($c['dry_run'])); ?>> تجربة جافة — تُكتب الصفوف ولا يُرسَل شيء</label></p>
        </fieldset>
        <?php if ($editable): ?><p><button class="button button-primary">حفظ المسودة وحساب الجمهور</button></p><?php endif; ?>
        </form>

        <?php if ($c && $editable): ?>
            <hr>
            <p><strong>الجمهور المحسوب:</strong> <?php echo number_format_i18n((int) $c['audience_count']); ?> شخص
                <?php if ((int) $c['audience_count'] > Zooboxi_Push_Campaigns::WARN_AUDIENCE): ?> <span class="zbp-pill off">كبير — راجعه</span><?php endif; ?></p>
            <?php self::form_open('campaign_canary'); ?>
            <input type="hidden" name="campaign_id" value="<?php echo (int) $c['id']; ?>">
            <p>
                <select name="device">
                    <?php foreach ($devices as $d):
                        $who = (int) $d['user_id'] > 0 ? (($u = get_userdata((int) $d['user_id'])) ? $u->user_login : '#' . $d['user_id']) : 'ضيف ' . substr((string) $d['guest_id'], 0, 8); ?>
                        <option value="<?php echo (int) $d['id']; ?>"><?php echo esc_html($who . ' · ' . $d['platform'] . ' · ' . $d['last_seen_at']); ?></option>
                    <?php endforeach; ?>
                </select>
                <button class="button">أرسل نسخة تجريبية لهذا الجهاز</button>
            </p>
            </form>
            <?php self::form_open('campaign_approve'); ?>
            <input type="hidden" name="campaign_id" value="<?php echo (int) $c['id']; ?>">
            <p><button class="button button-primary" onclick="return confirm('اعتماد الحملة وإرسالها إلى <?php echo (int) $c['audience_count']; ?> شخص عبر الحارس؟')">اعتمد وأرسل</button>
               <small>تمرّ كل رسالة بالحارس: ساعات الهدوء، السقوف، الضابطة، والتوقيت الشخصي.</small></p>
            </form>
        <?php elseif ($c && $c['status'] !== 'cancelled'): ?>
            <?php self::form_open('campaign_cancel'); ?>
            <input type="hidden" name="campaign_id" value="<?php echo (int) $c['id']; ?>">
            <p>في الطابور: <?php echo (int) $c['queued']; ?> · اعتمدها <?php echo esc_html($c['approved_by']); ?> <button class="button">ألغِ ما لم يُرسَل بعد</button></p>
            </form>
        <?php endif; ?>
        </div>
        <div>
            <h2>الحملات</h2>
            <table class="widefat striped zbp-table">
                <thead><tr><th>#</th><th>الاسم</th><th>الحالة</th><th>الجمهور</th><th>الطابور</th><th>أُنشئت</th></tr></thead>
                <tbody>
                <?php foreach (Zooboxi_Push_Campaigns::recent() as $r): ?>
                    <tr>
                        <td><a href="<?php echo esc_url(admin_url('admin.php?page=' . self::SLUG . '&tab=campaign&campaign=' . (int) $r['id'])); ?>">#<?php echo (int) $r['id']; ?></a></td>
                        <td><?php echo esc_html($r['name'] ?: $r['title_ar']); ?></td>
                        <td><?php echo esc_html($r['status']); ?><?php echo !empty($r['dry_run']) ? ' (جافة)' : ''; ?></td>
                        <td><?php echo (int) $r['audience_count']; ?></td><td><?php echo (int) $r['queued']; ?></td>
                        <td><?php echo esc_html($r['created_at']); ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
            <p><a class="button" href="<?php echo esc_url(admin_url('admin.php?page=' . self::SLUG . '&tab=campaign')); ?>">حملة جديدة</a></p>
        </div>
        </div>
        <?php
    }

    /* ── السجل ───────────────────────────────────────────────────── */

    private static function tab_log(): void
    {
        global $wpdb;
        $rows = $wpdb->get_results('SELECT id, user_id, guest_id, tier, topic, source, status, reason, title_ar, not_before, sent_at, opened_at, created_at FROM '
            . Zooboxi_Push_Engine::outbox() . ' ORDER BY id DESC LIMIT 200', ARRAY_A) ?: [];
        $tz = Zooboxi_Push_Gate::tz();
        $fmt = function ($v) use ($tz) {
            $t = Zooboxi_Push_Engine::ts($v);
            return $t > 0 ? (new \DateTimeImmutable('@' . $t))->setTimezone($tz)->format('m-d H:i') : '—';
        };
        ?>
        <table class="widefat striped zbp-table">
            <thead><tr><th>#</th><th>الشخص</th><th>المصدر</th><th>الدرجة</th><th>العنوان</th><th>الحالة</th><th>السبب</th><th>لا قبل</th><th>أُرسل</th><th>فُتح</th></tr></thead>
            <tbody>
            <?php foreach ($rows as $r):
                $who = (int) $r['user_id'] > 0 ? (($u = get_userdata((int) $r['user_id'])) ? $u->user_login : '#' . $r['user_id']) : 'ضيف ' . substr((string) $r['guest_id'], 0, 6); ?>
                <tr>
                    <td><?php echo (int) $r['id']; ?></td><td><?php echo esc_html($who); ?></td>
                    <td><?php echo esc_html(self::sources()[$r['source']] ?? $r['source']); ?></td>
                    <td><?php echo esc_html(self::tiers()[$r['tier']] ?? $r['tier']); ?></td>
                    <td><?php echo esc_html(mb_substr((string) $r['title_ar'], 0, 40)); ?></td>
                    <td><?php echo esc_html(self::statuses()[$r['status']] ?? $r['status']); ?></td>
                    <td><?php echo esc_html(self::reasons()[$r['reason']] ?? $r['reason']); ?></td>
                    <td><?php echo esc_html($fmt($r['not_before'])); ?></td><td><?php echo esc_html($fmt($r['sent_at'])); ?></td><td><?php echo esc_html($fmt($r['opened_at'])); ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <?php
    }

    /* ── الإعدادات ───────────────────────────────────────────────── */

    private static function tab_settings(): void
    {
        $g = Zooboxi_Push_Gate::defaults();
        $w = Zooboxi_Push_Windows::defaults();
        $field = function (string $key, string $label, $placeholder, string $type = 'text') {
            printf(
                '<label class="zbp-field"><span>%s</span><input type="%s" name="zooboxi_push_%s" value="%s" placeholder="%s"></label>',
                esc_html($label), esc_attr($type), esc_attr($key), esc_attr((string) get_option('zooboxi_push_' . $key, '')), esc_attr((string) $placeholder)
            );
        };
        self::form_open('settings');
        ?>
        <h2>المحرك</h2>
        <p><label><input type="checkbox" name="zooboxi_push_engine_enabled" <?php checked(Zooboxi_Push_Engine::engine_enabled()); ?>> تشغيل حارس البوابة والرحلات (إيقافه يترك حالات الطلب والمندوب تعمل)</label></p>
        <h2>النوافذ (بتوقيت الرياض؛ فارغ = الافتراضي)</h2>
        <div class="zbp-grid">
            <?php $field('quiet_start', 'هدوء من', $g['quiet_start']); $field('quiet_end', 'هدوء حتى', $g['quiet_end']);
                  $field('marketing_start', 'تسويق من', $g['marketing_start']); $field('marketing_end', 'تسويق حتى', $g['marketing_end']);
                  $field('friday_pause_start', 'هدنة الجمعة من', $g['friday_pause_start']); $field('friday_pause_end', 'هدنة الجمعة حتى', $g['friday_pause_end']); ?>
        </div>
        <h2>السقوف</h2>
        <div class="zbp-grid">
            <?php $field('marketing_per_day', 'تسويق / يوم', $g['marketing_per_day'], 'number'); $field('marketing_per_week', 'تسويق / أسبوع', $g['marketing_per_week'], 'number');
                  $field('marketing_gap_h', 'فجوة التسويق (ساعات)', $g['marketing_gap_h'], 'number'); $field('service_per_day', 'خدمة / يوم', $g['service_per_day'], 'number');
                  $field('service_gap_h', 'فجوة الخدمة (ساعات)', $g['service_gap_h'], 'number'); $field('total_per_day', 'الكل / يوم', $g['total_per_day'], 'number');
                  $field('total_per_week', 'الكل / أسبوع', $g['total_per_week'], 'number'); $field('repeat_days', 'لا تكرار للنص (أيام)', $g['repeat_days'], 'number'); ?>
        </div>
        <h2>الأذان</h2>
        <p><label><input type="checkbox" name="zooboxi_push_adhan" <?php checked(Zooboxi_Push_Windows::opt('adhan'), 'yes'); ?>> توقّف التسويق حول الأذان (مواقيت يومية من AlAdhan، أم القرى)</label></p>
        <div class="zbp-grid">
            <?php $field('adhan_minutes', '± دقائق', $w['adhan_minutes'], 'number'); $field('adhan_lat', 'خط العرض', $w['adhan_lat']); $field('adhan_lng', 'خط الطول', $w['adhan_lng']); ?>
        </div>
        <h2>وضع رمضان</h2>
        <p class="description">حدّد تاريخي البداية والنهاية ليتبدّل اليوم: تسويق مساءً بعد الإفطار، وخانة سحور لتذكير الطعام لعملاء إكسبريس فقط، والبقية هدوء.</p>
        <div class="zbp-grid">
            <?php $field('ramadan_from', 'من (Y-m-d)', '2027-02-08'); $field('ramadan_to', 'إلى (Y-m-d)', '2027-03-09');
                  $field('ramadan_start', 'تسويق من', $w['ramadan_start']); $field('ramadan_end', 'تسويق حتى', $w['ramadan_end']);
                  $field('suhoor_start', 'سحور من', $w['suhoor_start']); $field('suhoor_end', 'سحور حتى', $w['suhoor_end']); ?>
        </div>
        <p><button class="button button-primary">حفظ</button></p>
        </form>
        <?php
    }

    private static function styles(): void
    {
        ?>
        <style>
            .zbp .zbp-tabs{display:flex;gap:8px;margin:12px 0 18px;flex-wrap:wrap}
            .zbp .zbp-tabs a{padding:6px 14px;border:1px solid #c3c4c7;border-radius:8px;background:#fff;text-decoration:none;color:#1d2327}
            .zbp .zbp-tabs a.active{background:#429d9c;border-color:#429d9c;color:#fff}
            .zbp .zbp-pill{display:inline-block;font-size:12px;padding:2px 10px;border-radius:999px;background:#eee;color:#333;font-weight:600}
            .zbp .zbp-pill.on{background:#ddf0e3;color:#2f6f45}.zbp .zbp-pill.off{background:#f8e3de;color:#a63d2b}
            .zbp .zbp-range a{margin-inline-end:10px}.zbp .zbp-range a.active{font-weight:700;text-decoration:none}
            .zbp .zbp-tiles{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:10px;margin:10px 0 22px}
            .zbp .zbp-tile{background:#fff;border:1px solid #dcdcde;border-radius:10px;padding:12px 14px}
            .zbp .zbp-tile b{display:block;font-size:24px;line-height:1.1}.zbp .zbp-tile span{font-size:12px;color:#646970}
            .zbp .zbp-table{max-width:1100px}.zbp .zbp-table td,.zbp .zbp-table th{text-align:right}
            .zbp .zbp-reasons span{display:inline-block;background:#fff;border:1px solid #dcdcde;border-radius:8px;padding:3px 10px;margin:0 0 6px 6px;font-size:12px}
            .zbp .zbp-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:8px 14px;max-width:900px}
            .zbp .zbp-field{display:flex;flex-direction:column;gap:2px;font-size:12px}.zbp .zbp-field input{width:100%}
            .zbp .zbp-cols{display:grid;grid-template-columns:1.2fr 1fr;gap:28px;max-width:1200px}
            @media(max-width:1000px){.zbp .zbp-cols{grid-template-columns:1fr}}
        </style>
        <?php
    }
}
