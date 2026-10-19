<?php

namespace App\Http\Controllers;

use App\Filament\Resources\MuntajatInvoiceResource;
use App\Filament\Resources\ShipGoInvoiceResource;
use App\Services\ShipGo\TaxInvoicePdf;
use Illuminate\Http\Request;

/**
 * GET /admin/shipgo/invoices/{docEntry}/pdf[?format=html]
 * GET /admin/muntajat/invoices/{docEntry}/pdf[?format=html]
 * Streams a Saudi tax-invoice PDF built from SAP + its ZATCA e-invoice (read-only).
 */
class InvoicePdfController extends Controller
{
    public const COMPANIES = [
        'shipgo'   => ShipGoInvoiceResource::class,
        'muntajat' => MuntajatInvoiceResource::class,
    ];

    public function __invoke(Request $request, int $docEntry, TaxInvoicePdf $pdf)
    {
        $resource = self::COMPANIES[$request->route('company', 'shipgo')] ?? abort(404);
        abort_unless($resource::canViewAny(), 403);

        // Only invoices present in the mirror (respects the per-company exclusions).
        $row = $resource::getModel()::where('doc_entry', $docEntry)->firstOrFail();
        $sap = $resource::sapService();

        @set_time_limit(300);
        @ini_set('memory_limit', '1024M');

        try {
            if ($request->query('format') === 'html') {
                return response($pdf->html($pdf->data($sap, $row->doc_entry)));
            }
            $out = $pdf->render($sap, $row->doc_entry);
        } catch (\App\Exceptions\SapException $e) {
            return response()->view('shipgo.statement-error', [
                'customer' => (object) ['card_code' => $row->card_code, 'card_name' => $row->card_name . ' — فاتورة ' . $row->doc_num],
                'db'       => $sap->companyDb(),
                'title'    => 'تعذّر إنشاء الفاتورة',
                'message'  => $e->getMessage(),
            ], 502);
        }

        return response($out['pdf'], 200, [
            'Content-Type'        => 'application/pdf',
            'Content-Disposition' => 'inline; filename="' . $out['filename'] . '"',
            'Cache-Control'       => 'no-store',
        ]);
    }
}
