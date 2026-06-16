<?php
/**
 * Standard Shipping — 24 hour delivery from central city warehouse.
 */
class Zooboxi_Standard_Shipping extends WC_Shipping_Method
{
    public function __construct($instance_id = 0)
    {
        $this->id                 = 'zooboxi_standard';
        $this->instance_id        = absint($instance_id);
        $this->method_title       = __('توصيل عادي Zooboxi', 'zooboxi');
        $this->method_description = __('توصيل خلال 24 ساعة من المستودع المركزي بالمدينة', 'zooboxi');
        $this->supports           = ['shipping-zones', 'instance-settings'];
        $this->enabled            = 'yes';
        $this->title              = __('📦 توصيل عادي (خلال 24 ساعة)', 'zooboxi');
        $this->init();
    }

    public function init(): void { $this->init_settings(); }

    public function calculate_shipping($package = []): void
    {
        // Tier gate: standard (24h) is the only option for a next-day shipment — no speed choice.
        $tier = is_array($package) ? ($package['zooboxi_tier'] ?? null) : null;
        if (null !== $tier && 'same_day' !== $tier) {
            return;
        }

        $session = WC()->session;
        if (!$session) return;

        $city = $session->get('zooboxi_customer_city', '');

        // Fallback 1: check cookie
        if (empty($city) && !empty($_COOKIE['zooboxi_city'])) {
            $city = sanitize_text_field($_COOKIE['zooboxi_city']);
        }

        // Fallback 2: reverse from nearest warehouse
        if (empty($city)) {
            $lat = (float) $session->get('zooboxi_customer_lat');
            $lng = (float) $session->get('zooboxi_customer_lng');
            if ($lat && $lng) {
                $nearest = Zooboxi_Warehouse_Manager::find_nearest($lat, $lng);
                $city = $nearest['warehouse']['city'] ?? '';
            }
        }

        if (empty($city)) return;
        $central = Zooboxi_Warehouse_Manager::find_central($city);
        if (!$central) return;

        $fee = (float) get_option('zooboxi_standard_fee', 10);
        $freeMin = (float) get_option('zooboxi_free_shipping_min', 200);
        // Order-level free shipping (matches express): qualify once, every shipment is free.
        $orderTotal = (function_exists('WC') && WC()->cart) ? (float) WC()->cart->get_subtotal() : (float) ($package['contents_cost'] ?? 0);
        if ($orderTotal >= $freeMin) $fee = 0;

        $this->add_rate([
            'id'        => $this->id,
            'label'     => $this->title,
            'cost'      => $fee,
            'meta_data' => [
                'warehouse_code' => $central['warehouse_code'],
                'delivery_type'  => 'same_day',
            ],
        ]);
    }
}
