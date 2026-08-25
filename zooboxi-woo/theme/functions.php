<?php
/**
 * Zooboxi Child Theme for Astra
 */

// ═══════════ MODULES ═══════════
require_once get_stylesheet_directory() . '/inc/zbx-account.php';
require_once get_stylesheet_directory() . '/inc/zbx-wishlist.php';
require_once get_stylesheet_directory() . '/inc/zbx-card.php';
require_once get_stylesheet_directory() . '/inc/zbx-stock-order.php';

// ═══════════ STYLES & SCRIPTS ═══════════
add_action('wp_enqueue_scripts', function () {
    wp_enqueue_style('zooboxi-child', get_stylesheet_uri(), ['astra-theme-css'], time());
    wp_enqueue_style('google-fonts', 'https://fonts.googleapis.com/css2?family=Baloo+Bhaijaan+2:wght@600;700;800&family=El+Messiri:wght@400;500;600;700&family=Tajawal:wght@400;500;600;700;800&display=swap', [], null);
    wp_enqueue_script('zooboxi-delight', get_stylesheet_directory_uri() . '/js/zbx-delight.js', ['jquery'], time(), true);
    if (function_exists('is_checkout') && is_checkout()) {
        wp_enqueue_script('zooboxi-checkout', get_stylesheet_directory_uri() . '/js/zbx-checkout.js', ['jquery'], time(), true);
    }
});

// ═══════════ TOAST NOTIFICATION AUTO-DISMISS ═══════════
add_action('wp_footer', function () {
?>
<script>
(function(){
    function autoDismissNotices() {
        var notices = document.querySelectorAll('.woocommerce-message, .woocommerce-error, .woocommerce-info, .wc-block-components-notice-banner');
        notices.forEach(function(n) {
            if (n.dataset.zbxToast) return;
            n.dataset.zbxToast = '1';
            setTimeout(function(){
                n.classList.add('zbx-toast-dismiss');
                setTimeout(function(){ n.remove(); }, 400);
            }, 5000);
        });
    }
    // Run on load + watch for dynamically added notices
    document.addEventListener('DOMContentLoaded', autoDismissNotices);
    var observer = new MutationObserver(autoDismissNotices);
    observer.observe(document.body, { childList: true, subtree: true });
})();
</script>
<?php
}, 999);

// ═══════════ EXACT ZID HEADER REPLACEMENT ═══════════
// Force Full Width Stretched Layout for the Front Page in Astra
add_filter('astra_get_content_layout', function($layout) {
    if (is_front_page()) {
        return 'page-builder'; // Astra stretched layout
    }
    return $layout;
});

add_filter('astra_page_layout', function($sidebar) {
    if (is_front_page()) {
        return 'no-sidebar';
    }
    return $sidebar;
});

// Remove Astra Default Header
add_action('init', function() {
    remove_action('astra_header', 'astra_header_markup');
});

// Inject our exact custom header
add_action('astra_header', 'zooboxi_custom_exact_header');

function zooboxi_custom_exact_header() {
    $cookie_city = $_COOKIE['zooboxi_city'] ?? '';
    $cookie_district = $_COOKIE['zooboxi_district'] ?? '';
    $cookie_branch = $_COOKIE['zooboxi_branch'] ?? '';
    $cookie_express = $_COOKIE['zooboxi_express'] ?? '';
    $has_location = !empty($cookie_city);
    
    if ($has_location) {
        $location_text = function_exists('zooboxi_city_ar') ? zooboxi_city_ar($cookie_city) : $cookie_city;
        if (!empty($cookie_district)) {
            $location_text .= '، ' . $cookie_district;
        }
    } else {
        $location_text = 'تحديد الموقع';
    }

    $cart_count = WC()->cart ? WC()->cart->get_cart_contents_count() : 0;
    $fav_count  = function_exists('zooboxi_wishlist_count') ? zooboxi_wishlist_count() : 0;
    $upload_dir = wp_upload_dir();
    $logo_url = $upload_dir['baseurl'] . '/zooboxi-assets/ceb32bf7-abc5-4b15-b88f-9002f9eb27c9-200x.png';

    // SVG Icons
    $icon_search = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#d46856" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>';
    $icon_menu = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#d46856" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="12" x2="21" y2="12"></line><line x1="3" y1="6" x2="21" y2="6"></line><line x1="3" y1="18" x2="21" y2="18"></line></svg>';
    $icon_cart = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#d46856" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path><line x1="3" y1="6" x2="21" y2="6"></line><path d="M16 10a4 4 0 0 1-8 0"></path></svg>';
    $icon_user = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#d46856" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>';
    $icon_heart = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#d46856" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path></svg>';
    $icon_globe = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#d46856" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="2" y1="12" x2="22" y2="12"></line><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"></path></svg>';
    $icon_pin = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#d46856" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>';

    // Dynamically fetch Polylang languages
    $lang_html = '';
    if (function_exists('pll_the_languages')) {
        $languages = pll_the_languages(['raw' => 1]);
        if (!empty($languages)) {
            foreach ($languages as $lang) {
                $active_class = $lang['current_lang'] ? 'class="active"' : '';
                $lang_html .= '<a href="' . esc_url($lang['url']) . '" ' . $active_class . '>' . esc_html($lang['name']) . '</a>';
            }
        }
    }
    if (empty($lang_html)) {
        $lang_html = '<a href="#" class="active">العربية</a><a href="#">English</a>';
    }

    // Build WP menu items for the drawer
    $menu_items = wp_get_nav_menu_items('new');
    $menu_links = '';
    if (!empty($menu_items)) {
        foreach ($menu_items as $item) {
            $menu_links .= '<a href="' . esc_url($item->url) . '" class="zbx-drawer-link">' . esc_html($item->title) . '</a>';
        }
    } else {
        $menu_links = '
            <a href="' . home_url('/') . '" class="zbx-drawer-link">🏠 ' . __('الرئيسية', 'zooboxi') . '</a>
            <a href="' . wc_get_page_permalink('shop') . '" class="zbx-drawer-link">🛍️ ' . __('المتجر', 'zooboxi') . '</a>
            <a href="' . wc_get_page_permalink('myaccount') . '" class="zbx-drawer-link">👤 ' . __('حسابي', 'zooboxi') . '</a>
            <a href="' . esc_url(function_exists('wc_get_account_endpoint_url') ? wc_get_account_endpoint_url('wishlist') : wc_get_page_permalink('myaccount')) . '" class="zbx-drawer-link">💚 ' . __('المفضلة', 'zooboxi') . '</a>
            <a href="' . wc_get_cart_url() . '" class="zbx-drawer-link">🛒 ' . __('السلة', 'zooboxi') . '</a>
            <a href="' . wc_get_page_permalink('checkout') . '" class="zbx-drawer-link">💳 ' . __('إتمام الطلب', 'zooboxi') . '</a>';
    }

    // Category links for drawer
    $categories = get_terms(['taxonomy' => 'product_cat', 'parent' => 0, 'hide_empty' => true, 'number' => 8]);
    $cat_links = '';
    if (!is_wp_error($categories)) {
        foreach ($categories as $cat) {
            $cat_links .= '<a href="' . esc_url(get_term_link($cat)) . '" class="zbx-drawer-cat">' . esc_html($cat->name) . '</a>';
        }
    }

    echo '<header class="zooboxi-site-header">
        <div class="zooboxi-announcement-bar">
            <div class="zooboxi-marquee">
                <div class="zooboxi-marquee__content">
                    <span>🚀 اطلب بـ250+ ريال وخلّ التوصيل علينا!</span>
                    <span>🔥 خصم 20٪ لأول طلب! استخدم كود: <strong>hiboxi</strong></span>
                    <span>🚀 اطلب بـ250+ ريال وخلّ التوصيل علينا!</span>
                    <span>🔥 خصم 20٪ لأول طلب! استخدم كود: <strong>hiboxi</strong></span>
                </div>
            </div>
        </div>

        <div class="zooboxi-header-main">
            <div class="zbx-header-row">
                <div class="zbx-header-right">
                    <a href="#" class="icon-btn zbx-search-btn" aria-label="بحث">' . $icon_search . '</a>
                    <button id="zooboxi-menu-trigger" class="icon-btn zbx-menu-btn" aria-label="القائمة">' . $icon_menu . '</button>
                </div>

                <div class="zbx-header-center">
                    <a href="' . home_url('/') . '"><img src="' . esc_url($logo_url) . '" alt="Zooboxi" class="zbx-logo"></a>
                </div>

                <div class="zbx-header-left">
                    <button id="zooboxi-location-trigger" class="icon-btn zbx-location-btn" title="تغيير موقع التوصيل">
                        ' . $icon_pin . '
                        <span class="zbx-city-text">' . esc_html($location_text) . '</span>
                    </button>

                    <div class="zooboxi-lang-wrapper">
                        <button id="zooboxi-lang-trigger" class="icon-btn" title="تغيير اللغة">
                            ' . $icon_globe . '
                        </button>
                        <div id="zooboxi-lang-menu" class="zooboxi-lang-dropdown">
                            ' . $lang_html . '
                        </div>
                    </div>

                    <a href="' . esc_url(function_exists('wc_get_account_endpoint_url') ? wc_get_account_endpoint_url('wishlist') : wc_get_page_permalink('myaccount')) . '" class="icon-btn zbx-hide-mobile zbx-fav-link" title="' . esc_attr__('المفضلة', 'zooboxi') . '">' . $icon_heart . '
                        <span class="count zbx-fav-count' . ($fav_count ? '' : ' is-empty') . '">' . esc_html($fav_count) . '</span>
                    </a>
                    <a href="' . wc_get_page_permalink('myaccount') . '" class="icon-btn zbx-hide-mobile">' . $icon_user . '</a>
                    <a href="' . wc_get_cart_url() . '" class="icon-btn cart-btn">
                        ' . $icon_cart . '
                        <span class="count zooboxi-cart-count">' . $cart_count . '</span>
                    </a>
                </div>
            </div>
        </div>
    </header>';

    // ═══ MOBILE LOCATION INFO BAR ═══
    if ($has_location) {
        $cookie_dtype = $_COOKIE['zooboxi_delivery_type'] ?? '';
        $address_display = esc_html($location_text);
        $branch_display = !empty($cookie_branch) ? esc_html($cookie_branch) : __('غير محدد', 'zooboxi');
        
        // Determine delivery info from delivery_type cookie
        if ($cookie_dtype === 'express') {
            $delivery_label = __('خلال ساعتين ⚡', 'zooboxi');
            $delivery_class = 'zbx-info-express-on';
        } elseif ($cookie_dtype === 'same_day') {
            $delivery_label = __('توصيل خلال 24 ساعة 🚚', 'zooboxi');
            $delivery_class = 'zbx-info-standard';
        } else {
            // shipping or unknown
            $delivery_label = __('شحن 4-5 أيام عمل 📦', 'zooboxi');
            $delivery_class = 'zbx-info-shipping';
        }

        echo '<div class="zbx-mobile-info-bar">
            <div class="zbx-info-item">
                <span class="zbx-info-icon">📍</span>
                <span class="zbx-info-text">' . $address_display . '</span>
            </div>
            <div class="zbx-info-sep">|</div>
            <div class="zbx-info-item">
                <span class="zbx-info-icon">🏪</span>
                <span class="zbx-info-text">' . $branch_display . '</span>
            </div>
            <div class="zbx-info-sep">|</div>
            <div class="zbx-info-item ' . $delivery_class . '">
                <span class="zbx-info-text">' . $delivery_label . '</span>
            </div>
        </div>';
    }

    echo '
    <!-- ═══ CUSTOM MOBILE DRAWER ═══ -->
    <div id="zbx-drawer-overlay" class="zbx-drawer-overlay"></div>
    <div id="zbx-drawer" class="zbx-drawer">
        <div class="zbx-drawer-header">
            <img src="' . esc_url($logo_url) . '" alt="Zooboxi" class="zbx-drawer-logo">
            <button id="zbx-drawer-close" class="zbx-drawer-close">✕</button>
        </div>
        <div class="zbx-drawer-body">
            <div class="zbx-drawer-section">
                <div class="zbx-drawer-section-title">📋 ' . __('القائمة', 'zooboxi') . '</div>
                ' . $menu_links . '
            </div>
            <div class="zbx-drawer-divider"></div>
            <div class="zbx-drawer-section">
                <div class="zbx-drawer-section-title">🐾 ' . __('الأقسام', 'zooboxi') . '</div>
                <div class="zbx-drawer-cats">' . $cat_links . '</div>
            </div>
            <div class="zbx-drawer-divider"></div>
            <div class="zbx-drawer-section">
                <div class="zbx-drawer-section-title">🌐 ' . __('اللغة', 'zooboxi') . '</div>
                <div class="zbx-drawer-langs">' . $lang_html . '</div>
            </div>
        </div>
        <div class="zbx-drawer-footer">
            <a href="' . wc_get_page_permalink('myaccount') . '" class="zbx-drawer-footer-btn">👤 ' . __('حسابي', 'zooboxi') . '</a>
            <a href="' . wc_get_cart_url() . '" class="zbx-drawer-footer-btn">🛒 ' . __('السلة', 'zooboxi') . ' <span class="zooboxi-cart-count">' . $cart_count . '</span></a>
        </div>
    </div>';
}

// ═══════════ LOCATION & LANGUAGE POPUP JS ═══════════
add_action('wp_footer', function() {
    echo "<script>
        document.addEventListener('DOMContentLoaded', function() {
            // Location Modal Trigger
            var locBtn = document.getElementById('zooboxi-location-trigger');
            var locModal = document.getElementById('zooboxi-location-modal');
            if(locBtn && locModal) {
                locBtn.addEventListener('click', function(e) {
                    e.preventDefault();
                    locModal.style.display = 'flex';
                });
            }

            // Language Dropdown Toggle
            var langBtn = document.getElementById('zooboxi-lang-trigger');
            var langMenu = document.getElementById('zooboxi-lang-menu');
            if(langBtn && langMenu) {
                langBtn.addEventListener('click', function(e) {
                    e.stopPropagation();
                    langMenu.classList.toggle('show');
                });
                
                document.addEventListener('click', function() {
                    langMenu.classList.remove('show');
                });

                langMenu.addEventListener('click', function(e) {
                    e.stopPropagation();
                });
            }

            // ═══ CUSTOM DRAWER ═══
            var menuBtn = document.getElementById('zooboxi-menu-trigger');
            var drawer = document.getElementById('zbx-drawer');
            var drawerOverlay = document.getElementById('zbx-drawer-overlay');
            var drawerClose = document.getElementById('zbx-drawer-close');

            function openDrawer() {
                drawer.classList.add('open');
                drawerOverlay.classList.add('open');
                document.body.style.overflow = 'hidden';
            }
            function closeDrawer() {
                drawer.classList.remove('open');
                drawerOverlay.classList.remove('open');
                document.body.style.overflow = '';
            }

            if(menuBtn) menuBtn.addEventListener('click', function(e) { e.preventDefault(); openDrawer(); });
            if(drawerClose) drawerClose.addEventListener('click', closeDrawer);
            if(drawerOverlay) drawerOverlay.addEventListener('click', closeDrawer);
        });
    </script>";
}, 100);

// ═══════════ PRODUCT OPTIONS — CHOICE CARDS WITH PRICES ═══════════
// Woo's <select> hides the one fact that decides the purchase: what each
// option costs. Render real choice cards (label + price + stock) instead.
add_action('wp_footer', function () {
    if (!is_product()) return;
    ?>
    <script>
    jQuery(function ($) {
        var emojiMap = {
            'كرتون':'📦','صندوق':'📦','حبة':'🥫','حبات':'🥫','قطعة':'🥫','عبوة':'🥫','علبة':'🥫','كيس':'🛍️',
            'carton':'📦','box':'📦','pack':'📦','piece':'🥫','pcs':'🥫',
            'صغير':'🐾','وسط':'🐕','كبير':'🦁','ضخم':'🐘',
            'small':'🐾','medium':'🐕','large':'🦁',
            'دجاج':'🍗','لحم':'🥩','سمك':'🐟','سلمون':'🐟','تونة':'🐟','جمبري':'🦐',
            'chicken':'🍗','beef':'🥩','fish':'🐟','salmon':'🐟','tuna':'🐟'
        };
        function getEmoji(text) {
            var lower = (text || '').toLowerCase();
            for (var k in emojiMap) { if (lower.indexOf(k.toLowerCase()) !== -1) return emojiMap[k]; }
            return '🏷️';
        }

        var $form = $('form.variations_form');
        if (!$form.length) return;

        var variations = [];
        try { variations = $form.data('product_variations') || JSON.parse($form.attr('data-product_variations') || '[]'); } catch (e) { variations = []; }
        var $selects = $form.find('.variations select');
        var singleAttribute = $selects.length === 1;

        function infoFor(attrName, value) {
            if (!singleAttribute || !variations || !variations.length) return null;
            for (var i = 0; i < variations.length; i++) {
                var a = variations[i].attributes || {};
                if (String(a[attrName] || '').toLowerCase() === String(value).toLowerCase()) return variations[i];
            }
            return null;
        }

        $selects.each(function () {
            var $select = $(this);
            if ($select.data('swatch-done')) return;
            $select.data('swatch-done', true);
            $select.hide();

            var attrName = $select.attr('name');
            var $group = $('<div class="zbx-swatch-group"></div>');
            var count = 0;

            $select.find('option').each(function () {
                var val = $(this).val();
                if (!val) return;
                count++;
                var label = $(this).text();
                var info = infoFor(attrName, val);
                var priceHtml = info && info.price_html ? info.price_html : '';
                var outOfStock = info ? (info.is_in_stock === false) : false;

                var $btn = $('<button type="button" class="zbx-swatch-btn"></button>')
                    .attr('data-value', val)
                    .toggleClass('zbx-swatch-oos', outOfStock)
                    .append($('<span class="zbx-swatch-emoji" aria-hidden="true"></span>').text(getEmoji(label)))
                    .append($('<span class="zbx-swatch-body"></span>')
                        .append($('<span class="zbx-swatch-label"></span>').text(label))
                        .append(priceHtml ? $('<span class="zbx-swatch-price"></span>').html(priceHtml) : '')
                        .append(outOfStock ? $('<span class="zbx-swatch-oos-note"></span>').text('غير متوفر') : ''));
                $group.append($btn);
            });

            var $parent = $select.closest('td.value');
            ($parent.length ? $parent : $select.parent()).append($group);

            $group.on('click', '.zbx-swatch-btn', function (e) {
                e.preventDefault();
                var $btn = $(this);
                if ($btn.hasClass('zbx-swatch-oos')) return;
                if ($btn.hasClass('zbx-swatch-active')) {
                    $btn.removeClass('zbx-swatch-active');
                    $select.val('').trigger('change');
                } else {
                    $group.find('.zbx-swatch-btn').removeClass('zbx-swatch-active');
                    $btn.addClass('zbx-swatch-active');
                    $select.val($btn.attr('data-value')).trigger('change');
                }
                syncHint();
            });

            $select.on('change', function () {
                var v = $(this).val();
                $group.find('.zbx-swatch-btn').removeClass('zbx-swatch-active');
                if (v) $group.find('.zbx-swatch-btn[data-value="' + v + '"]').addClass('zbx-swatch-active');
                syncHint();
            });

            // a single option is not a choice — pick it for the customer
            if (count === 1) {
                $group.find('.zbx-swatch-btn').first().trigger('click');
            }
        });

        // Tell the customer WHY the button is asleep
        var $hint = $('<div class="zbx-choose-hint">👆 اختر أحد الخيارات بالأعلى لعرض السعر وإضافة المنتج</div>');
        $form.find('.woocommerce-variation-add-to-cart, .single_variation_wrap').first().before($hint);

        function syncHint() {
            var chosen = true;
            $selects.each(function () { if (!$(this).val()) chosen = false; });
            $hint.toggle(!chosen);
        }
        syncHint();
        $form.on('found_variation', function () { $hint.hide(); })
             .on('reset_data', function () { syncHint(); });
    });
    </script>
    <?php
}, 50);

// ═══════════ PRODUCT PAGE CLEANUP ═══════════
// Hide the SKU line when there is no SKU (it printed "رمز المنتج: غير محدد").
add_filter('wc_product_sku_enabled', function ($enabled) {
    if (!is_product()) return $enabled;
    global $product;
    return ($product instanceof WC_Product && $product->get_sku()) ? $enabled : false;
});

// A clearer label than the raw attribute name ("اختر").
add_filter('woocommerce_attribute_label', function ($label, $name) {
    if (get_locale() !== 'ar') return $label;
    $n = strtolower((string) $name);
    if ($n === 'pa_choose-opt' || trim((string) $label) === 'اختر') {
        return 'اختر الخيار';
    }
    return $label;
}, 10, 2);

// ═══════════ STICKY HEADER SHADOW ═══════════
add_action('wp_footer', function() {
    echo '<script>
    (function(){
        var h=document.querySelector(".zooboxi-site-header");
        if(!h)return;
        // Add body padding to compensate for fixed header
        function setPad(){ document.body.style.paddingTop = h.offsetHeight + "px"; }
        setPad();
        window.addEventListener("resize", setPad);
        window.addEventListener("scroll",function(){
            h.classList.toggle("is-stuck",window.scrollY>10);
        },{passive:true});
    })();
    </script>';
}, 5);

// ═══════════ THEME COLOR & RIYAL SVG ═══════════
add_action('wp_head', function () {
    echo '<meta name="theme-color" content="#429d9c">';
    echo '<script>
    document.addEventListener("DOMContentLoaded",function(){
        const riyalSVG = \'<svg class="riyal-svg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1124.14 1256.39" width="14" height="16" style="display:inline-block;vertical-align:-0.125em"><path fill="currentColor" d="M699.62,1113.02h0c-20.06,44.48-33.32,92.75-38.4,143.37l424.51-90.24c20.06-44.47,33.31-92.75,38.4-143.37l-424.51,90.24Z"/><path fill="currentColor" d="M1085.73,895.8c20.06-44.47,33.32-92.75,38.4-143.37l-330.68,70.33v-135.2l292.27-62.11c20.06-44.47,33.32-92.75,38.4-143.37l-330.68,70.27V66.13c-50.67,28.45-95.67,66.32-132.25,110.99v403.35l-132.25,28.11V0c-50.67,28.44-95.67,66.32-132.25,110.99v525.69l-295.91,62.88c-20.06,44.47-33.33,92.75-38.42,143.37l334.33-71.05v170.26l-358.3,76.14c-20.06,44.47-33.32,92.75-38.4,143.37l375.04-79.7c30.53-6.35,56.77-24.4,73.83-49.24l68.78-101.97v-.02c7.14-10.55,11.3-23.27,11.3-36.97v-149.98l132.25-28.11v270.4l424.53-90.28Z"/></svg>\';
        var isRunning=false;
        function replaceCurrency(){
            if(isRunning)return;
            isRunning=true;
            var walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,null,false);
            var node;
            var toReplace=[];
            while(node=walker.nextNode()){
                var parent=node.parentNode;
                if(parent.nodeName==="SCRIPT"||parent.nodeName==="STYLE")continue;
                if(parent.closest && parent.closest(".zooboxi-delivery-badge,.zooboxi-badge-icon,.zooboxi-badge-text"))continue;
                var text=node.nodeValue;
                if(text.indexOf("ر.س")>-1||text.indexOf("SAR")>-1){
                    toReplace.push(node);
                }
            }
            toReplace.forEach(function(n){
                var span=document.createElement("span");
                span.innerHTML=n.nodeValue.replace(/ر\.س/g,riyalSVG).replace(/SAR/g,riyalSVG);
                n.parentNode.replaceChild(span,n);
            });
            isRunning=false;
        }
        replaceCurrency();
        var debounceTimer;
        new MutationObserver(function(){clearTimeout(debounceTimer);debounceTimer=setTimeout(replaceCurrency,100);}).observe(document.body,{childList:true,subtree:true});
    });
    </script>';
});

// ═══════════ IMAGE FALLBACK ═══════════
function zooboxi_get_image_url($product) {
    $url = get_post_meta($product->get_id(), '_zooboxi_image_url', true);
    if (!empty($url)) return $url;
    $sap_code = get_post_meta($product->get_id(), '_zooboxi_item_code', true);
    if (!empty($sap_code)) return "https://gal.holeno.com/imghd/{$sap_code}.png";
    return '';
}

function zooboxi_get_ppte_url($product) {
    $sap_code = get_post_meta($product->get_id(), '_zooboxi_item_code', true);
    if (!empty($sap_code)) {
        $folder = substr($sap_code, 0, 4);
        return "https://ppte.sa/imghd/{$folder}/{$sap_code}.png";
    }
    return '';
}

add_filter('woocommerce_product_get_image', function ($image, $product, $size) {
    if ($product->get_image_id()) return $image;
    $url = zooboxi_get_image_url($product);
    if (empty($url)) return $image;
    $alt = esc_attr($product->get_name());
    $placeholder = esc_url(wc_placeholder_img_src());
    $ppte_url = esc_url(zooboxi_get_ppte_url($product));
    $onerror = $ppte_url 
        ? "this.onerror=function(){this.onerror=null;this.src='{$placeholder}';};this.src='{$ppte_url}';"
        : "this.onerror=null;this.src='{$placeholder}';";
    return '<img src="' . esc_url($url) . '" alt="' . $alt . '" class="attachment-woocommerce_thumbnail wp-post-image zooboxi-external-img" loading="lazy" onerror="' . esc_attr($onerror) . '" />';
}, 10, 3);

// ═══════════ DYNAMIC FREE SHIPPING PROGRESS BAR ═══════════
add_action('woocommerce_before_cart_totals', function() {
    if (!WC()->cart) return;
    
    $cart_subtotal = WC()->cart->get_subtotal();
    // Single source of truth: read the same threshold the shipping methods use
    // (Zooboxi plugin option), so the bar and the actual free-shipping never disagree.
    $free_shipping_threshold = (float) get_option('zooboxi_free_shipping_min', 200);
    
    echo '<div class="zooboxi-shipping-progress-wrapper">';
    if ($cart_subtotal >= $free_shipping_threshold) {
        echo '<div class="zooboxi-shipping-progress-msg zbx-ship-won">';
        echo '<span class="zbx-ship-icon" aria-hidden="true">🎉</span>';
        echo '<span>توصيلك <strong>مجاني</strong> على هذا الطلب</span>';
        echo '</div>';
        echo '<div class="zooboxi-shipping-progress-bar is-full"><span style="width:100%"></span></div>';
    } else {
        $remaining   = $free_shipping_threshold - $cart_subtotal;
        $percentage  = max(4, min(100, ($cart_subtotal / $free_shipping_threshold) * 100));
        echo '<div class="zooboxi-shipping-progress-msg">';
        echo '<span class="zbx-ship-icon" aria-hidden="true">🚚</span>';
        echo '<span>أضف <strong>' . wc_price($remaining) . '</strong> ليصبح توصيلك مجانياً</span>';
        echo '</div>';
        echo '<div class="zooboxi-shipping-progress-bar"><span style="width: ' . $percentage . '%;"></span></div>';
    }
    echo '</div>';
});

// ═══════════ WOOCOMMERCE CART LOCALIZATION ═══════════
add_filter('gettext', function($translated_text, $text, $domain) {
    if ($domain === 'woocommerce') {
        if (get_locale() === 'ar') {
            switch ($text) {
                case 'Cart totals':
                case 'Cart Totals':
                    return 'ملخص الإجمالي';
                case 'Apply coupon':
                    return 'تطبيق';
                case 'Coupon code':
                    return 'أدخل قسيمة الخصم';
                case 'Proceed to checkout':
                case 'Proceed to Checkout':
                    return 'إتمام الطلب';
                case 'Subtotal':
                    return 'المجموع الفرعي';
                case 'Total':
                    return 'المجموع';
                case 'Tax':
                    return 'ضريبة';
                case 'VAT':
                    return 'ضريبة القيمة المضافة';
                case 'Product':
                    return 'المنتج';
                case 'Quantity':
                    return 'الكمية';
                case 'Price':
                    return 'السعر';
                case 'Shipping':
                case 'Shipment':
                    return 'الشحن';
                case 'Select options':
                    return 'خيارات المنتج';
                case 'Add to cart':
                    return 'أضف للسلة';
                case 'Update cart':
                    return 'تحديث السلة';
                case 'Remove this item':
                    return 'إزالة';
                case 'Shipping options will be updated during checkout.':
                    return 'سيتم تحديث خيارات الشحن عند إتمام الطلب.';
            }
            // Fix "includes VAT/Tax"
            if (strpos($text, 'includes') !== false) {
                $translated = str_replace('includes', 'يشمل', $text);
                $translated = str_replace('VAT', 'ضريبة القيمة المضافة', $translated);
                $translated = str_replace('Tax', 'ضريبة', $translated);
                return $translated;
            }
        }
    }
    return $translated_text;
}, 20, 3);

// ═══════════ CUSTOM PROCEED TO CHECKOUT BUTTONS ═══════════
add_action('woocommerce_proceed_to_checkout', function() {
    $gift_svg = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display: inline-block; vertical-align: middle;"><polyline points="20 12 20 22 4 22 4 12"></polyline><rect x="2" y="7" width="20" height="5"></rect><line x1="12" y1="22" x2="12" y2="7"></line><path d="M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7z"></path><path d="M12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z"></path></svg>';
    
    $gift_text = (get_locale() === 'ar') ? 'اجعلها هدية' : 'Make it a gift';
    $continue_text = (get_locale() === 'ar') ? 'متابعة التسوق' : 'Continue Shopping';
    
    $shop_url = wc_get_page_permalink('shop');
    
    echo '<a href="#" class="button gift-button" style="margin-top: 12px; display: flex; align-items: center; justify-content: center; gap: 8px;">';
    echo '<span>' . $gift_text . '</span>';
    echo $gift_svg;
    echo '</a>';
    
    echo '<a href="' . esc_url($shop_url) . '" class="button continue-shopping" style="margin-top: 12px;">' . $continue_text . '</a>';
}, 30);

// ═══════════ QUANTITY INCREMENT DECREMENT BUTTONS ═══════════
add_action('wp_footer', function() {
    if (!is_cart()) return;
    ?>
    <script>
    jQuery(document).ready(function($) {
        function addQtyButtons() {
            $('.woocommerce-cart .quantity').each(function() {
                var $qty = $(this);
                if ($qty.find('.plus-btn').length === 0) {
                    $qty.prepend('<button type="button" class="qty-btn plus-btn" style="background:none;border:none;font-weight:bold;cursor:pointer;padding:0 8px;font-size:20px;color:#64748b;line-height:1;height:100%;">+</button>');
                }
                if ($qty.find('.minus-btn').length === 0) {
                    $qty.append('<button type="button" class="qty-btn minus-btn" style="background:none;border:none;font-weight:bold;cursor:pointer;padding:0 8px;font-size:20px;color:#64748b;line-height:1;height:100%;">-</button>');
                }
                // Styling input field
                $qty.find('input.qty').css({
                    'width': '40px',
                    'text-align': 'center',
                    'border': 'none',
                    'background': 'transparent',
                    'font-weight': 'bold',
                    'font-size': '16px',
                    'padding': '0',
                    'margin': '0',
                    'height': '100%',
                    '-moz-appearance': 'textfield'
                });
            });
        }
        
        addQtyButtons();
        
        $(document).on('click', '.qty-btn', function(e) {
            e.preventDefault();
            var $btn = $(this);
            var $input = $btn.parent().find('input.qty');
            var val = parseFloat($input.val()) || 0;
            var step = parseFloat($input.attr('step')) || 1;
            var min = parseFloat($input.attr('min')) || 0;
            var max = parseFloat($input.attr('max')) || 999999;
            
            var newVal = val;
            if ($btn.hasClass('plus-btn')) {
                newVal = val + step;
                if (newVal <= max) {
                    $input.val(newVal).trigger('change');
                }
            } else {
                newVal = val - step;
                if (newVal >= min) {
                    $input.val(newVal).trigger('change');
                }
            }
            
            // Auto update cart on change
            if (newVal !== val) {
                clearTimeout(window.wc_cart_update_timer);
                window.wc_cart_update_timer = setTimeout(function() {
                    $('[name="update_cart"]').prop('disabled', false).trigger('click');
                }, 400);
            }
        });
        
        $(document).on('ajaxComplete wc_fragments_refreshed wc_fragments_loaded', function() {
            addQtyButtons();
        });
    });
    </script>
    <style>
    /* Hide default spin buttons */
    .woocommerce-cart .quantity input.qty::-webkit-outer-spin-button,
    .woocommerce-cart .quantity input.qty::-webkit-inner-spin-button {
        -webkit-appearance: none !important;
        margin: 0 !important;
    }
    .woocommerce-cart .quantity input.qty {
        -moz-appearance: textfield !important;
    }
    </style>
    <?php
}, 100);

// ═══════════ TRANSLATE DYNAMIC TAX LABEL (VAT) ═══════════
add_filter('woocommerce_rate_label', function($label, $rate_id) {
    if (get_locale() === 'ar' && (strtolower($label) === 'vat' || strtolower($label) === 'value added tax')) {
        return 'ضريبة القيمة المضافة';
    }
    return $label;
}, 10, 2);

// ═══════════ AJAX FRAGMENTS FOR CART COUNT ═══════════
add_filter('woocommerce_add_to_cart_fragments', function($fragments) {
    $cart_count = WC()->cart ? WC()->cart->get_cart_contents_count() : 0;
    $fragments['span.zooboxi-cart-count'] = '<span class="count zooboxi-cart-count" style="position:absolute; top:-5px; right:-5px; background:#000; color:#fff; border-radius:50%; font-size:10px; font-weight:bold; width:16px; height:16px; display:flex; align-items:center; justify-content:center;">' . $cart_count . '</span>';
    
    // Send cart contents data for stepper sync
    $cart_data = [];
    if (WC()->cart) {
        foreach (WC()->cart->get_cart() as $cart_item_key => $cart_item) {
            $pid = $cart_item['product_id'];
            $cart_data[$pid] = [
                'qty' => $cart_item['quantity'],
                'key' => $cart_item_key,
            ];
        }
    }
    $fragments['script.zooboxi-cart-data'] = '<script class="zooboxi-cart-data" type="application/json">' . json_encode($cart_data) . '</script>';
    
    return $fragments;
});

// ═══════════ SHOP LOOP QUANTITY STEPPER ═══════════
add_action('wp_footer', function() {
    if (!is_shop() && !is_product_category() && !is_product_tag() && !is_search() && !is_front_page() && !is_home()) return;
    
    // Pass current cart data to JS on page load
    $cart_data = [];
    if (WC()->cart) {
        foreach (WC()->cart->get_cart() as $cart_item_key => $cart_item) {
            $pid = $cart_item['product_id'];
            $cart_data[$pid] = [
                'qty' => $cart_item['quantity'],
                'key' => $cart_item_key,
            ];
        }
    }
    ?>
    <script>
    jQuery(function($){
        var cartData = <?php echo json_encode($cart_data); ?>;
        var ajaxUrl = '<?php echo admin_url("admin-ajax.php"); ?>';
        var nonce = '<?php echo wp_create_nonce("woocommerce-cart"); ?>';

        function createStepper(productId, qty) {
            return '<div class="zbx-qty-stepper" data-product-id="' + productId + '">' +
                '<button type="button" class="zbx-qty-btn zbx-qty-plus" data-product-id="' + productId + '">+</button>' +
                '<span class="zbx-qty-value">' + qty + '</span>' +
                '<button type="button" class="zbx-qty-btn zbx-qty-minus" data-product-id="' + productId + '">−</button>' +
            '</div>';
        }

        // On page load: replace buttons for products already in cart
        // Only target buttons NOT inside thumbnail wrap (avoid Astra on-card quick button)
        var mainBtnSelector = 'li.product a.add_to_cart_button';

        // Group the price + the action control into one flex row (".zb-card-foot")
        // so the circular icon sits beside the price (and the stepper takes its place
        // on click). Idempotent — safe to re-run after hydration / fragment refresh.
        function wrapFoot(scope) {
            var $scope = scope ? $(scope) : $(document);
            $scope.find('li.product .astra-shop-summary-wrap').each(function(){
                var $s = $(this);
                if ($s.children('.zb-card-foot').length) return;
                var $price = $s.children('.price').first();
                var $act = $s.children('a.add_to_cart_button, .zbx-qty-stepper').first();
                if (!$act.length) $act = $s.children('a.button').first();
                if (!$price.length && !$act.length) return;
                var $foot = $('<div class="zb-card-foot"></div>');
                $s.append($foot);
                if ($price.length) $foot.append($price);
                if ($act.length) $foot.append($act);
            });
        }

        function initSteppers(scope) {
            var $scope = scope ? $(scope) : $(document);
            $scope.find(mainBtnSelector).each(function(){
                var $btn = $(this);
                if ($btn.closest('.astra-shop-thumbnail-wrap').length) return; // skip thumbnail buttons
                if ($btn.hasClass('ast-on-card-button')) return; // skip Astra's duplicate on-card button
                if ($btn.hasClass('product_type_variable') || $btn.hasClass('product_type_grouped')) return; // steppers are simple-only
                var pid = $btn.data('product_id');
                if (pid && cartData[pid] && cartData[pid].qty > 0) {
                    var $stepper = $(createStepper(pid, cartData[pid].qty));
                    $btn.replaceWith($stepper);
                    $stepper.siblings('.added_to_cart').remove();
                }
            });
        }

        function refreshCards(scope) { wrapFoot(scope); initSteppers(scope); }
        refreshCards(document);
        // Expose so the homepage hydration (zooboxi-home.js) can re-run on injected rails.
        window.zbxCards = { refresh: refreshCards };
        $(document.body).on('wc_fragments_refreshed wc_fragments_loaded', function(){ refreshCards(document); });

        // After AJAX add to cart: replace button with stepper
        $(document.body).on('added_to_cart', function(e, fragments, cart_hash, $btn){
            if (!$btn || !$btn.length) return;
            var pid = $btn.data('product_id');
            if (!pid) return;

            // Sync cart data from fragments
            if (fragments && fragments['script.zooboxi-cart-data']) {
                try {
                    var json = $(fragments['script.zooboxi-cart-data']).text();
                    var newData = JSON.parse(json);
                    if (newData) cartData = newData;
                } catch(ex){}
            }
            if (!cartData[pid]) cartData[pid] = { qty: 1, key: '' };

            // Find the MAIN button for this product (not thumbnail one)
            var $card = $btn.closest('li.product');
            var $mainBtn = $card.find('a.add_to_cart_button[data-product_id="'+pid+'"]').not('.ast-on-card-button').first();
            if (!$mainBtn.length) $mainBtn = $btn; // fallback

            // Only replace if not inside thumbnail
            if (!$mainBtn.closest('.astra-shop-thumbnail-wrap').length) {
                var $stepper = $(createStepper(pid, cartData[pid].qty));
                $mainBtn.replaceWith($stepper);
                $stepper.siblings('.added_to_cart').remove();
            }

            // Also hide thumbnail on-card button if it exists
            $card.find('.astra-shop-thumbnail-wrap a.add_to_cart_button').hide();
        });

        // Plus button
        $(document).on('click', '.zbx-qty-plus', function(e){
            e.preventDefault();
            e.stopPropagation();
            var pid = $(this).data('product-id');
            var $stepper = $(this).closest('.zbx-qty-stepper');
            var $val = $stepper.find('.zbx-qty-value');
            $stepper.addClass('zbx-loading');

            $.post(ajaxUrl, {
                action: 'zooboxi_update_cart_qty',
                product_id: pid,
                direction: 'plus',
                security: nonce
            }, function(res){
                $stepper.removeClass('zbx-loading');
                if (res.success) {
                    $val.text(res.data.qty);
                    cartData[pid] = { qty: res.data.qty, key: res.data.key };
                    $(document.body).trigger('wc_fragment_refresh');
                }
            });
        });

        // Minus button
        $(document).on('click', '.zbx-qty-minus', function(e){
            e.preventDefault();
            e.stopPropagation();
            var pid = $(this).data('product-id');
            var $stepper = $(this).closest('.zbx-qty-stepper');
            var $val = $stepper.find('.zbx-qty-value');
            var currentQty = parseInt($val.text()) || 1;
            $stepper.addClass('zbx-loading');

            if (currentQty <= 1) {
                // Remove from cart — replace stepper back to button
                $.post(ajaxUrl, {
                    action: 'zooboxi_update_cart_qty',
                    product_id: pid,
                    direction: 'remove',
                    security: nonce
                }, function(res){
                    $stepper.removeClass('zbx-loading');
                    if (res.success) {
                        delete cartData[pid];
                        var $newBtn = $('<a href="?add-to-cart=' + pid + '" data-quantity="1" class="button product_type_simple add_to_cart_button ajax_add_to_cart" data-product_id="' + pid + '" rel="nofollow">أضف للسلة</a>');
                        $stepper.replaceWith($newBtn);
                        $(document.body).trigger('wc_fragment_refresh');
                    }
                });
            } else {
                $.post(ajaxUrl, {
                    action: 'zooboxi_update_cart_qty',
                    product_id: pid,
                    direction: 'minus',
                    security: nonce
                }, function(res){
                    $stepper.removeClass('zbx-loading');
                    if (res.success) {
                        $val.text(res.data.qty);
                        cartData[pid] = { qty: res.data.qty, key: res.data.key };
                        $(document.body).trigger('wc_fragment_refresh');
                    }
                });
            }
        });
    });
    </script>
    <?php
}, 99);

// ═══════════ AJAX HANDLER: UPDATE CART QTY ═══════════
add_action('wp_ajax_zooboxi_update_cart_qty', 'zooboxi_update_cart_qty');
add_action('wp_ajax_nopriv_zooboxi_update_cart_qty', 'zooboxi_update_cart_qty');

function zooboxi_update_cart_qty() {
    check_ajax_referer('woocommerce-cart', 'security');
    
    $product_id = absint($_POST['product_id'] ?? 0);
    $direction  = sanitize_text_field($_POST['direction'] ?? '');
    
    if (!$product_id || !WC()->cart) {
        wp_send_json_error('Invalid request');
        return;
    }
    
    // Find cart item key for this product
    $cart_item_key = '';
    $current_qty = 0;
    foreach (WC()->cart->get_cart() as $key => $item) {
        if ($item['product_id'] == $product_id) {
            $cart_item_key = $key;
            $current_qty = $item['quantity'];
            break;
        }
    }
    
    if ($direction === 'remove' && $cart_item_key) {
        WC()->cart->remove_cart_item($cart_item_key);
        wp_send_json_success(['qty' => 0, 'key' => '']);
        return;
    }
    
    if ($direction === 'plus') {
        if ($cart_item_key) {
            WC()->cart->set_quantity($cart_item_key, $current_qty + 1);
            wp_send_json_success(['qty' => $current_qty + 1, 'key' => $cart_item_key]);
        } else {
            $new_key = WC()->cart->add_to_cart($product_id);
            wp_send_json_success(['qty' => 1, 'key' => $new_key]);
        }
        return;
    }
    
    if ($direction === 'minus' && $cart_item_key) {
        $new_qty = max(0, $current_qty - 1);
        if ($new_qty === 0) {
            WC()->cart->remove_cart_item($cart_item_key);
            wp_send_json_success(['qty' => 0, 'key' => '']);
        } else {
            WC()->cart->set_quantity($cart_item_key, $new_qty);
            wp_send_json_success(['qty' => $new_qty, 'key' => $cart_item_key]);
        }
        return;
    }
    
    wp_send_json_error('Unknown direction');
}

// ═══════════ QUICK VIEW POPUP FOR VARIABLE PRODUCTS ═══════════

// AJAX handler: get product quick-view data
add_action('wp_ajax_zooboxi_quick_view', 'zooboxi_quick_view');
add_action('wp_ajax_nopriv_zooboxi_quick_view', 'zooboxi_quick_view');

// ═══════════ POPUP ADD TO CART HANDLER ═══════════
add_action('wp_ajax_zooboxi_popup_add_to_cart', 'zooboxi_popup_add_to_cart');
add_action('wp_ajax_nopriv_zooboxi_popup_add_to_cart', 'zooboxi_popup_add_to_cart');

function zooboxi_popup_add_to_cart() {
    $product_id   = absint($_POST['product_id'] ?? 0);
    $variation_id = absint($_POST['variation_id'] ?? 0);
    $quantity     = max(1, intval($_POST['quantity'] ?? 1));

    if (!$product_id) {
        wp_send_json_error(['message' => 'منتج غير صالح']);
        return;
    }

    // Get variation attributes from POST or from variation object
    $variation = [];
    foreach ($_POST as $key => $value) {
        if (str_starts_with($key, 'attribute_')) {
            $variation[$key] = sanitize_text_field($value);
        }
    }

    // Fallback: get attributes from variation object if POST didn't include them
    if (empty($variation) && $variation_id) {
        $variation_obj = wc_get_product($variation_id);
        if ($variation_obj && $variation_obj->is_type('variation')) {
            $variation = $variation_obj->get_variation_attributes();
        }
    }

    // Check if product already exists in cart before adding
    $existing_qty = 0;
    foreach (WC()->cart->get_cart() as $item) {
        if ((int) $item['product_id'] === $product_id && (int) ($item['variation_id'] ?? 0) === $variation_id) {
            $existing_qty = $item['quantity'];
            break;
        }
    }

    // Add to cart
    $cart_item_key = WC()->cart->add_to_cart($product_id, $quantity, $variation_id, $variation);

    // Verify by checking cart contents (add_to_cart can return false even on success)
    $found = false;
    $new_qty = 0;
    foreach (WC()->cart->get_cart() as $item) {
        if ((int) $item['product_id'] === $product_id && (int) ($item['variation_id'] ?? 0) === $variation_id) {
            $found = true;
            $new_qty = $item['quantity'];
            break;
        }
    }

    // Also check for any WC error notices
    $notices = wc_get_notices('error');
    $has_real_error = false;
    foreach ($notices as $notice) {
        $notice_text = wp_strip_all_tags($notice['notice'] ?? '');
        // Ignore generic "already in cart" messages, treat stock errors as real
        if (str_contains($notice_text, 'المخزون') || str_contains($notice_text, 'stock') || str_contains($notice_text, 'متاح')) {
            $has_real_error = true;
            break;
        }
    }
    wc_clear_notices();

    if ($found && !$has_real_error) {
        // Trigger WC fragments refresh
        ob_start();
        wc_setcookie('woocommerce_items_in_cart', count(WC()->cart->get_cart()));
        WC_AJAX::get_refreshed_fragments();
        ob_end_clean();

        wp_send_json_success([
            'message' => 'تمت الإضافة للسلة',
            'cart_count' => WC()->cart->get_cart_contents_count(),
        ]);
    } else {
        $msg = !empty($notices) ? wp_strip_all_tags($notices[0]['notice'] ?? 'حدث خطأ') : 'لم يتم إضافة المنتج';
        wp_send_json_error(['message' => $msg]);
    }
}

function zooboxi_quick_view() {
    $product_id = absint($_POST['product_id'] ?? 0);
    if (!$product_id) {
        wp_send_json_error('Missing product ID');
        return;
    }

    $product = wc_get_product($product_id);
    if (!$product) {
        wp_send_json_error('Product not found');
        return;
    }

    // Get image
    $image_id = $product->get_image_id();
    $image_url = $image_id ? wp_get_attachment_image_url($image_id, 'medium_large') : wc_placeholder_img_src('medium_large');

    // Build variation form HTML manually (wc_get_template crashes without global $post)
    $form_html = '';
    if ($product->is_type('variable')) {
        $available_variations = $product->get_available_variations();
        $attributes = $product->get_variation_attributes();
        
        $form_html .= '<form class="variations_form cart" data-product_id="' . $product_id . '">';
        $form_html .= '<input type="hidden" name="product_id" value="' . $product_id . '">';
        $form_html .= '<input type="hidden" name="variation_id" value="">';
        
        // Emoji map for common attribute keywords
        $emoji_map = [
            // Size
            'صغير' => '🐾', 'وسط' => '🐕', 'كبير' => '🦁', 'ضخم' => '🐘',
            'small' => '🐾', 'medium' => '🐕', 'large' => '🦁', 'xlarge' => '🐘',
            'xs' => '🐾', 's' => '🐾', 'm' => '🐕', 'l' => '🦁', 'xl' => '🐘', 'xxl' => '🐘',
            // Weight / quantity
            'جرام' => '⚖️', 'كيلو' => '⚖️', 'غ' => '⚖️', 'كجم' => '⚖️',
            'g' => '⚖️', 'kg' => '⚖️', 'lb' => '⚖️', 'oz' => '⚖️',
            // Count
            'حبة' => '📦', 'حبات' => '📦', 'قطعة' => '📦', 'عبوة' => '📦', 'علبة' => '📦',
            'pack' => '📦', 'pcs' => '📦', 'piece' => '📦', 'box' => '📦',
            // Flavor
            'دجاج' => '🍗', 'لحم' => '🥩', 'سمك' => '🐟', 'سلمون' => '🐟', 'تونة' => '🐟',
            'chicken' => '🍗', 'beef' => '🥩', 'fish' => '🐟', 'salmon' => '🐟', 'tuna' => '🐟',
            'lamb' => '🐑', 'turkey' => '🦃', 'duck' => '🦆', 'شريمب' => '🦐', 'shrimp' => '🦐',
            // Color
            'أحمر' => '🔴', 'أزرق' => '🔵', 'أخضر' => '🟢', 'أسود' => '⚫', 'أبيض' => '⚪',
            'أصفر' => '🟡', 'وردي' => '🩷', 'بنفسجي' => '🟣', 'برتقالي' => '🟠',
            'red' => '🔴', 'blue' => '🔵', 'green' => '🟢', 'black' => '⚫', 'white' => '⚪',
            'yellow' => '🟡', 'pink' => '🩷', 'purple' => '🟣', 'orange' => '🟠', 'brown' => '🟤',
            'grey' => '⬜', 'gray' => '⬜', 'رمادي' => '⬜',
        ];

        $form_html .= '<div class="variations">';
        foreach ($attributes as $attribute_name => $options) {
            $label = wc_attribute_label($attribute_name, $product);
            $attr_slug = sanitize_title($attribute_name);
            $form_html .= '<div class="zbx-qv-attr-row">';
            $form_html .= '<label>' . esc_html($label) . '</label>';
            
            // Hidden select for form submission
            $form_html .= '<select style="display:none" name="attribute_' . esc_attr($attr_slug) . '" data-attribute_name="attribute_' . esc_attr($attr_slug) . '">';
            $form_html .= '<option value=""></option>';
            foreach ($options as $option) {
                $term = get_term_by('slug', $option, $attribute_name);
                $option_label = $term ? $term->name : $option;
                $form_html .= '<option value="' . esc_attr($option) . '">' . esc_html($option_label) . '</option>';
            }
            $form_html .= '</select>';
            
            // Button swatches
            $form_html .= '<div class="zbx-swatch-group" data-attr="attribute_' . esc_attr($attr_slug) . '">';
            foreach ($options as $option) {
                $term = get_term_by('slug', $option, $attribute_name);
                $option_label = $term ? $term->name : $option;
                
                // Auto-detect emoji from option label
                $emoji = '🏷️'; // default
                $lower = mb_strtolower($option_label);
                foreach ($emoji_map as $keyword => $icon) {
                    if (mb_strpos($lower, mb_strtolower($keyword)) !== false) {
                        $emoji = $icon;
                        break;
                    }
                }
                
                $form_html .= '<button type="button" class="zbx-swatch-btn" data-value="' . esc_attr($option) . '">';
                $form_html .= '<span class="zbx-swatch-emoji">' . $emoji . '</span>';
                $form_html .= '<span class="zbx-swatch-label">' . esc_html($option_label) . '</span>';
                $form_html .= '</button>';
            }
            $form_html .= '</div>';
            
            $form_html .= '</div>';
        }
        $form_html .= '</div>';
        
        // Variation price display
        $form_html .= '<div class="single_variation_wrap">';
        $form_html .= '<div class="woocommerce-variation single_variation" style="display:none;"></div>';
        $form_html .= '<div class="woocommerce-variation-add-to-cart variations_button">';
        $form_html .= '<input type="hidden" name="quantity" value="1">';
        $form_html .= '<button type="button" class="single_add_to_cart_button button alt disabled wc-variation-selection-needed">إضافة للسلة</button>';
        $form_html .= '</div></div>';
        
        // Inject variations data as JSON for WC JS
        $form_html .= '<script type="application/json" class="variations_data">' . wp_json_encode($available_variations) . '</script>';
        $form_html .= '</form>';
    }

    wp_send_json_success([
        'id'          => $product_id,
        'title'       => $product->get_name(),
        'image'       => $image_url,
        'price_html'  => $product->get_price_html(),
        'short_desc'  => wp_strip_all_tags($product->get_short_description()),
        'form_html'   => $form_html,
        'product_url' => get_permalink($product_id),
        'variations'  => $product->is_type('variable') ? $available_variations : [],
    ]);
}

// Modal HTML + JS
add_action('wp_footer', function() {
    if (!is_shop() && !is_product_category() && !is_product_tag() && !is_search() && !is_front_page() && !is_home()) return;
    ?>
    <!-- Quick View Modal -->
    <div id="zbx-quick-view-overlay" class="zbx-qv-overlay" style="display:none;">
        <div class="zbx-qv-modal">
            <button type="button" class="zbx-qv-close">&times;</button>
            <div class="zbx-qv-loading">
                <div class="zbx-qv-spinner"></div>
            </div>
            <div class="zbx-qv-content" style="display:none;">
                <div class="zbx-qv-image-wrap">
                    <img id="zbx-qv-image" src="" alt="">
                </div>
                <div class="zbx-qv-details">
                    <h2 id="zbx-qv-title" class="zbx-qv-title"></h2>
                    <div id="zbx-qv-price" class="zbx-qv-price"></div>
                    <p id="zbx-qv-desc" class="zbx-qv-desc"></p>
                    <div id="zbx-qv-form" class="zbx-qv-form"></div>
                    <a id="zbx-qv-link" href="#" class="zbx-qv-full-link">عرض التفاصيل الكاملة ←</a>
                </div>
            </div>
        </div>
    </div>

    <script>
    jQuery(function($){
        var ajaxUrl = '<?php echo admin_url("admin-ajax.php"); ?>';

        // Intercept "Select options" clicks
        $(document).on('click', 'a.product_type_variable, a.product_type_grouped', function(e){
            e.preventDefault();
            e.stopPropagation();

            // Get product ID — variable buttons don't have data-product_id
            var pid = $(this).data('product_id');
            if (!pid) {
                // Extract from parent li.product class: "post-{ID}"
                var $card = $(this).closest('li.product');
                var classes = ($card.attr('class') || '').split(/\s+/);
                for (var i = 0; i < classes.length; i++) {
                    var m = classes[i].match(/^post-(\d+)$/);
                    if (m) { pid = parseInt(m[1]); break; }
                }
            }
            if (!pid) {
                // Fallback: go to product page
                var href = $(this).attr('href');
                if (href) { window.location.href = href; }
                return;
            }

            var $overlay = $('#zbx-quick-view-overlay');
            var $loading = $overlay.find('.zbx-qv-loading');
            var $content = $overlay.find('.zbx-qv-content');

            // Show modal with loading
            $loading.show();
            $content.hide();
            $overlay.addClass('zbx-qv-active');
            $('body').css('overflow','hidden');

            $.post(ajaxUrl, {
                action: 'zooboxi_quick_view',
                product_id: pid
            }, function(res){
                $loading.hide();
                if (!res.success) {
                    $overlay.removeClass('zbx-qv-active');
                    $('body').css('overflow','');
                    return;
                }

                var d = res.data;
                $('#zbx-qv-image').attr('src', d.image).attr('alt', d.title);
                $('#zbx-qv-title').text(d.title);
                $('#zbx-qv-price').html(d.price_html);
                $('#zbx-qv-desc').text(d.short_desc || '');
                $('#zbx-qv-link').attr('href', d.product_url);

                // Inject variation form
                var $form = $('#zbx-qv-form');
                $form.html(d.form_html);

                // Custom variation handler with swatch buttons
                var $varForm = $form.find('form.variations_form');
                var variations = d.variations || [];
                
                if ($varForm.length && variations.length) {
                    function checkVariation() {
                        var selected = {};
                        var allSelected = true;
                        $varForm.find('select[name^="attribute_"]').each(function(){
                            selected[$(this).attr('name')] = $(this).val();
                            if (!$(this).val()) allSelected = false;
                        });

                        if (allSelected) {
                            var match = null;
                            for (var i = 0; i < variations.length; i++) {
                                var v = variations[i], isMatch = true;
                                for (var attr in selected) {
                                    var vAttr = v.attributes[attr] || '';
                                    if (vAttr !== '' && vAttr !== selected[attr]) { isMatch = false; break; }
                                }
                                if (isMatch && v.is_purchasable && v.is_in_stock) { match = v; break; }
                            }
                            if (match) {
                                $varForm.find('input[name="variation_id"]').val(match.variation_id);
                                $varForm.find('.single_add_to_cart_button').removeClass('disabled wc-variation-selection-needed');
                                if (match.price_html) $varForm.find('.single_variation').html(match.price_html).show();
                                if (match.image && match.image.src) $('#zbx-qv-image').attr('src', match.image.src);
                            } else {
                                $varForm.find('input[name="variation_id"]').val('');
                                $varForm.find('.single_add_to_cart_button').addClass('disabled');
                                $varForm.find('.single_variation').html('<p style="color:#e74c3c">هذا الخيار غير متوفر</p>').show();
                            }
                        } else {
                            $varForm.find('input[name="variation_id"]').val('');
                            $varForm.find('.single_add_to_cart_button').addClass('disabled wc-variation-selection-needed');
                            $varForm.find('.single_variation').hide();
                        }
                    }

                    // Swatch button click
                    $varForm.on('click', '.zbx-swatch-btn', function(e){
                        e.preventDefault();
                        var $btn = $(this);
                        var val = $btn.attr('data-value');
                        var $group = $btn.closest('.zbx-swatch-group');
                        var attrName = $group.data('attr');

                        // Toggle: deselect if already active
                        if ($btn.hasClass('zbx-swatch-active')) {
                            $btn.removeClass('zbx-swatch-active');
                            $varForm.find('select[name="'+attrName+'"]').val('');
                        } else {
                            $group.find('.zbx-swatch-btn').removeClass('zbx-swatch-active');
                            $btn.addClass('zbx-swatch-active');
                            $varForm.find('select[name="'+attrName+'"]').val(val);
                        }
                        checkVariation();
                    });
                }

                $content.show();

                // Handle add to cart inside popup
                $form.off('click', '.single_add_to_cart_button').on('click', '.single_add_to_cart_button', function(e2){
                    e2.preventDefault();
                    var $btn = $(this);
                    if ($btn.hasClass('disabled') || $btn.hasClass('wc-variation-selection-needed')) return;

                    var $thisForm = $btn.closest('form');
                    var variation_id = $thisForm.find('input[name="variation_id"]').val();
                    var product_id = $thisForm.find('input[name="product_id"]').val() || d.id;
                    var qty = $thisForm.find('input[name="quantity"]').val() || 1;

                    $btn.text('جاري الإضافة...').addClass('loading');

                    // Use our custom AJAX handler that works for both simple and variable
                    var formData = {
                        action: 'zooboxi_popup_add_to_cart',
                        product_id: product_id,
                        quantity: qty,
                        variation_id: variation_id || 0
                    };

                    // Include variation attributes
                    $thisForm.find('select[name^="attribute_"]').each(function(){
                        formData[$(this).attr('name')] = $(this).val();
                    });

                    $.post(ajaxUrl, formData, function(addRes){
                        $btn.removeClass('loading');
                        if (addRes.success) {
                            $btn.text('✓ تمت الإضافة').css('background','#27ae60');
                            $(document.body).trigger('wc_fragment_refresh');
                            setTimeout(function(){
                                $overlay.removeClass('zbx-qv-active');
                                $('body').css('overflow','');
                                $btn.text('إضافة للسلة').css('background','');
                            }, 1000);
                        } else {
                            var msg = (addRes.data && addRes.data.message) ? addRes.data.message : 'حدث خطأ';
                            $btn.text(msg).css('background','#e74c3c');
                            setTimeout(function(){ $btn.text('إضافة للسلة').css('background',''); }, 2000);
                        }
                    }).fail(function(){
                        $btn.removeClass('loading').text('إضافة للسلة');
                    });
                });
            });
        });

        // Close modal
        $(document).on('click', '.zbx-qv-close, .zbx-qv-overlay', function(e){
            if (e.target === this) {
                $('#zbx-quick-view-overlay').removeClass('zbx-qv-active');
                $('body').css('overflow','');
            }
        });

        // Close on ESC
        $(document).on('keydown', function(e){
            if (e.key === 'Escape') {
                $('#zbx-quick-view-overlay').removeClass('zbx-qv-active');
                $('body').css('overflow','');
            }
        });
    });
    </script>
    <?php
}, 98);

// ═══════════ PRODUCT CARD BRAND LOGO CHIP (store-wide) ═══════════
// Shows the product's brand logo in the top-end corner of every card.
// Source: product_brand taxonomy → term meta thumbnail_id (4113/4330 products
// have a brand; 73/86 brands have a logo → text-name chip is the fallback).
add_action('woocommerce_before_shop_loop_item_title', 'zooboxi_card_brand_chip', 9);
function zooboxi_card_brand_chip() {
    global $product;
    if (!($product instanceof WC_Product)) return;
    static $cache = [];
    $terms = get_the_terms($product->get_id(), 'product_brand');
    if (empty($terms) || is_wp_error($terms)) return;
    $t = $terms[0];
    if (!array_key_exists($t->term_id, $cache)) {
        $logo_id = get_term_meta($t->term_id, 'thumbnail_id', true);
        // 'medium' (soft-crop) — NOT 'thumbnail': that size hard-crops to a 150×150
        // square and beheads wide wordmark logos (Applaws → "pplaws").
        $cache[$t->term_id] = $logo_id ? wp_get_attachment_image_url((int) $logo_id, 'medium') : '';
    }
    $logo = $cache[$t->term_id];
    if ($logo) {
        echo '<span class="zb-card-brand"><img src="' . esc_url($logo) . '" alt="' . esc_attr($t->name) . '" loading="lazy"></span>';
    } else {
        echo '<span class="zb-card-brand zb-card-brand--text">' . esc_html($t->name) . '</span>';
    }
}

// ═══════════════════════════════════════════════════════════════════════
// ██ SUBCATEGORY NAVIGATION + PROFESSIONAL FILTERS (Zooboxi v4.0)
// ═══════════════════════════════════════════════════════════════════════


// ═══════════ CONTEXT HELPERS ═══════════

/**
 * Known root category IDs for context detection.
 */
function zooboxi_root_ids(): array {
    return [
        'health_criteria' => 102,
        'brands'          => 8643,
        'brands_en'       => 9061,
        'cat_main'        => 107,
        'dog_main'        => 114,
        'birds_main'      => 202,
        'small_main'      => 194,
        'cat_en'          => 1827,
        'dog_en'          => 1830,
        'cat_health'      => 103,
        'dog_health'      => 110,
        'birds_health'    => 199,
        'small_health'    => 189,
    ];
}

function zooboxi_is_under_health_criteria(int $term_id): bool {
    $roots = zooboxi_root_ids();
    if ($term_id === $roots['health_criteria']) return true;
    $ancestors = get_ancestors($term_id, 'product_cat', 'taxonomy');
    return in_array($roots['health_criteria'], $ancestors);
}

function zooboxi_is_under_brands(int $term_id): bool {
    $roots = zooboxi_root_ids();
    if ($term_id === $roots['brands'] || $term_id === $roots['brands_en']) return true;
    $ancestors = get_ancestors($term_id, 'product_cat', 'taxonomy');
    return in_array($roots['brands'], $ancestors) || in_array($roots['brands_en'], $ancestors);
}

function zooboxi_is_under_en_tree(int $term_id): bool {
    $roots = zooboxi_root_ids();
    if (in_array($term_id, [$roots['cat_en'], $roots['dog_en']])) return true;
    $ancestors = get_ancestors($term_id, 'product_cat', 'taxonomy');
    return in_array($roots['cat_en'], $ancestors) || in_array($roots['dog_en'], $ancestors);
}

/**
 * Structural subcategory IDs under health-criteria animal pages
 * mapped to their main-tree counterparts (for icon reuse).
 */
function zooboxi_health_structural_map(): array {
    return [
        // Health tree ID => Main tree ID
        8649 => 108,   // طعام (health-cat) -> طعام (main-cat)
        8691 => 146,   // مستلزمات القطط
        8685 => 132,   // المكافآت والفيتامينات
        8789 => 141,   // التنظيف والتدريب
        8799 => 148,   // صحة القطط
        8659 => 152,   // مستلزمات الرمل
        8829 => 235,   // رمل القطط
        9083 => 130,   // بكجات متعددة وموفّرة
        // Dog health structural
        8773 => 115,   // الطعام (health-dog) -> الطعام (main-dog)
        8805 => 174,   // المكافات والفيتامينات (health-dog)
        8739 => 162,   // التنظيف والتدريب (health-dog)
        8719 => 166,   // مستلزمات الكلاب (health-dog)
        8839 => 126,   // صحة الكلاب (health-dog) -> صحة الكلاب (main-dog)
    ];
}


// ═══════════ CATEGORY ICON SYSTEM ═══════════

/**
 * Icon map by term_id — definitive, no collision.
 */
function zooboxi_get_category_icon_map_by_id(): array {
    return [
        // Root main categories
        107 => 'https://gal.holeno.com/category/Cat.png',
        114 => 'https://gal.holeno.com/category/Dog.png',
        202 => 'https://gal.holeno.com/category/Birds.png',
        194 => 'https://gal.holeno.com/category/Small Animals.png',
        // Cat > main subcategories (parent=107)
        108 => 'https://gal.holeno.com/sub_category/Cat/Food/Food.png',
        132 => 'https://gal.holeno.com/sub_category/Cat/Treats %26 Vitamins/Treats_%26_Vitamins.png',
        141 => 'https://gal.holeno.com/sub_category/Cat/Cleaning %26 Training/Cleaning_%26_Training.png',
        146 => 'https://gal.holeno.com/sub_category/Cat/Supplies/Supplies.png',
        148 => 'https://gal.holeno.com/sub_category/Cat/Health/Health.png',
        152 => 'https://gal.holeno.com/sub_category/Cat/Litter Supplies/Litter_Supplies.png',
        235 => 'https://gal.holeno.com/sub_category/Cat/Litter/Litter.png',
        130 => 'https://gal.holeno.com/sub_category/Cat/Multi-Packs %26 Savers/Multi-Packs_%26_Savers.png',
        // Dog > main subcategories (parent=114)
        115 => 'https://gal.holeno.com/sub_category/Dog/Food/Food.png',
        174 => 'https://gal.holeno.com/sub_category/Dog/Treats %26 Vitamins/Treats_%26_Vitamins.png',
        162 => 'https://gal.holeno.com/sub_category/Dog/Cleaning %26 Training/Cleaning_%26_Training.png',
        166 => 'https://gal.holeno.com/sub_category/Dog/Supplies/Supplies.png',
        126 => 'https://gal.holeno.com/sub_category/Dog/Health/Health.png',
        // Health criteria root children (animal types)
        103 => 'https://gal.holeno.com/category/Cat.png',
        110 => 'https://gal.holeno.com/category/Dog.png',
        199 => 'https://gal.holeno.com/category/Birds.png',
        189 => 'https://gal.holeno.com/category/Small Animals.png',
    ];
}

/**
 * Fallback name-based map for categories with unique names only.
 */
function zooboxi_get_category_icon_map_by_name(): array {
    return [
        // Cat > Food sub-sub
        'الطعام الجاف'              => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Dry Food/Dry_Food.png',
        'الطعام الرطب'              => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Wet Food/Wet_Food.png',
        'طعام القطط البالغة'        => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Adult Cat Food/Adult_Cat_Food.png',
        'طعام القطط الصغيرة'        => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Kitten Food/Kitten_Food.png',
        'طعام القطط المسنة'         => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Senior Cat Food/Senior_Cat_Food.png',
        'الحليب والسوائل'           => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Milk %26 Liquids/Milk_%26_Liquids.png',
        'طعام للحساسية الهضمية'     => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Digestive Sensitivity Food/Digestive_Sensitivity_Food.png',
        'طعام التحكم في الوزن'      => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Weight Control Food/Weight_Control_Food.png',
        // Cat > Treats sub-sub
        'الكريمي'                 => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Creamy Treats/Creamy_Treats.png',
        'البسكويت والمقرمشات'    => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Biscuit %26 Crunchy Treats/Biscuit_%26_Crunchy_Treats.png',
        'المكافآت والوجبات الخفيفة' => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Treats %26 Snacks/Treats_%26_Snacks.png',
        'الناعمة والمضغية'       => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Soft %26 Chewy Treats/Soft_%26_Chewy_Treats.png',
        'مكافآت العناية بالأسنان' => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Dental Care Treats/Dental_Care_Treats.png',
        'الفيتامينات والمكملات'  => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Vitamins %26 Supplements/Vitamins_%26_Supplements.png',
        // Cat > Cleaning sub-sub
        'الاستحمام والتنظيف الجاف' => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Bathing %26 Dry Cleaning/Bathing_%26_Dry_Cleaning.png',
        'فرش وامشاط ومقصات'     => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Brushes %26 Combs %26 Scissors/Brushes_%26_Combs_%26_Scissors.png',
        'شامبو وبلسم'            => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Shampoo %26 Conditioner/Shampoo_%26_Conditioner.png',
        'العناية بالعين والاذن والاسنان' => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Eye %26 Ear %26 Dental Care/Eye_%26_Ear_%26_Dental_Care.png',
        'مزيلات البقع والروائح والشعر' => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Stain %26 Odor %26 Hair Removers/Stain_%26_Odor_%26_Hair_Removers.png',
        'التدريب وتحسين السلوك'  => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Training %26 Behavior Improvement/Training_%26_Behavior_Improvement.png',
        // Cat > Supplies sub-sub
        'وسادات وبيوت واقفاص'    => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Cushions %26 Houses %26 Cages/Cushions_%26_Houses_%26_Cages.png',
        'صناديق وشنط التنقل'     => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Carriers/Carriers.png',
        'ادوات الطعام'            => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Feeding Tools/Feeding_Tools.png',
        'العاب وكاتنيب'           => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Toys %26 Catnip/Toys_%26_Catnip.png',
        'اطواق'                   => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Collars/Collars.png',
        'اثاث وخداشات'            => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Furniture %26 Scratchers/Furniture_%26_Scratchers.png',
        'مشدات وصدريات'           => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Harnesses %26 Vests/Harnesses_%26_Vests.png',
        'قلادات قابلة للحفر'      => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Engravable Tags/Engravable_Tags.png',
        // Cat > Litter sub-sub
        'صناديق الرمل'            => 'https://gal.holeno.com/sub_sub_category/Cat/Litter Supplies/Litter Boxes/Litter_Boxes.png',
        'مستلزمات صندوق الرمل'   => 'https://gal.holeno.com/sub_sub_category/Cat/Litter Supplies/Litter Box Accessories/Litter_Box_Accessories.png',
        'معطرات ومقلل الروائح الكريهة' => 'https://gal.holeno.com/sub_sub_category/Cat/Litter Supplies/Odor Reducers/Odor_Reducers.png',
        // Dog sub-sub (unique)
        'طعام الكلاب البالغة'     => 'https://gal.holeno.com/sub_sub_category/Dog/Food/Adult Dog Food/Adult_Dog_Food.png',
        'طعام الكلاب البوبي'      => 'https://gal.holeno.com/sub_sub_category/Dog/Food/Puppy Food/Puppy_Food.png',
        'طعام الكلاب المسنة'      => 'https://gal.holeno.com/sub_sub_category/Dog/Food/Senior Dog Food/Senior_Dog_Food.png',
        // Birds (unique)
        'طعام ومكافات الطيور'     => 'https://gal.holeno.com/sub_category/Birds/Bird Food %26 Treats/Bird_Food_%26_Treats.png',
        'مستلزمات الطيور'         => 'https://gal.holeno.com/sub_category/Birds/Bird Supplies/Bird_Supplies.png',
        'اقفاص وبيوت'             => 'https://gal.holeno.com/sub_sub_category/Birds/Bird Supplies/Cages %26 Houses/Cages_%26_Houses.png',
        'اغصان'                   => 'https://gal.holeno.com/sub_sub_category/Birds/Bird Supplies/Branches %26 Perches/Branches_%26_Perches.png',
        // Small Animals (unique)
        'مستلزمات الارانب والهماستر' => 'https://gal.holeno.com/sub_category/Small Animals/Rabbit %26 Hamster Supplies/Rabbit_%26_Hamster_Supplies.png',
        'طعام ومكافات القوارض'    => 'https://gal.holeno.com/sub_category/Small Animals/Rodent Food %26 Treats/Rodent_Food_%26_Treats.png',
    ];
}

/**
 * Get icon URL for a category — context-aware, resolves name collisions.
 */
function zooboxi_get_category_icon(object $term): string {
    $id_map = zooboxi_get_category_icon_map_by_id();
    
    // 1. Direct term_id match (highest priority)
    if (isset($id_map[$term->term_id])) {
        return $id_map[$term->term_id];
    }
    
    // 2. Health-criteria structural subcategory -> use main counterpart icon
    $structural = zooboxi_health_structural_map();
    if (isset($structural[$term->term_id])) {
        $main_id = $structural[$term->term_id];
        if (isset($id_map[$main_id])) {
            return $id_map[$main_id];
        }
    }
    
    // 3. Name-based fallback (unique names only)
    $name_map = zooboxi_get_category_icon_map_by_name();
    if (isset($name_map[$term->name])) {
        return $name_map[$term->name];
    }
    
    // 4. WooCommerce thumbnail
    $thumb_id = get_term_meta($term->term_id, 'thumbnail_id', true);
    if ($thumb_id) {
        $img_url = wp_get_attachment_url($thumb_id);
        if ($img_url) return $img_url;
    }
    
    return '';
}


// ═══════════ SUBCATEGORY NAVIGATION BAR ═══════════
add_action('woocommerce_before_shop_loop', 'zooboxi_subcategory_navigation', 5);
add_action('woocommerce_archive_description', 'zooboxi_subcategory_navigation', 20);

function zooboxi_subcat_nav_rendered($set = false) {
    static $rendered = false;
    if ($set) $rendered = true;
    return $rendered;
}

function zooboxi_subcategory_navigation() {
    if (!is_product_category()) return;
    if (zooboxi_subcat_nav_rendered()) return;
    zooboxi_subcat_nav_rendered(true);
    
    $current_cat = get_queried_object();
    if (!$current_cat || !isset($current_cat->term_id)) return;
    
    // Skip brands and EN trees
    if (zooboxi_is_under_brands($current_cat->term_id)) return;
    if (zooboxi_is_under_en_tree($current_cat->term_id)) return;
    
    // Get child categories
    $children = get_terms([
        'taxonomy'   => 'product_cat',
        'parent'     => $current_cat->term_id,
        'hide_empty' => false,
        'orderby'    => 'count',
        'order'      => 'DESC',
    ]);
    
    if (empty($children) || is_wp_error($children)) return;
    
    // ─── Custom Breadcrumb ───
    $ancestors = get_ancestors($current_cat->term_id, 'product_cat', 'taxonomy');
    $ancestors = array_reverse($ancestors);
    
    $breadcrumb_html = '<nav class="zbx-breadcrumb" aria-label="breadcrumb"><a href="' . home_url('/') . '">الرئيسية</a>';
    foreach ($ancestors as $ancestor_id) {
        $ancestor = get_term($ancestor_id, 'product_cat');
        if ($ancestor && !is_wp_error($ancestor)) {
            $breadcrumb_html .= ' <span class="zbx-bc-sep">/</span> <a href="' . esc_url(get_term_link($ancestor)) . '">' . esc_html($ancestor->name) . '</a>';
        }
    }
    $breadcrumb_html .= ' <span class="zbx-bc-sep">/</span> <span class="zbx-bc-current">' . esc_html($current_cat->name) . '</span></nav>';
    
    // ─── Category Header ───
    $cat_icon = zooboxi_get_category_icon($current_cat);
    $cat_desc = $current_cat->description ?: '';
    
    echo '<div class="zbx-cat-header">';
    echo $breadcrumb_html;
    echo '<div class="zbx-cat-title-row">';
    if ($cat_icon) {
        echo '<img src="' . esc_url($cat_icon) . '" alt="' . esc_attr($current_cat->name) . '" class="zbx-cat-header-icon" onerror="this.style.display=\'none\'" />';
    }
    echo '<div class="zbx-cat-title-text">';
    echo '<h1 class="zbx-cat-title">' . esc_html($current_cat->name) . '</h1>';
    if ($cat_desc) {
        echo '<p class="zbx-cat-desc">' . esc_html(wp_strip_all_tags($cat_desc)) . '</p>';
    }
    echo '</div></div></div>';
    
    // ─── Detect: Health criteria animal page? ───
    $roots = zooboxi_root_ids();
    $is_health_animal_page = zooboxi_is_under_health_criteria($current_cat->term_id)
                             && $current_cat->term_id !== $roots['health_criteria'];
    
    if ($is_health_animal_page) {
        // Split children: structural vs health issues
        $structural_ids = array_keys(zooboxi_health_structural_map());
        $structural_children = [];
        $health_children = [];
        
        foreach ($children as $child) {
            if (in_array($child->term_id, $structural_ids)) {
                $structural_children[] = $child;
            } else {
                $health_children[] = $child;
            }
        }
        
        // ─── Structural as icon scrollbar ───
        if (!empty($structural_children)) {
            echo '<div class="zbx-subcat-nav">';
            echo '<div class="zbx-subcat-scroll">';
            foreach ($structural_children as $child) {
                $icon_url = zooboxi_get_category_icon($child);
                $link = get_term_link($child);
                echo '<a href="' . esc_url($link) . '" class="zbx-subcat-item" title="' . esc_attr($child->name) . '">';
                echo '<div class="zbx-subcat-img-wrap">';
                if ($icon_url) {
                    echo '<img src="' . esc_url($icon_url) . '" alt="' . esc_attr($child->name) . '" loading="lazy" onerror="this.parentElement.innerHTML=\'<span class=zbx-subcat-emoji>🐾</span>\'" />';
                } else {
                    echo '<span class="zbx-subcat-emoji">🐾</span>';
                }
                echo '</div>';
                echo '<span class="zbx-subcat-name">' . esc_html($child->name) . '</span>';
                echo '</a>';
            }
            echo '</div></div>';
        }
        
        // ─── Health Issues as Tag Cloud ───
        if (!empty($health_children)) {
            echo '<div class="zbx-health-tags">';
            echo '<h3 class="zbx-health-tags-title"><span class="zbx-health-icon">🩺</span> المشاكل الصحية</h3>';
            echo '<div class="zbx-health-tags-cloud">';
            foreach ($health_children as $child) {
                $link = get_term_link($child);
                $count = $child->count;
                echo '<a href="' . esc_url($link) . '" class="zbx-health-tag" title="' . esc_attr($child->name) . ' (' . $count . ' منتج)">';
                echo esc_html($child->name);
                if ($count > 0) {
                    echo '<span class="zbx-health-tag-count">' . $count . '</span>';
                }
                echo '</a>';
            }
            echo '</div></div>';
        }
        
    } else {
        // ─── Normal subcategory icon scrollbar ───
        echo '<div class="zbx-subcat-nav">';
        echo '<div class="zbx-subcat-scroll">';
        
        foreach ($children as $child) {
            $icon_url = zooboxi_get_category_icon($child);
            $link = get_term_link($child);
            
            echo '<a href="' . esc_url($link) . '" class="zbx-subcat-item" title="' . esc_attr($child->name) . '">';
            echo '<div class="zbx-subcat-img-wrap">';
            if ($icon_url) {
                echo '<img src="' . esc_url($icon_url) . '" alt="' . esc_attr($child->name) . '" loading="lazy" onerror="this.parentElement.innerHTML=\'<span class=zbx-subcat-emoji>🐾</span>\'" />';
            } else {
                echo '<span class="zbx-subcat-emoji">🐾</span>';
            }
            echo '</div>';
            echo '<span class="zbx-subcat-name">' . esc_html($child->name) . '</span>';
            echo '</a>';
        }
        
        echo '</div></div>';
    }
}



// ═══════════ PROFESSIONAL FILTER SYSTEM ═══════════

// Hide default WooCommerce breadcrumb on category pages (we use our own)
add_filter('woocommerce_before_main_content', function() {
    if (is_product_category()) {
        remove_action('woocommerce_before_main_content', 'woocommerce_breadcrumb', 20);
    }
}, 5);

// Determine which filter attributes are relevant for the current category
function zooboxi_get_relevant_filters(int $cat_id): array {
    $ancestors = get_ancestors($cat_id, 'product_cat', 'taxonomy');
    $cat = get_term($cat_id, 'product_cat');
    $name = $cat ? $cat->name : '';
    
    // Collect all relevant category names (current + ancestors)
    $all_names = [$name];
    foreach ($ancestors as $a_id) {
        $a = get_term($a_id, 'product_cat');
        if ($a) $all_names[] = $a->name;
    }
    
    // Food-related categories (Arabic names)
    $food_names = ['طعام', 'الطعام', 'الطعام الجاف', 'الطعام الرطب', 'طعام القطط البالغة',
                   'طعام القطط الصغيرة', 'طعام القطط المسنة', 'الحليب والسوائل',
                   'طعام التحكم في الوزن', 'طعام للحساسية الهضمية',
                   'طعام الكلاب البالغة', 'طعام الجراء', 'طعام الكلاب المسنة',
                   'طعام ومكافات الطيور', 'طعام ومكافات القوارض'];
    // Supplies-related
    $supplies_names = ['مستلزمات القطط', 'مستلزمات الكلاب', 'مستلزمات الطيور',
                       'مستلزمات الارانب والهماستر', 'وسادات وبيوت واقفاص',
                       'صناديق وشنط التنقل', 'ادوات الطعام', 'العاب وكاتنيب',
                       'اطواق', 'اثاث وخداشات', 'مشدات وصدريات', 'قلادات قابلة للحفر'];
    // Litter-related
    $litter_names = ['رمل القطط', 'مستلزمات الرمل', 'صناديق الرمل',
                     'مستلزمات صندوق الرمل', 'معطرات ومقلل الروائح الكريهة'];
    // Health-related
    $health_names = ['صحة القطط', 'صحة الكلاب', 'مضاد حساسية',
                     'لمعان وصحة الفرو والجلد'];
    // Treats
    $treats_names = ['المكافآت والفيتامينات', 'المكافات والفيتامينات',
                     'مكافآت كريمية', 'الكريمي', 'البسكويت والمقرمشات',
                     'المكافآت والوجبات الخفيفة', 'الناعمة والمضغية',
                     'مكافآت العناية بالأسنان', 'الفيتامينات والمكملات'];
    // Cleaning
    $cleaning_names = ['التنظيف والتدريب', 'الاستحمام والتنظيف الجاف',
                       'شامبو وبلسم', 'فرش وامشاط ومقصات'];

    $is_food    = !empty(array_intersect($all_names, $food_names));
    $is_supply  = !empty(array_intersect($all_names, $supplies_names));
    $is_litter  = !empty(array_intersect($all_names, $litter_names));
    $is_health  = !empty(array_intersect($all_names, $health_names));
    $is_treats  = !empty(array_intersect($all_names, $treats_names));
    $is_clean   = !empty(array_intersect($all_names, $cleaning_names));
    
    // Always show brand
    $filters = ['pa_brand'];
    
    if ($is_food) {
        $filters = array_merge($filters, ['pa_age', 'pa_flavor', 'pa_food-type', 'pa_weight-opt']);
    } elseif ($is_treats) {
        $filters = array_merge($filters, ['pa_age', 'pa_flavor', 'pa_food-type']);
    } elseif ($is_litter) {
        $filters = array_merge($filters, ['pa_litter-type']);
    } elseif ($is_supply) {
        $filters = array_merge($filters, ['pa_color', 'pa_material', 'pa_size-opt']);
    } elseif ($is_health) {
        $filters = array_merge($filters, ['pa_health', 'pa_age']);
    } elseif ($is_clean) {
        $filters = array_merge($filters, ['pa_product-type']);
    } else {
        // Top-level/root category: show common filters
        $filters = array_merge($filters, ['pa_age', 'pa_food-type']);
    }
    
    return array_unique($filters);
}

// Filter attribute labels in Arabic
function zooboxi_get_filter_labels(): array {
    return [
        'pa_brand'       => 'العلامة التجارية',
        'pa_age'         => 'المرحلة العمرية',
        'pa_flavor'      => 'النكهة',
        'pa_food-type'   => 'شكل الطعام',
        'pa_health'      => 'ميزة صحية',
        'pa_litter-type' => 'نوع الرمل',
        'pa_color'       => 'اللون',
        'pa_material'    => 'المادة',
        'pa_product-type'=> 'نوع المنتج',
        'pa_size-opt'    => 'الحجم',
        'pa_weight-opt'  => 'الوزن',
    ];
}

// Render filter button + sidebar on category pages
add_action('woocommerce_before_shop_loop', 'zooboxi_render_filter_system', 15);

function zooboxi_render_filter_system() {
    if (!is_product_category() && !is_shop()) return;
    
    $current_cat = get_queried_object();
    $cat_id = ($current_cat && isset($current_cat->term_id)) ? $current_cat->term_id : 0;
    
    // Total product count
    $count_query = new WP_Query([
        'post_type'      => 'product',
        'post_status'    => 'publish',
        'posts_per_page' => -1,
        'fields'         => 'ids',
        'tax_query'      => $cat_id ? [[
            'taxonomy' => 'product_cat',
            'field'    => 'term_id',
            'terms'    => $cat_id,
            'include_children' => true,
        ]] : [],
    ]);
    $total_count = $count_query->found_posts;
    wp_reset_postdata();
    
    // Get relevant filters  
    $relevant_filters = $cat_id ? zooboxi_get_relevant_filters($cat_id) : ['pa_brand', 'pa_age', 'pa_food-type'];
    $filter_labels = zooboxi_get_filter_labels();
    
    // Count + filter bar
    echo '<div class="zbx-shop-toolbar">';
    echo '<span class="zbx-product-count">إجمالي ' . $total_count . ' منتج</span>';
    echo '<button type="button" id="zbx-filter-toggle" class="zbx-filter-toggle-btn">';
    echo '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/><circle cx="8" cy="6" r="2" fill="currentColor"/><circle cx="16" cy="12" r="2" fill="currentColor"/><circle cx="10" cy="18" r="2" fill="currentColor"/></svg>';
    echo '<span>تصفية</span>';
    echo '</button>';
    echo '</div>';
    
    // Active filter tags container
    echo '<div id="zbx-active-filters" class="zbx-active-filters" style="display:none;"></div>';
    
    // ─── Filter Overlay + Sidebar ───
    echo '<div id="zbx-filter-overlay" class="zbx-filter-overlay"></div>';
    echo '<aside id="zbx-filter-sidebar" class="zbx-filter-sidebar">';
    
    // Sidebar header
    echo '<div class="zbx-filter-header">';
    echo '<h3 class="zbx-filter-title">تصفية</h3>';
    echo '<button type="button" id="zbx-filter-close" class="zbx-filter-close">✕</button>';
    echo '</div>';
    
    echo '<div class="zbx-filter-body">';
    
    // ─── Sort Section ───
    echo '<div class="zbx-filter-section zbx-filter-open">';
    echo '<button type="button" class="zbx-filter-section-toggle">';
    echo '<span>ترتيب حسب</span>';
    echo '<svg class="zbx-chevron" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="6 9 12 15 18 9"/></svg>';
    echo '</button>';
    echo '<div class="zbx-filter-section-content">';
    echo '<div class="zbx-sort-options">';
    $sort_options = [
        'date'       => 'الأحدث',
        'popularity' => 'الأكثر مبيعاً',
        'price-asc'  => 'من الأقل إلى الأعلى',
        'price-desc' => 'من الأعلى إلى الأقل',
    ];
    foreach ($sort_options as $val => $label) {
        $checked = ($val === 'date') ? ' checked' : '';
        echo '<label class="zbx-sort-option"><input type="radio" name="zbx_sort" value="' . esc_attr($val) . '"' . $checked . ' /><span>' . esc_html($label) . '</span></label>';
    }
    echo '</div></div></div>';
    
    // ─── Attribute Filter Sections ───
    foreach ($relevant_filters as $taxonomy) {
        $terms = get_terms([
            'taxonomy'   => $taxonomy,
            'hide_empty' => true,
            'orderby'    => 'count',
            'order'      => 'DESC',
        ]);
        
        if (empty($terms) || is_wp_error($terms)) continue;
        
        $label = $filter_labels[$taxonomy] ?? $taxonomy;
        $attr_slug = str_replace('pa_', '', $taxonomy);
        $show_more = count($terms) > 6;
        
        echo '<div class="zbx-filter-section">';
        echo '<button type="button" class="zbx-filter-section-toggle">';
        echo '<span>' . esc_html($label) . '</span>';
        echo '<svg class="zbx-chevron" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="6 9 12 15 18 9"/></svg>';
        echo '</button>';
        echo '<div class="zbx-filter-section-content">';
        echo '<div class="zbx-filter-checkboxes" data-attr="' . esc_attr($attr_slug) . '">';
        
        foreach ($terms as $i => $term) {
            $hidden_class = ($show_more && $i >= 6) ? ' zbx-hidden-option' : '';
            echo '<label class="zbx-filter-option' . $hidden_class . '">';
            echo '<input type="checkbox" name="filter_' . esc_attr($attr_slug) . '[]" value="' . esc_attr($term->slug) . '" />';
            echo '<span class="zbx-filter-label">' . esc_html($term->name) . '</span>';
            echo '<span class="zbx-filter-count">(' . $term->count . ')</span>';
            echo '</label>';
        }
        
        echo '</div>';
        if ($show_more) {
            echo '<button type="button" class="zbx-show-more-btn" data-attr="' . esc_attr($attr_slug) . '">عرض المزيد ▾</button>';
        }
        echo '</div></div>';
    }
    
    // ─── Price Range Section ───
    // Get min/max prices
    global $wpdb;
    $price_range = $wpdb->get_row("
        SELECT MIN(CAST(pm.meta_value AS DECIMAL(10,2))) as min_price, 
               MAX(CAST(pm.meta_value AS DECIMAL(10,2))) as max_price 
        FROM {$wpdb->postmeta} pm
        JOIN {$wpdb->posts} p ON pm.post_id = p.ID
        WHERE pm.meta_key = '_price' 
        AND p.post_type = 'product' 
        AND p.post_status = 'publish'
        AND pm.meta_value > 0
    ");
    
    $min_price = $price_range ? floor($price_range->min_price) : 0;
    $max_price = $price_range ? ceil($price_range->max_price) : 1000;
    
    echo '<div class="zbx-filter-section">';
    echo '<button type="button" class="zbx-filter-section-toggle">';
    echo '<span>نطاق السعر</span>';
    echo '<svg class="zbx-chevron" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="6 9 12 15 18 9"/></svg>';
    echo '</button>';
    echo '<div class="zbx-filter-section-content">';
    echo '<div class="zbx-price-range" data-min="' . $min_price . '" data-max="' . $max_price . '">';
    echo '<div class="zbx-price-slider-track">';
    echo '<div class="zbx-price-slider-range" id="zbx-price-range"></div>';
    echo '<input type="range" class="zbx-price-input" id="zbx-price-min" min="' . $min_price . '" max="' . $max_price . '" value="' . $min_price . '" step="5" />';
    echo '<input type="range" class="zbx-price-input" id="zbx-price-max" min="' . $min_price . '" max="' . $max_price . '" value="' . $max_price . '" step="5" />';
    echo '</div>';
    echo '<div class="zbx-price-labels">';
    echo '<span id="zbx-price-min-label">' . $min_price . ' ر.س</span>';
    echo '<span id="zbx-price-max-label">' . $max_price . ' ر.س</span>';
    echo '</div>';
    echo '</div></div></div>';
    
    echo '</div>'; // .zbx-filter-body
    
    // Sidebar footer
    echo '<div class="zbx-filter-footer">';
    echo '<button type="button" id="zbx-filter-reset" class="zbx-filter-btn-reset">إعادة تعيين</button>';
    echo '<button type="button" id="zbx-filter-apply" class="zbx-filter-btn-apply">تطبيق الفلاتر</button>';
    echo '</div>';
    
    echo '</aside>'; // .zbx-filter-sidebar
}


// ═══════════ AJAX FILTER HANDLER ═══════════
add_action('wp_ajax_zooboxi_filter_products', 'zooboxi_ajax_filter_products');
add_action('wp_ajax_nopriv_zooboxi_filter_products', 'zooboxi_ajax_filter_products');

function zooboxi_ajax_filter_products() {
    $cat_id     = absint($_POST['category'] ?? 0);
    $sort       = sanitize_text_field($_POST['sort'] ?? 'date');
    $page       = max(1, absint($_POST['page'] ?? 1));
    $price_min  = floatval($_POST['price_min'] ?? 0);
    $price_max  = floatval($_POST['price_max'] ?? 0);
    $per_page   = 24;
    
    // Build tax query
    $tax_query = ['relation' => 'AND'];
    
    if ($cat_id) {
        $tax_query[] = [
            'taxonomy'         => 'product_cat',
            'field'            => 'term_id',
            'terms'            => $cat_id,
            'include_children' => true,
        ];
    }
    
    // Process attribute filters
    $filter_keys = ['brand', 'age', 'flavor', 'food-type', 'health', 'litter-type', 
                    'color', 'material', 'product-type', 'size-opt', 'weight-opt'];
    
    foreach ($filter_keys as $key) {
        $values = isset($_POST['filter_' . str_replace('-', '_', $key)]) 
            ? array_map('sanitize_text_field', (array)$_POST['filter_' . str_replace('-', '_', $key)]) 
            : [];
        
        if (!empty($values)) {
            $tax_query[] = [
                'taxonomy' => 'pa_' . $key,
                'field'    => 'slug',
                'terms'    => $values,
                'operator' => 'IN',
            ];
        }
    }
    
    // Sort mapping
    $orderby = 'date';
    $order   = 'DESC';
    $meta_key = '';
    
    switch ($sort) {
        case 'popularity':
            $orderby = 'meta_value_num';
            $meta_key = 'total_sales';
            $order = 'DESC';
            break;
        case 'price-asc':
            $orderby = 'meta_value_num';
            $meta_key = '_price';
            $order = 'ASC';
            break;
        case 'price-desc':
            $orderby = 'meta_value_num';
            $meta_key = '_price';
            $order = 'DESC';
            break;
        case 'date':
        default:
            $orderby = 'date';
            $order = 'DESC';
            break;
    }
    
    $args = [
        'post_type'      => 'product',
        'post_status'    => 'publish',
        'posts_per_page' => $per_page,
        'paged'          => $page,
        'tax_query'      => $tax_query,
        'orderby'        => $orderby,
        'order'          => $order,
    ];
    
    if ($meta_key) {
        $args['meta_key'] = $meta_key;
    }
    
    // Price filter
    if ($price_min > 0 || $price_max > 0) {
        $args['meta_query'] = [
            'relation' => 'AND',
        ];
        if ($price_min > 0) {
            $args['meta_query'][] = [
                'key'     => '_price',
                'value'   => $price_min,
                'compare' => '>=',
                'type'    => 'NUMERIC',
            ];
        }
        if ($price_max > 0) {
            $args['meta_query'][] = [
                'key'     => '_price',
                'value'   => $price_max,
                'compare' => '<=',
                'type'    => 'NUMERIC',
            ];
        }
    }
    
    $query = new WP_Query($args);
    
    ob_start();
    
    if ($query->have_posts()) {
        woocommerce_product_loop_start();
        
        while ($query->have_posts()) {
            $query->the_post();
            wc_get_template_part('content', 'product');
        }
        
        woocommerce_product_loop_end();
    } else {
        echo '<div class="zbx-no-results">';
        echo '<div class="zbx-no-results-icon">🔍</div>';
        echo '<p class="zbx-no-results-text">لا توجد منتجات تطابق الفلاتر المحددة</p>';
        echo '<button type="button" class="zbx-no-results-reset" onclick="document.getElementById(\'zbx-filter-reset\').click()">إعادة تعيين الفلاتر</button>';
        echo '</div>';
    }
    
    $html = ob_get_clean();
    wp_reset_postdata();
    
    wp_send_json_success([
        'html'       => $html,
        'found'      => $query->found_posts,
        'max_pages'  => $query->max_num_pages,
        'page'       => $page,
    ]);
}


// ═══════════ FILTER + SUBCATEGORY JAVASCRIPT ═══════════
add_action('wp_footer', function() {
    if (!is_product_category() && !is_shop()) return;
    
    $current_cat = get_queried_object();
    $cat_id = ($current_cat && isset($current_cat->term_id)) ? $current_cat->term_id : 0;
    ?>
    <script>
    (function(){
        var catId = <?php echo $cat_id; ?>;
        var ajaxUrl = '<?php echo admin_url("admin-ajax.php"); ?>';
        var isLoading = false;
        var currentPage = 1;

        // ═══ Filter Sidebar Toggle ═══
        var filterToggle = document.getElementById('zbx-filter-toggle');
        var filterSidebar = document.getElementById('zbx-filter-sidebar');
        var filterOverlay = document.getElementById('zbx-filter-overlay');
        var filterClose = document.getElementById('zbx-filter-close');
        
        function openFilters() {
            if (filterSidebar) filterSidebar.classList.add('zbx-open');
            if (filterOverlay) filterOverlay.classList.add('zbx-open');
            document.body.style.overflow = 'hidden';
        }
        function closeFilters() {
            if (filterSidebar) filterSidebar.classList.remove('zbx-open');
            if (filterOverlay) filterOverlay.classList.remove('zbx-open');
            document.body.style.overflow = '';
        }
        
        if (filterToggle) filterToggle.addEventListener('click', openFilters);
        if (filterClose) filterClose.addEventListener('click', closeFilters);
        if (filterOverlay) filterOverlay.addEventListener('click', closeFilters);
        
        // ═══ Accordion Sections ═══
        document.querySelectorAll('.zbx-filter-section-toggle').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var section = this.closest('.zbx-filter-section');
                section.classList.toggle('zbx-filter-open');
            });
        });
        
        // ═══ Show More ═══
        document.querySelectorAll('.zbx-show-more-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var attr = this.dataset.attr;
                var container = this.previousElementSibling;
                var hidden = container.querySelectorAll('.zbx-hidden-option');
                hidden.forEach(function(el) { el.classList.remove('zbx-hidden-option'); });
                this.style.display = 'none';
            });
        });
        
        // ═══ Price Range Slider ═══
        var priceMin = document.getElementById('zbx-price-min');
        var priceMax = document.getElementById('zbx-price-max');
        var priceRange = document.getElementById('zbx-price-range');
        var minLabel = document.getElementById('zbx-price-min-label');
        var maxLabel = document.getElementById('zbx-price-max-label');
        
        function updatePriceSlider() {
            if (!priceMin || !priceMax) return;
            var min = parseInt(priceMin.value);
            var max = parseInt(priceMax.value);
            var total = parseInt(priceMax.max) - parseInt(priceMin.min);
            
            if (min > max) { priceMin.value = max; min = max; }
            
            var leftPercent = ((min - parseInt(priceMin.min)) / total) * 100;
            var rightPercent = ((parseInt(priceMax.max) - max) / total) * 100;
            
            if (priceRange) {
                priceRange.style.left = leftPercent + '%';
                priceRange.style.right = rightPercent + '%';
            }
            if (minLabel) minLabel.textContent = min + ' ر.س';
            if (maxLabel) maxLabel.textContent = max + ' ر.س';
        }
        
        if (priceMin) priceMin.addEventListener('input', updatePriceSlider);
        if (priceMax) priceMax.addEventListener('input', updatePriceSlider);
        updatePriceSlider();
        
        // ═══ Collect Filters ═══
        function collectFilters() {
            var filters = {};
            
            // Sort
            var sortRadio = document.querySelector('input[name="zbx_sort"]:checked');
            filters.sort = sortRadio ? sortRadio.value : 'date';
            
            // Attributes
            document.querySelectorAll('.zbx-filter-checkboxes').forEach(function(group) {
                var attr = group.dataset.attr;
                var checked = group.querySelectorAll('input:checked');
                if (checked.length > 0) {
                    filters['filter_' + attr.replace(/-/g, '_')] = Array.from(checked).map(function(c) { return c.value; });
                }
            });
            
            // Price
            if (priceMin && priceMax) {
                var minVal = parseInt(priceMin.value);
                var maxVal = parseInt(priceMax.value);
                if (minVal > parseInt(priceMin.min)) filters.price_min = minVal;
                if (maxVal < parseInt(priceMax.max)) filters.price_max = maxVal;
            }
            
            return filters;
        }
        
        // ═══ Apply Filters (AJAX) ═══
        function applyFilters(page) {
            if (isLoading) return;
            isLoading = true;
            currentPage = page || 1;
            
            var filters = collectFilters();
            
            var formData = new FormData();
            formData.append('action', 'zooboxi_filter_products');
            formData.append('category', catId);
            formData.append('page', currentPage);
            formData.append('sort', filters.sort || 'date');
            
            if (filters.price_min) formData.append('price_min', filters.price_min);
            if (filters.price_max) formData.append('price_max', filters.price_max);
            
            // Add attribute filters
            Object.keys(filters).forEach(function(key) {
                if (key.startsWith('filter_') && Array.isArray(filters[key])) {
                    filters[key].forEach(function(val) {
                        formData.append(key + '[]', val);
                    });
                }
            });
            
            // Show loading state
            var productsContainer = document.querySelector('.products, ul.products');
            if (productsContainer) {
                productsContainer.style.opacity = '0.4';
                productsContainer.style.pointerEvents = 'none';
            }
            
            fetch(ajaxUrl, { method: 'POST', body: formData })
            .then(function(r) { return r.json(); })
            .then(function(res) {
                isLoading = false;
                
                if (res.success && res.data.html) {
                    // Replace products
                    var wrapper = document.querySelector('.woocommerce-notices-wrapper');
                    var parent = productsContainer ? productsContainer.parentElement : null;
                    
                    if (parent && productsContainer) {
                        // Remove old products and pagination
                        productsContainer.remove();
                        var oldPagination = document.querySelector('.woocommerce-pagination');
                        if (oldPagination) oldPagination.remove();
                        
                        // Insert new content
                        var temp = document.createElement('div');
                        temp.innerHTML = res.data.html;
                        
                        if (wrapper && wrapper.nextSibling) {
                            wrapper.parentNode.insertBefore(temp.firstElementChild, wrapper.nextSibling);
                        } else {
                            parent.appendChild(temp.firstElementChild);
                        }
                    }
                    
                    // Update count
                    var countEl = document.querySelector('.zbx-product-count');
                    if (countEl) countEl.textContent = 'إجمالي ' + res.data.found + ' منتج';
                    
                    // Update URL
                    updateURL(filters);
                    
                    // Update active filter tags
                    updateActiveFilters(filters);
                    
                    // Scroll to top of products
                    var toolbar = document.querySelector('.zbx-shop-toolbar');
                    if (toolbar) toolbar.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    
                    // Re-init WC scripts
                    if (typeof jQuery !== 'undefined') {
                        jQuery(document.body).trigger('wc_fragment_refresh');
                    }
                }
            })
            .catch(function() { isLoading = false; })
            .finally(function() {
                var pc = document.querySelector('.products, ul.products');
                if (pc) { pc.style.opacity = ''; pc.style.pointerEvents = ''; }
            });
            
            closeFilters();
        }
        
        // ═══ Update URL Parameters ═══
        function updateURL(filters) {
            var params = new URLSearchParams();
            if (filters.sort && filters.sort !== 'date') params.set('sort', filters.sort);
            if (filters.price_min) params.set('price_min', filters.price_min);
            if (filters.price_max) params.set('price_max', filters.price_max);
            
            Object.keys(filters).forEach(function(key) {
                if (key.startsWith('filter_') && Array.isArray(filters[key])) {
                    params.set(key, filters[key].join(','));
                }
            });
            
            var newUrl = window.location.pathname;
            var qs = params.toString();
            if (qs) newUrl += '?' + qs;
            
            history.replaceState(null, '', newUrl);
        }
        
        // ═══ Active Filter Tags ═══
        function updateActiveFilters(filters) {
            var container = document.getElementById('zbx-active-filters');
            if (!container) return;
            
            var tags = [];
            var labels = <?php echo json_encode(zooboxi_get_filter_labels()); ?>;
            
            Object.keys(filters).forEach(function(key) {
                if (key.startsWith('filter_') && Array.isArray(filters[key])) {
                    var attrSlug = key.replace('filter_', '').replace(/_/g, '-');
                    var groupLabel = labels['pa_' + attrSlug] || attrSlug;
                    
                    filters[key].forEach(function(val) {
                        // Find the label text from the checkbox
                        var checkbox = document.querySelector('input[value="' + val + '"]');
                        var labelText = val;
                        if (checkbox) {
                            var parentLabel = checkbox.closest('.zbx-filter-option');
                            if (parentLabel) {
                                var labelSpan = parentLabel.querySelector('.zbx-filter-label');
                                if (labelSpan) labelText = labelSpan.textContent;
                            }
                        }
                        tags.push('<span class="zbx-active-tag" data-key="' + key + '" data-value="' + val + '">' + labelText + ' <button type="button" class="zbx-tag-remove">✕</button></span>');
                    });
                }
            });
            
            if (filters.price_min || filters.price_max) {
                var priceText = (filters.price_min || 0) + ' - ' + (filters.price_max || '∞') + ' ر.س';
                tags.push('<span class="zbx-active-tag zbx-tag-price">' + priceText + ' <button type="button" class="zbx-tag-remove zbx-tag-remove-price">✕</button></span>');
            }
            
            if (tags.length > 0) {
                tags.push('<button type="button" class="zbx-clear-all-filters">مسح الكل</button>');
                container.innerHTML = tags.join('');
                container.style.display = 'flex';
            } else {
                container.innerHTML = '';
                container.style.display = 'none';
            }
        }
        
        // ═══ Event: Remove individual filter tag ═══
        document.addEventListener('click', function(e) {
            if (e.target.classList.contains('zbx-tag-remove')) {
                var tag = e.target.closest('.zbx-active-tag');
                if (tag) {
                    if (tag.classList.contains('zbx-tag-price')) {
                        // Reset price
                        if (priceMin) priceMin.value = priceMin.min;
                        if (priceMax) priceMax.value = priceMax.max;
                        updatePriceSlider();
                    } else {
                        var key = tag.dataset.key;
                        var val = tag.dataset.value;
                        var checkbox = document.querySelector('.zbx-filter-checkboxes input[value="' + val + '"]');
                        if (checkbox) checkbox.checked = false;
                    }
                    applyFilters(1);
                }
            }
            if (e.target.classList.contains('zbx-clear-all-filters')) {
                document.getElementById('zbx-filter-reset').click();
            }
        });
        
        // ═══ Apply Button ═══
        var applyBtn = document.getElementById('zbx-filter-apply');
        if (applyBtn) applyBtn.addEventListener('click', function() { applyFilters(1); });
        
        // ═══ Reset Button ═══
        var resetBtn = document.getElementById('zbx-filter-reset');
        if (resetBtn) resetBtn.addEventListener('click', function() {
            // Uncheck all
            document.querySelectorAll('.zbx-filter-checkboxes input:checked').forEach(function(c) { c.checked = false; });
            // Reset sort
            var defaultSort = document.querySelector('input[name="zbx_sort"][value="date"]');
            if (defaultSort) defaultSort.checked = true;
            // Reset price
            if (priceMin) { priceMin.value = priceMin.min; }
            if (priceMax) { priceMax.value = priceMax.max; }
            updatePriceSlider();
            
            // Reload page without filters
            window.location.href = window.location.pathname;
        });
        
        // ═══ Desktop: Auto-apply on change ═══
        if (window.innerWidth >= 992) {
            document.querySelectorAll('.zbx-filter-checkboxes input, input[name="zbx_sort"]').forEach(function(input) {
                input.addEventListener('change', function() { applyFilters(1); });
            });
        }
        
        // ═══ Restore filters from URL ═══
        (function restoreFromURL() {
            var params = new URLSearchParams(window.location.search);
            var hasFilters = false;
            
            params.forEach(function(value, key) {
                if (key === 'sort') {
                    var radio = document.querySelector('input[name="zbx_sort"][value="' + value + '"]');
                    if (radio) { radio.checked = true; hasFilters = true; }
                } else if (key === 'price_min' && priceMin) {
                    priceMin.value = value; hasFilters = true;
                } else if (key === 'price_max' && priceMax) {
                    priceMax.value = value; hasFilters = true;
                } else if (key.startsWith('filter_')) {
                    var values = value.split(',');
                    values.forEach(function(v) {
                        var cb = document.querySelector('.zbx-filter-checkboxes input[value="' + v + '"]');
                        if (cb) { cb.checked = true; hasFilters = true; }
                    });
                }
            });
            
            if (hasFilters) {
                updatePriceSlider();
                applyFilters(1);
            }
        })();
        
    })();
    </script>
    <?php
}, 97);

// ═══════════ CUSTOM ZOOBOXI FOOTER ═══════════
// Remove Astra default footer
add_filter('astra_footer_copyright_section_1', '__return_empty_string');
add_filter('astra_footer_copyright_section_2', '__return_empty_string');

// Hide Astra footer via CSS and render our custom, on-brand footer.
add_action('wp_footer', function() {
    if (is_admin()) return;
    $year = date('Y');
    $acc  = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('myaccount') : '/my-account/';
    $cart = function_exists('wc_get_cart_url') ? wc_get_cart_url() : '/cart/';
    ?>
    <style>
    /* Hide Astra default footer */
    .site-below-footer-wrap,
    .ast-footer-copyright,
    .site-footer .ast-builder-grid-row-container { display: none !important; }

    /* ═══ Zooboxi Custom Footer ═══ */
    .zbx-footer {
        --zf-teal: var(--z-primary, #429d9c);
        --zf-teal-d: var(--z-primary-dark, #2d7a79);
        --zf-coral: var(--z-icons, #d46856);
        --zf-ink: var(--z-text, #2c3e2d);
        --zf-muted: #6b7c6e;
        background: linear-gradient(180deg, #f3faf8 0%, #eef6f1 60%, #f6f1ea 100%);
        padding: 46px 16px 100px;
        font-family: 'Tajawal', sans-serif;
        direction: rtl;
    }
    .zbx-footer * { box-sizing: border-box; }
    .zbx-footer-inner {
        position: relative;
        max-width: 1200px;
        margin: 0 auto;
        border: 1px solid rgba(66,157,156,0.18);
        border-radius: 26px;
        background: #fff;
        box-shadow: 0 18px 50px rgba(44,62,45,0.07);
        overflow: hidden;
    }
    .zbx-footer-inner::before {
        content: "";
        display: block;
        height: 5px;
        background: linear-gradient(90deg, var(--zf-teal), var(--zf-coral));
    }
    .zbx-footer-pad { padding: 36px 34px 26px; }

    /* Top grid */
    .zbx-footer-grid {
        display: grid;
        grid-template-columns: 1.7fr 1fr 1.1fr 1fr;
        gap: 32px;
    }
    .zbx-footer-col h4 {
        font-family: 'El Messiri', sans-serif;
        font-size: 17px;
        font-weight: 700;
        color: var(--zf-ink);
        margin: 0 0 14px;
        position: relative;
        padding-bottom: 10px;
    }
    .zbx-footer-col h4::after {
        content: "";
        position: absolute;
        inset-inline-start: 0;
        bottom: 0;
        width: 34px;
        height: 3px;
        border-radius: 3px;
        background: var(--zf-coral);
    }
    .zbx-footer-col a {
        display: block;
        color: #4a5a4c;
        text-decoration: none;
        font-size: 14px;
        font-weight: 600;
        padding: 7px 0;
        transition: color 0.2s ease, transform 0.2s ease;
    }
    .zbx-footer-col a:hover { color: var(--zf-coral); transform: translateX(-5px); }

    /* Brand column */
    .zbx-footer-brand { display: flex; flex-direction: column; gap: 14px; max-width: 350px; }
    .zbx-footer-logo-tile {
        width: 84px; height: 84px; border-radius: 18px; background: #fff;
        box-shadow: 0 6px 18px rgba(66,157,156,0.12);
        display: inline-flex; align-items: center; justify-content: center; padding: 8px;
    }
    .zbx-footer-logo-tile img { width: 100%; height: 100%; object-fit: contain; }
    .zbx-footer-desc { font-size: 14px; color: var(--zf-muted); line-height: 1.9; font-weight: 500; margin: 0; }
    .zbx-footer-contact {
        display: inline-flex; align-items: center; gap: 8px;
        color: var(--zf-teal-d); font-weight: 700; font-size: 14px; text-decoration: none;
        direction: ltr; unicode-bidi: plaintext; width: fit-content;
    }
    .zbx-footer-contact:hover { color: var(--zf-coral); }

    /* Trust strip (registrations) */
    .zbx-footer-trust {
        display: flex; gap: 14px; flex-wrap: wrap;
        margin-top: 28px; padding-top: 24px;
        border-top: 1px dashed rgba(66,157,156,0.25);
    }
    .zbx-footer-reg-card {
        display: flex; align-items: center; gap: 11px;
        padding: 12px 16px; background: #f7faf8;
        border: 1px solid rgba(66,157,156,0.14); border-radius: 16px;
        flex: 1; min-width: 210px; transition: all 0.25s ease;
    }
    .zbx-footer-reg-card:hover {
        border-color: var(--zf-teal);
        box-shadow: 0 8px 20px rgba(66,157,156,0.12);
        transform: translateY(-2px);
    }
    .zbx-footer-reg-iconwrap {
        width: 44px; height: 44px; border-radius: 12px;
        background: rgba(66,157,156,0.10);
        display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0;
    }
    .zbx-footer-reg-iconwrap img { width: 26px; height: 26px; }
    .zbx-footer-reg-label { display: block; font-size: 11px; font-weight: 600; color: var(--zf-muted); margin-bottom: 3px; }
    .zbx-footer-reg-value { display: block; font-size: 14px; font-weight: 800; color: var(--zf-ink); direction: ltr; unicode-bidi: plaintext; letter-spacing: 0.3px; }

    /* Bottom bar */
    .zbx-footer-bottom {
        display: flex; align-items: center; justify-content: space-between;
        gap: 18px; flex-wrap: wrap; margin-top: 22px; padding-top: 20px;
        border-top: 1px solid #eef2ee;
    }
    .zbx-footer-copy { font-size: 13px; color: var(--zf-muted); font-weight: 700; }
    .zbx-footer-made { font-size: 12.5px; color: var(--zf-muted); font-weight: 600; }
    .zbx-footer-payments { display: flex; gap: 9px; flex-wrap: wrap; align-items: center; }
    .zbx-footer-payments img {
        height: 30px; width: auto; border-radius: 7px; background: #fff;
        padding: 4px 9px; border: 1px solid #eef2ee; box-shadow: 0 1px 4px rgba(0,0,0,0.05);
    }

    /* Responsive */
    @media (max-width: 900px) {
        .zbx-footer-grid { grid-template-columns: 1fr 1fr; gap: 26px; }
        .zbx-footer-col--brand { grid-column: 1 / -1; }
    }
    /* Mobile: a deliberately tiny, simple footer (nav + drawer cover the rest). */
    @media (max-width: 768px) {
        .zbx-footer { padding: 16px 12px 110px; background: #f3faf8; }
        .zbx-footer-inner { border-radius: 16px; box-shadow: 0 8px 22px rgba(44,62,45,0.06); }
        .zbx-footer-inner::before { height: 3px; }
        .zbx-footer-pad { padding: 16px 16px 14px; }

        .zbx-footer-grid { display: block; text-align: center; }
        /* Shop + account columns are redundant on mobile (bottom nav + drawer). */
        .zbx-footer-col--shop, .zbx-footer-col--account { display: none; }

        /* Brand → just a small centered logo. */
        .zbx-footer-col--brand { margin-bottom: 12px; }
        .zbx-footer-brand { align-items: center; gap: 8px; max-width: none; }
        .zbx-footer-logo-tile { width: 50px; height: 50px; border-radius: 12px; padding: 6px; margin: 0 auto; }
        .zbx-footer-desc { display: none; }
        .zbx-footer-contact { margin: 0 auto; font-size: 12px; }

        /* Policies → one compact inline line with dot separators. */
        .zbx-footer-col--help { display: block; }
        .zbx-footer-col--help h4 { display: none; }
        .zbx-footer-col--help a { display: inline; padding: 0; font-size: 12px; font-weight: 600; color: var(--zf-muted); }
        .zbx-footer-col--help a::after { content: "•"; margin: 0 7px; color: #cbd6cd; }
        .zbx-footer-col--help a:last-child::after { content: ""; margin: 0; }
        .zbx-footer-col--help a:hover { color: var(--zf-coral); transform: none; }

        /* Registrations → tiny borderless chips. */
        .zbx-footer-trust { margin-top: 12px; padding-top: 10px; gap: 5px; justify-content: center; }
        .zbx-footer-reg-card { flex: 0 1 auto; min-width: 0; padding: 4px 9px; gap: 4px; }
        .zbx-footer-reg-card:hover { transform: none; box-shadow: none; }
        .zbx-footer-reg-iconwrap { display: none; }
        .zbx-footer-reg-info { display: flex; align-items: baseline; gap: 4px; }
        .zbx-footer-reg-label { margin: 0; font-size: 9.5px; }
        .zbx-footer-reg-value { font-size: 10px; font-weight: 700; }

        /* Bottom → tiny, stacked. */
        .zbx-footer-bottom { flex-direction: column; gap: 7px; margin-top: 12px; padding-top: 12px; text-align: center; }
        .zbx-footer-payments { gap: 6px; }
        .zbx-footer-payments img { height: 22px; padding: 3px 6px; }
        .zbx-footer-copy { font-size: 11px; }
        .zbx-footer-made { font-size: 10.5px; }
    }
    </style>

    <footer class="zbx-footer">
        <div class="zbx-footer-inner">
            <div class="zbx-footer-pad">
                <div class="zbx-footer-grid">
                    <!-- Brand -->
                    <div class="zbx-footer-col zbx-footer-col--brand">
                        <div class="zbx-footer-brand">
                            <span class="zbx-footer-logo-tile">
                                <img src="https://store.zooboxi.com/wp-content/uploads/zooboxi-assets/ceb32bf7-abc5-4b15-b88f-9002f9eb27c9-200x.png" alt="Zooboxi">
                            </span>
                            <p class="zbx-footer-desc">
                                Zooboxi متجرك الإلكتروني المتخصص في مستلزمات الحيوانات الأليفة 🐱🐶، بتوصيل سريع خلال ساعتين لأنحاء المملكة.
                            </p>
                            <a class="zbx-footer-contact" href="mailto:info@zooboxi.com">✉️ info@zooboxi.com</a>
                        </div>
                    </div>

                    <!-- Shop by animal -->
                    <div class="zbx-footer-col zbx-footer-col--shop">
                        <h4>تسوّق حسب الحيوان</h4>
                        <a href="/product-category/قطط/">🐱 قطط</a>
                        <a href="/product-category/كلاب/">🐕 كلاب</a>
                        <a href="/product-category/طيور/">🦜 طيور</a>
                        <a href="/product-category/حيوانات-صغيرة/">🐹 حيوانات صغيرة</a>
                        <a href="/shop/">كل المنتجات</a>
                    </div>

                    <!-- Customer service -->
                    <div class="zbx-footer-col zbx-footer-col--help">
                        <h4>خدمة العملاء</h4>
                        <a href="/shipping-policy">خيارات الشحن والتوصيل</a>
                        <a href="/return-policy">سياسة الاستبدال والإرجاع</a>
                        <a href="/terms-conditions">الشروط والأحكام</a>
                        <a href="/privacy-policy">سياسة الخصوصية</a>
                    </div>

                    <!-- Account -->
                    <div class="zbx-footer-col zbx-footer-col--account">
                        <h4>حسابك</h4>
                        <a href="<?php echo esc_url($acc); ?>">👤 حسابي</a>
                        <a href="<?php echo esc_url($cart); ?>">🛒 سلة التسوق</a>
                        <a href="<?php echo esc_url($acc); ?>">📦 تتبّع طلباتي</a>
                        <a href="mailto:info@zooboxi.com">💬 تواصل معنا</a>
                    </div>
                </div>

                <!-- Trust / registrations -->
                <div class="zbx-footer-trust">
                    <div class="zbx-footer-reg-card">
                        <span class="zbx-footer-reg-iconwrap"><img src="/wp-content/uploads/zooboxi-assets/vat-icon.svg" alt="VAT"></span>
                        <div class="zbx-footer-reg-info">
                            <span class="zbx-footer-reg-label">الرقم الضريبي</span>
                            <span class="zbx-footer-reg-value">310160668400003</span>
                        </div>
                    </div>
                    <div class="zbx-footer-reg-card">
                        <span class="zbx-footer-reg-iconwrap"><img src="/wp-content/uploads/zooboxi-assets/business-icon.svg" alt="منصة الأعمال"></span>
                        <div class="zbx-footer-reg-info">
                            <span class="zbx-footer-reg-label">منصة الأعمال</span>
                            <span class="zbx-footer-reg-value">7012580143</span>
                        </div>
                    </div>
                    <div class="zbx-footer-reg-card">
                        <span class="zbx-footer-reg-iconwrap"><img src="/wp-content/uploads/zooboxi-assets/saudi-emblem.svg" alt="السجل التجاري"></span>
                        <div class="zbx-footer-reg-info">
                            <span class="zbx-footer-reg-label">السجل التجاري</span>
                            <span class="zbx-footer-reg-value">7009370755</span>
                        </div>
                    </div>
                </div>

                <!-- Bottom bar -->
                <div class="zbx-footer-bottom">
                    <div class="zbx-footer-copy">© ZooBoxi <?php echo esc_html($year); ?> — جميع الحقوق محفوظة</div>
                    <div class="zbx-footer-made">صُنع بحبّ في السعودية 🇸🇦</div>
                    <div class="zbx-footer-payments">
                        <img src="/wp-content/uploads/zooboxi-assets/pay-mada.svg" alt="مدى" loading="lazy">
                        <img src="/wp-content/uploads/zooboxi-assets/pay-applepay.svg" alt="Apple Pay" loading="lazy">
                        <img src="/wp-content/uploads/zooboxi-assets/pay-stcpay.svg" alt="STC Pay" loading="lazy">
                        <img src="/wp-content/uploads/zooboxi-assets/pay-visa.svg" alt="Visa" loading="lazy">
                        <img src="/wp-content/uploads/zooboxi-assets/pay-mastercard.svg" alt="Mastercard" loading="lazy">
                    </div>
                </div>
            </div>
        </div>
    </footer>
    <?php
}, 5);


// ═══════════ DYNAMIC PRODUCT SORTING ═══════════
// Products with express delivery for THIS customer's location appear first.
// Products without images appear last.

/**
 * Get the customer's nearby express warehouse codes from cookies.
 * Cached per-request to avoid repeated DB + geo calculations.
 */
function zooboxi_get_customer_express_codes(): array {
    static $codes = null;
    if ($codes !== null) return $codes;

    $lat = (float) ($_COOKIE['zooboxi_lat'] ?? 0);
    $lng = (float) ($_COOKIE['zooboxi_lng'] ?? 0);
    $codes = [];

    if (!$lat || !$lng) return $codes;
    if (!class_exists('Zooboxi_Warehouse_Manager')) return $codes;

    // Get express warehouses within radius of customer (lenient — for product sorting)
    // We use radius check instead of strict polygon to match the delivery badge behavior
    $warehouses = Zooboxi_Warehouse_Manager::get_active();
    foreach ($warehouses as $wh) {
        if (empty($wh['is_express_enabled'])) continue;
        if (!$wh['latitude'] || !$wh['longitude']) continue;

        $radius = (float) ($wh['express_radius_km'] ?? 10);
        $dist = Zooboxi_Geo_Helper::distance($lat, $lng, (float) $wh['latitude'], (float) $wh['longitude']);

        if ($dist <= $radius) {
            $codes[] = $wh['warehouse_code'];
        }
    }

    return $codes;
}

// Hook into WooCommerce product query to set custom ordering
add_action('woocommerce_product_query', function ($query) {
    // Don't override if user explicitly chose a sort order
    $orderby = $query->get('orderby');
    if (in_array($orderby, ['price', 'price-desc', 'rating', 'date', 'popularity'])) {
        return;
    }
    // Mark this query for our posts_clauses filter
    $query->set('zooboxi_smart_sort', true);
}, 20);

// Runs AFTER the plugin's sort (priority 999) to enhance the orderby with express + image priority.
// Reuses the plugin's existing zbx_wh_stock JOIN — does NOT add duplicate JOINs.
add_filter('posts_clauses', function ($clauses, $query) {
    if (!$query->get('zooboxi_smart_sort')) return $clauses;

    global $wpdb;

    $express_codes = zooboxi_get_customer_express_codes();

    // Build express stock REGEXP check (reuses plugin's zbx_wh_stock alias)
    if (!empty($express_codes)) {
        $regexp_parts = [];
        foreach ($express_codes as $code) {
            $safe_code = esc_sql($code);
            $regexp_parts[] = "zbx_wh_stock.meta_value REGEXP '\"warehouse_code\":\"" . $safe_code . "\",\"in_stock\":[1-9]'";
        }
        $express_condition = '(' . implode(' OR ', $regexp_parts) . ')';
    } else {
        $express_condition = '0';
    }

    // Add thumbnail JOIN only (zbx_wh_stock already added by plugin at priority 999)
    if (strpos($clauses['join'], 'zbx_sort_thumb') === false) {
        $clauses['join'] .= " LEFT JOIN {$wpdb->postmeta} AS zbx_sort_thumb 
            ON ({$wpdb->posts}.ID = zbx_sort_thumb.post_id AND zbx_sort_thumb.meta_key = '_thumbnail_id')";
    }

    // Prepend express + image priority to the existing orderby
    $existing_orderby = $clauses['orderby'];
    $clauses['orderby'] = "
        CASE 
            WHEN {$express_condition} AND zbx_sort_thumb.meta_value IS NOT NULL AND CAST(zbx_sort_thumb.meta_value AS UNSIGNED) > 0 THEN 1
            WHEN {$express_condition} THEN 2
            WHEN zbx_sort_thumb.meta_value IS NOT NULL AND CAST(zbx_sort_thumb.meta_value AS UNSIGNED) > 0 THEN 3
            ELSE 4
        END ASC, {$existing_orderby}";

    return $clauses;
}, 1000, 2);

// Auto-update global fallback sort priority when warehouse stock changes (for non-geolocated users)
add_action('updated_post_meta', function ($meta_id, $post_id, $meta_key, $meta_value) {
    if ($meta_key !== '_zooboxi_warehouse_stock') return;

    global $wpdb;
    $express_codes = wp_cache_get('zooboxi_express_codes');
    if (!$express_codes) {
        $express_codes = $wpdb->get_col(
            "SELECT warehouse_code FROM {$wpdb->prefix}zooboxi_warehouses WHERE is_express_enabled = 1 AND is_active = 1"
        );
        wp_cache_set('zooboxi_express_codes', $express_codes, '', 3600);
    }

    $has_express = false;
    $stock = json_decode($meta_value, true);
    if (is_array($stock)) {
        foreach ($stock as $s) {
            if (in_array($s['warehouse_code'] ?? '', $express_codes) && ($s['in_stock'] ?? 0) > 0) {
                $has_express = true;
                break;
            }
        }
    }

    $has_image = (bool) get_post_thumbnail_id($post_id);

    if ($has_express && $has_image)       $priority = 1;
    elseif ($has_express && !$has_image)  $priority = 2;
    elseif (!$has_express && $has_image)  $priority = 3;
    else                                  $priority = 4;

    update_post_meta($post_id, '_zooboxi_sort_priority', $priority);
}, 10, 4);



// ═══════════ ARABIC CITY DISPLAY NAMES ═══════════
// Google reverse-geocoding stores English city names in the location cookie
// ("Riyadh"). Matching logic stays untouched — this maps DISPLAY ONLY.
if (!function_exists('zooboxi_city_ar_map')) {
    function zooboxi_city_ar_map(): array {
        static $map = [
            'riyadh' => 'الرياض', 'jeddah' => 'جدة', 'jiddah' => 'جدة',
            'makkah' => 'مكة المكرمة', 'mecca' => 'مكة المكرمة',
            'medina' => 'المدينة المنورة', 'madinah' => 'المدينة المنورة', 'al madinah' => 'المدينة المنورة',
            'dammam' => 'الدمام', 'ad dammam' => 'الدمام', 'khobar' => 'الخبر', 'al khobar' => 'الخبر',
            'dhahran' => 'الظهران', 'jubail' => 'الجبيل', 'al jubail' => 'الجبيل',
            'qatif' => 'القطيف', 'hofuf' => 'الهفوف', 'al hofuf' => 'الهفوف',
            'al ahsa' => 'الأحساء', 'hafar al batin' => 'حفر الباطن',
            'taif' => 'الطائف', 'at taif' => 'الطائف', 'tabuk' => 'تبوك',
            'buraydah' => 'بريدة', 'buraidah' => 'بريدة', 'unaizah' => 'عنيزة', 'unayzah' => 'عنيزة',
            'hail' => 'حائل', "ha'il" => 'حائل', 'abha' => 'أبها',
            'khamis mushait' => 'خميس مشيط', 'khamis mushayt' => 'خميس مشيط',
            'najran' => 'نجران', 'jazan' => 'جازان', 'jizan' => 'جازان',
            'yanbu' => 'ينبع', 'al kharj' => 'الخرج', 'al qassim' => 'القصيم',
            'sakaka' => 'سكاكا', 'arar' => 'عرعر', 'al baha' => 'الباحة', 'al bahah' => 'الباحة',
            // regions/provinces as Google reverse-geocoding returns them
            'riyadh principality' => 'منطقة الرياض', 'riyadh province' => 'منطقة الرياض', 'riyadh region' => 'منطقة الرياض',
            'makkah province' => 'منطقة مكة المكرمة', 'makkah region' => 'منطقة مكة المكرمة', 'mecca region' => 'منطقة مكة المكرمة',
            'al madinah province' => 'منطقة المدينة المنورة', 'medina region' => 'منطقة المدينة المنورة', 'al madinah region' => 'منطقة المدينة المنورة',
            'eastern province' => 'المنطقة الشرقية', 'eastern region' => 'المنطقة الشرقية', 'ash sharqiyah' => 'المنطقة الشرقية',
            'al qassim province' => 'منطقة القصيم', 'qassim region' => 'منطقة القصيم', 'al qassim region' => 'منطقة القصيم',
            'asir province' => 'منطقة عسير', 'asir region' => 'منطقة عسير', "'asir region" => 'منطقة عسير',
            'tabuk province' => 'منطقة تبوك', 'tabuk region' => 'منطقة تبوك',
            'hail province' => 'منطقة حائل', 'hail region' => 'منطقة حائل', "ha'il region" => 'منطقة حائل',
            'northern borders province' => 'منطقة الحدود الشمالية', 'northern borders region' => 'منطقة الحدود الشمالية',
            'jazan province' => 'منطقة جازان', 'jazan region' => 'منطقة جازان',
            'najran province' => 'منطقة نجران', 'najran region' => 'منطقة نجران',
            'al bahah province' => 'منطقة الباحة', 'al baha region' => 'منطقة الباحة',
            'al jawf province' => 'منطقة الجوف', 'al jawf region' => 'منطقة الجوف',
        ];
        return $map;
    }
}
if (!function_exists('zooboxi_city_ar')) {
    function zooboxi_city_ar(string $city): string {
        $map = zooboxi_city_ar_map();
        $k = strtolower(trim($city));
        return $map[$k] ?? $city;
    }
}

// ═══════════ CART TOTALS: NO DOUBLE EMOJI ═══════════
// The package heading already carries the tier emoji (🚀 شحنة التوصيل السريع);
// the method chip inside repeats it — strip leading emojis from the chip label.
add_filter('woocommerce_cart_shipping_method_full_label', function ($label, $method) {
    $label = preg_replace('/^[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}\x{200D}]+\s*/u', '', $label);
    // drop the raw "NAME:" colon before the price — the chip's flex gap separates them
    return preg_replace('/:\s*(<span)/u', ' $1', $label);
}, 10, 2);

// ═══════════ ARABIC SHIPPING DESTINATION ═══════════
// Google reverse-geocoding stores English city/region names in the customer
// address ("Riyadh Principality") — map them for the «الشحن إلى …» line.
// Zooboxi shipping matches by coordinates, so this is display-safe.
add_filter('woocommerce_cart_shipping_packages', function ($packages) {
    if (!function_exists('zooboxi_city_ar')) return $packages;
    foreach ($packages as &$p) {
        foreach (['city', 'state'] as $k) {
            if (!empty($p['destination'][$k]) && is_string($p['destination'][$k])) {
                $p['destination'][$k] = zooboxi_city_ar($p['destination'][$k]);
            }
        }
    }
    return $packages;
}, 20);

// ═══════════ CLEAR ADD-TO-CART TOAST MESSAGE ═══════════
// Replace WooCommerce's long sentence with a crisp two-line toast:
// bold confirmation + truncated product name + compact cart button.
add_filter('wc_add_to_cart_message_html', function ($message, $products, $show_qty) {
    $titles = [];
    foreach ((array) $products as $id => $qty) {
        $t = get_the_title($id);
        if ($t) { $titles[] = $t; }
    }
    $name = wc_trim_string(implode('، ', $titles), 46);
    $first = is_array($products) ? array_key_first($products) : 0;
    $thumb = $first ? get_the_post_thumbnail((int) $first, 'woocommerce_gallery_thumbnail', ['class' => 'zbx-toast-thumb', 'loading' => 'lazy']) : '';

    return ($thumb ?: '<span class="zbx-toast-check" aria-hidden="true">✓</span>')
         . '<span class="zbx-toast-txt"><strong class="zbx-toast-head">أُضيف إلى سلتك</strong>'
         . '<span class="zbx-toast-name">' . esc_html($name) . '</span></span>'
         . '<a href="' . esc_url(wc_get_cart_url()) . '" class="button wc-forward zbx-toast-btn">السلة</a>'
         . '<span class="zbx-toast-life" aria-hidden="true"></span>';
}, 10, 3);

// ═══════════ CART COPY: SHORTER, CLEARER, NON-REPEATING ═══════════
add_filter('gettext', function ($translated, $text, $domain) {
    if ('woocommerce' !== $domain || get_locale() !== 'ar') {
        return $translated;
    }
    switch ($text) {
        case 'Cart totals':
        case 'Cart Totals':
            return 'ملخص الطلب';
        case 'Total':
            return 'الإجمالي';
        case '(includes %s)':
            return 'شامل %s';
        case 'Shipping to %s.':
            return 'التوصيل إلى %s';
        case 'Change address':
            return 'تغيير';
        case 'Subtotal':
            // Piece count belongs on the CART's totals row only — on checkout the
            // same string is also the review table's column header, where it reads wrong.
            if (is_cart() && !is_checkout() && function_exists('WC') && WC()->cart) {
                $n = (int) WC()->cart->get_cart_contents_count();
                if ($n > 0) {
                    // Arabic counts: 1 and 2 read better without the numeral
                    if (1 === $n) { $count = 'قطعة واحدة'; }
                    elseif (2 === $n) { $count = 'قطعتان'; }
                    elseif ($n <= 10) { $count = $n . ' قطع'; }
                    else { $count = $n . ' قطعة'; }
                    return 'المجموع الفرعي · ' . $count;
                }
            }
            return 'المجموع الفرعي';
    }
    return $translated;
}, 30, 3);

// ═══════════ SHIPPING ROW: NO REPEATED TIER NAME ═══════════
// The package heading already names the tier ("🚚 شحنة اليوم التالي"). When a
// package offers a single rate, the chip repeating that name is noise — show
// the price alone (or «مجاني»). With 2+ rates the names stay: they're choices.
add_filter('woocommerce_cart_shipping_method_full_label', function ($label, $method) {
    $label = preg_replace('/^[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}\x{200D}]+\s*/u', '', $label);
    $label = preg_replace('/:\s*(<span)/u', ' $1', $label);

    if (!function_exists('WC') || !WC()->shipping()) {
        return $label;
    }
    $alone = false;
    foreach (WC()->shipping()->get_packages() as $package) {
        if (isset($package['rates'][$method->get_id()])) {
            $alone = (count($package['rates']) === 1);
            break;
        }
    }
    if (!$alone) {
        return $label;
    }
    $cost = (float) $method->get_cost() + (float) $method->get_shipping_tax();
    return $cost > 0
        ? wc_price($cost)
        : '<span class="zbx-free-ship">مجاني</span>';
}, 20, 2);

// ═══════════ CHECKOUT: ARABIC PAYMENT METHODS ═══════════
// The store is Arabic-only; gateways ship English titles/descriptions.
add_filter('woocommerce_gateway_title', function ($title, $id) {
    if (get_locale() !== 'ar') return $title;
    if ('cod' === $id) return 'الدفع عند الاستلام';
    if (false !== strpos((string) $id, 'myfatoorah')) return 'الدفع الإلكتروني';
    return $title;
}, 20, 2);

add_filter('woocommerce_gateway_description', function ($desc, $id) {
    if (get_locale() !== 'ar') return $desc;
    if ('cod' === $id) return 'ادفع نقداً أو بالشبكة لحظة استلام طلبك.';
    if (false !== strpos((string) $id, 'myfatoorah')) return 'ادفع بأمان عبر مدى · Apple Pay · STC Pay · أو بطاقتك البنكية.';
    return $desc;
}, 20, 2);

// ═══════════ CHECKOUT: NO DOUBLE "(اختياري)" ═══════════
// The plugin appends it to some labels while WooCommerce adds its own suffix.
add_filter('woocommerce_checkout_fields', function ($fields) {
    foreach ($fields as $group => $items) {
        foreach ($items as $key => $field) {
            if (!empty($field['label'])) {
                $fields[$group][$key]['label'] = trim(str_replace('(اختياري)', '', $field['label']));
            }
        }
    }
    return $fields;
}, 9999); // the plugin sets these labels at 999 — run after it

// ═══════════ CHECKOUT: DE-DUPLICATED DELIVERY BANNER ═══════════
// The plugin prints the tier line AND a summary that repeats it (with a
// "خلال خلال" typo). Buffer the hook and drop the echo when it repeats.
add_action('woocommerce_checkout_before_order_review', function () { ob_start(); }, 1);
add_action('woocommerce_checkout_before_order_review', function () {
    $html = ob_get_clean();
    if (!$html) { return; }

    $html = str_replace('خلال خلال', 'خلال', $html);

    if (preg_match('/__type">(.*?)<\/div>/su', $html, $t) &&
        preg_match('/__summary">(.*?)<\/div>/su', $html, $s)) {
        $type    = trim(wp_strip_all_tags($t[1]));
        $summary = trim(wp_strip_all_tags($s[1]));
        // the promise phrase lives after the em-dash: "توصيل عادي — خلال 24 ساعة"
        $promise = '';
        if (false !== strpos($type, '—')) {
            $promise = trim(substr($type, strpos($type, '—') + strlen('—')));
        }
        if ($promise !== '' && false !== mb_strpos($summary, $promise)) {
            $html = preg_replace('/<div class="[^"]*__summary">.*?<\/div>/su', '', $html, 1);
        }
    }
    // Hold it: printed here it lands BETWEEN the panel heading and the panel body,
    // splitting the order card in two. Re-emit it inside the card instead.
    $GLOBALS['zbx_delivery_banner'] = $html;
}, 999);

add_action('woocommerce_checkout_order_review', function () {
    if (!empty($GLOBALS['zbx_delivery_banner'])) {
        echo $GLOBALS['zbx_delivery_banner']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        $GLOBALS['zbx_delivery_banner'] = '';
    }
}, 5);

// ═══════════ CHECKOUT COPY ═══════════
add_filter('gettext', function ($translated, $text, $domain) {
    if ('woocommerce' !== $domain || get_locale() !== 'ar') {
        return $translated;
    }
    switch ($text) {
        case 'Billing details':   return 'بيانات التوصيل';
        case 'Your order':        return 'ملخص طلبك';
        case 'Order notes':       return 'ملاحظات للطلب';
        case 'Ship to a different address?': return 'التوصيل إلى عنوان آخر؟';
        case 'Place order':       return 'تأكيد الطلب والدفع';
        case 'Product':           return 'المنتج';
    }
    return $translated;
}, 99, 3);

// ═══════════ CHECKOUT: READABLE QUANTITY ═══════════
add_filter('woocommerce_checkout_cart_item_quantity', function ($html, $cart_item) {
    if (get_locale() !== 'ar') { return $html; }
    $qty = isset($cart_item['quantity']) ? (int) $cart_item['quantity'] : 0;
    return $qty > 0 ? '<span class="product-quantity">الكمية: ' . $qty . '</span>' : $html;
}, 10, 2);

// ═══════════ FIX: CHECKOUT MAP LOCATION UPDATE (AJAX 400) ═══════════
// The plugin REQUIREs Zooboxi_Checkout_Customizer during AJAX but only
// INSTANTIATES it when !is_admin() — so its wp_ajax hooks never registered and
// dragging the checkout map always failed with 400/"0" (shipping never
// recalculated for the new pin). The handler is static; register it directly.
if (!function_exists('zooboxi_ajax_checkout_location')) {
    function zooboxi_ajax_checkout_location() {
        if (is_callable(['Zooboxi_Checkout_Customizer', 'ajax_update_checkout_location'])) {
            Zooboxi_Checkout_Customizer::ajax_update_checkout_location(); // sends JSON + dies
        }
        wp_send_json_error(['message' => 'checkout location handler unavailable'], 500);
    }
}
add_action('wp_ajax_zooboxi_update_checkout_location', 'zooboxi_ajax_checkout_location');
add_action('wp_ajax_nopriv_zooboxi_update_checkout_location', 'zooboxi_ajax_checkout_location');

// ═══════════ TOTAL: TAX SHOWN AS ITS OWN ROW, NOT AN INLINE NOTE ═══════════
// A dedicated «الإجمالي قبل الضريبة» + «ضريبة القيمة المضافة» pair reads far
// clearer than "(شامل ...)" tucked under the total, so drop the inline note.
add_filter('woocommerce_cart_totals_order_total_html', function ($value) {
    if (get_locale() !== 'ar') {
        return $value;
    }
    return preg_replace('/<small class="includes_tax">.*?<\/small>/su', '', $value);
}, 20);

// Renders: net total, then one row per tax rate (label + percent + amount).
if (!function_exists('zooboxi_render_tax_breakdown')) {
    function zooboxi_render_tax_breakdown() {
        if (!function_exists('WC') || !WC()->cart || !wc_tax_enabled()) {
            return;
        }
        $tax = (float) WC()->cart->get_total_tax();
        if ($tax <= 0) {
            return;
        }
        $total = (float) WC()->cart->get_total('edit');
        $net   = max(0, $total - $tax);
        ?>
        <tr class="zbx-net-row">
            <th><?php esc_html_e('الإجمالي قبل الضريبة', 'zooboxi'); ?></th>
            <td><?php echo wp_kses_post(wc_price($net)); ?></td>
        </tr>
        <?php foreach ((array) WC()->cart->get_tax_totals() as $tt) :
            $rate_id = $tt->tax_rate_id ?? ($tt->rate_id ?? 0); // core exposes tax_rate_id
            $percent = $rate_id ? WC_Tax::get_rate_percent($rate_id) : '';
            $label   = isset($tt->label) ? $tt->label : __('ضريبة القيمة المضافة', 'zooboxi');
            ?>
            <tr class="zbx-vat-row">
                <th>
                    <?php echo esc_html($label); ?>
                    <?php if ($percent) : ?><span class="zbx-vat-rate"><?php echo esc_html($percent); ?></span><?php endif; ?>
                </th>
                <td><?php echo wp_kses_post($tt->formatted_amount); ?></td>
            </tr>
        <?php endforeach;
    }
}
add_action('woocommerce_cart_totals_before_order_total', 'zooboxi_render_tax_breakdown');
add_action('woocommerce_review_order_before_order_total', 'zooboxi_render_tax_breakdown');

// ═══════════ CHECKOUT: VISIBLE CITY + DISTRICT, TIED TO THE MAP ═══════════
// The address is chosen on the map, but the customer still needs to SEE the
// city and district it resolved to (and be able to correct the district).
add_filter('woocommerce_checkout_fields', function ($fields) {
    if (get_locale() !== 'ar') {
        return $fields;
    }
    $session  = function_exists('WC') ? WC()->session : null;
    $city     = $_COOKIE['zooboxi_city'] ?? ($session ? (string) $session->get('zooboxi_customer_city', '') : '');
    $district = $_COOKIE['zooboxi_district'] ?? ($session ? (string) $session->get('zooboxi_customer_district', '') : '');
    $city     = $city ? zooboxi_city_ar(sanitize_text_field(wp_unslash($city))) : '';
    $district = $district ? sanitize_text_field(wp_unslash($district)) : '';

    $fields['billing']['billing_city'] = [
        'type'        => 'text',
        'label'       => 'المدينة',
        'required'    => true,
        'priority'    => 78,
        'default'     => $city,
        'placeholder' => 'تُحدد من الخريطة',
        'class'       => ['form-row-first', 'zbx-map-field'],
    ];
    $fields['billing']['billing_address_2'] = [
        'type'        => 'text',
        'label'       => 'الحي',
        'required'    => false,
        'priority'    => 79,
        'default'     => $district,
        'placeholder' => 'يُملأ من الخريطة — عدّله إن لزم',
        'class'       => ['form-row-last', 'zbx-map-field'],
    ];
    return $fields;
}, 10000);

// Keep the map's own defaults in sync with those fields.
add_filter('woocommerce_checkout_get_value', function ($value, $input) {
    if (get_locale() !== 'ar') return $value;
    $session = function_exists('WC') ? WC()->session : null;
    if ('billing_city' === $input) {
        $c = $_COOKIE['zooboxi_city'] ?? ($session ? (string) $session->get('zooboxi_customer_city', '') : '');
        return $c ? zooboxi_city_ar(sanitize_text_field(wp_unslash($c))) : $value;
    }
    if ('billing_address_2' === $input) {
        $d = $_COOKIE['zooboxi_district'] ?? ($session ? (string) $session->get('zooboxi_customer_district', '') : '');
        return $d ? sanitize_text_field(wp_unslash($d)) : $value;
    }
    return $value;
}, 20, 2);

// Hand the Arabic city map to the browser so map-driven updates match the server.
add_action('wp_enqueue_scripts', function () {
    if (!is_checkout() || !wp_script_is('zooboxi-delight', 'enqueued')) {
        return;
    }
    wp_localize_script('zooboxi-delight', 'zbxCityMap', zooboxi_city_ar_map());
}, 20);

// ═══════════════════════════════════════════════════════════════
// ORDER RECEIVED — A CELEBRATION, NOT A RECEIPT DUMP
// The default page is a bare <ul> that even leaks the internal
// placeholder email. Replace it with a hero, a live order timeline,
// the delivery promise and clear next steps.
// ═══════════════════════════════════════════════════════════════
add_action('woocommerce_before_thankyou', function ($order_id) {
    $order = wc_get_order($order_id);
    if (!$order || get_locale() !== 'ar') {
        return;
    }

    // Delivery promise straight from the order's shipping lines.
    $promises = [];
    foreach ($order->get_shipping_methods() as $ship) {
        $name = trim(wp_strip_all_tags($ship->get_name()));
        if ($name !== '') { $promises[] = $name; }
    }

    // Where it is going (city + district, Arabic).
    $city     = trim((string) $order->get_billing_city()) ?: trim((string) $order->get_shipping_city());
    $city     = $city !== '' ? zooboxi_city_ar($city) : '';
    $district = trim((string) $order->get_billing_address_2()) ?: trim((string) $order->get_shipping_address_2());
    $parts    = array_filter([$district, $city], static function ($v) { return trim((string) $v) !== ''; });
    $place    = implode('، ', $parts);

    // Timeline state from the order status.
    $status = $order->get_status();
    $stage  = 1;
    if (in_array($status, ['processing', 'on-hold'], true)) { $stage = 2; }
    if (in_array($status, ['shipped', 'out-for-delivery'], true)) { $stage = 3; }
    if (in_array($status, ['completed'], true)) { $stage = 4; }

    $steps = [
        ['icon' => '📝', 'label' => 'استلمنا طلبك'],
        ['icon' => '📦', 'label' => 'قيد التجهيز'],
        ['icon' => '🚚', 'label' => 'في الطريق إليك'],
        ['icon' => '🎉', 'label' => 'وصل!'],
    ];

    $account = wc_get_page_permalink('myaccount');
    $shop    = wc_get_page_permalink('shop');
    ?>
    <div class="zbx-ty">
        <div class="zbx-ty-hero">
            <div class="zbx-ty-check" aria-hidden="true">
                <svg viewBox="0 0 52 52"><circle class="zbx-ty-ring" cx="26" cy="26" r="23" fill="none"/><path class="zbx-ty-tick" fill="none" d="M14 27l8 8 16-17"/></svg>
            </div>
            <h2 class="zbx-ty-title">تم استلام طلبك 🎉</h2>
            <p class="zbx-ty-sub">شكراً لك! بدأنا تجهيز طلبك، وأليفك على وشك أن يفرح.</p>

            <div class="zbx-ty-facts">
                <div class="zbx-ty-fact">
                    <span class="zbx-ty-fact-cap">رقم الطلب</span>
                    <strong class="zbx-ty-fact-val">#<?php echo esc_html($order->get_order_number()); ?></strong>
                </div>
                <div class="zbx-ty-fact">
                    <span class="zbx-ty-fact-cap">الإجمالي</span>
                    <strong class="zbx-ty-fact-val"><?php echo wp_kses_post($order->get_formatted_order_total()); ?></strong>
                </div>
                <div class="zbx-ty-fact">
                    <span class="zbx-ty-fact-cap">وسيلة الدفع</span>
                    <strong class="zbx-ty-fact-val"><?php echo esc_html($order->get_payment_method_title()); ?></strong>
                </div>
                <div class="zbx-ty-fact">
                    <span class="zbx-ty-fact-cap">تاريخ الطلب</span>
                    <strong class="zbx-ty-fact-val"><?php echo esc_html(zooboxi_date_ar($order->get_date_created())); ?></strong>
                </div>
            </div>
        </div>

        <?php if (!empty($promises) || $place !== '') : ?>
        <div class="zbx-ty-promise">
            <?php if (!empty($promises)) : ?>
                <div class="zbx-ty-promise-row">
                    <span class="zbx-ty-promise-ic">⏱️</span>
                    <span><strong>موعد الوصول:</strong> <?php echo esc_html(implode(' · ', $promises)); ?></span>
                </div>
            <?php endif; ?>
            <?php if ($place !== '') : ?>
                <div class="zbx-ty-promise-row">
                    <span class="zbx-ty-promise-ic">📍</span>
                    <span><strong>سيصل إلى:</strong> <?php echo esc_html($place); ?></span>
                </div>
            <?php endif; ?>
        </div>
        <?php endif; ?>

        <div class="zbx-ty-timeline" role="list">
            <?php foreach ($steps as $i => $s) :
                $n = $i + 1;
                $cls = $n < $stage ? 'is-done' : ($n === $stage ? 'is-current' : '');
                ?>
                <div class="zbx-ty-step <?php echo esc_attr($cls); ?>" role="listitem">
                    <span class="zbx-ty-step-dot"><?php echo esc_html($s['icon']); ?></span>
                    <span class="zbx-ty-step-label"><?php echo esc_html($s['label']); ?></span>
                </div>
                <?php if ($n < count($steps)) : ?><span class="zbx-ty-step-line <?php echo $n < $stage ? 'is-filled' : ''; ?>"></span><?php endif; ?>
            <?php endforeach; ?>
        </div>

        <div class="zbx-ty-actions">
            <a class="zbx-ty-btn zbx-ty-btn--primary" href="<?php echo esc_url($account); ?>">📦 تتبّع طلبي</a>
            <a class="zbx-ty-btn" href="<?php echo esc_url($shop); ?>">🛍️ متابعة التسوق</a>
            <a class="zbx-ty-btn" href="mailto:info@zooboxi.com">💬 تواصل معنا</a>
        </div>
    </div>

    <script>
    (function () {
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
        var colors = ['#429D9C', '#D46856', '#F4BE2C', '#7CC6C2', '#2DB87B'];
        var wrap = document.createElement('div');
        wrap.className = 'zbx-confetti';
        for (var i = 0; i < 44; i++) {
            var s = document.createElement('span');
            s.style.left = (Math.random() * 100) + '%';
            s.style.background = colors[i % colors.length];
            s.style.animationDelay = (Math.random() * 0.7) + 's';
            s.style.animationDuration = (2.2 + Math.random() * 1.6) + 's';
            s.style.transform = 'rotate(' + (Math.random() * 360) + 'deg)';
            wrap.appendChild(s);
        }
        document.body.appendChild(wrap);
        setTimeout(function () { wrap.remove(); }, 4600);
    })();
    </script>
    <?php
}, 5);

// The COD gateway prints its English instructions on this page. Gateways are
// instantiated late, so swap the hook while the template is rendering.
add_action('woocommerce_before_thankyou', function () {
    if (get_locale() !== 'ar') return;
    remove_all_actions('woocommerce_thankyou_cod');
    add_action('woocommerce_thankyou_cod', function () {
        echo '<p class="zbx-ty-note">💵 جهّز المبلغ نقداً أو بالشبكة عند استلام طلبك.</p>';
    });
}, 1);

/** Arabic long date — date_i18n follows the site locale (en_US) here. */
if (!function_exists('zooboxi_date_ar')) {
    function zooboxi_date_ar($date): string {
        if (!$date) return '';
        static $months = [
            1 => 'يناير', 2 => 'فبراير', 3 => 'مارس', 4 => 'أبريل', 5 => 'مايو', 6 => 'يونيو',
            7 => 'يوليو', 8 => 'أغسطس', 9 => 'سبتمبر', 10 => 'أكتوبر', 11 => 'نوفمبر', 12 => 'ديسمبر',
        ];
        $d = (int) $date->date('j');
        $m = (int) $date->date('n');
        $y = (int) $date->date('Y');
        return $d . ' ' . ($months[$m] ?? '') . ' ' . $y;
    }
}
