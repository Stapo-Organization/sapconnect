<?php

namespace Tests\Feature;

use App\Models\MrsoolDelivery;
use App\Models\WarehouseItemStock;
use App\Models\ZooboxiOrder;
use App\Models\ZooboxiOrderLine;
use App\Models\ZooboxiWarehouse;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * An order trashed or deleted in the store must disappear from sapconnect too.
 * Left behind, it sits in the branch app forever as a task nobody can finish —
 * which is exactly what the owner had to clean up by hand.
 */
class WooOrderDeletionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.woo.api_token' => 'store-token']);

        ZooboxiWarehouse::create([
            'warehouse_code'      => 'RUH010',
            'sap_warehouse_codes' => ['RUH010'],
            'display_name_ar'     => 'فرع الملك فهد - الرياض',
            'city'                => 'الرياض',
            'latitude'            => 24.7493638,
            'longitude'           => 46.6678227,
            'is_active'           => true,
        ]);
    }

    private function order(array $overrides = []): ZooboxiOrder
    {
        $order = ZooboxiOrder::create(array_merge([
            'woo_order_id'    => 32595,
            'warehouse_code'  => 'RUH010',
            'delivery_type'   => 'express',
            'delivery_status' => 'pending',
            'total_amount'    => 100,
        ], $overrides));

        ZooboxiOrderLine::create([
            'zooboxi_order_id' => $order->id,
            'item_code'        => 'P17900023',
            'warehouse_code'   => 'RUH010',
            'quantity'         => 2,
            'unit_price'       => 50,
            'total_price'      => 100,
        ]);

        return $order;
    }

    private function removeOrder(int $wooOrderId)
    {
        return $this->withHeader('Authorization', 'Bearer store-token')
            ->deleteJson('/api/woo/orders/' . $wooOrderId);
    }

    public function test_it_deletes_the_mirror_and_its_lines(): void
    {
        $order = $this->order();

        $this->removeOrder(32595)->assertOk()->assertJson(['status' => 'deleted']);

        $this->assertSame(0, ZooboxiOrder::count());
        $this->assertSame(0, ZooboxiOrderLine::where('zooboxi_order_id', $order->id)->count());
    }

    public function test_deleting_an_order_we_never_had_is_a_success(): void
    {
        // The store must not retry forever over a row that is already gone.
        $this->removeOrder(999999)->assertOk()->assertJson(['status' => 'already_absent']);
    }

    public function test_it_never_moves_stock(): void
    {
        WarehouseItemStock::create([
            'item_code'      => 'P17900023',
            'warehouse_code' => 'RUH010',
            'in_stock'       => 40,
            'committed'      => 0,
            'ordered'        => 0,
        ]);

        $this->order();
        $this->removeOrder(32595)->assertOk();

        $this->assertEquals(40.0, (float) WarehouseItemStock::first()->in_stock);
    }

    public function test_it_refuses_to_delete_while_a_courier_is_in_flight(): void
    {
        $order = $this->order(['delivery_status' => 'ready_for_pickup']);

        MrsoolDelivery::create([
            'zooboxi_order_id' => $order->id,
            'woo_order_id'     => $order->woo_order_id,
            'partner_order_id' => 'ZB-32595',
            'mrsool_order_id'  => 15805234,
            'environment'      => 'staging',
            'status'           => 'DELIVERING',
            'phase'            => MrsoolDelivery::PHASE_IN_TRANSIT,
            'requested_at'     => now(),
        ]);

        $this->removeOrder(32595)->assertOk()->assertJson(['status' => 'cancelled_instead']);

        // The order and the courier's audit trail both survive.
        $this->assertSame(1, ZooboxiOrder::count());
        $this->assertSame(1, MrsoolDelivery::count());
        $this->assertSame('cancelled', $order->refresh()->delivery_status);
    }

    public function test_a_finished_courier_does_not_block_deletion(): void
    {
        $order = $this->order(['delivery_status' => 'delivered']);

        MrsoolDelivery::create([
            'zooboxi_order_id' => $order->id,
            'woo_order_id'     => $order->woo_order_id,
            'partner_order_id' => 'ZB-32595',
            'mrsool_order_id'  => 15805235,
            'environment'      => 'staging',
            'status'           => 'DELIVERED',
            'phase'            => MrsoolDelivery::PHASE_DELIVERED,
            'requested_at'     => now(),
        ]);

        $this->removeOrder(32595)->assertOk()->assertJson(['status' => 'deleted']);

        $this->assertSame(0, ZooboxiOrder::count());
    }

    public function test_it_requires_the_store_token(): void
    {
        $this->order();

        $this->deleteJson('/api/woo/orders/32595')->assertUnauthorized();
        $this->assertSame(1, ZooboxiOrder::count());
    }
}
