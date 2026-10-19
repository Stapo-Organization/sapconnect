<?php

namespace Tests\Feature;

use App\Models\StockTransfer;
use App\Services\SAP\SapClient;
use App\Services\StockTransferService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

/**
 * SAP keeps a request's UpdateDate when a stock transfer delivers part of it or
 * closes it, so the incremental pull never saw either: the app showed nothing
 * received and closed requests stayed «New».
 */
class StockTransferReconcileTest extends TestCase
{
    use RefreshDatabase;

    private function transfer(int $de): StockTransfer
    {
        $t = StockTransfer::create([
            'sap_database' => 'PPTC_V5_PROD', 'doc_entry' => $de, 'doc_num' => 2600000 + $de,
            'from_warehouse' => 'RUH002', 'to_warehouse' => 'RUH010', 'document_status' => 'bost_Open',
            'internal_status' => 'New', 'update_date' => '2026-07-23',
        ]);
        $t->lines()->create(['item_code' => 'P1', 'quantity' => 15, 'received_quantity' => 0, 'sent_quantity' => 0, 'actual_received_quantity' => 0]);
        return $t;
    }

    private function row(int $de, string $status, float $remaining): array
    {
        return [
            'DocEntry' => $de, 'DocNum' => 2600000 + $de, 'DocumentStatus' => $status, 'FromWarehouse' => 'RUH002', 'ToWarehouse' => 'RUH010',
            'DocDate' => '2026-07-23', 'UpdateDate' => '2026-07-23',
            'StockTransferLines' => [['ItemCode' => 'P1', 'Quantity' => 15, 'RemainingOpenQuantity' => $remaining, 'LineStatus' => $status]],
        ];
    }

    private function reconcile(SapClient $sap): int
    {
        $svc = new StockTransferService($sap);
        return (new \ReflectionMethod($svc, 'reconcileClosed'))->invoke($svc, 'PPTC_V5_PROD');
    }

    public function test_partial_delivery_shows_and_closing_completes(): void
    {
        $this->transfer(1);
        $this->transfer(2);
        $sap = Mockery::mock(SapClient::class);
        $sap->shouldReceive('get')->once()->andReturn(['value' => [
            $this->row(1, 'bost_Open', 3),  // 12 of 15 delivered, still open
            $this->row(2, 'bost_Close', 0), // fully delivered, closed
        ]]);

        $this->assertSame(1, $this->reconcile($sap));

        $open = StockTransfer::where('doc_entry', 1)->first();
        $this->assertSame(['bost_Open', 'New'], [$open->document_status, $open->internal_status]);
        $this->assertEquals(12, $open->sapDelivered());
        $this->assertTrue($open->canReceive(), 'the branch can confirm what SAP delivered');

        $closed = StockTransfer::where('doc_entry', 2)->first();
        $this->assertSame(['bost_Close', 'Completed'], [$closed->document_status, $closed->internal_status]);
    }

    public function test_nothing_delivered_cannot_be_received(): void
    {
        $t = $this->transfer(3);
        $this->assertFalse($t->canReceive());
    }

    public function test_direct_stock_transfer_waits_for_the_branch_to_receive(): void
    {
        \App\Models\User::create(['name' => 'kf', 'email' => 'kf@example.test', 'password' => bcrypt('x'), 'warehouse_code' => ['RUH010']]);
        $this->transfer(10); // a request with the same DocEntry must not clash
        $sap = Mockery::mock(SapClient::class);
        $sap->shouldReceive('get')->with('StockTransfers', Mockery::on(fn ($p) => $p['$skip'] === 0))->andReturn(['value' => [
            ['DocEntry' => 10, 'ToWarehouse' => 'RUH010'],
            ['DocEntry' => 11, 'ToWarehouse' => 'RUH010'],
            ['DocEntry' => 12, 'ToWarehouse' => 'JED002'], // nobody on the app there
        ]]);
        $sap->shouldReceive('get')->with('StockTransfers', Mockery::on(fn ($p) => $p['$skip'] > 0))->andReturn(['value' => []]);
        $sap->shouldReceive('get')->with('StockTransfers(10)', [])->once()->andReturn([
            'DocEntry' => 10, 'DocNum' => 2603855, 'DocDate' => '2026-10-18', 'FromWarehouse' => 'RUH002', 'ToWarehouse' => 'RUH010',
            'DocumentStatus' => 'bost_Open', 'JournalMemo' => 'من النصر',
            'StockTransferLines' => [
                ['ItemCode' => 'P1', 'Quantity' => 5, 'InventoryQuantity' => 120, 'BaseType' => 'Default'],
                ['ItemCode' => 'P2', 'Quantity' => 3, 'InventoryQuantity' => 3, 'BaseType' => 'Default'],
                ['ItemCode' => 'P2', 'Quantity' => 2, 'InventoryQuantity' => 2, 'BaseType' => 'Default'],
            ],
        ]);
        $sap->shouldReceive('get')->with('StockTransfers(11)', [])->once()->andReturn([
            'DocEntry' => 11, 'StockTransferLines' => [['ItemCode' => 'P1', 'Quantity' => 1, 'BaseType' => 'InventoryTransferRequest', 'BaseEntry' => 9]],
        ]);
        $sap->shouldNotReceive('get')->with('StockTransfers(12)', []);

        $svc = new StockTransferService($sap);
        $run = fn () => (new \ReflectionMethod($svc, 'importDirectTransfers'))->invoke($svc, 'PPTC_V5_PROD');
        $this->assertSame(1, $run());
        $this->assertSame(0, $run(), 'a second pass adds nothing and does not re-read the request-based one');

        $t = StockTransfer::where('doc_type', StockTransfer::TYPE_TRANSFER)->with('lines')->sole();
        $this->assertSame([10, 'Shipped', 'من النصر'], [$t->doc_entry, $t->internal_status, $t->sender_notes]);
        $this->assertEquals(['P1' => 120, 'P2' => 5], $t->lines->pluck('quantity', 'item_code')->all());
        $this->assertEquals(125, $t->lines->sum('sent_quantity'));
        $this->assertTrue($t->isDirect() && $t->canReceive() && ! $t->canSend());
        $this->assertSame(1, StockTransfer::where('doc_entry', 10)->where('doc_type', 'request')->count());
    }
}
