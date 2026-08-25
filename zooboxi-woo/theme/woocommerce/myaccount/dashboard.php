<?php
/**
 * Account dashboard — the customer's own control room.
 *
 * Every figure here is derived from real orders (see zooboxi_account_stats).
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

$user   = wp_get_current_user();
$stats  = zooboxi_account_stats($user->ID);
$tier   = $stats['tier'];
$name   = zooboxi_account_display_name($user);
$hour   = (int) (new DateTimeImmutable('now', wp_timezone()))->format('G');
$hello  = $hour < 12 ? 'صباح الخير' : ($hour < 17 ? 'نهارك سعيد' : 'مساء الخير');
$freemin = zooboxi_free_shipping_min();
$shop   = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/shop/');
?>

<div class="zbx-dash">

    <p class="zbx-dash__hello"><?php echo esc_html($hello . '، ' . $name); ?> <span aria-hidden="true">👋</span></p>

    <?php /* ── 1. Recognition level + progress ───────────────────── */ ?>
    <section class="zbx-tier-card" style="--tier-1:<?php echo esc_attr($tier['c1']); ?>;--tier-2:<?php echo esc_attr($tier['c2']); ?>">
        <div class="zbx-tier-card__top">
            <span class="zbx-tier-card__badge" aria-hidden="true"><?php echo esc_html($tier['icon']); ?></span>
            <div>
                <span class="zbx-tier-card__cap">مستواك الحالي</span>
                <strong class="zbx-tier-card__name"><?php echo esc_html($tier['name']); ?></strong>
            </div>
        </div>

        <?php if ($tier['next']) : ?>
            <div class="zbx-tier-card__bar" role="progressbar"
                 aria-valuenow="<?php echo esc_attr($tier['progress']); ?>" aria-valuemin="0" aria-valuemax="100"
                 aria-label="التقدّم نحو <?php echo esc_attr($tier['next']); ?>">
                <span style="--p:<?php echo esc_attr($tier['progress']); ?>%"></span>
            </div>
            <p class="zbx-tier-card__next">
                <?php
                $left = (int) $tier['remaining'];
                echo esc_html(
                    'باقي ' . zooboxi_count_ar($left, 'طلب واحد', 'طلبان', 'طلبات', 'طلباً') .
                    ' للوصول إلى ' . $tier['next']
                );
                ?>
                <span aria-hidden="true"><?php echo esc_html($tier['next_icon']); ?></span>
            </p>
        <?php else : ?>
            <p class="zbx-tier-card__next">وصلت لأعلى مستوى — شكراً لثقتك بنا 💚</p>
        <?php endif; ?>
    </section>

    <?php /* ── 2. Live order tracker ──────────────────────────────── */ ?>
    <?php
    $active = $stats['active_order_id'] ? wc_get_order($stats['active_order_id']) : null;
    if ($active instanceof WC_Order) :
        $line     = zooboxi_order_timeline($active);
        $dtype    = (string) $active->get_meta('_zooboxi_delivery_type');
        [$dic, $dlabel, $dnote] = zooboxi_delivery_type_ar($dtype);
        $created  = $active->get_date_created();
        $items_n  = $active->get_item_count();
        ?>
        <section class="zbx-live" aria-labelledby="zbx-live-h">
            <header class="zbx-live__head">
                <h2 id="zbx-live-h" class="zbx-live__title">
                    <span class="zbx-live__dot" aria-hidden="true"></span>
                    طلبك الحالي
                </h2>
                <span class="zbx-pill zbx-pill--<?php echo esc_attr(zooboxi_status_tone($active->get_status())); ?>">
                    <?php echo esc_html($line['label']); ?>
                </span>
            </header>

            <?php if (!$line['dead']) : ?>
                <ol class="zbx-track" style="--at:<?php echo esc_attr((int) $line['at']); ?>">
                    <?php foreach ($line['steps'] as $i => $s) : ?>
                        <li class="zbx-track__step is-<?php echo esc_attr($s['state']); ?>">
                            <span class="zbx-track__ic" aria-hidden="true"><?php echo esc_html($s['icon']); ?></span>
                            <span class="zbx-track__tx">
                                <strong><?php echo esc_html($s['title']); ?></strong>
                                <em><?php echo esc_html($s['note']); ?></em>
                            </span>
                        </li>
                    <?php endforeach; ?>
                </ol>
            <?php endif; ?>

            <div class="zbx-live__facts">
                <span>طلب رقم <strong>#<?php echo esc_html($active->get_order_number()); ?></strong></span>
                <span><?php echo esc_html(zooboxi_count_ar((int) $items_n, 'صنف واحد', 'صنفان', 'أصناف', 'صنفاً')); ?></span>
                <span><?php echo wp_kses_post($active->get_formatted_order_total()); ?></span>
                <?php if ($dtype) : ?>
                    <span class="zbx-live__ship"><?php echo esc_html($dic . ' ' . $dlabel . ($dnote ? ' · ' . $dnote : '')); ?></span>
                <?php endif; ?>
                <?php if ($created) : ?>
                    <span class="zbx-live__when"><?php echo esc_html(zooboxi_ago_ar($created->getTimestamp())); ?></span>
                <?php endif; ?>
            </div>

            <a class="zbx-btn zbx-btn--ghost" href="<?php echo esc_url($active->get_view_order_url()); ?>">تتبّع الطلب</a>
        </section>
    <?php endif; ?>

    <?php /* ── 3. The numbers ─────────────────────────────────────── */ ?>
    <?php if ($stats['orders_count'] > 0) : ?>
        <section class="zbx-kpis" aria-label="ملخص حسابك">

            <article class="zbx-kpi zbx-kpi--orders">
                <span class="zbx-kpi__ic" aria-hidden="true">🧾</span>
                <strong class="zbx-kpi__n" data-count="<?php echo esc_attr($stats['orders_count']); ?>"><?php echo esc_html(number_format_i18n($stats['orders_count'])); ?></strong>
                <span class="zbx-kpi__cap">طلب أتممته</span>
            </article>

            <article class="zbx-kpi zbx-kpi--spend">
                <span class="zbx-kpi__ic" aria-hidden="true">💚</span>
                <strong class="zbx-kpi__n zbx-kpi__n--money"><?php echo wp_kses_post(wc_price($stats['total_spent'])); ?></strong>
                <span class="zbx-kpi__cap">قيمة مشترياتك</span>
                <?php
                $sm = $stats['spend_months'];
                if ($sm && max($sm) > 0) :
                    $vals = array_values($sm);
                    $max  = max($vals) ?: 1;
                    $n    = count($vals);
                    $pts  = [];
                    foreach ($vals as $i => $v) {
                        $x = $n > 1 ? ($i / ($n - 1)) * 100 : 50;
                        $y = 26 - ($v / $max) * 22;
                        $pts[] = round($x, 1) . ',' . round($y, 1);
                    }
                    $poly = implode(' ', $pts);
                    ?>
                    <svg class="zbx-kpi__spark" viewBox="0 0 100 30" preserveAspectRatio="none" aria-hidden="true" focusable="false">
                        <polygon points="0,30 <?php echo esc_attr($poly); ?> 100,30" fill="currentColor" opacity=".14"></polygon>
                        <polyline points="<?php echo esc_attr($poly); ?>" fill="none" stroke="currentColor" stroke-width="1.6"
                                  stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"></polyline>
                    </svg>
                    <span class="zbx-kpi__sub">آخر 6 أشهر</span>
                <?php endif; ?>
            </article>

            <article class="zbx-kpi zbx-kpi--items">
                <span class="zbx-kpi__ic" aria-hidden="true">📦</span>
                <strong class="zbx-kpi__n" data-count="<?php echo esc_attr($stats['items_count']); ?>"><?php echo esc_html(number_format_i18n($stats['items_count'])); ?></strong>
                <span class="zbx-kpi__cap">قطعة وصلت لبابك</span>
            </article>

            <?php if ($stats['savings'] > 0) : ?>
                <article class="zbx-kpi zbx-kpi--save">
                    <span class="zbx-kpi__ic" aria-hidden="true">🎁</span>
                    <strong class="zbx-kpi__n zbx-kpi__n--money"><?php echo wp_kses_post(wc_price($stats['savings'])); ?></strong>
                    <span class="zbx-kpi__cap">وفّرتها من الخصومات</span>
                </article>
            <?php elseif ($stats['free_shipping_count'] > 0) : ?>
                <article class="zbx-kpi zbx-kpi--save">
                    <span class="zbx-kpi__ic" aria-hidden="true">🚚</span>
                    <strong class="zbx-kpi__n" data-count="<?php echo esc_attr($stats['free_shipping_count']); ?>"><?php echo esc_html(number_format_i18n($stats['free_shipping_count'])); ?></strong>
                    <span class="zbx-kpi__cap">مرة حصلت على توصيل مجاني</span>
                </article>
            <?php else : ?>
                <article class="zbx-kpi zbx-kpi--save">
                    <span class="zbx-kpi__ic" aria-hidden="true">💳</span>
                    <strong class="zbx-kpi__n zbx-kpi__n--money"><?php echo wp_kses_post(wc_price($stats['avg_order'])); ?></strong>
                    <span class="zbx-kpi__cap">متوسط قيمة طلبك</span>
                </article>
            <?php endif; ?>

        </section>

        <p class="zbx-freeship-note">
            <span aria-hidden="true">🎁</span>
            كل طلب قيمته <strong><?php echo wp_kses_post(wc_price($freemin)); ?></strong> فأكثر — التوصيل عليه مجاني.
        </p>
    <?php endif; ?>

    <?php /* ── 4. Time to restock ─────────────────────────────────── */ ?>
    <?php
    $due = [];
    foreach (array_slice($stats['due_products'], 0, 4, true) as $pid => $info) {
        $p = wc_get_product($pid);
        if ($p && $p->is_purchasable() && $p->is_in_stock()) {
            $due[$pid] = ['p' => $p, 'i' => $info];
        }
    }
    if ($due) : ?>
        <section class="zbx-block zbx-restock" aria-labelledby="zbx-restock-h">
            <header class="zbx-block__head">
                <h2 id="zbx-restock-h"><span aria-hidden="true">🔁</span> حان وقت إعادة الطلب</h2>
                <p>حسب وتيرة شرائك السابقة، هذي الأصناف تقارب على الخلاص</p>
            </header>
            <ul class="zbx-rail">
                <?php foreach ($due as $pid => $row) :
                    $p = $row['p'];
                    ?>
                    <li class="product zbx-rail__item">
                        <a class="zbx-rail__img" href="<?php echo esc_url($p->get_permalink()); ?>">
                            <?php echo wp_kses_post($p->get_image('woocommerce_thumbnail')); ?>
                        </a>
                        <a class="zbx-rail__name" href="<?php echo esc_url($p->get_permalink()); ?>"><?php echo esc_html($p->get_name()); ?></a>
                        <span class="zbx-rail__hint">آخر طلب قبل <?php echo esc_html((int) $row['i']['since_days']); ?> يوم · عادةً كل <?php echo esc_html((int) $row['i']['avg_days']); ?> يوم</span>
                        <span class="zbx-rail__price"><?php echo wp_kses_post($p->get_price_html()); ?></span>
                        <a href="?add-to-cart=<?php echo esc_attr($pid); ?>"
                           data-quantity="1" data-product_id="<?php echo esc_attr($pid); ?>"
                           class="button add_to_cart_button ajax_add_to_cart zbx-rail__add"
                           rel="nofollow">أضف للسلة</a>
                    </li>
                <?php endforeach; ?>
            </ul>
        </section>
    <?php endif; ?>

    <?php /* ── 5. Your favourites ─────────────────────────────────── */ ?>
    <?php
    $fav = [];
    foreach ($stats['products'] as $pid => $row) {
        if (count($fav) >= 6) {
            break;
        }
        if (isset($due[$pid])) {
            continue;               // already surfaced above
        }
        $p = wc_get_product($pid);
        if ($p && $p->is_purchasable() && $p->is_in_stock()) {
            $fav[$pid] = ['p' => $p, 'n' => $row['orders']];
        }
    }
    if ($fav) : ?>
        <section class="zbx-block" aria-labelledby="zbx-fav-h">
            <header class="zbx-block__head">
                <h2 id="zbx-fav-h"><span aria-hidden="true">⭐</span> الأكثر طلباً عندك</h2>
                <p>أضفها للسلة بضغطة واحدة</p>
            </header>
            <ul class="zbx-rail">
                <?php foreach ($fav as $pid => $row) :
                    $p = $row['p'];
                    ?>
                    <li class="product zbx-rail__item">
                        <a class="zbx-rail__img" href="<?php echo esc_url($p->get_permalink()); ?>">
                            <?php echo wp_kses_post($p->get_image('woocommerce_thumbnail')); ?>
                            <?php if ($row['n'] > 1) : ?>
                                <span class="zbx-rail__times">طلبته <?php echo esc_html((int) $row['n']); ?> مرات</span>
                            <?php endif; ?>
                        </a>
                        <a class="zbx-rail__name" href="<?php echo esc_url($p->get_permalink()); ?>"><?php echo esc_html($p->get_name()); ?></a>
                        <span class="zbx-rail__price"><?php echo wp_kses_post($p->get_price_html()); ?></span>
                        <a href="?add-to-cart=<?php echo esc_attr($pid); ?>"
                           data-quantity="1" data-product_id="<?php echo esc_attr($pid); ?>"
                           class="button add_to_cart_button ajax_add_to_cart zbx-rail__add"
                           rel="nofollow">أضف للسلة</a>
                    </li>
                <?php endforeach; ?>
            </ul>
        </section>
    <?php endif; ?>

    <?php /* ── 6. First-time state ────────────────────────────────── */ ?>
    <?php if ($stats['orders_count'] === 0) : ?>
        <section class="zbx-welcome">
            <span class="zbx-welcome__ic" aria-hidden="true">🐾</span>
            <h2>أهلاً بك في زوبوكسي</h2>
            <p>حسابك جاهز. أول طلب لك يفتح لوحتك — عدد الطلبات، قيمة مشترياتك، وأصنافك المفضّلة بضغطة واحدة.</p>
            <ul class="zbx-welcome__perks">
                <li><span aria-hidden="true">⚡</span> توصيل خلال ساعتين داخل الرياض</li>
                <li><span aria-hidden="true">🎁</span> توصيل مجاني للطلبات فوق <?php echo wp_kses_post(wc_price($freemin)); ?></li>
                <li><span aria-hidden="true">🔁</span> إعادة الطلب بضغطة من صفحة مشترياتي</li>
            </ul>
            <a class="zbx-btn zbx-btn--solid" href="<?php echo esc_url($shop); ?>">ابدأ التسوّق</a>
        </section>
    <?php endif; ?>

    <?php /* ── 7. Quick actions ───────────────────────────────────── */ ?>
    <nav class="zbx-quick" aria-label="اختصارات">
        <a href="<?php echo esc_url(wc_get_account_endpoint_url('orders')); ?>">
            <span aria-hidden="true">🧾</span><strong>طلباتي</strong><em>تتبّع وتفاصيل</em>
        </a>
        <a href="<?php echo esc_url(wc_get_account_endpoint_url('my-products')); ?>">
            <span aria-hidden="true">🛍️</span><strong>مشترياتي</strong><em>أعد الطلب بضغطة</em>
        </a>
        <a href="<?php echo esc_url(wc_get_account_endpoint_url('edit-address')); ?>">
            <span aria-hidden="true">📍</span><strong>عناويني</strong><em>مواقع التوصيل</em>
        </a>
        <a href="mailto:info@zooboxi.com">
            <span aria-hidden="true">💬</span><strong>الدعم</strong><em>نساعدك بسرعة</em>
        </a>
    </nav>

    <?php
    do_action('woocommerce_account_dashboard');
    do_action('woocommerce_before_my_account');
    do_action('woocommerce_after_my_account');
    ?>
</div>
