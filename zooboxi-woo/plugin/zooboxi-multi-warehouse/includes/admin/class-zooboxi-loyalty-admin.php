<?php
/**
 * Zooboxi_Loyalty_Admin — one tabbed screen for «عائلة زوبوكسي».
 *
 * WHY EVERYTHING IS A SETTING: the spec's binding rule is that no number in this
 * program may need a deploy to change. Points per riyal, the paw's assumed cost, the
 * expiry window, the holdout share, the tier thresholds, the prize weights and every
 * mission reward are all edited here — the code only decides SHAPE, never VALUE.
 *
 * The metrics tab exists to keep us honest: the program's monthly cost is shown against
 * real sales and against the 4% ceiling, and the baseline box shows what the store was
 * already doing before any of this existed.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Admin
{
    public const SLUG = 'zooboxi-loyalty';
    private const CAP = 'manage_woocommerce';

    private const TABS = [
        'general'  => ['⚙️', 'عام'],
        'rewards'  => ['🎁', 'الهدايا'],
        'scratch'  => ['🃏', 'اخدش واربح'],
        'missions' => ['🎯', 'المهمات'],
        'habit'    => ['🔁', 'العادة'],
        'stamps'   => ['🏷️', 'بطاقات الماركات'],
        'metrics'  => ['📊', 'المؤشرات'],
        'member'   => ['🔎', 'بحث عن عضو'],
    ];

    public function register_hooks(): void
    {
        add_action('admin_menu', [$this, 'register_menu'], 20);
        add_action('admin_enqueue_scripts', [$this, 'enqueue']);
    }

    public function register_menu(): void
    {
        add_submenu_page(
            'zooboxi',
            __('عائلة زوبوكسي', 'zooboxi'),
            __('🐾 عائلة زوبوكسي', 'zooboxi'),
            self::CAP,
            self::SLUG,
            [__CLASS__, 'render']
        );
    }

    /** WooCommerce's own product search widget powers the gift picker. */
    public function enqueue($hook): void
    {
        if (!is_string($hook) || strpos($hook, self::SLUG) === false) {
            return;
        }
        wp_enqueue_script('wc-enhanced-select');
        wp_enqueue_style('woocommerce_admin_styles');
    }

    /* ══════════════════════════════════════════════════════════════
       RENDER
       ══════════════════════════════════════════════════════════════ */

    public static function render(): void
    {
        if (!current_user_can(self::CAP)) {
            wp_die(esc_html__('لا تملك صلاحية الوصول', 'zooboxi'));
        }

        Zooboxi_Loyalty_Schema::maybe_install();

        $notice = self::handle_post();
        $tab    = isset($_GET['tab']) ? sanitize_key(wp_unslash($_GET['tab'])) : 'general';
        if (!isset(self::TABS[$tab])) {
            $tab = 'general';
        }

        self::styles();
        ?>
        <div class="wrap zbl">
            <div class="zbl-hero">
                <div class="zbl-hero__logo">🐾</div>
                <div>
                    <h1><?php esc_html_e('عائلة زوبوكسي', 'zooboxi'); ?></h1>
                    <p><?php esc_html_e('البصمات والمستويات والهدايا والمهمات — كل رقم في البرنامج يُضبط من هنا بلا نشر.', 'zooboxi'); ?></p>
                </div>
            </div>

            <?php if ($notice !== ''): ?>
                <div class="zbl-saved">✓ <?php echo esc_html($notice); ?></div>
            <?php endif; ?>

            <?php if (Zooboxi_Loyalty::opt('enabled') !== 'yes'): ?>
                <div class="zbl-warn">⚠️ <?php esc_html_e('البرنامج معطّل حالياً — لا تُمنح بصمات ولا بطاقات، والمتجر يعمل كما لو أن الوحدة غير موجودة.', 'zooboxi'); ?></div>
            <?php endif; ?>

            <nav class="zbl-tabs">
                <?php foreach (self::TABS as $key => $meta): ?>
                    <a class="zbl-tab<?php echo $key === $tab ? ' is-active' : ''; ?>"
                       href="<?php echo esc_url(admin_url('admin.php?page=' . self::SLUG . '&tab=' . $key)); ?>">
                        <span><?php echo esc_html($meta[0]); ?></span> <?php echo esc_html($meta[1]); ?>
                    </a>
                <?php endforeach; ?>
            </nav>

            <?php
            switch ($tab) {
                case 'rewards':
                    self::tab_rewards();
                    break;
                case 'scratch':
                    self::tab_scratch();
                    break;
                case 'missions':
                    self::tab_missions();
                    break;
                case 'habit':
                    self::tab_habit();
                    break;
                case 'stamps':
                    self::tab_stamps();
                    break;
                case 'metrics':
                    self::tab_metrics();
                    break;
                case 'member':
                    self::tab_member();
                    break;
                default:
                    self::tab_general();
            }
            ?>
        </div>
        <?php
    }

    /* ══════════════════════════════════════════════════════════════
       POST HANDLERS
       ══════════════════════════════════════════════════════════════ */

    /** @return string a human confirmation, '' when nothing was saved */
    private static function handle_post(): string
    {
        if (empty($_POST['zbl_action']) || !current_user_can(self::CAP)) {
            return '';
        }
        $action = sanitize_key(wp_unslash($_POST['zbl_action']));
        if (!check_admin_referer('zbl_' . $action)) {
            return '';
        }

        switch ($action) {
            case 'general':
                return self::save_general();
            case 'reward_save':
                return self::save_reward();
            case 'reward_toggle':
                return self::toggle_reward();
            case 'scratch':
                return self::save_scratch();
            case 'missions':
                return self::save_missions();
            case 'habit':
                return self::save_habit();
            case 'referral_decide':
                return self::decide_referral();
            case 'stamp_save':
                return self::save_stamp_program();
            case 'stamp_toggle':
                $id = absint($_POST['program_id'] ?? 0);
                Zooboxi_Loyalty_Stamps::toggle($id, !empty($_POST['active']));
                return __('تم تحديث البرنامج', 'zooboxi');
            case 'habit_daily':
                $r = Zooboxi_Loyalty_Moments::run_daily();
                return sprintf(__('تم تشغيل مهام العادة: تذكيرات %d · إحالات %d · أعياد ميلاد %d · استرجاع %d', 'zooboxi'), (int) $r['sub_reminders'], (int) $r['referrals_paid'], (int) $r['birthdays'], (int) $r['winbacks']);
            case 'adjust':
                return self::save_adjust();
            case 'baseline':
                Zooboxi_Loyalty::baseline(true);
                return __('تم تحديث خط الأساس', 'zooboxi');
            case 'seed':
                $seed = Zooboxi_Loyalty_Schema::seed_defaults();
                return sprintf(__('تمت إضافة %d مكافأة افتراضية', 'zooboxi'), (int) $seed['created']);
        }
        return '';
    }

    private static function save_general(): string
    {
        $post = wp_unslash($_POST);

        update_option('zooboxi_loyalty_enabled', !empty($post['enabled']) ? 'yes' : 'no');
        update_option('zooboxi_loyalty_scratch_enabled', !empty($post['scratch_enabled']) ? 'yes' : 'no');
        update_option('zooboxi_loyalty_missions_enabled', !empty($post['missions_enabled']) ? 'yes' : 'no');

        $numbers = [
            'points_per_riyal' => 'float',
            'paw_value_sar'    => 'float',
            'expiry_months'    => 'int',
            'holdout_pct'      => 'int',
            'max_pets'         => 'int',
            'budget_pct'       => 'float',
            'star_free_min'    => 'float',
            'profile_paws'     => 'int',
            'pet_paws'         => 'int',
        ];
        foreach ($numbers as $key => $type) {
            if (!isset($post[$key])) {
                continue;
            }
            $value = $type === 'int' ? absint($post[$key]) : (float) $post[$key];
            update_option('zooboxi_loyalty_' . $key, $value);
        }

        // Tier thresholds.
        $tiers = [];
        foreach (Zooboxi_Loyalty_Tiers::ORDER as $key) {
            $tiers[$key] = isset($post['tier_' . $key]) ? absint($post['tier_' . $key]) : Zooboxi_Loyalty_Tiers::DEFAULT_MINS[$key];
        }
        update_option('zooboxi_loyalty_tiers', wp_json_encode($tiers));

        // species → product_cat slug, one `species=slug` pair per line.
        $map = [];
        foreach (preg_split('/\r\n|\r|\n/', (string) ($post['species_categories'] ?? '')) as $line) {
            $line = trim($line);
            if ($line === '' || strpos($line, '=') === false) {
                continue;
            }
            [$species, $slug] = array_map('trim', explode('=', $line, 2));
            $species = sanitize_key($species);
            $slug    = sanitize_title($slug);
            if ($species !== '' && $slug !== '' && in_array($species, Zooboxi_Loyalty_Pets::SPECIES, true)) {
                $map[$species] = $slug;
            }
        }
        update_option('zooboxi_loyalty_species_categories', wp_json_encode($map));

        // This request is about to re-render the page from these very options.
        Zooboxi_Loyalty::flush_state();

        return __('تم حفظ الإعدادات', 'zooboxi');
    }

    private static function save_reward(): string
    {
        global $wpdb;
        $post = wp_unslash($_POST);

        $kind = sanitize_key($post['kind'] ?? 'gift_product');
        if (!in_array($kind, Zooboxi_Loyalty_Rewards::KINDS, true)) {
            $kind = 'gift_product';
        }

        $data = [
            'kind'          => $kind,
            'reward_key'    => mb_substr(sanitize_key($post['reward_key'] ?? ''), 0, 32),
            'title_ar'      => mb_substr(sanitize_text_field($post['title_ar'] ?? ''), 0, 120),
            'title_en'      => mb_substr(sanitize_text_field($post['title_en'] ?? ''), 0, 120),
            'desc_ar'       => mb_substr(sanitize_textarea_field($post['desc_ar'] ?? ''), 0, 240),
            'desc_en'       => mb_substr(sanitize_textarea_field($post['desc_en'] ?? ''), 0, 240),
            'product_id'    => absint($post['product_id'] ?? 0) ?: null,
            'variation_id'  => absint($post['variation_id'] ?? 0) ?: null,
            'paws_cost'     => absint($post['paws_cost'] ?? 0),
            'cost_sar'      => (float) ($post['cost_sar'] ?? 0),
            'value_sar'     => (float) ($post['value_sar'] ?? 0),
            'validity_days' => max(1, absint($post['validity_days'] ?? 21)),
            'min_tier'      => in_array($post['min_tier'] ?? '', Zooboxi_Loyalty_Tiers::ORDER, true) ? sanitize_key($post['min_tier']) : '',
            'monthly_cap'   => ($post['monthly_cap'] ?? '') === '' ? null : absint($post['monthly_cap']),
            'is_active'     => !empty($post['is_active']) ? 1 : 0,
            'sort'          => absint($post['sort'] ?? 0),
            'updated_at'    => Zooboxi_Loyalty::now(),
        ];

        // A WC product search field can return a variation id in `product_id`.
        if ($data['product_id'] && function_exists('wc_get_product')) {
            $product = wc_get_product((int) $data['product_id']);
            if ($product instanceof \WC_Product_Variation) {
                $data['variation_id'] = (int) $product->get_id();
                $data['product_id']   = (int) $product->get_parent_id();
            }
        }
        if ($data['reward_key'] === '') {
            $data['reward_key'] = 'r' . substr(md5($data['title_en'] . $data['title_ar'] . microtime(true)), 0, 10);
        }

        $id = absint($post['reward_id'] ?? 0);
        if ($id > 0) {
            $wpdb->update(Zooboxi_Loyalty_Schema::rewards(), $data, ['id' => $id]);
            return __('تم تحديث المكافأة', 'zooboxi');
        }

        $data['created_at'] = Zooboxi_Loyalty::now();
        $wpdb->insert(Zooboxi_Loyalty_Schema::rewards(), $data);
        return __('تمت إضافة المكافأة', 'zooboxi');
    }

    /** Rewards are never deleted — a redeemed grant must keep its meaning. */
    private static function toggle_reward(): string
    {
        global $wpdb;
        $id = absint($_POST['reward_id'] ?? 0);
        if ($id <= 0) {
            return '';
        }
        $reward = Zooboxi_Loyalty_Rewards::reward($id);
        if ($reward === null) {
            return '';
        }
        $wpdb->update(
            Zooboxi_Loyalty_Schema::rewards(),
            ['is_active' => (int) $reward['is_active'] === 1 ? 0 : 1, 'updated_at' => Zooboxi_Loyalty::now()],
            ['id' => $id],
            ['%d', '%s'],
            ['%d']
        );
        return __('تم تغيير حالة المكافأة', 'zooboxi');
    }

    private static function save_scratch(): string
    {
        $post   = wp_unslash($_POST);
        $kinds  = (array) ($post['row_kind'] ?? []);
        $paws   = (array) ($post['row_paws'] ?? []);
        $reward = (array) ($post['row_reward'] ?? []);
        $weight = (array) ($post['row_weight'] ?? []);

        $table = [];
        foreach ($kinds as $i => $kind) {
            $kind = sanitize_key($kind);
            $w    = (float) ($weight[$i] ?? 0);
            if ($w <= 0) {
                continue;
            }
            if ($kind === 'paws') {
                $p = absint($paws[$i] ?? 0);
                if ($p > 0) {
                    $table[] = ['kind' => 'paws', 'paws' => $p, 'weight' => $w];
                }
            } elseif ($kind === 'reward') {
                $r = absint($reward[$i] ?? 0);
                if ($r > 0) {
                    $table[] = ['kind' => 'reward', 'reward_id' => $r, 'weight' => $w];
                }
            }
        }

        update_option('zooboxi_loyalty_scratch_table', wp_json_encode($table));
        return __('تم حفظ جدول الجوائز', 'zooboxi');
    }

    private static function save_missions(): string
    {
        $post = wp_unslash($_POST);
        $out  = [];

        foreach (array_keys(Zooboxi_Loyalty_Missions::TEMPLATES) as $key) {
            $row = [
                'enabled'     => !empty($post['m_enabled'][$key]),
                'reward_kind' => (($post['m_kind'][$key] ?? 'paws') === 'reward') ? 'reward' : 'paws',
                'reward_paws' => absint($post['m_paws'][$key] ?? 0),
                'reward_id'   => absint($post['m_reward'][$key] ?? 0),
            ];
            if ($key === 'frequency' && isset($post['m_target'][$key])) {
                $row['target'] = absint($post['m_target'][$key]);
            }
            $out[$key] = $row;
        }

        update_option('zooboxi_loyalty_missions', wp_json_encode($out));
        return __('تم حفظ إعدادات المهمات', 'zooboxi');
    }

    private static function save_adjust(): string
    {
        $user_id = absint($_POST['user_id'] ?? 0);
        $delta   = (int) ($_POST['delta'] ?? 0);
        $note    = mb_substr(sanitize_text_field(wp_unslash($_POST['note'] ?? '')), 0, 200);

        if ($user_id <= 0 || $delta === 0) {
            return '';
        }
        if ($note === '') {
            return __('التعديل اليدوي يحتاج ملاحظة توضّح السبب', 'zooboxi');
        }

        // ref_id = the moment of the adjustment, so the ledger's UNIQUE key never
        // collapses two different manual corrections into one.
        Zooboxi_Loyalty_Ledger::add($user_id, $delta, 'adjust', 'admin', time(), $note);

        return sprintf(__('تم تعديل رصيد العضو %d بمقدار %d', 'zooboxi'), $user_id, $delta);
    }

    /* ══════════════════════════════════════════════════════════════
       TABS
       ══════════════════════════════════════════════════════════════ */

    private static function tab_general(): void
    {
        $map_lines = [];
        foreach (Zooboxi_Loyalty::opt_json('species_categories', []) as $species => $slug) {
            $map_lines[] = $species . '=' . $slug;
        }
        ?>
        <form method="post" class="zbl-card">
            <?php wp_nonce_field('zbl_general'); ?>
            <input type="hidden" name="zbl_action" value="general">

            <h2><?php esc_html_e('التشغيل', 'zooboxi'); ?></h2>
            <label class="zbl-check"><input type="checkbox" name="enabled" value="1" <?php checked(Zooboxi_Loyalty::opt('enabled'), 'yes'); ?>> <?php esc_html_e('تفعيل برنامج عائلة زوبوكسي', 'zooboxi'); ?></label>
            <label class="zbl-check"><input type="checkbox" name="scratch_enabled" value="1" <?php checked(Zooboxi_Loyalty::opt('scratch_enabled'), 'yes'); ?>> <?php esc_html_e('تفعيل «اخدش واربح» (طلبات التطبيق فقط)', 'zooboxi'); ?></label>
            <label class="zbl-check"><input type="checkbox" name="missions_enabled" value="1" <?php checked(Zooboxi_Loyalty::opt('missions_enabled'), 'yes'); ?>> <?php esc_html_e('تفعيل مهمات الشهر', 'zooboxi'); ?></label>

            <h2><?php esc_html_e('البصمات', 'zooboxi'); ?></h2>
            <div class="zbl-grid">
                <?php
                self::number_field('points_per_riyal', __('بصمات لكل ريال', 'zooboxi'), __('يُضرب في مجموع السطور بعد الخصم، بلا شحن ولا ضريبة ولا هدايا.', 'zooboxi'), '0.1');
                self::number_field('paw_value_sar', __('تكلفة البصمة (ريال)', 'zooboxi'), __('التقدير المستخدم في حساب تكلفة البرنامج شهرياً.', 'zooboxi'), '0.01');
                self::number_field('expiry_months', __('انتهاء الصلاحية (أشهر خمول)', 'zooboxi'), __('يُصفَّر الرصيد بعد هذه المدة بلا كسب.', 'zooboxi'), '1');
                self::number_field('profile_paws', __('بصمات اكتمال الملف', 'zooboxi'), __('مرة واحدة عند أول حيوان بوزن وتاريخ ميلاد.', 'zooboxi'), '1');
                self::number_field('pet_paws', __('بصمات إضافة حيوان', 'zooboxi'), __('لكل حيوان، حتى الحد الأقصى.', 'zooboxi'), '1');
                self::number_field('max_pets', __('الحد الأقصى للحيوانات', 'zooboxi'), '', '1');
                ?>
            </div>

            <h2><?php esc_html_e('القياس والميزانية', 'zooboxi'); ?></h2>
            <div class="zbl-grid">
                <?php
                self::number_field('holdout_pct', __('نسبة المجموعة الضابطة %', 'zooboxi'), __('لا خدش ولا مهمات لهذه النسبة — بها نقيس أثر البرنامج فعلياً.', 'zooboxi'), '1');
                self::number_field('budget_pct', __('سقف التكلفة من المبيعات %', 'zooboxi'), '', '0.5');
                ?>
            </div>

            <h2><?php esc_html_e('المستويات', 'zooboxi'); ?></h2>
            <p class="zbl-hint"><?php esc_html_e('الحد = عدد الطلبات المكتملة خلال آخر 365 يوماً. star يخفض حد الشحن المجاني، gold يصفّر رسم التوصيل السريع، amb يلغي الحد الأدنى كلياً.', 'zooboxi'); ?></p>
            <div class="zbl-grid">
                <?php
                $ladder = [];
                foreach (Zooboxi_Loyalty_Tiers::ladder() as $tier) {
                    $ladder[$tier['key']] = $tier;
                }
                foreach (Zooboxi_Loyalty_Tiers::ORDER as $key):
                    $tier = $ladder[$key] ?? ['name' => $key, 'min' => 0, 'icon' => ''];
                    ?>
                    <label class="zbl-field">
                        <span><?php echo esc_html($tier['icon'] . ' ' . $tier['name']); ?></span>
                        <input type="number" min="0" name="tier_<?php echo esc_attr($key); ?>" value="<?php echo esc_attr((string) $tier['min']); ?>">
                    </label>
                <?php endforeach; ?>
                <?php self::number_field('star_free_min', __('حد الشحن المجاني لمستوى مميّز', 'zooboxi'), '', '1'); ?>
            </div>

            <h2><?php esc_html_e('نوع الحيوان ← تصنيف مقترح', 'zooboxi'); ?></h2>
            <p class="zbl-hint"><?php esc_html_e('سطر لكل نوع بالصيغة species=category-slug — يُستخدم في مهمة «جرّب تصنيفاً». الأنواع: cat, dog, bird, fish, small, reptile, other', 'zooboxi'); ?></p>
            <textarea name="species_categories" rows="5" class="zbl-textarea" placeholder="cat=wet-food-cats"><?php echo esc_textarea(implode("\n", $map_lines)); ?></textarea>

            <p><button type="submit" class="button button-primary button-large"><?php esc_html_e('حفظ', 'zooboxi'); ?></button></p>
        </form>
        <?php
    }

    private static function tab_rewards(): void
    {
        $edit_id = isset($_GET['reward']) ? absint($_GET['reward']) : 0;
        $editing = $edit_id > 0 ? Zooboxi_Loyalty_Rewards::reward($edit_id) : null;
        $rows    = Zooboxi_Loyalty_Rewards::catalog(false);
        ?>
        <div class="zbl-card">
            <h2><?php esc_html_e('كتالوج الهدايا', 'zooboxi'); ?></h2>
            <?php if (empty($rows)): ?>
                <p><?php esc_html_e('الكتالوج فارغ.', 'zooboxi'); ?></p>
                <form method="post" style="display:inline">
                    <?php wp_nonce_field('zbl_seed'); ?>
                    <input type="hidden" name="zbl_action" value="seed">
                    <button class="button button-primary"><?php esc_html_e('ازرع الكتالوج الافتراضي', 'zooboxi'); ?></button>
                </form>
            <?php else: ?>
                <table class="widefat striped zbl-table">
                    <thead><tr>
                        <th><?php esc_html_e('العنوان', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('النوع', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('المنتج', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('البصمات', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('التكلفة', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('الصلاحية', 'zooboxi'); ?></th>
                        <th><?php esc_html_e('الحالة', 'zooboxi'); ?></th>
                        <th></th>
                    </tr></thead>
                    <tbody>
                    <?php foreach ($rows as $row):
                        $product = Zooboxi_Loyalty_Rewards::reward_product($row); ?>
                        <tr>
                            <td><strong><?php echo esc_html($row['title_ar']); ?></strong><br><code><?php echo esc_html($row['reward_key']); ?></code></td>
                            <td><?php echo esc_html(self::kind_label((string) $row['kind'])); ?></td>
                            <td><?php
                                if ((string) $row['kind'] !== 'gift_product') {
                                    echo '—';
                                } elseif ($product) {
                                    echo esc_html($product->get_name());
                                } else {
                                    echo '<span style="color:#b32d2e">' . esc_html__('لم يُربط منتج', 'zooboxi') . '</span>';
                                }
                            ?></td>
                            <td><?php echo esc_html((string) (int) $row['paws_cost']); ?></td>
                            <td><?php echo esc_html(number_format((float) $row['cost_sar'], 2)); ?></td>
                            <td><?php echo esc_html((string) (int) $row['validity_days']); ?> <?php esc_html_e('يوم', 'zooboxi'); ?></td>
                            <td><?php echo (int) $row['is_active'] === 1 ? '✅' : '⛔'; ?></td>
                            <td>
                                <a class="button button-small" href="<?php echo esc_url(admin_url('admin.php?page=' . self::SLUG . '&tab=rewards&reward=' . (int) $row['id'])); ?>"><?php esc_html_e('تعديل', 'zooboxi'); ?></a>
                                <form method="post" style="display:inline">
                                    <?php wp_nonce_field('zbl_reward_toggle'); ?>
                                    <input type="hidden" name="zbl_action" value="reward_toggle">
                                    <input type="hidden" name="reward_id" value="<?php echo (int) $row['id']; ?>">
                                    <button class="button button-small"><?php echo (int) $row['is_active'] === 1 ? esc_html__('تعطيل', 'zooboxi') : esc_html__('تفعيل', 'zooboxi'); ?></button>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>

        <form method="post" class="zbl-card">
            <?php wp_nonce_field('zbl_reward_save'); ?>
            <input type="hidden" name="zbl_action" value="reward_save">
            <input type="hidden" name="reward_id" value="<?php echo (int) ($editing['id'] ?? 0); ?>">

            <h2><?php echo $editing ? esc_html__('تعديل مكافأة', 'zooboxi') : esc_html__('مكافأة جديدة', 'zooboxi'); ?></h2>
            <div class="zbl-grid">
                <label class="zbl-field">
                    <span><?php esc_html_e('النوع', 'zooboxi'); ?></span>
                    <select name="kind">
                        <?php foreach (Zooboxi_Loyalty_Rewards::KINDS as $kind): ?>
                            <option value="<?php echo esc_attr($kind); ?>" <?php selected($editing['kind'] ?? '', $kind); ?>><?php echo esc_html(self::kind_label($kind)); ?></option>
                        <?php endforeach; ?>
                    </select>
                </label>
                <label class="zbl-field"><span><?php esc_html_e('المفتاح', 'zooboxi'); ?></span><input type="text" name="reward_key" value="<?php echo esc_attr($editing['reward_key'] ?? ''); ?>"></label>
                <label class="zbl-field"><span><?php esc_html_e('العنوان (عربي)', 'zooboxi'); ?></span><input type="text" name="title_ar" value="<?php echo esc_attr($editing['title_ar'] ?? ''); ?>" required></label>
                <label class="zbl-field"><span><?php esc_html_e('العنوان (إنجليزي)', 'zooboxi'); ?></span><input type="text" name="title_en" value="<?php echo esc_attr($editing['title_en'] ?? ''); ?>"></label>
                <label class="zbl-field"><span><?php esc_html_e('تكلفة البصمات', 'zooboxi'); ?></span><input type="number" min="0" name="paws_cost" value="<?php echo esc_attr((string) ($editing['paws_cost'] ?? 0)); ?>"></label>
                <label class="zbl-field"><span><?php esc_html_e('تكلفتنا (ريال)', 'zooboxi'); ?></span><input type="number" step="0.01" min="0" name="cost_sar" value="<?php echo esc_attr((string) ($editing['cost_sar'] ?? 0)); ?>"></label>
                <label class="zbl-field"><span><?php esc_html_e('القيمة المدرَكة (ريال)', 'zooboxi'); ?></span><input type="number" step="0.01" min="0" name="value_sar" value="<?php echo esc_attr((string) ($editing['value_sar'] ?? 0)); ?>"></label>
                <label class="zbl-field"><span><?php esc_html_e('الصلاحية (أيام)', 'zooboxi'); ?></span><input type="number" min="1" name="validity_days" value="<?php echo esc_attr((string) ($editing['validity_days'] ?? 21)); ?>"></label>
                <label class="zbl-field">
                    <span><?php esc_html_e('أقل مستوى', 'zooboxi'); ?></span>
                    <select name="min_tier">
                        <option value=""><?php esc_html_e('الجميع', 'zooboxi'); ?></option>
                        <?php foreach (Zooboxi_Loyalty_Tiers::ladder() as $tier): ?>
                            <option value="<?php echo esc_attr($tier['key']); ?>" <?php selected($editing['min_tier'] ?? '', $tier['key']); ?>><?php echo esc_html($tier['name']); ?></option>
                        <?php endforeach; ?>
                    </select>
                </label>
                <label class="zbl-field"><span><?php esc_html_e('سقف شهري (فارغ = بلا سقف)', 'zooboxi'); ?></span><input type="number" min="0" name="monthly_cap" value="<?php echo esc_attr($editing['monthly_cap'] === null ? '' : (string) $editing['monthly_cap']); ?>"></label>
                <label class="zbl-field"><span><?php esc_html_e('الترتيب', 'zooboxi'); ?></span><input type="number" name="sort" value="<?php echo esc_attr((string) ($editing['sort'] ?? 0)); ?>"></label>
            </div>

            <label class="zbl-field zbl-field--wide">
                <span><?php esc_html_e('المنتج (للهدايا فقط)', 'zooboxi'); ?></span>
                <?php
                $selected_id = (int) ($editing['variation_id'] ?? 0) ?: (int) ($editing['product_id'] ?? 0);
                $selected    = $selected_id && function_exists('wc_get_product') ? wc_get_product($selected_id) : null;
                ?>
                <select class="wc-product-search" name="product_id" style="width:100%"
                        data-placeholder="<?php esc_attr_e('ابحث عن منتج…', 'zooboxi'); ?>"
                        data-action="woocommerce_json_search_products_and_variations"
                        data-allow_clear="true">
                    <?php if ($selected): ?>
                        <option value="<?php echo esc_attr((string) $selected_id); ?>" selected><?php echo esc_html(wp_strip_all_tags($selected->get_formatted_name())); ?></option>
                    <?php endif; ?>
                </select>
            </label>

            <label class="zbl-field zbl-field--wide"><span><?php esc_html_e('الوصف (عربي)', 'zooboxi'); ?></span><textarea name="desc_ar" rows="2" class="zbl-textarea"><?php echo esc_textarea($editing['desc_ar'] ?? ''); ?></textarea></label>
            <label class="zbl-field zbl-field--wide"><span><?php esc_html_e('الوصف (إنجليزي)', 'zooboxi'); ?></span><textarea name="desc_en" rows="2" class="zbl-textarea"><?php echo esc_textarea($editing['desc_en'] ?? ''); ?></textarea></label>

            <label class="zbl-check"><input type="checkbox" name="is_active" value="1" <?php checked((int) ($editing['is_active'] ?? 1), 1); ?>> <?php esc_html_e('نشطة', 'zooboxi'); ?></label>

            <p><button type="submit" class="button button-primary button-large"><?php esc_html_e('حفظ المكافأة', 'zooboxi'); ?></button></p>
        </form>
        <?php
    }

    private static function tab_scratch(): void
    {
        $raw     = Zooboxi_Loyalty::opt_json('scratch_table', Zooboxi_Loyalty_Scratch::DEFAULT_TABLE);
        $catalog = Zooboxi_Loyalty_Rewards::catalog(false);
        $odds    = Zooboxi_Loyalty_Scratch::odds();

        // Present the shipped defaults (which name keys) as ids the editor can save.
        $rows = [];
        foreach ($raw as $row) {
            if (!is_array($row)) {
                continue;
            }
            $reward_id = (int) ($row['reward_id'] ?? 0);
            if (!$reward_id && !empty($row['reward_key'])) {
                $found     = Zooboxi_Loyalty_Rewards::reward_by_key((string) $row['reward_key']);
                $reward_id = $found ? (int) $found['id'] : 0;
            }
            $rows[] = [
                'kind'      => (string) ($row['kind'] ?? 'paws'),
                'paws'      => (int) ($row['paws'] ?? 0),
                'reward_id' => $reward_id,
                'weight'    => (float) ($row['weight'] ?? 0),
            ];
        }
        while (count($rows) < 8) {
            $rows[] = ['kind' => 'paws', 'paws' => 0, 'reward_id' => 0, 'weight' => 0];
        }
        ?>
        <form method="post" class="zbl-card">
            <?php wp_nonce_field('zbl_scratch'); ?>
            <input type="hidden" name="zbl_action" value="scratch">

            <h2><?php esc_html_e('جدول الجوائز', 'zooboxi'); ?></h2>
            <p class="zbl-hint"><?php esc_html_e('الوزن نسبي وليس نسبة مئوية. الصف بوزن صفر يُحذف. الصف الذي يشير إلى مكافأة غير نشطة (أو هدية بلا منتج) يسقط تلقائياً من السحب.', 'zooboxi'); ?></p>

            <table class="widefat striped zbl-table">
                <thead><tr>
                    <th><?php esc_html_e('النوع', 'zooboxi'); ?></th>
                    <th><?php esc_html_e('بصمات', 'zooboxi'); ?></th>
                    <th><?php esc_html_e('المكافأة', 'zooboxi'); ?></th>
                    <th><?php esc_html_e('الوزن', 'zooboxi'); ?></th>
                </tr></thead>
                <tbody>
                <?php foreach ($rows as $i => $row): ?>
                    <tr>
                        <td>
                            <select name="row_kind[<?php echo (int) $i; ?>]">
                                <option value="paws" <?php selected($row['kind'], 'paws'); ?>><?php esc_html_e('بصمات', 'zooboxi'); ?></option>
                                <option value="reward" <?php selected($row['kind'], 'reward'); ?>><?php esc_html_e('مكافأة', 'zooboxi'); ?></option>
                            </select>
                        </td>
                        <td><input type="number" min="0" name="row_paws[<?php echo (int) $i; ?>]" value="<?php echo esc_attr((string) $row['paws']); ?>" style="width:90px"></td>
                        <td>
                            <select name="row_reward[<?php echo (int) $i; ?>]">
                                <option value="0">—</option>
                                <?php foreach ($catalog as $reward): ?>
                                    <option value="<?php echo (int) $reward['id']; ?>" <?php selected($row['reward_id'], (int) $reward['id']); ?>>
                                        <?php echo esc_html($reward['title_ar'] . ((int) $reward['is_active'] === 1 ? '' : ' (معطّلة)')); ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </td>
                        <td><input type="number" step="0.1" min="0" name="row_weight[<?php echo (int) $i; ?>]" value="<?php echo esc_attr((string) $row['weight']); ?>" style="width:90px"></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>

            <p><button type="submit" class="button button-primary button-large"><?php esc_html_e('حفظ الجدول', 'zooboxi'); ?></button></p>
        </form>

        <div class="zbl-card">
            <h2><?php esc_html_e('الاحتمالات الفعلية', 'zooboxi'); ?></h2>
            <?php if (empty($odds['rows'])): ?>
                <p><?php esc_html_e('لا يوجد صف قابل للسحب — لن تُصدر أي بطاقة.', 'zooboxi'); ?></p>
            <?php else: ?>
                <table class="widefat striped zbl-table">
                    <thead><tr><th><?php esc_html_e('الجائزة', 'zooboxi'); ?></th><th><?php esc_html_e('الاحتمال', 'zooboxi'); ?></th><th><?php esc_html_e('تكلفتها', 'zooboxi'); ?></th></tr></thead>
                    <tbody>
                    <?php foreach ($odds['rows'] as $row): ?>
                        <tr>
                            <td><?php echo esc_html($row['label']); ?></td>
                            <td><?php echo esc_html((string) $row['probability']); ?>%</td>
                            <td><?php echo esc_html(number_format((float) $row['cost_sar'], 2)); ?> ﷼</td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
                <p class="zbl-big"><?php esc_html_e('التكلفة المتوقعة لكل بطاقة:', 'zooboxi'); ?> <strong><?php echo esc_html(number_format((float) $odds['expected_cost_sar'], 3)); ?> ﷼</strong></p>
            <?php endif; ?>
        </div>
        <?php
    }

    private static function tab_missions(): void
    {
        $catalog = Zooboxi_Loyalty_Rewards::catalog(true);
        ?>
        <form method="post" class="zbl-card">
            <?php wp_nonce_field('zbl_missions'); ?>
            <input type="hidden" name="zbl_action" value="missions">

            <h2><?php esc_html_e('قوالب المهمات', 'zooboxi'); ?></h2>
            <p class="zbl-hint"><?php esc_html_e('يُختار حتى 4 قوالب مؤهلة لكل عميل شهرياً بالترتيب أدناه. مكافأة «هدية» تعود تلقائياً إلى البصمات إن كانت المكافأة غير نشطة.', 'zooboxi'); ?></p>

            <table class="widefat striped zbl-table">
                <thead><tr>
                    <th><?php esc_html_e('القالب', 'zooboxi'); ?></th>
                    <th><?php esc_html_e('مفعّل', 'zooboxi'); ?></th>
                    <th><?php esc_html_e('نوع المكافأة', 'zooboxi'); ?></th>
                    <th><?php esc_html_e('بصمات', 'zooboxi'); ?></th>
                    <th><?php esc_html_e('هدية', 'zooboxi'); ?></th>
                    <th><?php esc_html_e('الهدف', 'zooboxi'); ?></th>
                </tr></thead>
                <tbody>
                <?php foreach (Zooboxi_Loyalty_Missions::TEMPLATES as $key => $tpl):
                    $cfg = Zooboxi_Loyalty_Missions::config($key); ?>
                    <tr>
                        <td><strong><?php echo esc_html(self::mission_label($key)); ?></strong><br><code><?php echo esc_html($key); ?></code></td>
                        <td><input type="checkbox" name="m_enabled[<?php echo esc_attr($key); ?>]" value="1" <?php checked($cfg['enabled']); ?>></td>
                        <td>
                            <select name="m_kind[<?php echo esc_attr($key); ?>]">
                                <option value="paws" <?php selected($cfg['reward_kind'], 'paws'); ?>><?php esc_html_e('بصمات', 'zooboxi'); ?></option>
                                <option value="reward" <?php selected($cfg['reward_kind'], 'reward'); ?>><?php esc_html_e('هدية', 'zooboxi'); ?></option>
                            </select>
                        </td>
                        <td><input type="number" min="0" name="m_paws[<?php echo esc_attr($key); ?>]" value="<?php echo esc_attr((string) $cfg['reward_paws']); ?>" style="width:90px"></td>
                        <td>
                            <select name="m_reward[<?php echo esc_attr($key); ?>]">
                                <option value="0">—</option>
                                <?php foreach ($catalog as $reward): ?>
                                    <option value="<?php echo (int) $reward['id']; ?>" <?php selected($cfg['reward_id'], (int) $reward['id']); ?>><?php echo esc_html($reward['title_ar']); ?></option>
                                <?php endforeach; ?>
                            </select>
                        </td>
                        <td>
                            <?php if ($key === 'frequency'): ?>
                                <input type="number" min="0" name="m_target[frequency]" value="<?php echo esc_attr($cfg['target'] === null ? '' : (string) $cfg['target']); ?>" style="width:80px" placeholder="<?php esc_attr_e('تلقائي', 'zooboxi'); ?>">
                            <?php else: ?>
                                <?php echo esc_html((string) ($tpl['target'] ?? 1)); ?>
                            <?php endif; ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>

            <p><button type="submit" class="button button-primary button-large"><?php esc_html_e('حفظ المهمات', 'zooboxi'); ?></button></p>
        </form>
        <?php
    }

    private static function tab_metrics(): void
    {
        $m = Zooboxi_Loyalty::metrics();
        $b = Zooboxi_Loyalty::baseline();
        ?>
        <div class="zbl-card">
            <h2><?php esc_html_e('هذا الشهر', 'zooboxi'); ?> · <?php echo esc_html($m['period']); ?></h2>
            <div class="zbl-stats">
                <?php
                self::stat(__('الأعضاء', 'zooboxi'), (string) $m['members']);
                self::stat(__('المجموعة الضابطة', 'zooboxi'), (string) $m['holdout']);
                self::stat(__('الحيوانات', 'zooboxi'), (string) $m['pets']);
                self::stat(__('بصمات صادرة', 'zooboxi'), (string) $m['paws']['issued']);
                self::stat(__('بصمات مستبدلة', 'zooboxi'), (string) $m['paws']['spent']);
                self::stat(__('بصمات منتهية', 'zooboxi'), (string) $m['paws']['expired']);
                self::stat(__('البطاقات', 'zooboxi'), $m['cards_revealed'] . ' / ' . $m['cards_total']);
                self::stat(__('مهمات مكافأة', 'zooboxi'), (string) $m['missions_done']);
                ?>
            </div>

            <h3><?php esc_html_e('العادة (المرحلة 2)', 'zooboxi'); ?></h3>
            <div class="zbl-stats">
                <?php
                $h = $m['habit'] ?? [];
                self::stat(__('اشتراكات نشطة', 'zooboxi'), (string) ($h['subs_active'] ?? 0));
                self::stat(__('توصيلات اشتراك هذا الشهر', 'zooboxi'), (string) ($h['sub_deliveries'] ?? 0));
                self::stat(__('إحالات مكافأة هذا الشهر', 'zooboxi'), (string) ($h['referrals_rewarded'] ?? 0));
                self::stat(__('إحالات قيد المراجعة', 'zooboxi'), (string) ($h['referrals_review'] ?? 0));
                self::stat(__('هدايا عيد ميلاد', 'zooboxi'), (string) ($h['birthdays'] ?? 0));
                self::stat(__('مهمات استرجاع', 'zooboxi'), (string) ($h['winbacks'] ?? 0));
                ?>
            </div>

            <h3><?php esc_html_e('المنح', 'zooboxi'); ?></h3>
            <p><?php
                $parts = [];
                foreach (Zooboxi_Loyalty_Rewards::STATES as $state) {
                    $parts[] = esc_html(self::state_label($state)) . ': <strong>' . (int) ($m['grants'][$state] ?? 0) . '</strong>';
                }
                echo wp_kses_post(implode(' · ', $parts));
            ?></p>

            <h3><?php esc_html_e('التكلفة مقابل المبيعات', 'zooboxi'); ?></h3>
            <?php if (!$m['stats_table']): ?>
                <p class="zbl-warn"><?php esc_html_e('جدول تحليلات WooCommerce غير موجود — المبيعات غير متاحة.', 'zooboxi'); ?></p>
            <?php endif; ?>
            <p class="zbl-big">
                <?php echo esc_html(number_format((float) $m['cost_sar'], 2)); ?> ﷼
                <?php esc_html_e('من', 'zooboxi'); ?>
                <?php echo esc_html(number_format((float) $m['sales_sar'], 2)); ?> ﷼
                <?php if ($m['cost_pct'] !== null): ?>
                    — <strong style="color:<?php echo $m['cost_pct'] > $m['budget_pct'] ? '#b32d2e' : '#046b2f'; ?>"><?php echo esc_html((string) $m['cost_pct']); ?>%</strong>
                    <?php esc_html_e('والسقف', 'zooboxi'); ?> <?php echo esc_html((string) $m['budget_pct']); ?>%
                <?php endif; ?>
            </p>
            <p class="zbl-hint"><?php printf(
                esc_html__('منها %s ﷼ هدايا مستبدلة و%s ﷼ قيمة تقديرية للبصمات الصادرة.', 'zooboxi'),
                esc_html(number_format((float) $m['cost_rewards'], 2)),
                esc_html(number_format((float) $m['cost_paws'], 2))
            ); ?></p>
        </div>

        <div class="zbl-card">
            <h2><?php esc_html_e('خط الأساس — آخر 365 يوماً', 'zooboxi'); ?></h2>
            <form method="post" style="display:inline">
                <?php wp_nonce_field('zbl_baseline'); ?>
                <input type="hidden" name="zbl_action" value="baseline">
                <button class="button"><?php esc_html_e('تحديث الآن', 'zooboxi'); ?></button>
            </form>

            <?php if (empty($b['available'])): ?>
                <p class="zbl-warn"><?php esc_html_e('جدول wc_order_stats غير موجود على هذا المتجر.', 'zooboxi'); ?></p>
            <?php else: ?>
                <div class="zbl-stats">
                    <?php
                    self::stat(__('الطلبات', 'zooboxi'), number_format((int) $b['orders']));
                    self::stat(__('العملاء', 'zooboxi'), number_format((int) $b['customers']));
                    self::stat(__('متوسط الطلب', 'zooboxi'), number_format((float) $b['avg_order_sar'], 2) . ' ﷼');
                    self::stat(__('طلبات لكل عميل', 'zooboxi'), (string) $b['orders_per_customer']);
                    self::stat(__('نسبة المكرِّرين', 'zooboxi'), $b['repeat_rate'] . '%');
                    self::stat(__('إعادة شراء خلال 90 يوماً', 'zooboxi'), $b['repurchase_90d_rate'] . '%');
                    ?>
                </div>
                <h3><?php esc_html_e('توزيع العملاء حسب عدد الطلبات', 'zooboxi'); ?></h3>
                <div class="zbl-stats">
                    <?php
                    self::stat('1', number_format((int) $b['distribution']['one']));
                    self::stat('2', number_format((int) $b['distribution']['two']));
                    self::stat('3–5', number_format((int) $b['distribution']['three_five']));
                    self::stat('6+', number_format((int) $b['distribution']['six_plus']));
                    ?>
                </div>
                <p class="zbl-hint"><?php esc_html_e('احتُسب في:', 'zooboxi'); ?> <?php echo esc_html((string) $b['computed_at']); ?> UTC</p>
            <?php endif; ?>
        </div>
        <?php
    }

    private static function tab_member(): void
    {
        $query = isset($_GET['q']) ? sanitize_text_field(wp_unslash($_GET['q'])) : '';
        $user  = $query !== '' ? self::find_user($query) : null;
        ?>
        <div class="zbl-card">
            <h2><?php esc_html_e('بحث عن عضو', 'zooboxi'); ?></h2>
            <form method="get">
                <input type="hidden" name="page" value="<?php echo esc_attr(self::SLUG); ?>">
                <input type="hidden" name="tab" value="member">
                <input type="search" name="q" value="<?php echo esc_attr($query); ?>" placeholder="<?php esc_attr_e('رقم الجوال أو معرّف المستخدم', 'zooboxi'); ?>" style="min-width:280px">
                <button class="button button-primary"><?php esc_html_e('بحث', 'zooboxi'); ?></button>
            </form>

            <?php if ($query !== '' && !$user): ?>
                <p class="zbl-warn"><?php esc_html_e('لم يُعثر على عميل بهذا المعرّف.', 'zooboxi'); ?></p>
            <?php endif; ?>
        </div>

        <?php if ($user):
            $uid    = (int) $user->ID;
            $member = Zooboxi_Loyalty_Members::get($uid);
            $tier   = Zooboxi_Loyalty_Tiers::dto($uid);
            $ledger = Zooboxi_Loyalty_Ledger::page($uid, 1, 20);
            $grants = Zooboxi_Loyalty_Rewards::grants_for($uid, Zooboxi_Loyalty_Rewards::STATES, 20);
            $pets   = Zooboxi_Loyalty_Pets::dtos($uid);
            ?>
            <div class="zbl-card">
                <h2><?php echo esc_html($user->display_name); ?> <small>#<?php echo (int) $uid; ?></small></h2>
                <div class="zbl-stats">
                    <?php
                    self::stat(__('الرصيد', 'zooboxi'), (string) Zooboxi_Loyalty_Ledger::balance($uid));
                    self::stat(__('المستوى', 'zooboxi'), $tier['icon'] . ' ' . $tier['name']);
                    self::stat(__('طلبات 12 شهراً', 'zooboxi'), (string) $tier['orders_12m']);
                    self::stat(__('المجموعة الضابطة', 'zooboxi'), $member && (int) $member['holdout'] === 1 ? __('نعم', 'zooboxi') : __('لا', 'zooboxi'));
                    self::stat(__('الحيوانات', 'zooboxi'), (string) count($pets));
                    ?>
                </div>

                <h3><?php esc_html_e('تعديل يدوي للرصيد', 'zooboxi'); ?></h3>
                <form method="post">
                    <?php wp_nonce_field('zbl_adjust'); ?>
                    <input type="hidden" name="zbl_action" value="adjust">
                    <input type="hidden" name="user_id" value="<?php echo (int) $uid; ?>">
                    <input type="number" name="delta" placeholder="<?php esc_attr_e('± بصمات', 'zooboxi'); ?>" required style="width:130px">
                    <input type="text" name="note" placeholder="<?php esc_attr_e('السبب (إلزامي)', 'zooboxi'); ?>" required style="min-width:320px">
                    <button class="button button-primary"><?php esc_html_e('تسجيل القيد', 'zooboxi'); ?></button>
                </form>
            </div>

            <div class="zbl-card">
                <h3><?php esc_html_e('الدفتر', 'zooboxi'); ?></h3>
                <table class="widefat striped zbl-table">
                    <thead><tr><th><?php esc_html_e('التاريخ', 'zooboxi'); ?></th><th><?php esc_html_e('السبب', 'zooboxi'); ?></th><th><?php esc_html_e('المرجع', 'zooboxi'); ?></th><th><?php esc_html_e('التغيير', 'zooboxi'); ?></th><th><?php esc_html_e('الرصيد', 'zooboxi'); ?></th><th><?php esc_html_e('ملاحظة', 'zooboxi'); ?></th></tr></thead>
                    <tbody>
                    <?php foreach ($ledger['items'] as $row): ?>
                        <tr>
                            <td><?php echo esc_html((string) $row['created_at']); ?></td>
                            <td><?php echo esc_html((string) $row['reason']); ?></td>
                            <td><?php echo esc_html($row['ref_type'] . ':' . $row['ref_id']); ?></td>
                            <td style="color:<?php echo $row['delta'] >= 0 ? '#046b2f' : '#b32d2e'; ?>"><?php echo esc_html(($row['delta'] > 0 ? '+' : '') . $row['delta']); ?></td>
                            <td><?php echo esc_html((string) $row['balance_after']); ?></td>
                            <td><?php echo esc_html((string) $row['note']); ?></td>
                        </tr>
                    <?php endforeach; ?>
                    <?php if (empty($ledger['items'])): ?>
                        <tr><td colspan="6"><?php esc_html_e('لا توجد قيود بعد.', 'zooboxi'); ?></td></tr>
                    <?php endif; ?>
                    </tbody>
                </table>
            </div>

            <div class="zbl-card">
                <h3><?php esc_html_e('المنح', 'zooboxi'); ?></h3>
                <table class="widefat striped zbl-table">
                    <thead><tr><th>#</th><th><?php esc_html_e('المكافأة', 'zooboxi'); ?></th><th><?php esc_html_e('المصدر', 'zooboxi'); ?></th><th><?php esc_html_e('الحالة', 'zooboxi'); ?></th><th><?php esc_html_e('تنتهي', 'zooboxi'); ?></th><th><?php esc_html_e('الطلب', 'zooboxi'); ?></th></tr></thead>
                    <tbody>
                    <?php foreach ($grants as $grant):
                        $reward = Zooboxi_Loyalty_Rewards::reward((int) $grant['reward_id']); ?>
                        <tr>
                            <td><?php echo (int) $grant['id']; ?></td>
                            <td><?php echo esc_html($reward['title_ar'] ?? '—'); ?></td>
                            <td><?php echo esc_html((string) $grant['source']); ?></td>
                            <td><?php echo esc_html(self::state_label((string) $grant['state'])); ?></td>
                            <td><?php echo esc_html((string) ($grant['expires_at'] ?? '—')); ?></td>
                            <td><?php echo esc_html((string) ($grant['redeemed_order_id'] ?: ($grant['activates_on_order'] ?: '—'))); ?></td>
                        </tr>
                    <?php endforeach; ?>
                    <?php if (empty($grants)): ?>
                        <tr><td colspan="6"><?php esc_html_e('لا توجد منح.', 'zooboxi'); ?></td></tr>
                    <?php endif; ?>
                    </tbody>
                </table>
            </div>

            <div class="zbl-card">
                <h3><?php esc_html_e('الحيوانات', 'zooboxi'); ?></h3>
                <?php if (empty($pets)): ?>
                    <p><?php esc_html_e('لا توجد حيوانات مسجّلة.', 'zooboxi'); ?></p>
                <?php else: ?>
                    <ul class="zbl-pets">
                        <?php foreach ($pets as $pet): ?>
                            <li><strong><?php echo esc_html($pet['name']); ?></strong> · <?php echo esc_html($pet['species']); ?>
                                <?php if ($pet['age_label']): ?>· <?php echo esc_html($pet['age_label']); ?><?php endif; ?>
                                <?php if ($pet['weight_kg']): ?>· <?php echo esc_html((string) $pet['weight_kg']); ?> <?php esc_html_e('كجم', 'zooboxi'); ?><?php endif; ?>
                            </li>
                        <?php endforeach; ?>
                    </ul>
                <?php endif; ?>
            </div>
        <?php endif; ?>
        <?php
    }

    /* ══════════════════════════════════════════════════════════════
       HELPERS
       ══════════════════════════════════════════════════════════════ */

    /** Look a customer up by user id, login, email or billing phone. */
    private static function find_user(string $query): ?\WP_User
    {
        if (ctype_digit($query) && strlen($query) <= 9) {
            $user = get_user_by('id', (int) $query);
            if ($user) {
                return $user;
            }
        }
        foreach (['login', 'email', 'slug'] as $field) {
            $user = get_user_by($field, $query);
            if ($user) {
                return $user;
            }
        }

        // Phone: the OTP flow parks customers on a `zb_{digits}` login, and the billing
        // phone is stored with and without a country prefix, so try the tail.
        $digits = preg_replace('/[^0-9]/', '', $query);
        if ($digits === '') {
            return null;
        }
        $user = get_user_by('login', 'zb_' . $digits);
        if ($user) {
            return $user;
        }

        $found = get_users([
            'meta_key'     => 'billing_phone',
            'meta_value'   => substr($digits, -9),
            'meta_compare' => 'LIKE',
            'number'       => 1,
            'fields'       => 'all',
        ]);
        return !empty($found) ? $found[0] : null;
    }

    private static function number_field(string $key, string $label, string $hint = '', string $step = '1'): void
    {
        ?>
        <label class="zbl-field">
            <span><?php echo esc_html($label); ?></span>
            <input type="number" step="<?php echo esc_attr($step); ?>" min="0" name="<?php echo esc_attr($key); ?>" value="<?php echo esc_attr((string) Zooboxi_Loyalty::opt($key)); ?>">
            <?php if ($hint !== ''): ?><em><?php echo esc_html($hint); ?></em><?php endif; ?>
        </label>
        <?php
    }

    private static function stat(string $label, string $value): void
    {
        echo '<div class="zbl-stat"><span>' . esc_html($label) . '</span><strong>' . esc_html($value) . '</strong></div>';
    }

    private static function kind_label(string $kind): string
    {
        $map = [
            'gift_product'  => __('هدية منتج', 'zooboxi'),
            'express_free'  => __('ترقية توصيل سريع', 'zooboxi'),
            'free_delivery' => __('توصيل مجاني بلا حد أدنى', 'zooboxi'),
            'paws'          => __('بصمات', 'zooboxi'),
        ];
        return $map[$kind] ?? $kind;
    }

    private static function state_label(string $state): string
    {
        $map = [
            'pending'   => __('بانتظار التسليم', 'zooboxi'),
            'active'    => __('نشطة', 'zooboxi'),
            'claimed'   => __('في السلة', 'zooboxi'),
            'redeemed'  => __('استُخدمت', 'zooboxi'),
            'expired'   => __('منتهية', 'zooboxi'),
            'cancelled' => __('ملغاة', 'zooboxi'),
        ];
        return $map[$state] ?? $state;
    }

    private static function mission_label(string $key): string
    {
        $map = [
            'profile'          => __('أكمل ملف عائلتك', 'zooboxi'),
            'first_app_order'  => __('أول طلب من التطبيق', 'zooboxi'),
            'frequency'        => __('طلبات الشهر', 'zooboxi'),
            'try_new_brand'    => __('جرّب ماركة جديدة', 'zooboxi'),
            'species_category' => __('جرّب تصنيفاً جديداً', 'zooboxi'),
            'on_time'          => __('اطلب في وقتك', 'zooboxi'),
            'refer_friend'     => __('ادعُ صديقاً', 'zooboxi'),
        ];
        return $map[$key] ?? $key;
    }

    /* ══════════════════════════════════════════════════════════════
       PHASE 2 — «العادة»
       ══════════════════════════════════════════════════════════════ */

    private static function save_habit(): string
    {
        $post = wp_unslash($_POST);

        foreach (['supply_enabled', 'subscriptions_enabled', 'referral_enabled', 'birthday_enabled', 'winback_enabled', 'mail_enabled'] as $flag) {
            update_option('zooboxi_loyalty_' . $flag, !empty($post[$flag]) ? 'yes' : 'no');
        }

        $numbers = [
            'on_time_pct', 'on_time_before', 'on_time_after',
            'max_subscriptions', 'sub_reminder_days', 'sub_bonus_pct', 'sub_gift_every', 'sub_gift_paws',
            'referral_paws', 'referral_cap', 'referral_hold_days', 'referral_welcome_paws',
            'birthday_paws', 'winback_days', 'winback_paws', 'mail_weekly_cap',
        ];
        foreach ($numbers as $key) {
            if (isset($post[$key])) {
                update_option('zooboxi_loyalty_' . $key, absint($post[$key]));
            }
        }

        $tier = sanitize_key((string) ($post['birthday_min_tier'] ?? 'friend'));
        update_option('zooboxi_loyalty_birthday_min_tier', in_array($tier, Zooboxi_Loyalty_Tiers::ORDER, true) ? $tier : 'friend');

        foreach (['supply_food_cats', 'supply_treat_cats'] as $key) {
            update_option('zooboxi_loyalty_' . $key, sanitize_text_field((string) ($post[$key] ?? '')));
        }

        // species roots: lines "cat=107"
        $roots = [];
        foreach (preg_split('/[\r\n]+/', (string) ($post['species_roots'] ?? '')) as $line) {
            if (strpos($line, '=') === false) {
                continue;
            }
            [$species, $id] = array_map('trim', explode('=', $line, 2));
            $species = sanitize_key($species);
            if ($species !== '' && absint($id) > 0) {
                $roots[$species] = absint($id);
            }
        }
        update_option('zooboxi_loyalty_species_roots', wp_json_encode($roots));

        // feeding table: raw JSON, validated
        $json = trim((string) ($post['feeding_table'] ?? ''));
        if ($json === '') {
            delete_option('zooboxi_loyalty_feeding_table');
        } else {
            $decoded = json_decode($json, true);
            if (!is_array($decoded)) {
                return __('جدول التغذية ليس JSON صالحاً — لم يُحفظ', 'zooboxi');
            }
            update_option('zooboxi_loyalty_feeding_table', wp_json_encode($decoded, JSON_UNESCAPED_UNICODE));
        }

        return __('تم حفظ إعدادات العادة', 'zooboxi');
    }

    private static function decide_referral(): string
    {
        $id = absint($_POST['referral_id'] ?? 0);
        if ($id <= 0) {
            return '';
        }
        if (!empty($_POST['approve'])) {
            return Zooboxi_Loyalty_Referrals::pay($id) ? __('تم اعتماد الإحالة ودفع المكافأة', 'zooboxi') : __('تعذّر اعتماد الإحالة', 'zooboxi');
        }
        Zooboxi_Loyalty_Referrals::reject($id);
        return __('تم رفض الإحالة', 'zooboxi');
    }

    private static function save_stamp_program(): string
    {
        $post = wp_unslash($_POST);
        $id   = Zooboxi_Loyalty_Stamps::save([
            'id'             => $post['program_id'] ?? 0,
            'title_ar'       => $post['title_ar'] ?? '',
            'title_en'       => $post['title_en'] ?? '',
            'brand_term_id'  => $post['brand_term_id'] ?? 0,
            'units_required' => $post['units_required'] ?? 6,
            'min_pack_kg'    => $post['min_pack_kg'] ?? 0,
            'reward_id'      => $post['reward_id'] ?? 0,
            'is_active'      => !empty($post['is_active']),
            'sort'           => $post['sort'] ?? 0,
        ]);
        return $id > 0 ? __('تم حفظ برنامج الماركة', 'zooboxi') : __('تعذّر الحفظ', 'zooboxi');
    }

    private static function check_field(string $key, string $label, string $hint = ''): void
    {
        ?>
        <label class="zbl-check"><input type="checkbox" name="<?php echo esc_attr($key); ?>" value="1" <?php checked(Zooboxi_Loyalty::opt($key), 'yes'); ?>> <?php echo esc_html($label); ?>
            <?php if ($hint !== ''): ?><em style="display:block;color:#6b6b6b;font-weight:400;margin-inline-start:26px"><?php echo esc_html($hint); ?></em><?php endif; ?>
        </label>
        <?php
    }

    private static function tab_habit(): void
    {
        $roots = [];
        foreach (Zooboxi_Loyalty_Supply::species_roots() as $species => $id) {
            $roots[] = $species . '=' . $id;
        }
        $feeding = Zooboxi_Loyalty::opt_json('feeding_table', []);
        $feeding_json = wp_json_encode($feeding ?: Zooboxi_Loyalty_Supply::DEFAULT_FEEDING, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        $review  = Zooboxi_Loyalty_Referrals::in_review();
        $ran     = (string) get_option('zooboxi_loyalty_habit_ran_at', '');
        ?>
        <form method="post" class="zbl-card">
            <?php wp_nonce_field('zbl_habit'); ?>
            <input type="hidden" name="zbl_action" value="habit">

            <h2><?php esc_html_e('عدّاد الأكل', 'zooboxi'); ?></h2>
            <p class="zbl-hint"><?php esc_html_e('يتنبأ بموعد نفاد أكل كل حيوان من حجم العبوة وجدول التغذية، ويتعلّم من فواصل الشراء الفعلية وزر «خلص». الطلب داخل النافذة يكسب بصمات إضافية.', 'zooboxi'); ?></p>
            <?php self::check_field('supply_enabled', __('تفعيل عدّاد الأكل', 'zooboxi')); ?>
            <div class="zbl-grid">
                <?php
                self::number_field('on_time_pct', __('مكافأة «في وقته» %', 'zooboxi'), __('نسبة إضافية على بصمات السطور المطلوبة داخل النافذة.', 'zooboxi'));
                self::number_field('on_time_before', __('النافذة: أيام قبل النفاد', 'zooboxi'));
                self::number_field('on_time_after', __('النافذة: أيام بعد النفاد', 'zooboxi'));
                ?>
            </div>
            <label class="zbl-field"><span><?php esc_html_e('تصنيفات الطعام (معرّفات، بفاصلة)', 'zooboxi'); ?></span>
                <input type="text" name="supply_food_cats" value="<?php echo esc_attr(implode(', ', Zooboxi_Loyalty_Supply::food_cats())); ?>"></label>
            <label class="zbl-field"><span><?php esc_html_e('تصنيفات المكافآت (معرّفات، بفاصلة)', 'zooboxi'); ?></span>
                <input type="text" name="supply_treat_cats" value="<?php echo esc_attr(implode(', ', Zooboxi_Loyalty_Supply::treat_cats())); ?>"></label>
            <label class="zbl-field"><span><?php esc_html_e('جذور الأنواع (سطر لكل نوع: species=category_id)', 'zooboxi'); ?></span>
                <textarea name="species_roots" rows="4" class="zbl-textarea"><?php echo esc_textarea(implode("\n", $roots)); ?></textarea></label>
            <label class="zbl-field"><span><?php esc_html_e('جدول التغذية (غرام/يوم) — JSON', 'zooboxi'); ?></span>
                <textarea name="feeding_table" rows="14" class="zbl-textarea" dir="ltr" style="font-family:monospace"><?php echo esc_textarea($feeding_json); ?></textarea>
                <em><?php esc_html_e('per_kg × وزن الحيوان (أو default_kg)، أو flat. tiers اختيارية للكلاب: [[حتى كجم, غرام/كجم], …]. اتركه فارغاً للعودة للافتراضي.', 'zooboxi'); ?></em></label>

            <h2><?php esc_html_e('الاشتراك المرن', 'zooboxi'); ?></h2>
            <?php self::check_field('subscriptions_enabled', __('تفعيل «وصّل لي كل شهر»', 'zooboxi'), __('بلا حفظ بطاقة: تذكير قبل الموعد وطلب بضغطة. توصيلة الاشتراك تشحن مجاناً.', 'zooboxi')); ?>
            <div class="zbl-grid">
                <?php
                self::number_field('max_subscriptions', __('الحد الأقصى للاشتراكات', 'zooboxi'));
                self::number_field('sub_reminder_days', __('التذكير قبل (أيام)', 'zooboxi'));
                self::number_field('sub_bonus_pct', __('بصمات إضافية على التوصيلة %', 'zooboxi'));
                self::number_field('sub_gift_every', __('هدية كل N توصيلة', 'zooboxi'), __('0 = بلا هدية. تُمنح «هدية الاشتراك» من الكتالوج إن رُبط بها منتج.', 'zooboxi'));
                self::number_field('sub_gift_paws', __('بديل الهدية بالبصمات', 'zooboxi'));
                ?>
            </div>

            <h2><?php esc_html_e('الإحالة', 'zooboxi'); ?></h2>
            <?php self::check_field('referral_enabled', __('تفعيل «ادعُ صديقاً»', 'zooboxi'), __('الرابط: ' . home_url('/?ref=CODE') . ' — المكافأة بعد اكتمال أول طلب للمدعو ومرور فترة الإرجاع.', 'zooboxi')); ?>
            <div class="zbl-grid">
                <?php
                self::number_field('referral_paws', __('بصمات الداعي', 'zooboxi'));
                self::number_field('referral_welcome_paws', __('بصمات المدعو (إن لم تُربط هدية)', 'zooboxi'));
                self::number_field('referral_cap', __('سقف الدعوات شهرياً', 'zooboxi'));
                self::number_field('referral_hold_days', __('فترة الانتظار بعد التسليم (أيام)', 'zooboxi'));
                ?>
            </div>

            <h2><?php esc_html_e('اللحظات', 'zooboxi'); ?></h2>
            <?php self::check_field('birthday_enabled', __('هدية عيد ميلاد الحيوان', 'zooboxi'), __('مرة سنوياً لكل حيوان، قبل أسبوع من الميلاد. تُمنح «هدية عيد الميلاد» من الكتالوج إن رُبط بها منتج، وإلا بصمات.', 'zooboxi')); ?>
            <div class="zbl-grid">
                <label class="zbl-field"><span><?php esc_html_e('من مستوى', 'zooboxi'); ?></span>
                    <select name="birthday_min_tier">
                        <?php foreach (Zooboxi_Loyalty_Tiers::ORDER as $key): ?>
                            <option value="<?php echo esc_attr($key); ?>" <?php selected(Zooboxi_Loyalty::opt('birthday_min_tier'), $key); ?>><?php echo esc_html(Zooboxi_Loyalty_Tiers::name($key)); ?></option>
                        <?php endforeach; ?>
                    </select></label>
                <?php self::number_field('birthday_paws', __('بديل الهدية بالبصمات', 'zooboxi')); ?>
            </div>
            <?php self::check_field('winback_enabled', __('الاسترجاع «نشتاق لـ…»', 'zooboxi'), __('مهمة بهدية أقوى لمن صمت بعد موعده المتوقع. لا تتكرر خلال 90 يوماً. تُمنح «هدية اشتقنا لك» إن رُبط بها منتج.', 'zooboxi')); ?>
            <div class="zbl-grid">
                <?php
                self::number_field('winback_days', __('أيام الصمت بعد الموعد المتوقع', 'zooboxi'));
                self::number_field('winback_paws', __('بديل الهدية بالبصمات', 'zooboxi'));
                ?>
            </div>

            <h2><?php esc_html_e('البريد', 'zooboxi'); ?></h2>
            <?php self::check_field('mail_enabled', __('إرسال تنبيهات بالبريد', 'zooboxi'), __('التطبيق بلا Push بعد؛ البريد يذكّر بالاشتراك وعيد الميلاد والاسترجاع. حسابات OTP بلا بريد تُتجاهل.', 'zooboxi')); ?>
            <div class="zbl-grid">
                <?php self::number_field('mail_weekly_cap', __('سقف الرسائل أسبوعياً لكل عضو', 'zooboxi')); ?>
            </div>

            <p><button type="submit" class="button button-primary button-large"><?php esc_html_e('حفظ', 'zooboxi'); ?></button></p>
        </form>

        <div class="zbl-card">
            <h2><?php esc_html_e('الإحالات قيد المراجعة', 'zooboxi'); ?></h2>
            <p class="zbl-hint"><?php esc_html_e('إحالات تطابق عنوانها أو جوالها مع الداعي — قرارك يدفع المكافأة أو يرفضها.', 'zooboxi'); ?></p>
            <?php if (empty($review)): ?>
                <p><?php esc_html_e('لا شيء بانتظارك.', 'zooboxi'); ?></p>
            <?php else: ?>
                <table class="widefat striped zbl-table">
                    <thead><tr><th>#</th><th><?php esc_html_e('الداعي', 'zooboxi'); ?></th><th><?php esc_html_e('المدعو', 'zooboxi'); ?></th><th><?php esc_html_e('الأعلام', 'zooboxi'); ?></th><th><?php esc_html_e('الطلب', 'zooboxi'); ?></th><th></th></tr></thead>
                    <tbody>
                    <?php foreach ($review as $row):
                        $a = get_user_by('id', (int) $row['referrer_id']);
                        $b = get_user_by('id', (int) $row['referee_id']); ?>
                        <tr>
                            <td><?php echo (int) $row['id']; ?></td>
                            <td><?php echo esc_html($a ? $a->display_name . ' (' . $a->ID . ')' : (string) $row['referrer_id']); ?></td>
                            <td><?php echo esc_html($b ? $b->display_name . ' (' . $b->ID . ')' : (string) $row['referee_id']); ?></td>
                            <td><code><?php echo esc_html((string) $row['flags']); ?></code></td>
                            <td>#<?php echo (int) $row['first_order_id']; ?></td>
                            <td>
                                <form method="post" style="display:inline"><?php wp_nonce_field('zbl_referral_decide'); ?><input type="hidden" name="zbl_action" value="referral_decide"><input type="hidden" name="referral_id" value="<?php echo (int) $row['id']; ?>"><input type="hidden" name="approve" value="1"><button class="button button-small button-primary"><?php esc_html_e('اعتماد', 'zooboxi'); ?></button></form>
                                <form method="post" style="display:inline"><?php wp_nonce_field('zbl_referral_decide'); ?><input type="hidden" name="zbl_action" value="referral_decide"><input type="hidden" name="referral_id" value="<?php echo (int) $row['id']; ?>"><button class="button button-small"><?php esc_html_e('رفض', 'zooboxi'); ?></button></form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>

        <div class="zbl-card">
            <h2><?php esc_html_e('المهام اليومية', 'zooboxi'); ?></h2>
            <p class="zbl-hint"><?php echo esc_html($ran !== '' ? sprintf(__('آخر تشغيل: %s UTC', 'zooboxi'), $ran) : __('لم تعمل بعد.', 'zooboxi')); ?></p>
            <form method="post"><?php wp_nonce_field('zbl_habit_daily'); ?><input type="hidden" name="zbl_action" value="habit_daily"><button class="button"><?php esc_html_e('تشغيل الآن (تذكيرات، إحالات، أعياد ميلاد، استرجاع)', 'zooboxi'); ?></button></form>
        </div>
        <?php
    }

    private static function tab_stamps(): void
    {
        $programs = Zooboxi_Loyalty_Stamps::programs(false);
        $catalog  = Zooboxi_Loyalty_Rewards::catalog(true);
        $edit     = isset($_GET['program']) ? Zooboxi_Loyalty_Stamps::program(absint($_GET['program'])) : null;
        $brands   = taxonomy_exists('product_brand') ? get_terms(['taxonomy' => 'product_brand', 'hide_empty' => false, 'orderby' => 'name', 'number' => 300]) : [];
        $brands   = is_wp_error($brands) ? [] : $brands;
        ?>
        <div class="zbl-card">
            <h2><?php esc_html_e('بطاقات المشتري الدائم للماركات', 'zooboxi'); ?></h2>
            <p class="zbl-warn"><?php esc_html_e('لا برنامج فعّال افتراضياً. الكيس المجاني يعادل خصماً فعلياً (~14%) ويحتاج اتفاقاً مع الماركة — الهدية آمنة تماماً. فعّل برنامجاً فقط بعد قرار التمويل.', 'zooboxi'); ?></p>
            <?php if (empty($programs)): ?>
                <p><?php esc_html_e('لا برامج بعد.', 'zooboxi'); ?></p>
            <?php else: ?>
                <table class="widefat striped zbl-table">
                    <thead><tr><th><?php esc_html_e('البرنامج', 'zooboxi'); ?></th><th><?php esc_html_e('الماركة', 'zooboxi'); ?></th><th><?php esc_html_e('الوحدات', 'zooboxi'); ?></th><th><?php esc_html_e('حد العبوة', 'zooboxi'); ?></th><th><?php esc_html_e('المكافأة', 'zooboxi'); ?></th><th><?php esc_html_e('نشط', 'zooboxi'); ?></th><th></th></tr></thead>
                    <tbody>
                    <?php foreach ($programs as $p):
                        $term = get_term((int) $p['brand_term_id'], 'product_brand');
                        $rw   = (int) $p['reward_id'] > 0 ? Zooboxi_Loyalty_Rewards::reward((int) $p['reward_id']) : null; ?>
                        <tr>
                            <td><strong><?php echo esc_html((string) $p['title_ar']); ?></strong><br><small><?php echo esc_html((string) $p['title_en']); ?></small></td>
                            <td><?php echo esc_html(($term && !is_wp_error($term)) ? $term->name : '—'); ?></td>
                            <td><?php echo (int) $p['units_required']; ?></td>
                            <td><?php echo esc_html((string) (float) $p['min_pack_kg']); ?> كجم</td>
                            <td><?php echo esc_html($rw ? (string) $rw['title_ar'] : '—'); ?></td>
                            <td>
                                <form method="post" style="display:inline"><?php wp_nonce_field('zbl_stamp_toggle'); ?><input type="hidden" name="zbl_action" value="stamp_toggle"><input type="hidden" name="program_id" value="<?php echo (int) $p['id']; ?>"><input type="hidden" name="active" value="<?php echo (int) $p['is_active'] === 1 ? '' : '1'; ?>"><button class="button button-small"><?php echo (int) $p['is_active'] === 1 ? esc_html__('فعّال — إيقاف', 'zooboxi') : esc_html__('متوقف — تفعيل', 'zooboxi'); ?></button></form>
                            </td>
                            <td><a class="button button-small" href="<?php echo esc_url(admin_url('admin.php?page=' . self::SLUG . '&tab=stamps&program=' . (int) $p['id'])); ?>"><?php esc_html_e('تعديل', 'zooboxi'); ?></a></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>

        <form method="post" class="zbl-card">
            <?php wp_nonce_field('zbl_stamp_save'); ?>
            <input type="hidden" name="zbl_action" value="stamp_save">
            <input type="hidden" name="program_id" value="<?php echo (int) ($edit['id'] ?? 0); ?>">
            <h2><?php echo $edit ? esc_html__('تعديل برنامج', 'zooboxi') : esc_html__('برنامج جديد', 'zooboxi'); ?></h2>
            <div class="zbl-grid">
                <label class="zbl-field"><span><?php esc_html_e('العنوان (عربي)', 'zooboxi'); ?></span><input type="text" name="title_ar" value="<?php echo esc_attr((string) ($edit['title_ar'] ?? '')); ?>" required></label>
                <label class="zbl-field"><span><?php esc_html_e('العنوان (إنجليزي)', 'zooboxi'); ?></span><input type="text" name="title_en" value="<?php echo esc_attr((string) ($edit['title_en'] ?? '')); ?>"></label>
                <label class="zbl-field"><span><?php esc_html_e('الماركة', 'zooboxi'); ?></span>
                    <select name="brand_term_id" required>
                        <option value="0">—</option>
                        <?php foreach ($brands as $b): ?>
                            <option value="<?php echo (int) $b->term_id; ?>" <?php selected((int) ($edit['brand_term_id'] ?? 0), (int) $b->term_id); ?>><?php echo esc_html($b->name); ?></option>
                        <?php endforeach; ?>
                    </select></label>
                <label class="zbl-field"><span><?php esc_html_e('الوحدات المطلوبة', 'zooboxi'); ?></span><input type="number" min="1" name="units_required" value="<?php echo (int) ($edit['units_required'] ?? 6); ?>"></label>
                <label class="zbl-field"><span><?php esc_html_e('أقل حجم عبوة (كجم، 0 = أي)', 'zooboxi'); ?></span><input type="number" step="0.1" min="0" name="min_pack_kg" value="<?php echo esc_attr((string) (float) ($edit['min_pack_kg'] ?? 1.5)); ?>"></label>
                <label class="zbl-field"><span><?php esc_html_e('المكافأة', 'zooboxi'); ?></span>
                    <select name="reward_id">
                        <option value="0">—</option>
                        <?php foreach ($catalog as $reward): ?>
                            <option value="<?php echo (int) $reward['id']; ?>" <?php selected((int) ($edit['reward_id'] ?? 0), (int) $reward['id']); ?>><?php echo esc_html((string) $reward['title_ar']); ?></option>
                        <?php endforeach; ?>
                    </select></label>
                <label class="zbl-field"><span><?php esc_html_e('الترتيب', 'zooboxi'); ?></span><input type="number" name="sort" value="<?php echo (int) ($edit['sort'] ?? 0); ?>"></label>
            </div>
            <label class="zbl-check"><input type="checkbox" name="is_active" value="1" <?php checked((int) ($edit['is_active'] ?? 0), 1); ?>> <?php esc_html_e('نشط', 'zooboxi'); ?></label>
            <p><button type="submit" class="button button-primary button-large"><?php esc_html_e('حفظ البرنامج', 'zooboxi'); ?></button></p>
        </form>
        <?php
    }

    private static function styles(): void
    {
        ?>
        <style>
        .zbl { max-width: 1180px; }
        .zbl-hero { display:flex; gap:16px; align-items:center; background:linear-gradient(135deg,#429d9c,#2f7c7b); color:#fff; padding:18px 22px; border-radius:14px; margin:16px 0; }
        .zbl-hero h1 { color:#fff; margin:0 0 4px; font-size:20px; }
        .zbl-hero p { margin:0; opacity:.9; }
        .zbl-hero__logo { font-size:34px; }
        .zbl-saved { background:#e7f7ee; border:1px solid #9fdcbb; color:#046b2f; padding:10px 14px; border-radius:10px; margin-bottom:14px; }
        .zbl-warn { background:#fff5f5; border:1px solid #f3c2c2; color:#b32d2e; padding:10px 14px; border-radius:10px; margin-bottom:14px; }
        .zbl-tabs { display:flex; flex-wrap:wrap; gap:8px; margin-bottom:16px; }
        .zbl-tab { background:#fff; border:1px solid #dcdcde; border-radius:999px; padding:7px 16px; text-decoration:none; color:#2c3338; font-weight:600; }
        .zbl-tab.is-active { background:#429d9c; border-color:#429d9c; color:#fff; }
        .zbl-card { background:#fff; border:1px solid #e2e4e7; border-radius:14px; padding:18px 22px; margin-bottom:18px; }
        .zbl-card h2 { margin-top:0; }
        .zbl-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(240px,1fr)); gap:14px; margin-bottom:10px; }
        .zbl-field { display:flex; flex-direction:column; gap:4px; font-weight:600; }
        .zbl-field--wide { grid-column:1/-1; margin:10px 0; }
        .zbl-field em { font-weight:400; color:#646970; font-style:normal; font-size:12px; }
        .zbl-field input, .zbl-field select { width:100%; }
        .zbl-check { display:block; margin:6px 0; font-weight:600; }
        .zbl-hint { color:#646970; }
        .zbl-textarea { width:100%; font-family:monospace; }
        .zbl-table { margin:12px 0; }
        .zbl-stats { display:grid; grid-template-columns:repeat(auto-fill,minmax(160px,1fr)); gap:12px; margin:12px 0; }
        .zbl-stat { background:#f6f7f7; border-radius:10px; padding:12px 14px; display:flex; flex-direction:column; gap:4px; }
        .zbl-stat span { color:#646970; font-size:12px; }
        .zbl-stat strong { font-size:20px; }
        .zbl-big { font-size:17px; }
        .zbl-pets { margin:0; padding-inline-start:18px; }
        </style>
        <?php
    }
}
