<?php
/**
 * Click & Collect — free pickup from branch.
 */
class Zooboxi_Pickup_Shipping extends WC_Shipping_Method
{
    public function __construct($instance_id = 0)
    {
        $this->id                 = 'zooboxi_pickup';
        $this->instance_id        = absint($instance_id);
        $this->method_title       = __('استلام من الفرع Zooboxi', 'zooboxi');
        $this->method_description = __('استلام مجاني من أقرب فرع', 'zooboxi');
        $this->supports           = ['shipping-zones', 'instance-settings'];
        $this->enabled            = 'yes';
        $this->title              = __('🏬 استلام من الفرع (مجاناً)', 'zooboxi');
        $this->init();
    }

    public function init(): void { $this->init_settings(); }

    public function calculate_shipping($package = []): void
    {
        $session = WC()->session;
        $lat = $session ? (float) $session->get('zooboxi_customer_lat') : 0;
        $lng = $session ? (float) $session->get('zooboxi_customer_lng') : 0;

        if ($lat && $lng) {
            $locations = Zooboxi_Warehouse_Manager::get_pickup_locations($lat, $lng);
        } else {
            $locations = array_map(fn($wh) => ['warehouse' => $wh, 'distance' => 0], Zooboxi_Warehouse_Manager::get_active());
        }

        foreach (array_slice($locations, 0, 3) as $loc) {
            $wh = $loc['warehouse'];
            if (!($wh['is_pickup_enabled'] ?? true)) continue;

            $name = is_rtl() ? ($wh['display_name_ar'] ?: $wh['display_name_en']) : ($wh['display_name_en'] ?: $wh['display_name_ar']);
            $label = sprintf('🏬 %s %s', __('استلام من', 'zooboxi'), $name);
            if ($loc['distance'] > 0) {
                $label .= sprintf(' (%.1f كم)', $loc['distance']);
            }

            $this->add_rate([
                'id'        => $this->id . '_' . $wh['warehouse_code'],
                'label'     => $label,
                'cost'      => 0,
                'meta_data' => [
                    'warehouse_code' => $wh['warehouse_code'],
                    'delivery_type'  => 'pickup',
                ],
            ]);
        }
    }
}
