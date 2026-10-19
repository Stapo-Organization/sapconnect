<?php

namespace App\Http\Controllers;

use App\Filament\Resources\MuntajatCustomerResource;
use App\Filament\Resources\ShipGoCustomerResource;
use App\Services\ShipGo\CustomerStatementPdf;
use App\Services\ShipGo\StatementTooLargeException;
use Carbon\Carbon;
use Illuminate\Http\Request;

/**
 * GET /admin/shipgo/customers/{cardCode}/statement?from=&to=[&format=html]
 * GET /admin/muntajat/customers/{cardCode}/statement?from=&to=[&format=html]
 * Streams the customer's account statement as an inline PDF (read-only SAP).
 */
class ShipGoStatementController extends Controller
{
    /** route default `company` => Filament resource that owns it */
    public const COMPANIES = [
        'shipgo'   => ShipGoCustomerResource::class,
        'muntajat' => MuntajatCustomerResource::class,
    ];

    public function __invoke(Request $request, string $cardCode, CustomerStatementPdf $pdf)
    {
        $resource = self::COMPANIES[$request->route('company', 'shipgo')] ?? abort(404);
        abort_unless($resource::canViewAny(), 403);

        $data = $request->validate([
            'from'   => ['required', 'date'],
            'to'     => ['required', 'date', 'after_or_equal:from'],
            'format' => ['nullable', 'in:pdf,html'],
        ]);

        $sap      = $resource::sapService();
        $customer = $resource::getModel()::where('card_code', $cardCode)->firstOrFail();
        $from     = Carbon::parse($data['from'])->startOfDay();
        $to       = Carbon::parse($data['to'])->startOfDay();

        try {
            @set_time_limit(300);
            @ini_set('memory_limit', '1024M');

            if (($data['format'] ?? 'pdf') === 'html') {
                $statement = $sap->statement($customer->card_code, $from, $to);
                return response($pdf->html($customer, $from, $to, $statement, $sap->brand()));
            }

            $out = $pdf->render($customer, $from, $to, $sap);
        } catch (StatementTooLargeException $e) {
            return response()->view('shipgo.statement-error', [
                'customer' => $customer,
                'db'       => $sap->companyDb(),
                'title'    => 'الفترة المختارة كبيرة جداً',
                'hint'     => "الكشف يحتوي {$e->lines} حركة والحد {$e->max}. اختر فترة أقصر.",
                'message'  => null,
            ], 422);
        } catch (\App\Exceptions\SapException $e) {
            return response()->view('shipgo.statement-error', [
                'customer' => $customer,
                'db'       => $sap->companyDb(),
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
