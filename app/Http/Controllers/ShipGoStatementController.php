<?php

namespace App\Http\Controllers;

use App\Filament\Resources\ShipGoCustomerResource;
use App\Models\ShipGoCustomer;
use App\Services\ShipGo\CustomerStatementPdf;
use Carbon\Carbon;
use Illuminate\Http\Request;

/**
 * GET /admin/shipgo/customers/{cardCode}/statement?from=&to=[&format=html]
 * Streams the customer's account statement as an inline PDF (read-only SAP).
 */
class ShipGoStatementController extends Controller
{
    public function __invoke(Request $request, string $cardCode, CustomerStatementPdf $pdf)
    {
        abort_unless(ShipGoCustomerResource::canViewAny(), 403);

        $data = $request->validate([
            'from'   => ['required', 'date'],
            'to'     => ['required', 'date', 'after_or_equal:from'],
            'format' => ['nullable', 'in:pdf,html'],
        ]);

        $customer = ShipGoCustomer::where('card_code', $cardCode)->firstOrFail();
        $from     = Carbon::parse($data['from'])->startOfDay();
        $to       = Carbon::parse($data['to'])->startOfDay();

        try {
            if (($data['format'] ?? 'pdf') === 'html') {
                $statement = app(\App\Services\ShipGo\ShipGoSapService::class)->statement($customer->card_code, $from, $to);
                return response($pdf->html($customer, $from, $to, $statement));
            }

            @set_time_limit(180);
            $out = $pdf->render($customer, $from, $to);
        } catch (\App\Exceptions\SapException $e) {
            return response()->view('shipgo.statement-error', ['message' => $e->getMessage(), 'customer' => $customer], 502);
        }

        return response($out['pdf'], 200, [
            'Content-Type'        => 'application/pdf',
            'Content-Disposition' => 'inline; filename="' . $out['filename'] . '"',
            'Cache-Control'       => 'no-store',
        ]);
    }
}
