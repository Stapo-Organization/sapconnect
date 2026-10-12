<?php

namespace Tests\Feature;

use App\Models\ShipGoCustomer;
use App\Services\ShipGo\CustomerStatementPdf;
use App\Services\ShipGo\ShipGoSapService;
use Carbon\Carbon;
use Tests\TestCase;

/**
 * Pure-logic coverage of the ShipGo customer statement (no SAP calls).
 */
class ShipGoStatementTest extends TestCase
{
    private function rows(): array
    {
        return [
            ['date' => '2025-12-20', 'trans_id' => 10, 'trans_type' => '13', 'ref_no' => 'INV-1', 'memo' => null, 'debit' => 1000.0, 'credit' => 0.0],
            ['date' => '2025-12-28', 'trans_id' => 11, 'trans_type' => '24', 'ref_no' => 'PAY-1', 'memo' => null, 'debit' => 0.0, 'credit' => 400.0],
            ['date' => '2026-02-05', 'trans_id' => 13, 'trans_type' => '13', 'ref_no' => 'INV-2', 'memo' => 'فاتورة', 'debit' => 408.25, 'credit' => 0.0],
            ['date' => '2026-01-28', 'trans_id' => 12, 'trans_type' => '24', 'ref_no' => 'PAY-2', 'memo' => null, 'debit' => 0.0, 'credit' => 408.25],
        ];
    }

    public function test_opening_balance_and_running_balance(): void
    {
        $svc = new ShipGoSapService();
        $st  = $svc->buildStatement('ledger', $this->rows(), Carbon::parse('2026-01-01'));

        $this->assertSame('ledger', $st['source']);
        $this->assertSame(600.0, $st['opening']);            // 1000 - 400 before the period
        $this->assertCount(2, $st['lines']);
        $this->assertSame('2026-01-28', $st['lines'][0]['date']); // sorted oldest first
        $this->assertSame(191.75, $st['lines'][0]['balance']);
        $this->assertSame(600.0, $st['lines'][1]['balance']);
        $this->assertSame(408.25, $st['debit']);
        $this->assertSame(408.25, $st['credit']);
        $this->assertSame(600.0, $st['closing']);
        $this->assertSame('دفعة واردة', $st['lines'][0]['type_label']);
    }

    public function test_zero_balance_is_never_negative_zero(): void
    {
        $svc = new ShipGoSapService();
        $st  = $svc->buildStatement('ledger', [
            ['date' => '2026-01-05', 'trans_id' => 1, 'trans_type' => '24', 'ref_no' => null, 'memo' => null, 'debit' => 0.0, 'credit' => 0.1],
            ['date' => '2026-01-06', 'trans_id' => 2, 'trans_type' => '13', 'ref_no' => null, 'memo' => null, 'debit' => 0.1, 'credit' => 0.0],
        ], Carbon::parse('2026-01-01'));

        $this->assertSame('0.00', number_format($st['closing'], 2));
        $this->assertSame('0.00', number_format($st['opening'], 2));
    }

    public function test_pdf_renders_arabic_statement(): void
    {
        $customer = new ShipGoCustomer([
            'card_code' => 'C0001', 'card_name' => 'شركة الاختبار', 'currency' => 'SAR', 'current_account_balance' => 600,
        ]);
        $svc = new ShipGoSapService();
        $st  = $svc->buildStatement('documents', $this->rows(), Carbon::parse('2026-01-01'));

        $pdf  = app(CustomerStatementPdf::class);
        $html = $pdf->html($customer, Carbon::parse('2026-01-01'), Carbon::parse('2026-09-22'), $st);
        $this->assertStringContainsString('كشف حساب', $html);
        $this->assertStringContainsString('لا يشمل قيود اليومية', $html); // documents-mode note

        $bytes = $pdf->toPdf($html);
        $this->assertStringStartsWith('%PDF', $bytes);
        $this->assertGreaterThan(5000, strlen($bytes));
    }
}
