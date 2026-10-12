<?php
defined('ABSPATH') || exit;

/** Maps ShipGo fulfilment events to WooCommerce statuses + Arabic labels. */
class ShipGo_Statuses {

    const META_STATUS   = '_shipgo_status';
    const META_CODE     = '_shipgo_order_code';
    const META_TRACKING = '_shipgo_tracking';
    const META_AWB      = '_shipgo_awb';
    const META_CARRIER  = '_shipgo_carrier';
    const META_SYNCED   = '_shipgo_synced_at';
    const META_ATTEMPTS = '_shipgo_attempts';

    /** Arabic label for a ShipGo status (for notes + customer/admin display). */
    public static function label_ar(string $status): string {
        $map = [
            'created'    => 'تم الاستلام في المستودع',
            'allocated'  => 'تم حجز الكمية',
            'picking'    => 'جارٍ التجهيز',
            'picked'     => 'تم تجميع الطلب',
            'packed'     => 'تم التغليف',
            'dispatched' => 'تم الشحن',
            'delivered'  => 'تم التسليم',
            'cancelled'  => 'أُلغي',
        ];
        return $map[$status] ?? $status;
    }

    /**
     * WC status a ShipGo event should move the order to (or null to keep the
     * current status and only annotate). dispatch_status is configurable.
     */
    public static function wc_status_for(string $shipgo): ?string {
        switch ($shipgo) {
            case 'allocated':
            case 'picking':
            case 'picked':
            case 'packed':
                return 'processing';
            case 'dispatched':
                return (string) ShipGo_Settings::get('dispatch_status', 'completed');
            case 'delivered':
                return 'completed';
            case 'cancelled':
                return 'cancelled';
            default:
                return null;
        }
    }
}
