<?php
/**
 * Custom WooCommerce order status: "جاهز للتسليم" (wc-zb-ready).
 *
 * Set by the Exhibition Manager app (branch manager) once a branch finishes
 * preparing an express order — the app calls sapconnect, which pushes the
 * status to this store via the WooCommerce REST API.
 *
 * Registering the status here is what makes:
 *   1. the WC REST API accept  PUT /wc/v3/orders/{id} {"status":"zb-ready"}
 *   2. the status appear in the admin order list + the status dropdown.
 */
class Zooboxi_Order_Statuses
{
    const STATUS_KEY  = 'wc-zb-ready'; // post status (with the wc- prefix)
    const STATUS_SLUG = 'zb-ready';    // REST/value slug (no prefix)
    const LABEL       = 'جاهز للتسليم';

    public function register_hooks(): void
    {
        add_action('init', [$this, 'register_status']);
        add_filter('wc_order_statuses', [$this, 'add_to_order_statuses']);
        add_filter('woocommerce_reports_order_statuses', [$this, 'add_to_reports']);
    }

    /**
     * Register the post status with WordPress / WooCommerce.
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
    }

    /**
     * Add the status to the WooCommerce order-status list (dropdown + REST).
     * Inserted right after "processing" so it reads as a fulfillment step.
     */
    public function add_to_order_statuses(array $statuses): array
    {
        $new = [];
        foreach ($statuses as $key => $label) {
            $new[$key] = $label;
            if ($key === 'wc-processing') {
                $new[self::STATUS_KEY] = self::LABEL;
            }
        }
        if (!isset($new[self::STATUS_KEY])) {
            $new[self::STATUS_KEY] = self::LABEL;
        }
        return $new;
    }

    /**
     * Count "ready" orders in WooCommerce reports alongside completed/processing.
     */
    public function add_to_reports(array $statuses): array
    {
        $statuses[] = self::STATUS_SLUG;
        return $statuses;
    }
}
