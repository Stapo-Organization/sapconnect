<?php
/**
 * National Shipping — 4-5 days from main hub.
 * Only shown when the customer does NOT have a central warehouse in their city.
 */
class Zooboxi_National_Shipping extends WC_Shipping_Method
{
    public function __construct($instance_id = 0)
    {
        $this->id                 = 'zooboxi_shipping';
        $this->instance_id        = absint($instance_id);
        $this->method_title       = __('شحن وطني Zooboxi', 'zooboxi');
        $this->method_description = __('شحن خلال 4-5 أيام عمل من المستودع المركزي الرئيسي', 'zooboxi');
        $this->supports           = ['shipping-zones', 'instance-settings'];
        $this->enabled            = 'yes';
        $this->title              = __('🚚 شحن عادي (4-5 أيام عمل)', 'zooboxi');
        $this->init();
    }

    public function init(): void { $this->init_settings(); }

    public function calculate_shipping($package = []): void
    {
        // 1. Get customer city
        $city = '';
        if (function_exists('WC') && WC()->session) {
            $city = WC()->session->get('zooboxi_customer_city', '');
        }
        if (empty($city) && !empty($_COOKIE['zooboxi_city'])) {
            $city = sanitize_text_field($_COOKIE['zooboxi_city']);
        }

        // Fallback: reverse from nearest warehouse
        if (empty($city)) {
            $lat = 0.0;
            $lng = 0.0;
            if (function_exists('WC') && WC()->session) {
                $lat = (float) WC()->session->get('zooboxi_customer_lat');
                $lng = (float) WC()->session->get('zooboxi_customer_lng');
            }
            if (!$lat && !empty($_COOKIE['zooboxi_lat'])) $lat = (float) $_COOKIE['zooboxi_lat'];
            if (!$lng && !empty($_COOKIE['zooboxi_lng'])) $lng = (float) $_COOKIE['zooboxi_lng'];

            if ($lat && $lng) {
                $nearest = Zooboxi_Warehouse_Manager::find_nearest($lat, $lng);
                $city = $nearest['warehouse']['city'] ?? '';
            }
        }

        // 2. If customer has a central warehouse in their city → DON'T show national shipping
        if (!empty($city)) {
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            if ($central) {
                // Customer has same-city central warehouse → Standard 24h is sufficient
                return;
            }
        }

        // 3. No central warehouse in customer's city → show national shipping
        $hub = Zooboxi_Warehouse_Manager::get_main_hub();
        if (!$hub) return;

        $fee = (float) get_option('zooboxi_shipping_fee', 25);
        $freeMin = (float) get_option('zooboxi_free_shipping_min', 200);
        if (isset($package['contents_cost']) && $package['contents_cost'] >= $freeMin) $fee = 0;

        $this->add_rate([
            'id'        => $this->id,
            'label'     => $this->title,
            'cost'      => $fee,
            'meta_data' => [
                'warehouse_code' => $hub['warehouse_code'],
                'delivery_type'  => 'shipping',
            ],
        ]);
    }
}
