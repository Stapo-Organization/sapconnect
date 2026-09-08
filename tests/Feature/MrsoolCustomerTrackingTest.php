<?php

namespace Tests\Feature;

use App\Models\MrsoolDelivery;
use App\Models\ZooboxiOrder;
use App\Models\ZooboxiWarehouse;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * `GET /api/woo/orders/{id}/mrsool` — the courier as the CUSTOMER sees him.
 *
 * This payload crosses the store and lands on a stranger's phone, so the tests
 * care as much about what it does NOT say (price, cancel rights, a delivered
 * courier's phone number) as about what it does.
 */
class MrsoolCustomerTrackingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.woo.api_token'             => 'store-token',
            'services.mrsool.enabled'            => true,
            'services.mrsool.api_key'            => 'test-key',
            'services.mrsool.base_url'           => 'https://logistics.staging.mrsool.co',
            'services.mrsool.live_refresh_seconds' => 25,
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
    }

    private function order(): ZooboxiOrder
    {
        return ZooboxiOrder::create([
            'woo_order_id'       => 32664,
            'warehouse_code'     => 'RUH010',
            'delivery_type'      => 'express',
            'delivery_status'    => 'ready_for_pickup',
            'total_amount'       => 100,
            'customer_latitude'  => 24.7600000,
            'customer_longitude' => 46.6600000,
        ]);
    }

    private function delivery(ZooboxiOrder $order, array $overrides = []): MrsoolDelivery
    {
        return MrsoolDelivery::create(array_merge([
            'zooboxi_order_id' => $order->id,
            'woo_order_id'     => $order->woo_order_id,
            'partner_order_id' => 'ZB-' . $order->id,
            'mrsool_order_id'  => 357415601,
            'environment'      => 'staging',
            'status'           => MrsoolDelivery::S_DELIVERING,
            'phase'            => MrsoolDelivery::PHASE_IN_TRANSIT,
            'price_quote'      => 17,
            'courier_name'     => 'FAHAD MIAH',
            'courier_phone'    => '0555555555',
            'courier_lat'      => 24.7550000,
            'courier_lng'      => 46.6640000,
            'tracking_url'     => 'https://mrsool.co/t/abc',
            'requested_at'     => now()->subMinutes(9),
            'assigned_at'      => now()->subMinutes(7),
            'picked_up_at'     => now()->subMinutes(3),
            'last_synced_at'   => now(),
        ], $overrides));
    }

    private function track(int $wooOrderId)
    {
        return $this->withHeader('Authorization', 'Bearer store-token')
            ->getJson("/api/woo/orders/{$wooOrderId}/mrsool");
    }

    public function test_it_requires_the_store_token(): void
    {
        $this->getJson('/api/woo/orders/32664/mrsool')->assertStatus(401);
    }

    public function test_an_order_without_a_courier_answers_null(): void
    {
        $this->order();

        $this->track(32664)->assertOk()->assertJson(['data' => null]);
    }

    public function test_an_unknown_order_answers_null(): void
    {
        $this->track(999999)->assertOk()->assertJson(['data' => null]);
    }

    public function test_it_returns_the_live_courier_with_a_map_and_an_eta(): void
    {
        Http::fake();

        $order = $this->order();
        $this->delivery($order);

        $data = $this->track(32664)->assertOk()->json('data');

        $this->assertTrue($data['active']);
        $this->assertSame('in_transit', $data['phase']);
        $this->assertSame('مندوبك في الطريق إليك', $data['status_label']);
        $this->assertSame('FAHAD MIAH', $data['courier']['name']);
        $this->assertSame('0555555555', $data['courier']['phone']);
        $this->assertEqualsWithDelta(24.755, $data['courier']['lat'], 0.0001);

        // Both ends of the journey are present, so the app can frame a map.
        $this->assertEqualsWithDelta(24.7493638, $data['pickup']['lat'], 0.0001);
        $this->assertEqualsWithDelta(24.76, $data['dropoff']['lat'], 0.0001);

        // ~0.7 km at 22 km/h, floored at two minutes.
        $this->assertNotNull($data['distance_km']);
        $this->assertGreaterThan(0, $data['eta_minutes']);
        $this->assertLessThan(10, $data['eta_minutes']);

        $this->assertSame('https://mrsool.co/t/abc', $data['tracking_url']);
    }

    public function test_the_customer_never_sees_what_the_delivery_cost_or_who_may_cancel_it(): void
    {
        Http::fake();

        $order = $this->order();
        $this->delivery($order, ['last_error' => 'internal: quota exceeded']);

        $data = $this->track(32664)->assertOk()->json('data');

        $this->assertArrayNotHasKey('price_quote', $data);
        $this->assertArrayNotHasKey('can_cancel', $data);
        $this->assertArrayNotHasKey('last_error', $data);
        $this->assertArrayNotHasKey('id', $data);
    }

    public function test_a_delivered_courier_keeps_his_phone_number_to_himself(): void
    {
        $order = $this->order();
        $this->delivery($order, [
            'status'         => MrsoolDelivery::S_DELIVERED,
            'phase'          => MrsoolDelivery::PHASE_DELIVERED,
            'delivered_at'   => now(),
            'dropoff_images' => ['https://cdn.mrsool.co/proof.jpg'],
        ]);

        $data = $this->track(32664)->assertOk()->json('data');

        $this->assertFalse($data['active']);
        $this->assertNull($data['courier']['name']);
        $this->assertNull($data['courier']['phone']);
        $this->assertNull($data['courier']['lat']);
        $this->assertNull($data['eta_minutes']);
        $this->assertSame(['https://cdn.mrsool.co/proof.jpg'], $data['proof_images']);
    }

    public function test_the_four_steps_read_as_a_journey(): void
    {
        Http::fake();

        $order = $this->order();
        $this->delivery($order);

        $steps = $this->track(32664)->assertOk()->json('data.steps');

        $this->assertSame(['requested', 'assigned', 'picked_up', 'delivered'], array_column($steps, 'key'));
        $this->assertSame([true, true, true, false], array_column($steps, 'done'));
    }

    public function test_a_failed_courier_ends_the_journey_honestly(): void
    {
        $order = $this->order();
        $this->delivery($order, [
            'status'    => MrsoolDelivery::S_EXPIRED,
            'phase'     => MrsoolDelivery::PHASE_FAILED,
            'failed_at' => now(),
        ]);

        $data = $this->track(32664)->assertOk()->json('data');

        $this->assertSame('failed', $data['phase']);
        $this->assertSame('لم نجد مندوباً متاحاً', $data['status_label']);
        $this->assertSame('failed', $data['steps'][3]['key']);
        $this->assertTrue($data['steps'][3]['done']);
    }

    public function test_a_stale_live_row_is_refreshed_from_mrsool_before_answering(): void
    {
        Http::fake([
            '*/api/v1/orders/357415601' => Http::response([
                'data' => [
                    'id'               => 357415601,
                    'status'           => 'DROPOFF_ARRIVED',
                    'courier_info'     => ['full_name' => 'FAHAD MIAH', 'phone' => '0555555555'],
                    'courier_location' => ['latitude' => 24.7599, 'longitude' => 46.6601],
                ],
            ], 200),
        ]);

        $order = $this->order();
        $this->delivery($order, ['last_synced_at' => now()->subMinutes(2)]);

        $data = $this->track(32664)->assertOk()->json('data');

        Http::assertSentCount(1);
        $this->assertSame('DROPOFF_ARRIVED', $data['status']);
        $this->assertSame('مندوبك وصل عندك', $data['status_label']);
        $this->assertSame(0, $data['eta_minutes']);
    }

    public function test_a_fresh_row_is_served_without_calling_mrsool(): void
    {
        Http::fake();

        $order = $this->order();
        $this->delivery($order, ['last_synced_at' => now()->subSeconds(5)]);

        $this->track(32664)->assertOk();

        Http::assertNothingSent();
    }

    public function test_a_customer_refresh_never_pushes_to_the_store_or_the_branch(): void
    {
        // A phase change discovered while a customer refreshes a map must record
        // itself and stop there. Fanning out a store push + branch notifications
        // from a GET turns one person watching a dot into a chain of writes, and
        // races the cron that owns those side effects.
        Http::fake([
            '*/api/v1/orders/357415601' => Http::response([
                'data' => ['id' => 357415601, 'status' => 'DELIVERED'],
            ], 200),
        ]);

        $order = $this->order();
        $this->delivery($order, ['last_synced_at' => now()->subMinutes(5)]);

        $data = $this->track(32664)->assertOk()->json('data');

        $this->assertSame('delivered', $data['phase']);

        // Exactly one call went out: the Mrsool GET. Nothing to the store.
        Http::assertSentCount(1);
        Http::assertNotSent(fn ($request) => str_contains($request->url(), 'zooboxi'));

        // The order itself is left to the cron, which owns that transition.
        $this->assertSame('ready_for_pickup', $order->fresh()->delivery_status);
    }

    public function test_a_failed_refresh_backs_every_viewer_off(): void
    {
        Http::fake(['*/api/v1/orders/*' => Http::response([], 500)]);

        $order = $this->order();
        $this->delivery($order, ['last_synced_at' => now()->subMinutes(5)]);

        $this->track(32664)->assertOk();
        $this->track(32664)->assertOk();
        $this->track(32664)->assertOk();

        // One attempt, then the door is shut for a minute — a Mrsool outage must
        // not be re-dialled by every viewer every ten seconds.
        Http::assertSentCount(1);
    }

    public function test_an_unchanged_position_is_not_mistaken_for_a_failure(): void
    {
        // A courier stopped at a light produces an identical payload. Reading
        // that as a failed refresh would put every viewer into backoff within
        // a minute of a perfectly healthy delivery.
        Http::fake([
            '*/api/v1/orders/357415601' => Http::response([
                'data' => [
                    'id'               => 357415601,
                    'status'           => 'DELIVERING',
                    'courier_location' => ['latitude' => 24.755, 'longitude' => 46.664],
                ],
            ], 200),
        ]);

        $order = $this->order();
        $this->delivery($order, ['last_synced_at' => now()->subMinutes(5)]);

        $this->track(32664)->assertOk();

        $delivery = $order->mrsoolDeliveries()->first();
        $delivery->update(['last_synced_at' => now()->subMinutes(5)]);

        $this->track(32664)->assertOk();

        Http::assertSentCount(2);
    }

    public function test_a_courier_with_no_gps_fix_has_no_position_and_no_eta(): void
    {
        $order = $this->order();
        $this->delivery($order, ['courier_lat' => 0, 'courier_lng' => 0]);

        $data = $this->track(32664)->assertOk()->json('data');

        $this->assertNull($data['courier']['lat']);
        $this->assertNull($data['courier']['lng']);
        $this->assertNull($data['distance_km']);
        $this->assertNull($data['eta_minutes']);
    }

    public function test_before_pickup_there_is_no_distance_to_the_customers_door(): void
    {
        $order = $this->order();
        $this->delivery($order, [
            'status'      => MrsoolDelivery::S_COURIER_ASSIGNED,
            'phase'       => MrsoolDelivery::PHASE_ASSIGNED,
            'picked_up_at' => null,
        ]);

        $data = $this->track(32664)->assertOk()->json('data');

        // He is riding to the BRANCH; the gap between him and the door is not
        // the distance to the order.
        $this->assertNull($data['distance_km']);
        $this->assertNull($data['eta_minutes']);
        $this->assertSame('pickup', $data['heading_to']);
    }

    public function test_a_delivered_courier_is_shown_even_after_a_failed_retry(): void
    {
        $order = $this->order();

        $this->delivery($order, [
            'status'       => MrsoolDelivery::S_DELIVERED,
            'phase'        => MrsoolDelivery::PHASE_DELIVERED,
            'delivered_at' => now()->subMinutes(20),
        ]);

        // A retry whose create call never reached Mrsool: newest row, no id.
        MrsoolDelivery::create([
            'zooboxi_order_id' => $order->id,
            'partner_order_id' => 'ZB-' . $order->id . '-R2',
            'environment'      => 'staging',
            'phase'            => MrsoolDelivery::PHASE_FAILED,
            'failed_at'        => now(),
            'requested_at'     => now(),
        ]);

        $data = $this->track(32664)->assertOk()->json('data');

        $this->assertSame('delivered', $data['phase']);
        $this->assertSame('357415601', $data['number']);
    }

    public function test_a_terminal_delivery_is_never_re_fetched(): void
    {
        Http::fake();

        $order = $this->order();
        $this->delivery($order, [
            'status'         => MrsoolDelivery::S_DELIVERED,
            'phase'          => MrsoolDelivery::PHASE_DELIVERED,
            'delivered_at'   => now()->subHour(),
            'last_synced_at' => now()->subDay(),
        ]);

        $this->track(32664)->assertOk();

        Http::assertNothingSent();
    }
}
