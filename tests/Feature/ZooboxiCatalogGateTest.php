<?php

namespace Tests\Feature;

use App\Models\Brand;
use App\Models\Product;
use App\Models\WarehouseItemStock;
use App\Models\ZooboxiWarehouse;
use App\Services\Zooboxi\CatalogCopywriter;
use App\Services\Zooboxi\CatalogGateService;
use App\Services\Zooboxi\ProductImageResolver;
use App\Services\Zooboxi\ShipGoChannelClient;
use App\Services\Zooboxi\WooCategoryTree;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * بوابة كتالوج زوبوكسي — a production item becomes zooboxi_active by itself
 * when price + barcode + brand + stock + picture are all there; anything
 * short is held with readable reasons and never silently skipped.
 */
class ZooboxiCatalogGateTest extends TestCase
{
    use RefreshDatabase;

    private const HEAD_OK = 'https://gal.holeno.com/imghd/P1.png';

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.shipgo.store_key' => '',            // ShipGo unreachable → unknown, not zero
            'services.anthropic.api_key' => '',           // copywriter off → SAP fallback copy
            'services.woo.consumer_key' => '',            // no category tree
            'services.zooboxi_gate.price_list' => 1,
        ]);
        Brand::create(['code' => 176, 'name' => 'Applaws']);
        ZooboxiWarehouse::create([
            'warehouse_code' => 'RUH004', 'sap_warehouse_codes' => ['RUH004'], 'display_name_ar' => 'فرع',
            'display_name_en' => 'Branch', 'city' => 'الرياض', 'express_radius_km' => 12, 'is_active' => true,
        ]);
        ZooboxiWarehouse::create([
            'warehouse_code' => 'RUH003', 'sap_warehouse_codes' => ['RUH003'], 'display_name_ar' => 'مستودع',
            'display_name_en' => 'Hub', 'city' => 'الرياض', 'express_radius_km' => 0, 'is_active' => true,
        ]);
        Http::fake([
            'gal.holeno.com/imghd/P1.png' => Http::response('', 200, ['Content-Type' => 'image/png']),
            'gal.holeno.com/*' => Http::response('', 404),
        ]);
    }

    private function product(string $code, array $over = []): Product
    {
        return Product::create(array_merge([
            'item_code' => $code,
            'item_name' => 'Applaws Tuna 70g',
            'foreign_name' => 'ابلاوز تونة 70 جم',
            'piece_barcode' => '5060122490078',
            'items_group_code' => 176,
            'prices' => [['PriceList' => 1, 'Price' => 9.5]],
            'source' => 'production',
            'zooboxi_active' => false,
        ], $over));
    }

    private function gate(): CatalogGateService
    {
        return app(CatalogGateService::class);
    }

    public function test_ready_product_is_activated_with_sap_copy_and_verified_picture(): void
    {
        $p = $this->product('P1');
        WarehouseItemStock::create(['item_code' => 'P1', 'warehouse_code' => 'RUH004', 'in_stock' => 3]);

        $s = $this->gate()->run();

        $this->assertSame(1, $s['activated']);
        $p->refresh();
        $this->assertTrue((bool) $p->zooboxi_active);
        $this->assertTrue((bool) $p->woo_sync);
        $this->assertSame('active', $p->zooboxi_gate_status);
        $this->assertSame([self::HEAD_OK], $p->zb_resolved_images);
        $this->assertSame([self::HEAD_OK], $p->zb_images);
        $this->assertSame('ابلاوز تونة 70 جم', $p->zb_name_ar);
        $this->assertSame('Applaws Tuna 70g', $p->zb_name_en);
        $this->assertSame('sap', $p->zb_content_source);
        $this->assertDatabaseHas('zooboxi_gate_events', ['item_code' => 'P1', 'action' => 'activated']);
    }

    public function test_missing_picture_holds_with_reason_and_no_activation(): void
    {
        $this->product('P2'); // holeno 404 for P2
        WarehouseItemStock::create(['item_code' => 'P2', 'warehouse_code' => 'RUH004', 'in_stock' => 3]);

        $s = $this->gate()->run();

        $this->assertSame(1, $s['held']);
        $p = Product::where('item_code', 'P2')->first();
        $this->assertFalse((bool) $p->zooboxi_active);
        $this->assertSame('held', $p->zooboxi_gate_status);
        $this->assertSame(['no_image'], $p->zooboxi_gate_reasons);
    }

    public function test_cheap_rules_are_reported_together_and_no_image_check_is_made(): void
    {
        $this->product('P3', ['piece_barcode' => null, 'prices' => [], 'items_group_code' => 999]);

        $s = $this->gate()->run();

        $p = Product::where('item_code', 'P3')->first();
        $this->assertSame(['no_price', 'no_barcode', 'no_brand', 'no_stock'], $p->zooboxi_gate_reasons);
        Http::assertNotSent(fn ($req) => str_contains($req->url(), 'holeno'));
        $this->assertSame(1, $s['held']);
    }

    public function test_hub_mirror_stock_counts_as_available(): void
    {
        $this->product('P1');
        WarehouseItemStock::create(['item_code' => 'P1', 'warehouse_code' => 'RUH003', 'in_stock' => 7]);

        $this->assertSame(1, $this->gate()->run()['activated']);
    }

    public function test_shipgo_live_atp_counts_when_sap_mirror_is_empty(): void
    {
        config(['services.shipgo.store_key' => 'sk_test']);
        Http::fake([
            'wms.stapo.io/v1/channel/catalog/lookup' => Http::response(['data' => ['results' => [
                ['sku' => '5060122490078', 'matched' => true, 'atp' => 12, 'name' => 'Applaws Tuna 70g', 'image_url' => 'https://gal.holeno.com/imghd/P1.png'],
            ]]], 200),
            'gal.holeno.com/imghd/P1.png' => Http::response('', 200, ['Content-Type' => 'image/png']),
            'gal.holeno.com/*' => Http::response('', 404),
        ]);
        $this->product('P9'); // no SAP stock anywhere; picture only known to ShipGo

        $s = $this->gate()->run();

        $this->assertSame(1, $s['activated']);
        $this->assertSame([self::HEAD_OK], Product::where('item_code', 'P9')->value('zb_resolved_images'));
        Http::assertSent(fn ($req) => str_contains($req->url(), '/v1/channel/catalog/lookup') && $req['skus'] === ['5060122490078']);
    }

    public function test_blocked_products_are_never_evaluated_and_dry_run_writes_nothing(): void
    {
        $blocked = $this->product('P4', ['zooboxi_gate_status' => 'blocked']);
        $this->product('P1');
        WarehouseItemStock::create(['item_code' => 'P1', 'warehouse_code' => 'RUH004', 'in_stock' => 3]);

        $s = $this->gate()->run(dryRun: true);

        $this->assertSame(1, $s['checked']);
        $this->assertSame(1, $s['activated']);
        $this->assertFalse((bool) Product::where('item_code', 'P1')->value('zooboxi_active'));
        $this->assertSame('blocked', $blocked->fresh()->zooboxi_gate_status);
        $this->assertSame(0, DB::table('zooboxi_gate_events')->count());
    }

    public function test_force_skips_only_the_stock_rule(): void
    {
        $this->product('P1');

        $this->assertSame(1, $this->gate()->run(itemCodes: ['P1'], force: true)['activated']);

        $this->product('P2', ['prices' => []]);
        $s = $this->gate()->run(itemCodes: ['P2'], force: true);
        // a product without a price is not worth an image round-trip
        $this->assertSame(['no_price'], $s['items'][0]['reasons']);
    }

    public function test_ai_copy_is_used_when_the_copywriter_answers(): void
    {
        $writer = $this->createMock(CatalogCopywriter::class);
        $writer->method('write')->willReturn([
            'name_ar' => 'ابلاوز تونة فيليه 70 جم', 'name_en' => 'Applaws Tuna Fillet 70g',
            'short_ar' => 'قصير', 'short_en' => 'short', 'desc_ar' => 'طويل', 'desc_en' => 'long',
            'category_path' => 'قطط > طعام رطب', 'keywords' => 'تونة, قطط',
            'seo_title_ar' => 'ابلاوز تونة', 'seo_description_ar' => 'وصف',
        ]);
        $this->app->instance(CatalogCopywriter::class, $writer);
        $this->product('P1');
        WarehouseItemStock::create(['item_code' => 'P1', 'warehouse_code' => 'RUH004', 'in_stock' => 1]);

        $this->gate()->run();

        $p = Product::where('item_code', 'P1')->first();
        $this->assertSame('ai', $p->zb_content_source);
        $this->assertSame('قطط > طعام رطب', $p->zb_categories_ar);
        $this->assertSame('ابلاوز تونة فيليه 70 جم', $p->zb_name_ar);
    }

    public function test_feed_exposes_gate_block_only_for_active_products(): void
    {
        config(['services.woo.api_token' => 'store-token']);
        $this->product('P1', ['zooboxi_active' => true, 'zooboxi_gate_status' => 'active', 'zb_resolved_images' => [self::HEAD_OK], 'zb_content_source' => 'ai']);
        $this->product('P2');

        $res = $this->withHeader('Authorization', 'Bearer store-token')->get('/api/woo/products')->assertOk()->json();

        $this->assertCount(1, $res['data']);
        $this->assertSame('P1', $res['data'][0]['item_code']);
        $this->assertSame([self::HEAD_OK], $res['data'][0]['gate']['pictures']);
        $this->assertSame('ai', $res['data'][0]['gate']['content_source']);
    }
}
