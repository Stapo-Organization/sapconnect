<?php

namespace Tests\Feature;

use App\Models\ShipGoCustomer;
use App\Models\User;
use App\Support\PanelAccess;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * The Accountant role sees ShipGo Customers and nothing else in the panel.
 */
class AccountantPanelAccessTest extends TestCase
{
    use RefreshDatabase;

    private User $accountant;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.env' => 'local']);

        Role::findOrCreate('Accountant', 'web');
        Role::findOrCreate('Operator', 'web');
        $this->accountant = User::create(['name' => 'Acc', 'email' => 'acc@example.test', 'password' => bcrypt('x')]);
        $this->accountant->assignRole('Accountant');

        ShipGoCustomer::create(['card_code' => 'SG0001', 'card_name' => 'عميل', 'currency' => 'SAR']);
        \App\Models\MuntajatCustomer::create(['card_code' => 'MC0001', 'card_name' => 'عميل منتجات', 'currency' => 'SAR']);
    }

    public function test_migration_seeded_role_and_first_user(): void
    {
        $u = User::where('email', 'e.hasan@ppte.sa')->first();
        $this->assertNotNull($u);
        $this->assertTrue($u->hasRole('Accountant'));
        $this->assertTrue(Hash::check('12345678', $u->password));
        $this->assertTrue(PanelAccess::isLimited($u));
    }

    public function test_accountant_can_open_shipgo_customers_with_a_minimal_sidebar(): void
    {
        // Session-based login (like a browser), NOT actingAs: the panel boots before the
        // session middleware, so the sidebar swap must not rely on an early auth()->user().
        $this->withSession([auth()->guard('web')->getName() => $this->accountant->getAuthIdentifier()])
            ->get('/admin/ship-go-customers')
            ->assertOk()
            ->assertSee('SG0001')
            ->assertDontSee('Supply Chain')
            ->assertDontSee('SAP Management')
            ->assertDontSee('Master Data')
            ->assertSee('muntajat-customers');     // second allowed section in the sidebar
    }

    public function test_accountant_can_open_muntajat_customers(): void
    {
        $this->withSession([auth()->guard('web')->getName() => $this->accountant->getAuthIdentifier()])
            ->get('/admin/muntajat-customers')
            ->assertOk()
            ->assertSee('MC0001')
            ->assertSee('ship-go-customers')
            ->assertDontSee('SAP Management');
        $this->assertNull(PanelAccess::gate($this->accountant, 'viewAny', [\App\Models\MuntajatCustomer::class]));
    }

    public function test_accountant_is_redirected_away_from_everything_else(): void
    {
        $home = '/admin/ship-go-customers';
        foreach (['/admin', '/admin/customers', '/admin/users', '/admin/container-tracking', '/admin/zid-orders', '/admin/shipments'] as $url) {
            $this->actingAs($this->accountant)->get($url)->assertRedirect($home);
        }
        // profile stays reachable
        $this->actingAs($this->accountant)->get('/admin/profile')->assertOk();
    }

    public function test_gate_denies_other_models_but_allows_shipgo_customer(): void
    {
        $this->actingAs($this->accountant);
        // Gate::before: null = fall through to policies (allowed model), false = denied.
        $this->assertNull(PanelAccess::gate($this->accountant, 'viewAny', [ShipGoCustomer::class]));
        $this->assertFalse(PanelAccess::gate($this->accountant, 'viewAny', [\App\Models\Customer::class]));
        $this->assertFalse(PanelAccess::gate($this->accountant, 'viewAny', [User::class]));
        $this->assertFalse($this->accountant->can('viewAny', \App\Models\Customer::class));
        $this->assertFalse($this->accountant->can('viewAny', User::class));
        // Filament's own check (what the panel uses) admits the ShipGo resource only.
        $this->assertTrue(\App\Filament\Resources\ShipGoCustomerResource::canViewAny());
        $this->assertFalse(\App\Filament\Resources\CustomerResource::canViewAny());
    }

    public function test_mixed_roles_are_not_limited(): void
    {
        $this->accountant->assignRole('Operator');
        $this->assertFalse(PanelAccess::isLimited($this->accountant->fresh()));
    }
}
