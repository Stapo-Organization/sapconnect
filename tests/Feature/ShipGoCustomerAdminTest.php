<?php

namespace Tests\Feature;

use App\Models\ShipGoCustomer;
use App\Models\User;
use App\Services\ShipGo\ShipGoSapService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * Admin screens for ShipGo customers + the statement PDF route, with SAP faked.
 */
class ShipGoCustomerAdminTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private ShipGoCustomer $customer;

    protected function setUp(): void
    {
        parent::setUp();

        // Filament only admits users that do not implement FilamentUser in the local env.
        config(['app.env' => 'local']);

        Role::findOrCreate('Super Admin', 'web');
        $this->admin = User::create([
            'name'     => 'Admin',
            'email'    => 'admin@example.test',
            'password' => bcrypt('secret'),
        ]);
        $this->admin->assignRole('Super Admin');

        $this->customer = ShipGoCustomer::create([
            'card_code' => 'SG0001',
            'card_name' => 'عميل شيب جو التجريبي',
            'currency'  => 'SAR',
            'current_account_balance' => 1250.5,
            'synced_at' => now(),
        ]);

        // Fake SAP: a service whose statement() never touches the network.
        $this->app->instance(ShipGoSapService::class, new class extends ShipGoSapService {
            public function statement(string $cardCode, Carbon $from, Carbon $to): array
            {
                return $this->buildStatement('ledger', [
                    ['date' => '2026-01-10', 'trans_id' => 1, 'trans_type' => '13', 'ref_no' => 'INV-9', 'memo' => 'فاتورة', 'debit' => 1250.5, 'credit' => 0.0],
                ], $from);
            }
        });
    }

    public function test_list_and_view_pages_render_under_shipgo_group(): void
    {
        $this->actingAs($this->admin)
            ->get('/admin/ship-go-customers')
            ->assertOk()
            ->assertSee('SG0001')
            ->assertSee('عميل شيب جو التجريبي');

        $this->actingAs($this->admin)
            ->get('/admin/ship-go-customers/' . $this->customer->id)
            ->assertOk()
            ->assertSee('SG0001');
    }

    public function test_statement_pdf_route_streams_pdf(): void
    {
        $res = $this->actingAs($this->admin)
            ->get(route('shipgo.customers.statement', ['cardCode' => 'SG0001', 'from' => '2026-01-01', 'to' => '2026-09-22']));

        $res->assertOk();
        $this->assertSame('application/pdf', $res->headers->get('Content-Type'));
        $this->assertStringContainsString('statement-SG0001-20260101-20260922.pdf', $res->headers->get('Content-Disposition'));
        $this->assertStringStartsWith('%PDF', $res->getContent());
    }

    public function test_statement_html_preview_shows_running_balance(): void
    {
        $this->actingAs($this->admin)
            ->get(route('shipgo.customers.statement', ['cardCode' => 'SG0001', 'from' => '2026-01-01', 'to' => '2026-09-22', 'format' => 'html']))
            ->assertOk()
            ->assertSee('كشف حساب')
            ->assertSee('1,250.50');
    }

    public function test_statement_requires_login_and_valid_dates(): void
    {
        $this->get(route('shipgo.customers.statement', ['cardCode' => 'SG0001', 'from' => '2026-01-01', 'to' => '2026-09-22']))
            ->assertRedirect();

        $this->actingAs($this->admin)
            ->get(route('shipgo.customers.statement', ['cardCode' => 'SG0001', 'from' => '2026-09-22', 'to' => '2026-01-01']))
            ->assertSessionHasErrors('to');
    }
}
