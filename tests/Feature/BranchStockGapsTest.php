<?php

namespace Tests\Feature;

use App\Exceptions\SapException;
use App\Filament\Pages\BranchStockGaps;
use App\Models\BranchGapTransferRequest;
use App\Models\User;
use App\Services\Inventory\BranchGapService;
use App\Services\Inventory\TransferRequestWriter;
use App\Services\SAP\SapClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use Mockery;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * «عجز الفروع»: what sells (showrooms + ShipGo online) but is thin at King Fahd,
 * what An Nasr can spare, and the SAP transfer request raised from it.
 */
class BranchStockGapsTest extends TestCase
{
    use RefreshDatabase;

    private int $doc = 0;

    protected function setUp(): void
    {
        parent::setUp();
        config(['app.env' => 'local']);
        foreach (['Super Admin', 'Stakeholder', 'Operator'] as $role) {
            Role::findOrCreate($role, 'web');
        }

        $cats = [
            'P1' => 'المعايير الصحية > قطط > السمنة,العلامات التجارية > رويال كانين,العلامات التجارية > رويال كانين > قطط,قطط,قطط > طعام,قطط > طعام > الطعام الجاف',
            'P2' => 'كلاب,كلاب > ألعاب',
            'P3' => 'العلامات التجارية > سينيور جاتو,قطط,قطط > رمل القطط,قطط > رمل القطط > قابل للتكتل',
        ];
        foreach (['P1' => 'رويال كانين قطط بالغة', 'P2' => 'صنف بطيء', 'P3' => 'رمل قطط'] as $code => $name) {
            DB::table('products')->insert(['item_code' => $code, 'item_name' => $name, 'piece_barcode' => '62800' . substr($code, 1), 'source' => 'production', 'zb_categories_ar' => $cats[$code]]);
        }

        // P1: Nasr 180, Rabie 90 (9 returned), King Fahd 9 in its 30 days open; ShipGo 900 online.
        $this->sale('P1', 'RUH002', 180, 20);
        $this->sale('P1', 'RUH004', 90, 20);
        $this->credit('P1', 'RUH004', 9, 20);
        $this->sale('P1', 'RUH010', 9, 20, daysAgo: 29);
        $this->sale('P1', 'RUH003', 900, 18, card: 'C0000183', daysAgo: 5);
        $this->sale('P1', 'RUH002', 500, 20, cancelled: true);
        // P2 sells too little to count.
        $this->sale('P2', 'RUH002', 10, 5);
        // P3: sells at Rabie only; Nasr holds 2, the central Starlinks 50.
        $this->sale('P3', 'RUH004', 120, 30);
        // One basket where P3 is the big line and P2 rides along (40 ﷼).
        $id = DB::table('sap_invoices')->insertGetId(['doc_num' => ++$this->doc, 'card_code' => 'C0000001', 'doc_date' => now()->subDays(3)->toDateString(), 'doc_total' => 140, 'cancelled' => 'N']);
        DB::table('sap_invoice_lines')->insert([
            ['sap_invoice_id' => $id, 'item_code' => 'P3', 'warehouse_code' => 'RUH004', 'quantity' => 2, 'line_revenue' => 100],
            ['sap_invoice_id' => $id, 'item_code' => 'P2', 'warehouse_code' => 'RUH004', 'quantity' => 1, 'line_revenue' => 40],
        ]);

        $this->stock('P1', 'RUH010', 5);
        $this->stock('P1', 'RUH002', 120);
        $this->stock('P3', 'RUH002', 2);
        $this->stock('P3', 'STL001', 50);

        // An open SAP request already bringing 6 more P1 (10 asked, 4 delivered).
        $t = DB::table('sap_stock_transfers')->insertGetId([
            'sap_database' => 'PPTC_V5_PROD', 'doc_entry' => 500, 'doc_num' => 2600500, 'from_warehouse' => 'STL001',
            'to_warehouse' => 'RUH010', 'document_status' => 'bost_Open', 'internal_status' => 'New', 'creation_date' => now()->subDays(2),
        ]);
        DB::table('sap_stock_transfer_lines')->insert(['stock_transfer_id' => $t, 'item_code' => 'P1', 'quantity' => 10, 'received_quantity' => 4, 'line_status' => 'bost_Open']);
    }

    private function sale(string $item, string $wh, float $qty, float $price, string $card = 'C0000001', int $daysAgo = 10, bool $cancelled = false): void
    {
        $id = DB::table('sap_invoices')->insertGetId([
            'doc_num' => ++$this->doc, 'card_code' => $card, 'doc_date' => now()->subDays($daysAgo)->toDateString(),
            'doc_total' => $qty * $price, 'cancelled' => $cancelled ? 'Y' : 'N',
        ]);
        DB::table('sap_invoice_lines')->insert(['sap_invoice_id' => $id, 'item_code' => $item, 'warehouse_code' => $wh, 'quantity' => $qty, 'line_revenue' => $qty * $price]);
    }

    private function credit(string $item, string $wh, float $qty, float $price): void
    {
        $id = DB::table('sap_credit_memos')->insertGetId([
            'doc_num' => ++$this->doc, 'card_code' => 'C0000001', 'doc_date' => now()->subDays(8)->toDateString(), 'doc_total' => $qty * $price, 'cancelled' => 'N',
        ]);
        DB::table('sap_credit_memo_lines')->insert(['sap_credit_memo_id' => $id, 'item_code' => $item, 'warehouse_code' => $wh, 'quantity' => $qty, 'line_revenue' => $qty * $price]);
    }

    private function stock(string $item, string $wh, float $qty): void
    {
        DB::table('warehouse_item_stocks')->insert(['item_code' => $item, 'warehouse_code' => $wh, 'in_stock' => $qty, 'committed' => 0, 'ordered' => 0]);
    }

    private function rows(): array
    {
        return collect(app(BranchGapService::class)->analyse()['rows'])->keyBy('code')->all();
    }

    public function test_gap_math_for_king_fahd_from_nasr(): void
    {
        $rows = $this->rows();

        $this->assertSame(['P1', 'P3'], array_keys($rows), 'biggest loss first; slow P2 left out');

        $p1 = $rows['P1'];
        // Riyadh typical branch (Nasr 180 + Rabie 81) / 2 / 90 = 1.45 a day, + 10% of 10 a day online.
        $this->assertEqualsWithDelta(2.45 * 30, $p1['est_month'], 0.1);
        $this->assertSame(35, $p1['goal']);
        $this->assertSame(6.0, $p1['coming']);
        $this->assertSame(24, $p1['gap']);
        // Nasr keeps 30 days of its own 2 a day: 120 − 60 = 60 spare.
        $this->assertSame(60, $p1['source_spare']);
        $this->assertSame(24, $p1['suggest']);
        $this->assertSame('full', $p1['status']);
        $this->assertSame(3, $p1['branches']);

        $p3 = $rows['P3'];
        $this->assertTrue($p3['out']);
        $this->assertSame(10, $p3['gap']);
        $this->assertSame(0, $p3['source_spare'], 'Nasr keeps its 3-piece shelf');
        $this->assertSame('none', $p3['status']);
        $this->assertSame(['STL001', 50], [$p3['alt']['code'], $p3['alt']['spare']]);
    }

    public function test_lost_sales_and_basket_effect(): void
    {
        $rows = $this->rows();

        // P1 lasts (5 + 6) / 2.45 = 4.5 days → 25.5 of the next 30 empty × 2.45 × 20 ﷼.
        $this->assertSame(26, $rows['P1']['lost_days']);
        $this->assertSame(1250, $rows['P1']['lost_value']);
        $this->assertSame(0, $rows['P1']['halo_value'], 'always bought alone');

        // P3 is out all month: 122/2/90 a day × 30 × 30.33 ﷼.
        $p3 = $rows['P3'];
        $this->assertSame(30, $p3['lost_days']);
        $this->assertSame(617, $p3['lost_value']);
        // Anchor on both its invoices; 40 ﷼ rides along per 2 invoices, 61 pcs per invoice.
        $this->assertSame(100, $p3['anchor_pct']);
        $this->assertSame(7, $p3['halo_value']);

        $totals = app(BranchGapService::class)->analyse()['totals'];
        $this->assertSame([1867, 7], [$totals['lost_value'], $totals['halo_value']]);
    }

    public function test_shipgo_keeps_its_online_pace(): void
    {
        // ShipGo sells 10 a day online: of 320 it keeps 30 days (300), spares 20.
        $this->stock('P1', 'RUH003', 320);

        $p1 = app(BranchGapService::class)->analyse(['source' => 'RUH003']);
        $this->assertSame(20, collect($p1['rows'])->firstWhere('code', 'P1')['source_spare']);
    }

    private function sap(?callable $post = null): SapClient
    {
        $sap = Mockery::mock(SapClient::class);
        $sap->shouldReceive('setCompanyDb')->with('PPTC_V5_PROD');
        $sap->shouldReceive('getCompanyDb')->andReturn('PPTC_V5_PROD');
        $sap->shouldReceive('get')->with('Items', Mockery::any())->andReturn(['value' => [
            ['ItemCode' => 'P1', 'InventoryUoMEntry' => 58, 'UoMGroupEntry' => 3, 'InventoryItem' => 'tYES'],
        ]]);
        $sap->shouldReceive('get')->with('InventoryTransferRequests', Mockery::any())->andReturn(['value' => []]);
        $sap->shouldReceive('post')->andReturnUsing($post ?? fn () => ['DocEntry' => 777, 'DocNum' => 2609999]);

        return $sap;
    }

    public function test_request_is_posted_to_sap_in_pieces_and_counts_as_on_the_way(): void
    {
        $sent = null;
        $writer = new TransferRequestWriter($this->sap(function ($resource, $payload) use (&$sent) {
            $sent = [$resource, $payload];

            return ['DocEntry' => 777, 'DocNum' => 2609999];
        }));

        $req = $writer->create('RUH002', 'RUH010', [['item_code' => 'P1', 'quantity' => 24]], null, 'عاجل');

        $this->assertSame(BranchGapTransferRequest::STATUS_POSTED, $req->status);
        $this->assertSame(2609999, $req->doc_num);
        $this->assertSame('InventoryTransferRequests', $sent[0]);
        $this->assertSame(['RUH002', 'RUH010', $req->reference], [$sent[1]['FromWarehouse'], $sent[1]['ToWarehouse'], $sent[1]['JournalMemo']]);
        $this->assertSame([[
            'ItemCode' => 'P1', 'Quantity' => 24, 'FromWarehouseCode' => 'RUH002', 'WarehouseCode' => 'RUH010', 'UoMEntry' => 58,
        ]], $sent[1]['StockTransferLines']);

        app(BranchGapService::class)->forget();
        $this->assertArrayNotHasKey('P1', $this->rows(), 'the 24 on the way close the gap before the sync mirrors them');
    }

    public function test_sap_refusal_is_recorded_not_posted(): void
    {
        $writer = new TransferRequestWriter($this->sap(fn () => throw new SapException('Item not active', 400)));

        $req = $writer->create('RUH002', 'RUH010', [['item_code' => 'P1', 'quantity' => 5]]);

        $this->assertSame(BranchGapTransferRequest::STATUS_FAILED, $req->status);
        $this->assertSame('Item not active', $req->error);
        $this->assertNull($req->doc_num);
    }

    public function test_never_asks_for_more_than_the_source_holds(): void
    {
        $sap = Mockery::mock(SapClient::class);
        $sap->shouldReceive('setCompanyDb');
        $sap->shouldNotReceive('post');

        $this->expectException(\InvalidArgumentException::class);
        (new TransferRequestWriter($sap))->create('RUH002', 'RUH010', [['item_code' => 'P1', 'quantity' => 121]]);
    }

    public function test_category_paths_become_pet_department_brand(): void
    {
        $this->assertSame(
            ['pets' => ['قطط'], 'depts' => ['قطط › طعام'], 'brand' => 'رويال كانين'],
            BranchGapService::categories('المعايير الصحية > قطط > السمنة,العلامات التجارية > رويال كانين,العلامات التجارية > رويال كانين > قطط,قطط,قطط > طعام,قطط > طعام > الطعام الجاف'),
        );
    }

    public function test_focus_filters_rank_and_recount(): void
    {
        $page = Livewire::actingAs($this->user('Super Admin'))->test(BranchStockGaps::class);

        $b = $page->set('pet', 'قطط')->instance()->board();
        $this->assertSame(['قطط' => 2], $b['facets']['pets']);
        $this->assertSame(['قطط › طعام' => 1, 'قطط › رمل القطط' => 1], $b['facets']['depts']);
        $this->assertSame(['P1', 'P3'], array_column($b['rows'], 'code'));
        $this->assertSame([1, 2], array_column($b['rows'], 'rank'));
        $this->assertSame(100, end($b['rows'])['cum']);

        $b = $page->set('dept', 'قطط › رمل القطط')->instance()->board();
        $this->assertSame(['P3'], array_column($b['rows'], 'code'));
        $this->assertSame(1, $b['totals']['items'], 'the cards count the focused set');

        // P1 alone is 67% of the loss: «80%» still needs P3; «top 50» of one dept is that dept.
        $b = $page->set('dept', '')->set('top', 'p80')->instance()->board();
        $this->assertSame(['P1', 'P3'], array_column($b['rows'], 'code'));
        $b = $page->set('brand', 'سينيور جاتو')->instance()->board();
        $this->assertSame(['P3'], array_column($b['rows'], 'code'));
    }

    public function test_excel_export_follows_the_filters(): void
    {
        $page = Livewire::actingAs($this->user('Super Admin'))->test(BranchStockGaps::class)->set('pet', 'قطط');
        $page->call('export')->assertFileDownloaded();

        $path = \App\Services\Inventory\BranchGapExport::write($page->instance()->board(everything: true), ['pet' => 'قطط']);
        $reader = new \OpenSpout\Reader\XLSX\Reader();
        $reader->open($path);
        $sheets = [];
        foreach ($reader->getSheetIterator() as $sheet) {
            foreach ($sheet->getRowIterator() as $row) {
                $sheets[$sheet->getName()][] = $row->toArray();
            }
        }
        $reader->close();
        @unlink($path);

        $this->assertSame(['العجز', 'للتحويل'], array_keys($sheets));
        $header = array_search('#', array_column($sheets['العجز'], 0), true);
        $list = array_slice($sheets['العجز'], $header + 1);
        $this->assertSame(['P1', 'P3'], array_column($list, 1));
        $this->assertSame('قطط', $list[0][4]);
        $this->assertSame('طعام', $list[0][5]);
        $this->assertSame(24, (int) $list[0][19], 'suggested qty');
        // Only P1 can come from Nasr: one line + total.
        $this->assertSame([['P1', '628001', 'رويال كانين قطط بالغة', 24, 24], ['الإجمالي', '', '', 24, '']], array_map(fn ($r) => array_map(fn ($v) => is_float($v) ? (int) $v : $v, $r), array_slice($sheets['للتحويل'], array_search('كود الصنف', array_column($sheets['للتحويل'], 0), true) + 1)));
    }

    private function user(string $role): User
    {
        $user = User::create(['name' => $role, 'email' => str_replace(' ', '', $role) . '@example.test', 'password' => bcrypt('x')]);
        $user->assignRole($role);

        return $user;
    }

    private function as(User $user): static
    {
        return $this->withSession([auth()->guard('web')->getName() => $user->getAuthIdentifier()]);
    }

    public function test_owner_sees_the_gaps_and_can_request(): void
    {
        $this->as($this->user('Super Admin'))->get('/admin/stock-gaps')->assertOk()
            ->assertSee('Branch gaps')->assertSee('رمل قطط')->assertSee('Request transfer');
    }

    public function test_stakeholder_reads_but_cannot_request(): void
    {
        $viewer = $this->user('Stakeholder');
        $this->as($viewer)->get('/admin/stock-gaps')->assertOk()->assertSee('رمل قطط')->assertDontSee('Request transfer');
        Livewire::actingAs($viewer)->test(BranchStockGaps::class)
            ->call('requestTransfer', [['item_code' => 'P1', 'quantity' => 1]])->assertForbidden();
        $this->assertSame(0, BranchGapTransferRequest::count());
    }

    public function test_owner_requests_from_the_page(): void
    {
        $this->app->instance(TransferRequestWriter::class, new TransferRequestWriter($this->sap()));

        Livewire::actingAs($this->user('Super Admin'))->test(BranchStockGaps::class)
            ->call('requestTransfer', [['item_code' => 'P1', 'quantity' => 24]], 'عاجل')
            ->assertSet('result.ok', true)
            ->assertSet('result.docs', [2609999])
            ->assertDispatched('gaps-requested');

        $this->assertSame(1, BranchGapTransferRequest::where('status', 'posted')->count());
    }

    public function test_operator_has_no_access(): void
    {
        $this->as($this->user('Operator'))->get('/admin/stock-gaps')->assertForbidden();
    }
}
