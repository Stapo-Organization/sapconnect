<?php

namespace App\Services\ShipGo;

use App\Models\ShipGoCustomer;
use Carbon\Carbon;
use Mpdf\Mpdf;

/**
 * Renders a customer account statement (كشف حساب) as an A4 RTL PDF.
 */
class CustomerStatementPdf
{
    public function __construct(private ShipGoSapService $sap) {}

    /**
     * @return array{pdf:string, filename:string, statement:array}
     */
    public function render(ShipGoCustomer $customer, Carbon $from, Carbon $to, ?ShipGoSapService $sap = null): array
    {
        $sap       = $sap ?? $this->sap;
        $statement = $sap->statement($customer->card_code, $from, $to);
        $html      = $this->html($customer, $from, $to, $statement, $sap->brand());

        return [
            'pdf'       => $this->toPdf($html),
            'filename'  => $this->filename($customer, $from, $to),
            'statement' => $statement,
        ];
    }

    public function html(ShipGoCustomer $customer, Carbon $from, Carbon $to, array $statement, ?array $brand = null): string
    {
        $brand = $brand ?? $this->sap->brand();
        return view('shipgo.statement', [
            'customer'  => $customer,
            'from'      => $from,
            'to'        => $to,
            'statement' => $statement,
            'company'   => $brand,
            'generated' => now(),
        ])->render();
    }

    public function filename(ShipGoCustomer $customer, Carbon $from, Carbon $to): string
    {
        $code = preg_replace('/[^A-Za-z0-9_-]/', '', $customer->card_code);
        return "statement-{$code}-{$from->format('Ymd')}-{$to->format('Ymd')}.pdf";
    }

    public function toPdf(string $html, string $title = 'كشف حساب', string $footer = '{PAGENO} / {nbpg}'): string
    {
        // Large statements (1000+ lines) need more than the default 128M.
        if ((int) ini_get('memory_limit') > 0 && (int) ini_get('memory_limit') < 1024) {
            @ini_set('memory_limit', '1024M');
        }
        @set_time_limit(300);

        $tmp = storage_path('app/mpdf');
        if (!is_dir($tmp)) {
            @mkdir($tmp, 0775, true);
        }

        $mpdf = new Mpdf([
            'mode'              => 'utf-8',
            'format'            => 'A4',
            'margin_top'        => 12,
            'margin_bottom'     => 14,
            'margin_left'       => 10,
            'margin_right'      => 10,
            'tempDir'           => $tmp,
            'default_font'      => 'tajawal',
            'default_font_size' => 9,
            'fontDir'           => array_merge(
                (new \Mpdf\Config\ConfigVariables())->getDefaults()['fontDir'],
                [resource_path('fonts/tajawal')]
            ),
            'fontdata'          => (new \Mpdf\Config\FontVariables())->getDefaults()['fontdata'] + [
                'tajawal' => [
                    'R'          => 'Tajawal-Regular.ttf',
                    'B'          => 'Tajawal-Bold.ttf',
                    'useOTL'     => 0xFF,
                    'useKashida' => 75,
                ],
            ],
        ]);

        $mpdf->SetDirectionality('ltr');
        $mpdf->autoScriptToLang = true;
        $mpdf->autoLangToFont   = true;
        $mpdf->SetTitle($title);
        $mpdf->SetFooter($footer);
        $mpdf->WriteHTML($html);

        return $mpdf->Output('', \Mpdf\Output\Destination::STRING_RETURN);
    }
}
