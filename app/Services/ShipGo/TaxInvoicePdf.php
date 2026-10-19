<?php

namespace App\Services\ShipGo;

/**
 * Renders a SAP A/R invoice as a Saudi tax-invoice PDF in the company's
 * brand (ShipGo / Muntajat). Read-only: one Service Layer GET per print.
 */
class TaxInvoicePdf
{
    public function __construct(private CustomerStatementPdf $pdf) {}

    public function data(ShipGoSapService $sap, int $docEntry): array
    {
        $doc = $sap->fetchInvoice($docEntry);
        return (new TaxInvoiceBuilder($sap))->build($doc);
    }

    public function html(array $invoice): string
    {
        return view('shipgo.invoice', ['inv' => $invoice, 'generated' => now()])->render();
    }

    /** @return array{pdf:string, filename:string, invoice:array} */
    public function render(ShipGoSapService $sap, int $docEntry): array
    {
        $invoice = $this->data($sap, $docEntry);
        $html    = $this->html($invoice);
        $footer  = $invoice['title_ar'] . ' ' . $invoice['number'] . '|صفحة {PAGENO} من {nbpg}|' . ($invoice['brand']['company_name'] ?? '');

        return [
            'pdf'      => $this->pdf->toPdf($html, $invoice['title_ar'] . ' ' . $invoice['number'], $footer),
            'filename' => 'invoice-' . preg_replace('/[^A-Za-z0-9_-]/', '', $invoice['number']) . '.pdf',
            'invoice'  => $invoice,
        ];
    }
}
