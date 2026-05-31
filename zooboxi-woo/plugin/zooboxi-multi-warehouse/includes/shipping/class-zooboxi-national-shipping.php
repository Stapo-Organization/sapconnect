<?php
/**
 * National Shipping — 2-4 days from main hub.
 */
class Zooboxi_National_Shipping extends WC_Shipping_Method
{
    public function __construct($instance_id = 0)
    {
        $this->id                 = 'zooboxi_shipping';
        $this->instance_id        = absint($instance_id);
        $this->method_title       = __('شحن وطني Zooboxi', 'zooboxi');
        $this->method_description = __('شحن خلال 2-4 أيام عمل من المستودع المركزي الرئيسي', 'zooboxi');
        $this->supports           = ['shipping-zones', 'instance-settings'];
        $this->enabled            = 'yes';
        $this->title              = __('🚚 شحن (2-4 أيام عمل)', 'zooboxi');
        $this->init();
    }

    public function init(): void { $this->init_settings(); }

    public function calculate_shipping($package = []): void
    {
        $hub = Zooboxi_Warehouse_Manager::get_main_hub();
        if (!$hub) return;

        $fee = (float) get_option('zooboxi_shipping_fee', 25);
        $freeMin = (float) get_option('zooboxi_free_shipping_min', 200);
        if ($package['contents_cost'] >= $freeMin) $fee = 0;

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
