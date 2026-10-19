<?php

namespace Tests\Feature;

use App\Models\InventoryCounting;
use App\Models\InventoryCountingSnapshot;
use App\Models\Product;
use App\Models\StoreLocation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * Full count, the team rules learned on RUH010's count #22: one open unit per
 * counter, the owner hands units around and alone approves or cancels, and a
 * recount stays open until its counter closes it.
 */
class FullCountTeamFlowTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;
    private User $roumi;
    private User $branch;
    private User $robin;
    private User $arif;
    private InventoryCounting $c;

    protected function setUp(): void
    {
        parent::setUp();
        $perms = collect(['view', 'create', 'complete'])->map(fn ($a) => Permission::findOrCreate("app.inventory_counting.$a", 'web'));
        Role::findOrCreate('Super Admin', 'web')->givePermissionTo($perms);
        Role::findOrCreate('Branch Manager', 'web')->givePermissionTo($perms);
        Role::findOrCreate('showroom', 'web')->givePermissionTo($perms[0]);

        $mk = fn ($name, $role, $wh) => tap(User::create(['name' => $name, 'email' => "$name@example.test", 'password' => bcrypt('x'), 'warehouse_code' => $wh]))->assignRole($role);
        $this->owner = $mk('owner', 'Super Admin', []);
        config(['counting.managers' => ['owner@example.test']]);
        $this->roumi = $mk('roumi', 'Super Admin', []);
        $this->branch = $mk('branch', 'Branch Manager', ['RUH010']);
        $this->robin = $mk('robin', 'showroom', ['RUH010']);
        $this->arif = $mk('arif', 'showroom', ['RUH010']);

        foreach (['G01', 'G02'] as $u) {
            foreach ([1, 2] as $n) {
                StoreLocation::create(['warehouse_code' => 'RUH010', 'code' => "$u-R$n", 'unit_code' => $u, 'kind' => 'G', 'shelf_no' => $n, 'sort' => $n]);
            }
        }
        Product::forceCreate(['item_code' => 'P1', 'item_name' => 'Cat food', 'piece_barcode' => '111', 'source' => 'production']);
        $this->c = InventoryCounting::create([
            'warehouse_code' => 'RUH010', 'status' => 'in_progress', 'counting_type' => 'full', 'phase' => 'counting',
            'snapshot_status' => 'ready', 'started_at' => now(),
        ]);
        InventoryCountingSnapshot::create(['inventory_counting_id' => $this->c->id, 'item_code' => 'P1', 'system_qty' => 20]);
    }

    private function url(string $p): string
    {
        return "/api/full-counts/{$this->c->id}/$p";
    }

    public function test_one_open_unit_per_counter(): void
    {
        $this->actingAs($this->robin)->postJson($this->url('units/G01/claim'))->assertOk();
        $this->actingAs($this->robin)->postJson($this->url('units/G02/claim'))->assertStatus(409);
        $this->actingAs($this->robin)->postJson($this->url('units/G02/claim'), ['close_previous' => true])->assertOk();
        $a = $this->c->fresh()->unit_assignments;
        $this->assertSame('done', $a['G01']['status']);
        $this->assertSame('counting', $a['G02']['status']);

        // Counting a shelf of a unit you do not hold is refused.
        $this->actingAs($this->robin)->postJson($this->url('count'), ['item_code' => 'P1', 'location_code' => 'G01-R1', 'quantity' => 3, 'unit_code' => 'G02'])->assertStatus(422);
        $this->actingAs($this->robin)->postJson($this->url('count'), ['item_code' => 'P1', 'location_code' => 'G02-R1', 'quantity' => 3, 'unit_code' => 'G02'])->assertCreated();
    }

    public function test_only_the_owner_moves_units_approves_and_cancels(): void
    {
        $this->actingAs($this->robin)->postJson($this->url('units/G01/claim'))->assertOk();
        $this->actingAs($this->arif)->postJson($this->url('units/G01/release'))->assertStatus(403);
        $this->actingAs($this->branch)->postJson($this->url('units/G01/assign'), ['user_id' => $this->arif->id])->assertStatus(403);

        $this->actingAs($this->owner)->getJson($this->url('board'))->assertJsonPath('can_manage', true)->assertJsonCount(3, 'team');
        $this->actingAs($this->branch)->getJson($this->url('board'))->assertJsonPath('can_manage', false);
        // Another Super Admin is not the owner.
        $this->actingAs($this->roumi)->getJson($this->url('board'))->assertJsonPath('can_manage', false);
        $this->actingAs($this->roumi)->postJson($this->url('cancel'))->assertStatus(403);

        $this->actingAs($this->owner)->postJson($this->url('units/G01/assign'), ['user_id' => $this->arif->id])->assertOk();
        $this->assertSame($this->arif->id, $this->c->fresh()->unit_assignments['G01']['user_id']);
        // robin no longer holds it.
        $this->actingAs($this->robin)->postJson($this->url('count'), ['item_code' => 'P1', 'location_code' => 'G01-R1', 'quantity' => 1, 'unit_code' => 'G01'])->assertStatus(409);

        $this->actingAs($this->branch)->postJson($this->url('cancel'))->assertStatus(403);
        $this->actingAs($this->branch)->postJson($this->url('approve'))->assertStatus(403);
        $this->actingAs($this->owner)->postJson($this->url('cancel'))->assertOk();
    }

    public function test_a_recount_stays_open_until_closed(): void
    {
        // Round 1: 10 against a book of 20 → recount.
        $this->actingAs($this->robin)->postJson($this->url('count'), ['item_code' => 'P1', 'location_code' => 'G01-R1', 'quantity' => 6])->assertCreated();
        $this->actingAs($this->robin)->postJson($this->url('count'), ['item_code' => 'P1', 'location_code' => 'G02-R1', 'quantity' => 4])->assertCreated();
        $q = $this->actingAs($this->arif)->getJson($this->url('recount-queue'))->json('data');
        $this->assertSame(2, $q[0]['round']);

        // arif counts one shelf (by mistake 10) and leaves: the item stays his, open.
        $line = $this->actingAs($this->arif)->postJson($this->url('count'), ['item_code' => 'P1', 'location_code' => 'G01-R1', 'quantity' => 10, 'count_round' => 2, 'keep_open' => true])->json('data');
        $q = $this->actingAs($this->arif)->getJson($this->url('recount-queue'))->json('data');
        $this->assertTrue($q[0]['in_progress']);
        $this->assertTrue($q[0]['yours']);
        $this->assertSame(1, $this->actingAs($this->owner)->getJson($this->url('board'))->json('queues.recount'));
        // Nobody else can step into his recount.
        $this->actingAs($this->owner)->postJson($this->url('count'), ['item_code' => 'P1', 'quantity' => 1, 'count_round' => 2, 'keep_open' => true])->assertStatus(409);

        // He fixes the wrong line and counts the second shelf, then closes.
        $this->assertCount(1, $this->actingAs($this->arif)->getJson($this->url('my-lines') . '?item=P1&round=2')->json('data'));
        $this->actingAs($this->arif)->deleteJson($this->url('lines/' . $line['id']))->assertOk();
        $this->assertEmpty($this->c->fresh()->recount_progress);
        $this->actingAs($this->arif)->postJson($this->url('count'), ['item_code' => 'P1', 'location_code' => 'G01-R1', 'quantity' => 6, 'count_round' => 2, 'keep_open' => true])->assertCreated();
        $this->actingAs($this->arif)->postJson($this->url('count'), ['item_code' => 'P1', 'location_code' => 'G02-R1', 'quantity' => 4, 'count_round' => 2, 'keep_open' => true])->assertCreated();
        $this->actingAs($this->owner)->postJson($this->url('approve'))->assertStatus(422);
        $this->actingAs($this->arif)->postJson($this->url('recount/P1/close'))->assertOk();

        // 10 = round 1 → settled.
        $this->assertSame([], $this->actingAs($this->arif)->getJson($this->url('recount-queue'))->json('data'));
        $this->assertSame(0, $this->actingAs($this->owner)->getJson($this->url('board'))->json('queues.recount'));
    }
}
