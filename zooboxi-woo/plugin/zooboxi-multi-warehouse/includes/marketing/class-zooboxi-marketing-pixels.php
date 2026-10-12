<?php
/**
 * Browser pixels for the web store — Meta, TikTok, Snap, GA4 / Google Ads.
 *
 * Only printed when an id is configured and the switch is on. The purchase on
 * the thank-you page carries the same event id as the server send so each
 * platform de-duplicates the pair. Nothing is printed inside wp-admin or the
 * app's REST calls.
 */

if (!defined('ABSPATH')) exit;

final class Zooboxi_Marketing_Pixels
{
    public static function register_hooks(): void
    {
        add_action('wp_head', [__CLASS__, 'head'], 5);
        add_action('woocommerce_thankyou', [__CLASS__, 'thankyou'], 5, 1);
        add_action('wp_footer', [__CLASS__, 'footer'], 50);
    }

    private static function on(): bool
    {
        return Zooboxi_Marketing::is_enabled() && Zooboxi_Marketing::opt('pixels_enabled') === 'yes' && !is_admin();
    }

    public static function head(): void
    {
        if (!self::on()) return;
        $meta = Zooboxi_Marketing::opt('meta_pixel_id');
        $tt   = Zooboxi_Marketing::opt('tiktok_pixel_id');
        $snap = Zooboxi_Marketing::opt('snap_pixel_id');
        $ga   = Zooboxi_Marketing::opt('ga4_id');
        $gads = Zooboxi_Marketing::opt('gads_conversion_id');

        if ($meta !== '') {
            printf("<script>!function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';n.queue=[];t=b.createElement(e);t.async=!0;t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}(window,document,'script','https://connect.facebook.net/en_US/fbevents.js');fbq('init','%s');fbq('track','PageView');</script>\n", esc_js($meta));
        }
        if ($tt !== '') {
            printf("<script>!function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];ttq.methods=['page','track','identify','instances','debug','on','off','once','ready','alias','group','enableCookie','disableCookie','holdConsent','revokeConsent','grantConsent'],ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}};for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);ttq.instance=function(t){for(var e=ttq._i[t]||[],n=0;n<ttq.methods.length;n++)ttq.setAndDefer(e,ttq.methods[n]);return e},ttq.load=function(e,n){var r='https://analytics.tiktok.com/i18n/pixel/events.js',o=n&&n.partner;ttq._i=ttq._i||{},ttq._i[e]=[],ttq._i[e]._u=r,ttq._t=ttq._t||{},ttq._t[e]=+new Date,ttq._o=ttq._o||{},ttq._o[e]=n||{};n=document.createElement('script');n.type='text/javascript',n.async=!0,n.src=r+'?sdkid='+e+'&lib='+t;e=document.getElementsByTagName('script')[0];e.parentNode.insertBefore(n,e)};ttq.load('%s');ttq.page();}(window,document,'ttq');</script>\n", esc_js($tt));
        }
        if ($snap !== '') {
            printf("<script>(function(e,t,n){if(e.snaptr)return;var a=e.snaptr=function(){a.handleRequest?a.handleRequest.apply(a,arguments):a.queue.push(arguments)};a.queue=[];var s='script';var r=t.createElement(s);r.async=!0;r.src=n;var u=t.getElementsByTagName(s)[0];u.parentNode.insertBefore(r,u);})(window,document,'https://sc-static.net/scevent.min.js');snaptr('init','%s');snaptr('track','PAGE_VIEW');</script>\n", esc_js($snap));
        }
        if ($ga !== '' || $gads !== '') {
            $first = $ga !== '' ? $ga : $gads;
            printf("<script async src=\"https://www.googletagmanager.com/gtag/js?id=%s\"></script>\n<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());", esc_attr($first));
            if ($ga !== '')   printf("gtag('config','%s');", esc_js($ga));
            if ($gads !== '') printf("gtag('config','%s');", esc_js($gads));
            echo "</script>\n";
        }
    }

    /** Browser-side AddToCart / InitiateCheckout, wired to WooCommerce's own JS events. */
    public static function footer(): void
    {
        if (!self::on()) return;
        if (Zooboxi_Marketing::opt('meta_pixel_id') === '' && Zooboxi_Marketing::opt('tiktok_pixel_id') === '' && Zooboxi_Marketing::opt('snap_pixel_id') === '') return;
        ?>
<script>
(function(){
  function fire(meta,tt,snap,data){
    try{ if(window.fbq) fbq('track',meta,data); }catch(e){}
    try{ if(window.ttq) ttq.track(tt,{currency:'SAR',value:data.value||0}); }catch(e){}
    try{ if(window.snaptr) snaptr('track',snap,{currency:'SAR',price:data.value||0}); }catch(e){}
  }
  if(window.jQuery){
    jQuery(document.body).on('added_to_cart',function(){ fire('AddToCart','AddToCart','ADD_CART',{currency:'SAR'}); });
  }
  <?php if (function_exists('is_checkout') && is_checkout() && !is_order_received_page()) : ?>
  fire('InitiateCheckout','InitiateCheckout','START_CHECKOUT',{currency:'SAR',value:<?php echo function_exists('WC') && WC()->cart ? (float) WC()->cart->get_total('edit') : 0; ?>});
  <?php endif; ?>
})();
</script>
        <?php
    }

    public static function thankyou($order_id): void
    {
        if (!self::on()) return;
        $order = wc_get_order($order_id);
        if (!$order instanceof \WC_Order) return;
        if ($order->get_meta('_zb_pixel_fired')) return;
        $order->update_meta_data('_zb_pixel_fired', 1);
        $order->save();

        $value = (float) $order->get_total();
        $id    = 'zb_purchase_' . $order->get_id();
        $first = Zooboxi_Marketing::orders_count_including($order) === 1;
        $ids   = [];
        foreach ($order->get_items() as $item) {
            if ($item instanceof \WC_Order_Item_Product) {
                $p = $item->get_product();
                $ids[] = $p ? (string) ($p->get_sku() ?: $p->get_id()) : (string) $item->get_product_id();
            }
        }
        $ids_js = wp_json_encode($ids);
        $gads   = Zooboxi_Marketing::opt('gads_conversion_id');
        $label  = Zooboxi_Marketing::opt('gads_conversion_label');
        ?>
<script>
(function(){
  var v=<?php echo json_encode($value); ?>, id=<?php echo json_encode($id); ?>, ids=<?php echo $ids_js; ?>, first=<?php echo $first ? 'true' : 'false'; ?>;
  try{ if(window.fbq){ fbq('track','Purchase',{currency:'SAR',value:v,content_type:'product',content_ids:ids},{eventID:id}); if(first) fbq('trackCustom','FirstOrder',{currency:'SAR',value:v},{eventID:'zb_first_<?php echo (int) $order->get_id(); ?>'}); } }catch(e){}
  try{ if(window.ttq){ ttq.track('CompletePayment',{currency:'SAR',value:v,content_type:'product',contents:ids.map(function(i){return {content_id:i};})},{event_id:id}); } }catch(e){}
  try{ if(window.snaptr){ snaptr('track','PURCHASE',{currency:'SAR',price:v,item_ids:ids,client_dedup_id:id,transaction_id:'<?php echo (int) $order->get_id(); ?>'}); } }catch(e){}
  try{ if(window.gtag){ gtag('event','purchase',{transaction_id:'<?php echo (int) $order->get_id(); ?>',value:v,currency:'SAR'}); <?php if ($gads !== '' && $label !== '') : ?>gtag('event','conversion',{send_to:'<?php echo esc_js($gads . '/' . $label); ?>',value:v,currency:'SAR',transaction_id:'<?php echo (int) $order->get_id(); ?>'});<?php endif; ?> } }catch(e){}
})();
</script>
        <?php
    }
}
