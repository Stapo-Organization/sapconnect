<?php
/**
 * Express Shipping — delivery within 2 hours from nearest warehouse.
 */
class Zooboxi_Express_Shipping extends WC_Shipping_Method
{
    public function __construct($instance_id = 0)
    {
        $this->id                 = 'zooboxi_express';
        $this->instance_id        = absint($instance_id);
        $this->method_title       = __('توصيل سريع Zooboxi', 'zooboxi');
        $this->method_description = __('توصيل خلال ساعتين من أقرب مستودع', 'zooboxi');
        $this->supports           = ['shipping-zones', 'instance-settings'];
        $this->enabled            = 'yes';
        $this->title              = __('🚀 توصيل سريع (خلال ساعتين)', 'zooboxi');
        $this->init();
    }

    public function init(): void
    {
        $this->init_settings();
    }

    public function calculate_shipping($package = []): void
    {
        $session = WC()->session;
        if (!$session) return;

        $lat = (float) $session->get('zooboxi_customer_lat');
        $lng = (float) $session->get('zooboxi_customer_lng');
        if (!$lat || !$lng) return;

        $nearest = Zooboxi_Warehouse_Manager::find_nearest($lat, $lng);
        if (!$nearest) return;

        $wh = $nearest['warehouse'];
        $radius = (float) ($wh['express_radius_km'] ?? 10);

        if ($nearest['distance'] > $radius) return;

        $fee = (float) get_option('zooboxi_express_fee', 15);
        $freeMin = (float) get_option('zooboxi_free_shipping_min', 200);
        if ($package['contents_cost'] >= $freeMin) $fee = 0;

        $this->add_rate([
            'id'        => $this->id,
            'label'     => $this->title,
            'cost'      => $fee,
            'meta_data' => [
                'warehouse_code' => $wh['warehouse_code'],
                'delivery_type'  => 'express',
                'estimated_time' => '2 hours',
            ],
        ]);
    }
}
