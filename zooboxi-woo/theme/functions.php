<?php
/**
 * Zooboxi Child Theme v3.0
 * Premium Pet Store Theme — Matching Zid Design
 */

// ═══════════ STYLES & SCRIPTS ═══════════
add_action('wp_enqueue_scripts', function () {
    wp_enqueue_style('zooboxi-parent', get_template_directory_uri() . '/style.css');
    wp_enqueue_style('zooboxi-child', get_stylesheet_uri(), ['zooboxi-parent'], '3.0.0');
    wp_enqueue_style('google-fonts', 'https://fonts.googleapis.com/css2?family=El+Messiri:wght@400;500;600;700&display=swap', [], null);
});

// ═══════════ WOOCOMMERCE SUPPORT ═══════════
add_action('after_setup_theme', function () {
    add_theme_support('woocommerce');
    add_theme_support('wc-product-gallery-zoom');
    add_theme_support('wc-product-gallery-lightbox');
    add_theme_support('wc-product-gallery-slider');
});

// ═══════════ IMAGE FALLBACK (holeno.com → ppte.sa → placeholder) ═══════════
function zooboxi_get_image_url($product) {
    // First check _zooboxi_image_url meta (stored as holeno.com direct)
    $url = get_post_meta($product->get_id(), '_zooboxi_image_url', true);
    if (!empty($url)) return $url;

    // Fallback: build from _zooboxi_item_code → holeno.com (no subfolder)
    $sap_code = get_post_meta($product->get_id(), '_zooboxi_item_code', true);
    if (!empty($sap_code)) {
        return "https://gal.holeno.com/imghd/{$sap_code}.png";
    }

    return '';
}

/**
 * Build ppte.sa fallback URL from item code (uses subfolder pattern).
 */
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
    $ppte_url = zooboxi_get_ppte_url($product);
    $ppte_escaped = esc_url($ppte_url);

    // onerror chain: holeno → ppte.sa → placeholder
    $onerror = $ppte_url 
        ? "this.onerror=function(){this.onerror=null;this.src='{$placeholder}';};this.src='{$ppte_escaped}';"
        : "this.onerror=null;this.src='{$placeholder}';";

    return '<img src="' . esc_url($url) . '" alt="' . $alt . '" class="attachment-woocommerce_thumbnail wp-post-image zooboxi-external-img" loading="lazy" onerror="' . esc_attr($onerror) . '" />';
}, 10, 3);

// Single product image
add_action('woocommerce_before_single_product_summary', function () {
    global $product;
    if ($product && !$product->get_image_id()) {
        $url = zooboxi_get_image_url($product);
        if (empty($url)) return;
        $alt = esc_attr($product->get_name());
        $placeholder = esc_url(wc_placeholder_img_src());
        $ppte_url = esc_url(zooboxi_get_ppte_url($product));
        
        $onerror = $ppte_url 
            ? "this.onerror=function(){this.onerror=null;this.src='{$placeholder}';};this.src='{$ppte_url}';"
            : "this.onerror=null;this.src='{$placeholder}';";

        echo '<style>.woocommerce div.product div.images.woocommerce-product-gallery{display:none}</style>';
        echo '<div class="zooboxi-single-image" style="background:#fff;border-radius:20px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,0.08);margin-bottom:24px;">';
        echo '<img src="' . esc_url($url) . '" alt="' . $alt . '" style="width:100%;height:auto;object-fit:contain;max-height:500px;padding:24px;" onerror="' . esc_attr($onerror) . '" />';
        echo '</div>';
    }
}, 5);

// ═══════════ PRODUCTS PER PAGE & COLUMNS ═══════════
add_filter('loop_shop_per_page', function () { return 24; });
add_filter('loop_shop_columns', function () { return 4; });

// ═══════════ ANNOUNCEMENT MARQUEE BAR ═══════════
add_action('wp_body_open', function () {
    echo '<div class="zooboxi-announcement-bar">
        <div class="zooboxi-marquee">
            <div class="zooboxi-marquee__content">
                <span>🚀 اطلب بـ250+ ريال وخلّ التوصيل علينا!</span>
                <span>🔥 خصم 20٪ لأول طلب! استخدم كود: <strong>hiboxi</strong></span>
                <span>🚀 اطلب بـ250+ ريال وخلّ التوصيل علينا!</span>
                <span>🔥 خصم 20٪ لأول طلب! استخدم كود: <strong>hiboxi</strong></span>
            </div>
        </div>
    </div>';
});

// ═══════════ FREE SHIPPING PROGRESS BAR ═══════════
add_action('woocommerce_before_cart', function () {
    $min = 250;
    $cur = WC()->cart->get_cart_contents_total();
    $rem = max(0, $min - $cur);
    $pct = min(100, ($cur / max($min, 1)) * 100);

    echo '<div style="background:#fff;border-radius:14px;padding:20px;margin-bottom:24px;box-shadow:0 1px 3px rgba(0,0,0,0.06);">';
    if ($rem > 0) {
        echo '<p style="margin:0 0 8px;font-weight:600;font-size:14px;">🚚 أضف ' . number_format($rem, 2) . ' ر.س للحصول على شحن مجاني!</p>';
    } else {
        echo '<p style="margin:0 0 8px;font-weight:600;color:#429d9c;font-size:14px;">🎉 مبروك! حصلت على شحن مجاني!</p>';
    }
    echo '<div style="background:#e2e8e5;border-radius:10px;height:8px;overflow:hidden;">';
    echo '<div style="background:linear-gradient(90deg,#429d9c,#2d7a79);height:100%;width:' . $pct . '%;border-radius:10px;transition:width 0.5s ease;"></div>';
    echo '</div></div>';
});

// ═══════════ CHECKOUT BUTTON ═══════════
add_filter('woocommerce_order_button_text', function () {
    return '🛒 تأكيد الطلب والدفع';
});

// ═══════════ THEME COLOR ═══════════
add_action('wp_head', function () {
    echo '<meta name="theme-color" content="#429d9c">';
    // SAR SVG replacement script
    echo '<script>
    document.addEventListener("DOMContentLoaded",function(){
        const riyalSVG = \'<svg class="riyal-svg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1124.14 1256.39" width="14" height="16" style="display:inline-block;vertical-align:-0.125em"><path fill="currentColor" d="M699.62,1113.02h0c-20.06,44.48-33.32,92.75-38.4,143.37l424.51-90.24c20.06-44.47,33.31-92.75,38.4-143.37l-424.51,90.24Z"/><path fill="currentColor" d="M1085.73,895.8c20.06-44.47,33.32-92.75,38.4-143.37l-330.68,70.33v-135.2l292.27-62.11c20.06-44.47,33.32-92.75,38.4-143.37l-330.68,70.27V66.13c-50.67,28.45-95.67,66.32-132.25,110.99v403.35l-132.25,28.11V0c-50.67,28.44-95.67,66.32-132.25,110.99v525.69l-295.91,62.88c-20.06,44.47-33.33,92.75-38.42,143.37l334.33-71.05v170.26l-358.3,76.14c-20.06,44.47-33.32,92.75-38.4,143.37l375.04-79.7c30.53-6.35,56.77-24.4,73.83-49.24l68.78-101.97v-.02c7.14-10.55,11.3-23.27,11.3-36.97v-149.98l132.25-28.11v270.4l424.53-90.28Z"/></svg>\';
        function replaceCurrency(){
            var walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,null,false);
            var node;
            while(node=walker.nextNode()){
                var parent=node.parentNode;
                if(parent.nodeName==="SCRIPT"||parent.nodeName==="STYLE")continue;
                var text=node.nodeValue;
                if(text.indexOf("ر.س")>-1||text.indexOf("SAR")>-1){
                    var span=document.createElement("span");
                    span.innerHTML=text.replace(/ر\.س/g,riyalSVG).replace(/SAR/g,riyalSVG);
                    parent.replaceChild(span,node);
                }
            }
        }
        replaceCurrency();
        new MutationObserver(function(){requestAnimationFrame(replaceCurrency)}).observe(document.body,{childList:true,subtree:true});
    });
    </script>';
});

// ═══════════ WC BLOCKS IMAGE INJECTION ═══════════
add_action('wp_footer', function () {
    if (!is_shop() && !is_product_category() && !is_product_tag() && !is_search() && !is_front_page()) return;
    
    global $wpdb;
    // Get product IDs with image URLs AND item codes for fallback
    $results = $wpdb->get_results("
        SELECT p.ID, 
               pm.meta_value as img_url,
               pm2.meta_value as item_code
        FROM {$wpdb->posts} p 
        INNER JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key = '_zooboxi_image_url'
        LEFT JOIN {$wpdb->postmeta} pm2 ON p.ID = pm2.post_id AND pm2.meta_key = '_zooboxi_item_code'
        WHERE p.post_type = 'product' AND p.post_status = 'publish'
        AND pm.meta_value != ''
        LIMIT 6000
    ");
    
    $map = [];
    $ppteMap = [];
    foreach ($results as $r) {
        $map[$r->ID] = $r->img_url;
        if (!empty($r->item_code)) {
            $folder = substr($r->item_code, 0, 4);
            $ppteMap[$r->ID] = "https://ppte.sa/imghd/{$folder}/{$r->item_code}.png";
        }
    }
    
    if (empty($map)) return;
    
    $placeholder = esc_url(wc_placeholder_img_src());
    echo '<script>
    (function(){
        var imgMap = ' . json_encode($map, JSON_UNESCAPED_SLASHES) . ';
        var ppteMap = ' . json_encode($ppteMap, JSON_UNESCAPED_SLASHES) . ';
        var placeholder = "' . $placeholder . '";
        
        function getProductId(el) {
            // Walk up to find data-wp-context with productId
            var current = el;
            while (current && current !== document.body) {
                var ctx = current.getAttribute("data-wp-context");
                if (ctx) {
                    // Format: woocommerce/products::{"productId":21197,...}
                    var match = ctx.match(/"productId"\s*:\s*(\d+)/);
                    if (match) return match[1];
                }
                // Also check data-product_id
                var pid = current.getAttribute("data-product_id");
                if (pid) return pid;
                current = current.parentElement;
            }
            return null;
        }
        
        function injectImages() {
            document.querySelectorAll(".wc-block-components-product-image__inner-container").forEach(function(container) {
                if (container.querySelector("img")) return;
                
                var productId = getProductId(container);
                if (productId && imgMap[productId]) {
                    var img = document.createElement("img");
                    img.src = imgMap[productId];
                    img.alt = "";
                    img.className = "zooboxi-external-img";
                    img.loading = "lazy";
                    img.style.cssText = "width:100%;height:auto;object-fit:contain;aspect-ratio:1/1;padding:12px;background:#fff;border-radius:12px;";
                    // Fallback chain: holeno → ppte.sa → placeholder
                    img.onerror = function(){
                        if (ppteMap[productId]) {
                            this.onerror = function(){ this.onerror=null; this.src=placeholder; };
                            this.src = ppteMap[productId];
                        } else {
                            this.onerror = null;
                            this.src = placeholder;
                        }
                    };
                    container.appendChild(img);
                }
            });
        }
        
        if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", injectImages);
        } else {
            injectImages();
        }
        new MutationObserver(function(){ requestAnimationFrame(injectImages); }).observe(document.body, {childList:true, subtree:true});
    })();
    </script>';
});

// ═══════════ AJAX HANDLERS ═══════════
add_action('wp_ajax_zooboxi_detect_warehouse', 'zooboxi_handle_detect');
add_action('wp_ajax_nopriv_zooboxi_detect_warehouse', 'zooboxi_handle_detect');
function zooboxi_handle_detect() {
    $lat = floatval($_POST['lat'] ?? 0);
    $lng = floatval($_POST['lng'] ?? 0);
    if (!$lat || !$lng) wp_send_json_error(['message' => 'Invalid coords']);
    $options = class_exists('Zooboxi_Delivery_Engine') ? Zooboxi_Delivery_Engine::detect_options($lat, $lng) : [];
    if (WC()->session) {
        WC()->session->set('zooboxi_customer_lat', $lat);
        WC()->session->set('zooboxi_customer_lng', $lng);
    }
    setcookie('zooboxi_lat', $lat, time() + 86400 * 30, '/');
    setcookie('zooboxi_lng', $lng, time() + 86400 * 30, '/');
    wp_send_json_success($options);
}

add_action('wp_ajax_zooboxi_set_city', 'zooboxi_handle_city');
add_action('wp_ajax_nopriv_zooboxi_set_city', 'zooboxi_handle_city');
function zooboxi_handle_city() {
    $city = sanitize_text_field($_POST['city'] ?? '');
    if (empty($city)) wp_send_json_error(['message' => 'No city']);
    if (WC()->session) WC()->session->set('zooboxi_customer_city', $city);
    setcookie('zooboxi_city', $city, time() + 86400 * 30, '/');
    wp_send_json_success(['city' => $city]);
}

// ═══════════ DISABLE GUTENBERG FOR PRODUCTS ═══════════
add_filter('use_block_editor_for_post_type', function ($use, $type) {
    return $type === 'product' ? false : $use;
}, 10, 2);

// ═══════════ FORCE CLASSIC WC TEMPLATES ═══════════
add_filter('woocommerce_has_block_template', '__return_false');

// ═══════════ WC BLOCKS IMAGE SUPPORT ═══════════
// Inject thumbnail for products without WP images
add_filter('post_thumbnail_html', function ($html, $post_id) {
    if (empty($html) && get_post_type($post_id) === 'product') {
        $product = wc_get_product($post_id);
        if ($product) {
            $url = zooboxi_get_image_url($product);
            if (!empty($url)) {
                $alt = esc_attr($product->get_name());
                $placeholder = esc_url(wc_placeholder_img_src());
                return '<img src="' . esc_url($url) . '" alt="' . $alt . '" class="attachment-woocommerce_thumbnail wp-post-image zooboxi-external-img" loading="lazy" onerror="this.onerror=null;this.src=\'' . $placeholder . '\';" />';
            }
        }
    }
    return $html;
}, 10, 2);

// Render external image in WC product-image block
add_filter('render_block_woocommerce/product-image', function ($content, $block) {
    if (strpos($content, '<img') === false) {
        global $post;
        if ($post && $post->post_type === 'product') {
            $product = wc_get_product($post->ID);
            if ($product) {
                $url = zooboxi_get_image_url($product);
                if (!empty($url)) {
                    $alt = esc_attr($product->get_name());
                    $placeholder = esc_url(wc_placeholder_img_src());
                    $img = '<img src="' . esc_url($url) . '" alt="' . $alt . '" class="zooboxi-external-img" style="width:100%;height:auto;object-fit:contain;aspect-ratio:1/1;padding:12px;background:#fff;" loading="lazy" onerror="this.onerror=null;this.src=\'' . $placeholder . '\';" />';
                    $content = preg_replace(
                        '/(<div class="wc-block-components-product-image__inner-container">)\s*(<\/div>)/s',
                        '$1' . $img . '$2',
                        $content
                    );
                }
            }
        }
    }
    return $content;
}, 10, 2);

// REST API image support for WC Blocks store API
add_filter('woocommerce_rest_prepare_product_object', function ($response, $product) {
    $data = $response->get_data();
    if (empty($data['images'])) {
        $url = zooboxi_get_image_url($product);
        if (!empty($url)) {
            $data['images'] = [['id' => 0, 'src' => $url, 'name' => $product->get_name(), 'alt' => $product->get_name()]];
            $response->set_data($data);
        }
    }
    return $response;
}, 10, 2);

