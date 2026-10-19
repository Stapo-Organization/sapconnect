<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\Branch\BranchInsightsService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Collection;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * Admin «الفروع»: the branch ranking and one branch's detail page. The
 * insights service runs MariaDB SQL, so it is replaced by a fixed fake here.
 */
class AdminBranchesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.env' => 'local']);
        foreach (['Super Admin', 'Stakeholder', 'Operator'] as $role) {
            Role::findOrCreate($role, 'web');
        }
        $this->app->bind(BranchInsightsService::class, fn () => new class extends BranchInsightsService {
            public function __construct() {}

            public function exhibitions(): Collection
            {
                return collect(['RUH004' => (object) ['warehouse_code' => 'RUH004', 'warehouse_name' => 'الربيع · الرياض'],
                    'JED002' => (object) ['warehouse_code' => 'JED002', 'warehouse_name' => 'جدة']]);
            }

            public function revenueByWarehouse(Carbon $start, Carbon $end): array
            {
                return ['RUH004' => ['gross' => 1100.0, 'returns' => 100.0, 'net' => 1000.0, 'invoices' => 10],
                    'JED002' => ['gross' => 3000.0, 'returns' => 0.0, 'net' => 3000.0, 'invoices' => 20]];
            }

            public function actualProfitByWarehouse(Carbon $start, Carbon $end): array
            {
                return ['RUH004' => ['profit' => 300.0, 'margin_pct' => 30.0, 'estimated' => false],
                    'JED002' => ['profit' => 900.0, 'margin_pct' => 30.0, 'estimated' => false]];
            }

            public function pulseRow(string $warehouseCode): ?object
            {
                return null;
            }

            public function opsCounts(string $warehouseCode): array
            {
                return ['quality_pending' => 1, 'counting_active' => 0, 'transfers_new' => 2, 'zooboxi_pending' => 0, 'zooboxi_urgent' => 0];
            }

            public function salesProfitTrend(Carbon $start, Carbon $end, string $granularity, ?string $warehouseCode = null, string $channel = 'retail'): array
            {
                return ['granularity' => 'day', 'points' => [['label' => $start->toDateString(), 'sales' => 10.0, 'profit' => 3.0]]];
            }

            public function topProducts(string $warehouseCode, Carbon $start, Carbon $end, int $limit = 10): array
            {
                return [['item_code' => 'P1', 'name' => 'صنف تجريبي', 'image_url' => 'https://x.test/p.png', 'units' => 5.0]];
            }

            public function bleedingItems(string $warehouseCode, int $limit = 6): array
            {
                return [];
            }

            public function trappedItems(string $warehouseCode, int $limit = 6): array
            {
                return [];
            }
        });
    }

    private function as(string $role): static
    {
        $user = User::create(['name' => $role, 'email' => str_replace(' ', '', $role) . '@example.test', 'password' => bcrypt('x')]);
        $user->assignRole($role);

        return $this->withSession([auth()->guard('web')->getName() => $user->getAuthIdentifier()]);
    }

    public function test_ranking_lists_every_branch_best_first(): void
    {
        $this->as('Super Admin')->get('/admin/branches')
            ->assertOk()
            ->assertSeeInOrder(['جدة', 'الربيع · الرياض'])
            ->assertSee('4,000'); // network net sales
    }

    public function test_branch_page_shows_the_branch_against_the_network(): void
    {
        $this->as('Stakeholder')->get('/admin/branches/RUH004?period=week')
            ->assertOk()
            ->assertSee('الربيع · الرياض')
            ->assertSee('صنف تجريبي')
            ->assertSee('25%'); // 1000 of 4000
    }

    public function test_unknown_branch_is_a_404(): void
    {
        $this->as('Super Admin')->get('/admin/branches/NOPE01')->assertNotFound();
    }

    public function test_operators_cannot_open_branch_finances(): void
    {
        $this->as('Operator')->get('/admin/branches')->assertForbidden();
    }
}
