<?php

namespace Tests\Feature;

use App\Models\MrsoolDelivery;
use App\Models\User;
use App\Models\ZooboxiOrder;
use App\Models\ZooboxiOrderLine;
use App\Models\ZooboxiWarehouse;
use App\Services\Mrsool\MrsoolDeliveryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Mrsool (مرسول) courier integration — the guards are the point of the design,
 * so most of these tests assert that a courier is NOT requested.
 */
class MrsoolDeliveryTest extends TestCase
{
    use RefreshDatabase;

    private const BASE = 'https://logistics.staging.mrsool.co';
    private const STORE = 'https://store.zooboxi.test';

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.mrsool.enabled'       => true,
            'services.mrsool.base_url'      => self::BASE,
            'services.mrsool.api_key'       => 'test-key',
            'services.mrsool.webhook_token' => 'secret-token',
            'services.mrsool.warehouses'    => 'RUH010',
            'services.mrsool.daily_cap'     => 20,
            'services.mrsool.allow_cod'     => false,
            'services.mrsool.store_phone'   => '0500000000',
            'services.woo.store_url'        => self::STORE,
            'services.woo.api_token'        => 'woo-token',
        ]);
    }

    // ─── Fixtures ───────────────────────────────────────────────

    private function warehouse(string $code = 'RUH010'): ZooboxiWarehouse
    {
        return ZooboxiWarehouse::create([
            'warehouse_code'      => $code,
            'sap_warehouse_codes' => [$code],
            'display_name_ar'     => 'فرع الملك فهد',
            'city'                => 'الرياض',
            'address_ar'          => 'طريق الملك فهد، الرياض',
            'latitude'            => 24.7136,
            'longitude'           => 46.6753,
            'phone'               => '0551112233',
            'is_active'           => true,
        ]);
    }

    private function order(array $overrides = []): ZooboxiOrder
    {
        $order = ZooboxiOrder::create(array_merge([
            'woo_order_id'       => 32579,
            'woo_order_number'   => 'ZB-32579',
            'warehouse_code'     => 'RUH010',
            'delivery_type'      => ZooboxiOrder::DELIVERY_EXPRESS,
            'delivery_status'    => ZooboxiOrder::STATUS_READY_FOR_PICKUP,
            'customer_latitude'  => 24.8000,
            'customer_longitude' => 46.7000,
            'customer_name'      => 'محمد',
            'customer_phone'     => '+966501234567',
            'customer_address'   => 'حي الملقا، الرياض',
            'customer_city'      => 'الرياض',
            'payment_method'     => 'myfatoorah',
            'payment_status'     => 'paid',
            'total_amount'       => 189.50,
        ], $overrides));

        ZooboxiOrderLine::create([
            'zooboxi_order_id' => $order->id,
            'item_code'        => 'P0001',
            'item_name'        => 'طعام قطط',
            'warehouse_code'   => 'RUH010',
            'quantity'         => 2,
            'unit_price'       => 50,
            'total_price'      => 100,
        ]);

        return $order->refresh();
    }

    private function manager(): User
    {
        return User::create([
            'name'           => 'مدير الفرع',
            'email'          => 'branch@example.test',
            'password'       => bcrypt('secret'),
            'warehouse_code' => json_encode(['RUH010']),
        ]);
    }

    private function service(): MrsoolDeliveryService
    {
        return app(MrsoolDeliveryService::class);
    }

    /** A Mrsool Order payload as the API returns it. */
    private function remoteOrder(string $status = 'COURIER_PENDING', array $extra = []): array
    {
        return ['data' => array_merge([
            'id'               => 7788,
            'status'           => $status,
            'partner_order_id' => 'ZB-32579',
            'courier_info'     => ['name' => 'سعد', 'phone' => '0555555555'],
            'events_history'   => [['event' => $status, 'created_at' => '2026-09-06T10:00:00Z']],
        ], $extra)];
    }

    // ─── Eligibility guards ─────────────────────────────────────

    public function test_cod_orders_are_not_eligible(): void
    {
        $this->warehouse();
        $order = $this->order(['payment_method' => 'cod']);

        $result = $this->service()->eligibility($order);

        $this->assertFalse($result['ok']);
        $this->assertStringContainsString('الدفع عند الاستلام', $result['reason']);
    }

    public function test_non_pilot_warehouse_is_not_eligible(): void
    {
        $this->warehouse('JED020');
        $order = $this->order(['warehouse_code' => 'JED020']);

        $result = $this->service()->eligibility($order);

        $this->assertFalse($result['ok']);
        $this->assertStringContainsString('غير مفعّل لهذا الفرع', $result['reason']);
    }

    public function test_master_switch_off_blocks_everything(): void
    {
        config(['services.mrsool.enabled' => false]);
        $this->warehouse();
        $order = $this->order();

        $result = $this->service()->eligibility($order);

        $this->assertFalse($result['ok']);
        $this->assertFalse($this->service()->eligibleQuick($order));
    }

    public function test_daily_cap_blocks_further_requests(): void
    {
        config(['services.mrsool.daily_cap' => 1]);
        $this->warehouse();
        $order = $this->order();

        // One request already made today (terminal, so it is not an "active" row).
        MrsoolDelivery::create([
            'zooboxi_order_id' => $order->id,
            'partner_order_id' => 'ZB-OTHER',
            'phase'            => MrsoolDelivery::PHASE_DELIVERED,
            'requested_at'     => now(),
        ]);

        $result = $this->service()->eligibility($order);

        $this->assertFalse($result['ok']);
        $this->assertStringContainsString('الحد اليومي', $result['reason']);
    }

    public function test_unprepared_order_is_not_eligible(): void
    {
        $this->warehouse();
        $order = $this->order(['delivery_status' => ZooboxiOrder::STATUS_PREPARING]);

        $this->assertFalse($this->service()->eligibility($order)['ok']);
    }

    // ─── Request path ───────────────────────────────────────────

    public function test_request_claims_a_ledger_row_and_sends_the_expected_payload(): void
    {
        Http::fake([
            self::BASE . '/api/v1/orders/calculate_price' => Http::response(['data' => '18.5'], 200),
            self::BASE . '/api/v1/orders' => Http::response($this->remoteOrder(), 201),
        ]);

        $this->warehouse();
        $order = $this->order();
        $user = $this->manager();

        Sanctum::actingAs($user);
        $response = $this->postJson("/api/zooboxi-orders/{$order->id}/mrsool/request");

        $response->assertStatus(201)
            ->assertJsonPath('delivery.mrsool_order_id', 7788)
            ->assertJsonPath('delivery.phase', MrsoolDelivery::PHASE_SEARCHING)
            ->assertJsonPath('delivery.price_quote', 18.5);

        $delivery = MrsoolDelivery::firstOrFail();
        $this->assertSame('ZB-32579', $delivery->partner_order_id);
        $this->assertSame(7788, $delivery->mrsool_order_id);
        $this->assertSame($user->id, $delivery->requested_by);
        $this->assertSame('staging', $delivery->environment);

        Http::assertSent(function (Request $request) {
            if (!str_ends_with($request->url(), '/api/v1/orders')) {
                return false;
            }
            $body = $request->data();

            // Lat/lng must be STRINGS, phones normalised to local 05XXXXXXXX.
            return $body['pickup']['latitude'] === '24.7136'
                && $body['dropoff']['longitude'] === '46.7'
                && is_string($body['dropoff']['latitude'])
                && $body['buyer']['phone'] === '0501234567'
                && $body['store']['phone'] === '0551112233'
                && $body['store']['name'] === 'فرع الملك فهد'
                && $body['partner_order_id'] === 'ZB-32579'
                && $body['pickup_type'] === 'shop_pickup'
                && $body['shipment_value'] === 189.5
                && $body['metadata']['commodities'] === 2
                && str_contains($body['description'], 'زوبوكسي ZB-32579')
                && mb_strlen($body['description']) <= 250
                && str_contains($body['metadata']['pickup_instructions'], 'ZB-32579');
        });
    }

    public function test_phone_normalisation_accepts_every_saudi_form(): void
    {
        $service = $this->service();

        $this->assertSame('0501234567', $service->normalizePhone('+966501234567'));
        $this->assertSame('0501234567', $service->normalizePhone('966501234567'));
        $this->assertSame('0501234567', $service->normalizePhone('00966501234567'));
        $this->assertSame('0501234567', $service->normalizePhone('501234567'));
        $this->assertSame('0501234567', $service->normalizePhone('0501234567'));
        $this->assertSame('0501234567', $service->normalizePhone('050 123 4567'));
        $this->assertSame('', $service->normalizePhone(null));
    }

    public function test_a_second_request_while_one_is_active_is_rejected(): void
    {
        Http::fake([
            self::BASE . '/api/v1/orders/calculate_price' => Http::response(['data' => '18.5'], 200),
            self::BASE . '/api/v1/orders' => Http::response($this->remoteOrder(), 201),
        ]);

        $this->warehouse();
        $order = $this->order();
        Sanctum::actingAs($this->manager());

        $this->postJson("/api/zooboxi-orders/{$order->id}/mrsool/request")->assertStatus(201);

        $this->postJson("/api/zooboxi-orders/{$order->id}/mrsool/request")
            ->assertStatus(422)
            ->assertJsonPath('message', 'يوجد طلب مندوب قائم لهذا الطلب.');

        $this->assertSame(1, MrsoolDelivery::count());
    }

    public function test_a_failed_create_marks_the_claim_failed_and_returns_502(): void
    {
        Http::fake([
            self::BASE . '/api/v1/orders/calculate_price' => Http::response(['data' => '18.5'], 200),
            self::BASE . '/api/v1/orders' => Http::response([
                'errors' => [['message' => 'لم يتم تحديد إعدادات الأسعار للمتجر']],
            ], 422),
        ]);

        $this->warehouse();
        $order = $this->order();
        Sanctum::actingAs($this->manager());

        $this->postJson("/api/zooboxi-orders/{$order->id}/mrsool/request")
            ->assertStatus(502)
            ->assertJsonPath('message', 'لم يتم تحديد إعدادات الأسعار للمتجر');

        $delivery = MrsoolDelivery::firstOrFail();
        $this->assertSame(MrsoolDelivery::PHASE_FAILED, $delivery->phase);
        $this->assertNull($delivery->mrsool_order_id);
        $this->assertNotNull($delivery->failed_at);

        // A retry gets a fresh partner_order_id (-R2), never a duplicate claim.
        $this->assertSame('ZB-32579-R2', $this->service()->nextPartnerOrderId($order));
    }

    public function test_quote_endpoint_degrades_to_null_when_pricing_is_unconfigured(): void
    {
        Http::fake([
            self::BASE . '/api/v1/orders/calculate_price' => Http::response([
                'errors' => [['message' => 'لم يتم تحديد إعدادات الأسعار للمتجر']],
            ], 422),
        ]);

        $this->warehouse();
        $order = $this->order();
        Sanctum::actingAs($this->manager());

        $this->getJson("/api/zooboxi-orders/{$order->id}/mrsool/quote")
            ->assertOk()
            ->assertJson(['price' => null, 'currency' => 'SAR']);
    }

    public function test_branch_cannot_see_another_branches_order(): void
    {
        $this->warehouse();
        $order = $this->order();

        $other = User::create([
            'name' => 'مدير آخر', 'email' => 'other@example.test',
            'password' => bcrypt('secret'), 'warehouse_code' => json_encode(['JED020']),
        ]);

        Sanctum::actingAs($other);
        $this->getJson("/api/zooboxi-orders/{$order->id}/mrsool")->assertNotFound();
    }

    // ─── Webhook ────────────────────────────────────────────────

    public function test_webhook_with_a_wrong_token_is_forbidden(): void
    {
        $this->postJson('/api/webhooks/mrsool/not-the-token', ['id' => 7788, 'status' => 'DELIVERED'])
            ->assertStatus(403);
    }

    public function test_webhook_with_an_empty_configured_token_is_forbidden(): void
    {
        config(['services.mrsool.webhook_token' => '']);

        $this->postJson('/api/webhooks/mrsool/', ['id' => 7788])->assertStatus(404);
        $this->postJson('/api/webhooks/mrsool/anything', ['id' => 7788])->assertStatus(403);
    }

    public function test_webhook_for_an_unknown_order_is_accepted_but_not_applied(): void
    {
        $this->postJson('/api/webhooks/mrsool/secret-token', ['id' => 999999, 'status' => 'DELIVERED'])
            ->assertStatus(202)
            ->assertJson(['received' => true]);

        $this->assertDatabaseHas('mrsool_webhook_events', [
            'mrsool_order_id' => 999999,
            'processed'       => false,
        ]);
    }

    public function test_delivered_webhook_completes_the_order_and_pushes_woo(): void
    {
        Http::fake([
            self::BASE . '/api/v1/orders/7788' => Http::response($this->remoteOrder('DELIVERED', [
                'dropoff_confirmation_images' => ['https://cdn.mrsool.test/proof.jpg'],
            ]), 200),
            self::STORE . '/wp-json/zooboxi/v1/orders/*' => Http::response(['success' => true], 200),
        ]);

        $this->warehouse();
        $order = $this->order(['delivery_status' => ZooboxiOrder::STATUS_OUT_FOR_DELIVERY]);
        $delivery = $this->activeDelivery($order, MrsoolDelivery::PHASE_IN_TRANSIT, 'DELIVERING');

        $this->postJson('/api/webhooks/mrsool/secret-token', ['id' => 7788, 'status' => 'DELIVERED'])
            ->assertOk()
            ->assertJson(['received' => true]);

        $delivery->refresh();
        $this->assertSame(MrsoolDelivery::PHASE_DELIVERED, $delivery->phase);
        $this->assertSame('DELIVERED', $delivery->status);
        $this->assertNotNull($delivery->delivered_at);
        $this->assertSame(['https://cdn.mrsool.test/proof.jpg'], $delivery->dropoff_images);
        $this->assertSame(ZooboxiOrder::STATUS_DELIVERED, $order->refresh()->delivery_status);
        $this->assertNotNull($order->woo_status_synced_at);

        Http::assertSent(function (Request $request) {
            return str_contains($request->url(), '/wp-json/zooboxi/v1/orders/32579/status')
                && $request['status'] === 'completed'
                && ($request['mrsool']['order_id'] ?? null) === 7788;
        });
    }

    public function test_in_transit_webhook_moves_the_order_out_for_delivery(): void
    {
        Http::fake([
            self::BASE . '/api/v1/orders/7788' => Http::response($this->remoteOrder('DELIVERING'), 200),
            self::STORE . '/wp-json/zooboxi/v1/orders/*' => Http::response(['success' => true], 200),
        ]);

        $this->warehouse();
        $order = $this->order();
        $delivery = $this->activeDelivery($order, MrsoolDelivery::PHASE_ASSIGNED, 'COURIER_ASSIGNED');

        $this->postJson('/api/webhooks/mrsool/secret-token', ['id' => 7788, 'status' => 'CONFIRMED_PICKUP'])
            ->assertOk();

        $this->assertSame(ZooboxiOrder::STATUS_OUT_FOR_DELIVERY, $order->refresh()->delivery_status);
        $this->assertSame(MrsoolDelivery::PHASE_IN_TRANSIT, $delivery->refresh()->phase);

        Http::assertSent(fn (Request $r) => str_contains($r->url(), '/status')
            && $r['status'] === 'zb-out-for-delivery');
    }

    public function test_canceled_webhook_hands_the_order_back_to_the_branch(): void
    {
        Http::fake([
            self::BASE . '/api/v1/orders/7788' => Http::response($this->remoteOrder('CANCELED'), 200),
        ]);

        $this->warehouse();
        $order = $this->order(['delivery_status' => ZooboxiOrder::STATUS_OUT_FOR_DELIVERY]);
        $delivery = $this->activeDelivery($order, MrsoolDelivery::PHASE_IN_TRANSIT, 'DELIVERING');

        $this->postJson('/api/webhooks/mrsool/secret-token', ['id' => 7788, 'status' => 'CANCELED'])
            ->assertOk();

        $this->assertSame(ZooboxiOrder::STATUS_READY_FOR_PICKUP, $order->refresh()->delivery_status);

        $delivery->refresh();
        $this->assertSame(MrsoolDelivery::PHASE_FAILED, $delivery->phase);
        $this->assertNotNull($delivery->failed_at);
        $this->assertNotEmpty($delivery->last_error);
    }

    public function test_reapplying_a_delivered_payload_is_idempotent(): void
    {
        $this->warehouse();
        $order = $this->order(['delivery_status' => ZooboxiOrder::STATUS_OUT_FOR_DELIVERY]);
        $delivery = $this->activeDelivery($order, MrsoolDelivery::PHASE_IN_TRANSIT, 'DELIVERING');

        Http::fake([self::STORE . '/wp-json/zooboxi/v1/orders/*' => Http::response(['ok' => true], 200)]);

        $payload = $this->remoteOrder('DELIVERED')['data'];

        $this->assertTrue($this->service()->applyRemote($delivery, $payload));
        $deliveredAt = $delivery->refresh()->delivered_at;

        // Second apply changes nothing and must not push Woo again.
        $this->assertFalse($this->service()->applyRemote($delivery, $payload));
        $this->assertEquals($deliveredAt, $delivery->refresh()->delivered_at);
        Http::assertSentCount(1);
    }

    public function test_a_late_non_terminal_webhook_never_un_delivers_an_order(): void
    {
        $this->warehouse();
        $order = $this->order(['delivery_status' => ZooboxiOrder::STATUS_DELIVERED]);
        $delivery = $this->activeDelivery($order, MrsoolDelivery::PHASE_DELIVERED, 'DELIVERED');
        $delivery->update(['delivered_at' => now()]);

        $this->service()->applyRemote($delivery, ['id' => 7788, 'status' => 'DELIVERING']);

        $this->assertSame(MrsoolDelivery::PHASE_DELIVERED, $delivery->refresh()->phase);
        $this->assertSame(ZooboxiOrder::STATUS_DELIVERED, $order->refresh()->delivery_status);
    }

    // ─── Cancel ─────────────────────────────────────────────────

    public function test_branch_can_cancel_before_pickup(): void
    {
        Http::fake([self::BASE . '/api/v1/orders/7788/cancel' => Http::response(['data' => ['id' => 7788, 'status' => 'CANCELED']], 200)]);

        $this->warehouse();
        $order = $this->order();
        $this->activeDelivery($order, MrsoolDelivery::PHASE_SEARCHING, 'COURIER_PENDING');

        Sanctum::actingAs($this->manager());
        $this->postJson("/api/zooboxi-orders/{$order->id}/mrsool/cancel")
            ->assertOk()
            ->assertJsonPath('delivery.phase', MrsoolDelivery::PHASE_FAILED)
            ->assertJsonPath('delivery.last_error', 'ألغي من الفرع');
    }

    public function test_cancel_is_refused_once_the_courier_has_collected(): void
    {
        $this->warehouse();
        $order = $this->order();
        $this->activeDelivery($order, MrsoolDelivery::PHASE_IN_TRANSIT, 'DELIVERING');

        Sanctum::actingAs($this->manager());
        $this->postJson("/api/zooboxi-orders/{$order->id}/mrsool/cancel")->assertStatus(422);
    }

    // ─── Order payload ──────────────────────────────────────────

    public function test_order_resource_exposes_the_mrsool_block_and_map_coordinates(): void
    {
        $this->warehouse();
        $order = $this->order();

        Sanctum::actingAs($this->manager());
        $this->getJson("/api/zooboxi-orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.mrsool.eligible', true)
            ->assertJsonPath('data.mrsool.active', null)
            ->assertJsonPath('data.customer.latitude', 24.8)
            ->assertJsonPath('data.warehouse.code', 'RUH010')
            ->assertJsonPath('data.warehouse.latitude', 24.7136);
    }

    // ─── Helpers ────────────────────────────────────────────────

    private function activeDelivery(ZooboxiOrder $order, string $phase, string $status): MrsoolDelivery
    {
        return MrsoolDelivery::create([
            'zooboxi_order_id' => $order->id,
            'woo_order_id'     => $order->woo_order_id,
            'partner_order_id' => $order->woo_order_number,
            'mrsool_order_id'  => 7788,
            'environment'      => 'staging',
            'phase'            => $phase,
            'status'           => $status,
            'requested_at'     => now(),
        ]);
    }
}
