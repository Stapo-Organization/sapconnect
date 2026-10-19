<?php

namespace Tests\Feature;

use App\Filament\Resources\WarehouseItemStockResource\Pages\ListWarehouseItemStocks;
use App\Models\User;
use App\Models\WarehouseItemStock;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/** Admin «مخزون المستودعات»: the search finds an item by its barcode too. */
class WarehouseStockSearchTest extends TestCase
{
    use RefreshDatabase;

    public function test_search_by_code_name_and_any_barcode(): void
    {
        Role::findOrCreate('Super Admin', 'web');
        $user = User::create(['name' => 'Owner', 'email' => 'owner@example.test', 'password' => bcrypt('x')]);
        $user->assignRole('Super Admin');

        DB::table('products')->insert([
            ['item_code' => 'P12600061', 'item_name' => 'كت كات تونا 80غ', 'piece_barcode' => '6281100123456', 'source' => 'production'],
            ['item_code' => 'P14600002', 'item_name' => 'سينيور غاتو رمل', 'piece_barcode' => '8410650151234', 'source' => 'production'],
        ]);
        // A carton barcode, and a 12-digit UPC SAP stores with its leading zero.
        DB::table('product_barcodes')->insert([
            ['item_code' => 'P12600061', 'barcode' => '16281100123453', 'barcode_norm' => '16281100123453', 'kind' => 'carton', 'source' => 'sap'],
            ['item_code' => 'P14600002', 'barcode' => '0012345678905', 'barcode_norm' => '12345678905', 'kind' => 'piece', 'source' => 'sap'],
        ]);
        $kitkat = WarehouseItemStock::create(['item_code' => 'P12600061', 'warehouse_code' => 'RUH010', 'in_stock' => 31]);
        $litter = WarehouseItemStock::create(['item_code' => 'P14600002', 'warehouse_code' => 'RUH010', 'in_stock' => 4]);

        $page = Livewire::actingAs($user)->test(ListWarehouseItemStocks::class);

        $page->searchTable('6281100123456')->assertCanSeeTableRecords([$kitkat])->assertCanNotSeeTableRecords([$litter]);
        $page->searchTable('16281100123453')->assertCanSeeTableRecords([$kitkat])->assertCanNotSeeTableRecords([$litter]);
        $page->searchTable('012345678905')->assertCanSeeTableRecords([$litter])->assertCanNotSeeTableRecords([$kitkat]);
        $page->searchTable('سينيور')->assertCanSeeTableRecords([$litter])->assertCanNotSeeTableRecords([$kitkat]);
        $page->searchTable('P12600061')->assertCanSeeTableRecords([$kitkat])->assertCanNotSeeTableRecords([$litter]);
    }
}
