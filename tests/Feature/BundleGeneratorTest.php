<?php

namespace Tests\Feature;

use App\Models\ProductBundle;
use App\Models\User;
use App\Models\WarehouseItemStock;
use App\Models\ZooboxiWarehouse;
use App\Services\Marketing\BundleGenerator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class BundleGeneratorTest extends TestCase
{
    use RefreshDatabase;

    private function seedWorld(): void
    {
        // Warehouses: one express branch, one central.
        ZooboxiWarehouse::create([
            'warehouse_code' => 'RUH004', 'display_name_ar' => 'فرع الربيع', 'city' => 'الرياض',
            'latitude' => 24.8, 'longitude' => 46.6, 'express_radius_km' => 10,
            'is_central' => false, 'is_main_hub' => false, 'is_active' => true,
            'sap_warehouse_codes' => ['RUH004'],
        ]);
        ZooboxiWarehouse::create([
            'warehouse_code' => 'RUH003', 'display_name_ar' => 'المستودع المركزي', 'city' => 'الرياض',
            'latitude' => 24.7, 'longitude' => 46.7, 'express_radius_km' => 0,
            'is_central' => true, 'is_main_hub' => true, 'is_active' => true,
            'sap_warehouse_codes' => ['RUH003'],
        ]);

        $products = [
            // Fast wet cat food — stacking + variety material (same brand B01).
            ['W1', 'تونا بالمرق طعام رطب للقطط 85غ', 'B01', 12.0, 6.0, 'healthy', 8.0, 90],
            ['W2', 'دجاج بالمرق طعام رطب للقطط 85غ', 'B01', 12.0, 6.0, 'healthy', 7.0, 90],
            ['W3', 'سلمون بالجيلي طعام رطب للقطط 85غ', 'B01', 13.0, 6.5, 'healthy', 6.0, 90],
            // Fast dry cat bag — anchor for companion/smart_gift.
            ['D1', 'طعام جاف للقطط البالغة بالدجاج 7.5 كيلو', 'B02', 260.0, 150.0, 'healthy', 3.0, 60],
            // FBT partner (healthy treat).
            ['T1', 'مكافآت كريمية للقطط بالتونا', 'B03', 20.0, 9.0, 'healthy', 2.0, 120],
            // Overstock litter — smart_gift fodder.
            ['G1', 'رمل قطط متكتل برائحة اللافندر 10 لتر', 'B04', 45.0, 20.0, 'overstock', 0.2, 400],
            // A dog item that must never mix into cat bundles.
            ['X1', 'طعام جاف للكلاب البالغة 12 كيلو', 'B05', 300.0, 180.0, 'healthy', 2.0, 60],
        ];

        foreach ($products as [$code, $name, $brand, $retail, $cost, $health, $velocity, $cover]) {
            DB::table('products')->insert([
                'item_code' => $code, 'item_name' => $name, 'zb_name_ar' => $name,
                'piece_barcode' => 'BC' . $code, 'items_group_code' => $brand,
                'source' => 'production', 'created_at' => now(), 'updated_at' => now(),
            ]);
            DB::table('product_intelligence')->insert([
                'item_code' => $code, 'warehouse_code' => '',
                'velocity_blended' => $velocity, 'health_status' => $health,
                'days_of_cover' => $cover, 'unit_retail_sar' => $retail, 'unit_cost_sar' => $cost,
                'excess_units' => $health === 'overstock' ? 500 : 0,
                'capital_at_risk_sar' => $health === 'overstock' ? 10000 : 0,
                'current_stock' => 1000, 'created_at' => now(), 'updated_at' => now(),
            ]);
            // Express branch holds everything except the dog food; central holds all.
            if ($code !== 'X1') {
                WarehouseItemStock::create(['item_code' => $code, 'warehouse_code' => 'RUH004', 'in_stock' => 500]);
            }
            WarehouseItemStock::create(['item_code' => $code, 'warehouse_code' => 'RUH003', 'in_stock' => 2000]);
        }

        DB::table('product_associations')->insert([
            'item_code_a' => 'D1', 'item_code_b' => 'T1', 'rule_type' => 'fbt',
            'co_count' => 40, 'support' => 0.01, 'confidence' => 0.4, 'lift' => 6.5, 'score' => 6.5,
        ]);
    }

    public function test_generates_all_four_templates_with_safe_prices(): void
    {
        $this->seedWorld();

        $result = app(BundleGenerator::class)->generate(5);

        $this->assertGreaterThanOrEqual(1, $result['by_template']['stacking']);
        $this->assertGreaterThanOrEqual(1, $result['by_template']['variety']);
        $this->assertGreaterThanOrEqual(1, $result['by_template']['companion']);
        $this->assertGreaterThanOrEqual(1, $result['by_template']['smart_gift']);

        foreach (ProductBundle::with('items')->get() as $b) {
            // The two hard channel-safety rules.
            $this->assertGreaterThanOrEqual($b->floor_price - 0.01, $b->bundle_price, "floor: {$b->name_ar}");
            $cap = $b->template === 'smart_gift' ? BundleGenerator::CAP_GIFT : BundleGenerator::CAP_HEALTHY;
            $this->assertLessThanOrEqual($cap + 0.02, $b->savings_pct, "cap: {$b->name_ar}");

            // Species purity: no dog item rides in a cat bundle.
            $this->assertSame('cat', $b->species, $b->name_ar);
            $this->assertFalse($b->items->pluck('item_code')->contains('X1'));

            // Stock class computed from the map: everything here fits the express branch.
            $this->assertSame('express', $b->stock_class);
            $this->assertContains('RUH004', $b->warehouse_scope);
        }
    }

    public function test_variety_bundle_takes_same_brand_flavours(): void
    {
        $this->seedWorld();
        app(BundleGenerator::class)->generate(5);

        $variety = ProductBundle::with('items')->where('template', 'variety')->first();
        $this->assertNotNull($variety);
        $this->assertEqualsCanonicalizing(['W1', 'W2', 'W3'], $variety->items->pluck('item_code')->all());
        $this->assertEqualsWithDelta(20.0, $variety->savings_pct, 0.1);
    }

    public function test_smart_gift_uses_overstock_and_respects_gift_cap(): void
    {
        $this->seedWorld();
        app(BundleGenerator::class)->generate(5);

        $gift = ProductBundle::with('items')->where('template', 'smart_gift')->first();
        $this->assertNotNull($gift);
        $giftLine = $gift->items->firstWhere('role', 'gift');
        $this->assertSame('G1', $giftLine->item_code);
        // Customer pays the anchor's retail; the gift is the whole saving.
        $this->assertEqualsWithDelta(260.0, $gift->bundle_price, 0.01);
        $this->assertLessThanOrEqual(BundleGenerator::CAP_GIFT + 0.02, $gift->savings_pct);
    }

    public function test_rerun_is_idempotent(): void
    {
        $this->seedWorld();
        $g = app(BundleGenerator::class);
        $g->generate(5);
        $first = ProductBundle::count();

        $again = app(BundleGenerator::class)->generate(5);
        $this->assertSame(0, $again['created']);
        $this->assertSame($first, ProductBundle::count());
    }

    public function test_no_viable_warehouse_drops_the_candidate(): void
    {
        $this->seedWorld();
        // Starve every warehouse of W1 → its stacking bundle must not appear.
        WarehouseItemStock::where('item_code', 'W1')->update(['in_stock' => 1]);

        app(BundleGenerator::class)->generate(5);

        $this->assertSame(
            0,
            ProductBundle::where('template', 'stacking')->where('anchor_item_code', 'W1')->count()
        );
    }

    public function test_approve_reguards_edited_price(): void
    {
        $this->seedWorld();
        app(BundleGenerator::class)->generate(5);
        $bundle = ProductBundle::where('template', 'stacking')->firstOrFail();

        $owner = User::create([
            'name' => 'المالك', 'email' => 'owner@example.test', 'password' => bcrypt('secret'),
        ]);
        $owner->assignRole(\Spatie\Permission\Models\Role::findOrCreate('Super Admin', 'web'));

        // A price under the cost floor is refused.
        $this->actingAs($owner)
            ->postJson("/api/bundles/{$bundle->id}/approve", ['bundle_price' => 1.0])
            ->assertStatus(422);

        // The suggested price goes through and the bundle becomes approved.
        $this->actingAs($owner)
            ->postJson("/api/bundles/{$bundle->id}/approve")
            ->assertOk()
            ->assertJsonPath('bundle.status', 'approved');

        // …and now shows in the store feed.
        $this->assertSame(1, ProductBundle::where('status', 'approved')->count());
    }
}
