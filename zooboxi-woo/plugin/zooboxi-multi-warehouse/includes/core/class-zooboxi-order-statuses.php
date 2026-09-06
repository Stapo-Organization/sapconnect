<?php
/**
 * Custom WooCommerce order statuses:
 *   "جاهز للتسليم"    (wc-zb-ready)
 *   "في الطريق إليك"  (wc-zb-out-for-delivery)
 *
 * `zb-ready` is set by the Exhibition Manager app (branch manager) once a branch
 * finishes preparing an express order. `zb-out-for-delivery` is set by sapconnect
 * when the Mrsool (مرسول) courier confirms pickup — both travel the same road:
 * the app/backend calls sapconnect, which pushes the status to this store.
 *
 * Registering the statuses here is what makes:
 *   1. the WC REST API accept  PUT /wc/v3/orders/{id} {"status":"zb-ready"}
 *   2. the status appear in the admin order list + the status dropdown.
 *
 * Stock: neither status touches stock. WooCommerce reduces stock on
 * processing/completed/on-hold (wc_maybe_reduce_stock_levels) and restores it on
 * cancelled/pending — an order reaches `zb-ready`/`zb-out-for-delivery` only
 * *after* `processing`, so stock is already reduced and must not be touched
 * again. `zb-out-for-delivery` therefore mirrors `zb-ready` exactly: registered,
 * listed and reported, but deliberately absent from wc_order_is_paid_statuses.
 */
class Zooboxi_Order_Statuses
{
    const STATUS_KEY  = 'wc-zb-ready'; // post status (with the wc- prefix)
    const STATUS_SLUG = 'zb-ready';    // REST/value slug (no prefix)
    const LABEL       = 'جاهز للتسليم';

    const OFD_STATUS_KEY  = 'wc-zb-out-for-delivery';
    const OFD_STATUS_SLUG = 'zb-out-for-delivery';
    const OFD_LABEL       = 'في الطريق إليك';

    public function register_hooks(): void
    {
        add_action('init', [$this, 'register_status']);
        add_filter('wc_order_statuses', [$this, 'add_to_order_statuses']);
        add_filter('woocommerce_reports_order_statuses', [$this, 'add_to_reports']);
    }

    /**
     * Register the post statuses with WordPress / WooCommerce.
     */
    public function register_status(): void
    {
        register_post_status(self::STATUS_KEY, [
            'label'                     => self::LABEL,
            'public'                    => true,
            'exclude_from_search'       => false,
            'show_in_admin_all_list'    => true,
            'show_in_admin_status_list' => true,
            /* translators: %s: order count */
            'label_count'               => _n_noop(
                'جاهز للتسليم <span class="count">(%s)</span>',
                'جاهز للتسليم <span class="count">(%s)</span>'
            ),
        ]);

        register_post_status(self::OFD_STATUS_KEY, [
            'label'                     => self::OFD_LABEL,
            'public'                    => true,
            'exclude_from_search'       => false,
            'show_in_admin_all_list'    => true,
            'show_in_admin_status_list' => true,
            /* translators: %s: order count */
            'label_count'               => _n_noop(
                'في الطريق إليك <span class="count">(%s)</span>',
                'في الطريق إليك <span class="count">(%s)</span>'
            ),
        ]);
    }

    /**
     * Add the statuses to the WooCommerce order-status list (dropdown + REST).
     * Inserted right after "processing" so they read as fulfillment steps, in the
     * order they actually happen: processing → ready → out for delivery.
     */
    public function add_to_order_statuses(array $statuses): array
    {
        $new = [];
        foreach ($statuses as $key => $label) {
            $new[$key] = $label;
            if ($key === 'wc-processing') {
                $new[self::STATUS_KEY]     = self::LABEL;
                $new[self::OFD_STATUS_KEY] = self::OFD_LABEL;
            }
        }
        if (!isset($new[self::STATUS_KEY])) {
            $new[self::STATUS_KEY] = self::LABEL;
        }
        if (!isset($new[self::OFD_STATUS_KEY])) {
            $new[self::OFD_STATUS_KEY] = self::OFD_LABEL;
        }
        return $new;
    }

    /**
     * Count "ready" / "out for delivery" orders in WooCommerce reports alongside
     * completed/processing.
     */
    public function add_to_reports(array $statuses): array
    {
        $statuses[] = self::STATUS_SLUG;
        $statuses[] = self::OFD_STATUS_SLUG;
        return $statuses;
    }
}
