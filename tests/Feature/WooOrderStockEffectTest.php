<?php

namespace Tests\Feature;

use App\Models\WarehouseItemStock;
use App\Models\ZooboxiOrder;
use App\Models\ZooboxiWarehouse;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Owner rule (2026-09-06): a Zooboxi store order reaching sapconnect must NOT
 * move stock, and nothing here may ever write to SAP.
 *
 * `warehouse_item_stocks` is a read-only mirror of SAP refreshed every ten
 * minutes, so a deduction is both erased later and wrong while it lasts.
 */
class WooOrderStockEffectTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.woo.api_token'   => 'store-token',
            'services.woo.deduct_stock' => false,
        ]);

        ZooboxiWarehouse::create([
            'warehouse_code'      => 'RUH010',
            'sap_warehouse_codes' => ['RUH010'],
            'display_name_ar'     => 'فرع الملك فهد - الرياض',
            'city'                => 'الرياض',
            'latitude'            => 24.7493638,
            'longitude'           => 46.6678227,
            'is_active'           => true,
        ]);

        WarehouseItemStock::create([
            'item_code'      => 'P17900023',
            'warehouse_code' => 'RUH010',
            'in_stock'       => 40,
            'committed'      => 0,
            'ordered'        => 0,
        ]);
    }

    private function payload(array $overrides = []): array
    {
        return array_replace_recursive([
            'woo_order_id'   => 32597,
            'delivery_type'  => 'express',
            'warehouse_code' => 'RUH010',
            'customer'       => ['name' => 'عميل', 'phone' => '0500000000'],
            'items'          => [[
                'item_code'   => 'P17900023',
                'item_name'   => 'صنف',
                'quantity'    => 3,
                'unit_price'  => 10,
                'total_price' => 30,
            ]],
            'payment' => ['method' => 'myfatoorah_v2', 'status' => 'paid'],
            'totals'  => ['subtotal' => 30, 'total' => 30],
        ], $overrides);
    }

    private function sendOrder(array $payload)
    {
        return $this->withHeader('Authorization', 'Bearer store-token')
            ->postJson('/api/woo/orders', $payload);
    }

    public function test_a_paid_order_arrives_without_touching_stock(): void
    {
        $this->sendOrder($this->payload())->assertCreated();

        $this->assertSame(1, ZooboxiOrder::count());
        $this->assertEquals(40.0, (float) WarehouseItemStock::first()->in_stock);
    }

    public function test_a_pending_to_paid_transition_does_not_touch_stock(): void
    {
        $this->sendOrder($this->payload(['payment' => ['status' => 'pending']]))->assertCreated();

        $this->withHeader('Authorization', 'Bearer store-token')
            ->putJson('/api/woo/orders/32597/status', ['payment_status' => 'paid'])
            ->assertOk();

        $this->assertEquals(40.0, (float) WarehouseItemStock::first()->in_stock);
    }

    public function test_a_cancellation_does_not_invent_stock(): void
    {
        $this->sendOrder($this->payload())->assertCreated();

        $this->withHeader('Authorization', 'Bearer store-token')
            ->putJson('/api/woo/orders/32597/status', ['delivery_status' => 'cancelled'])
            ->assertOk();

        // The order never took stock, so cancelling it must not give any back.
        $this->assertEquals(40.0, (float) WarehouseItemStock::first()->in_stock);
    }

    public function test_the_flag_still_works_when_the_owner_turns_it_on(): void
    {
        config(['services.woo.deduct_stock' => true]);

        $this->sendOrder($this->payload())->assertCreated();

        $this->assertEquals(37.0, (float) WarehouseItemStock::first()->in_stock);
    }
}
