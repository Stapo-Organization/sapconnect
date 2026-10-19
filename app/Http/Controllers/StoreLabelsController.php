<?php

namespace App\Http\Controllers;

use App\Models\InventoryCounting;
use App\Models\StoreLocation;
use App\Services\Counting\FullCountService;
use Illuminate\Http\Request;
use Mpdf\Mpdf;

/**
 * Signed, short-lived downloads for the full count (links minted by the API):
 *  - shelf labels as a PDF (A4 sheet of 3×8 70×37mm labels, or one 70×30mm
 *    label per page (62×29mm, Brother DK-11209) for a thermal label printer);
 *  - the approved count as a CSV for the accountant to post in SAP.
 */
class StoreLabelsController extends Controller
{
    private const STRIPE = [
        'gondola' => '#0B7D57', 'wall' => '#4F46E5', 'endcap' => '#B45309',
        'cashier' => '#13141D', 'backroom' => '#C2410C', 'other' => '#585C6C',
    ];

    public function labels(Request $request, string $wh)
    {
        $q = StoreLocation::where('warehouse_code', $wh)->orderBy('sort')->orderBy('code');
        if ($request->filled('unit')) {
            $q->where('unit_code', $request->unit);
        }
        $locs = $q->get();
        abort_if($locs->isEmpty(), 404, 'No locations');
        // thermal = 70 × 30 mm roll (Zebra ZD421 and most 4" label printers);
        // thermal62 = Brother DK-11209 (62 × 29 mm).
        $format = (string) $request->input('format', 'a4');
        $thermal = in_array($format, ['thermal', 'thermal62'], true);
        [$tw, $th] = $format === 'thermal62' ? [62, 29] : [70, 30];

        // Every label is drawn with absolutely positioned blocks (mm): mPDF
        // shrinks nested tables, which broke the A4 grid.
        $label = function (StoreLocation $l, float $x, float $y, float $h, float $w = 70) {
            $stripe = self::STRIPE[$l->kind] ?? '#585C6C';
            $name = e(trim(($l->name ?? '') . ' · الرف ' . $l->shelf_no, ' ·'));
            $qr = e($l->qrPayload());
            $qrSize = $h >= 35 ? 0.80 : 0.68;
            $qrMm = $qrSize * 27;
            $qrTop = $y + ($h - $qrMm) / 2;
            $textTop = $y + ($h >= 35 ? 6.5 : 4.5);
            return '<div style="position:absolute;left:' . $x . 'mm;top:' . $y . 'mm;width:3mm;height:' . $h . 'mm;background:' . $stripe . '"></div>'
                . '<div style="position:absolute;left:' . ($x + 5.5) . 'mm;top:' . $textTop . 'mm;width:' . ($w - $qrMm - 9) . 'mm">'
                . '<div class="code">' . e($l->code) . '</div>'
                . '<div class="name">' . $name . '</div>'
                . '<div class="foot">' . e($l->warehouse_code) . ' · ' . $qr . '</div></div>'
                . '<div style="position:absolute;left:' . ($x + $w - $qrMm - 2) . 'mm;top:' . $qrTop . 'mm;width:' . ($qrMm + 1) . 'mm">'
                . '<barcode code="' . $qr . '" type="QR" size="' . $qrSize . '" error="M" disableborder="1" /></div>';
        };

        $css = <<<CSS
body{font-family:tajawal;margin:0}
.code{font-family:dejavusansmono;font-weight:bold;font-size:22pt;line-height:1}
.name{font-size:8pt;color:#585C6C;margin-top:1.2mm}
.foot{font-family:dejavusansmono;font-size:5.5pt;color:#9CA0AE;margin-top:1.5mm}
CSS;

        $tmp = storage_path('app/mpdf');
        if (! is_dir($tmp)) {
            @mkdir($tmp, 0775, true);
        }
        $mpdf = new Mpdf([
            'mode' => 'utf-8',
            'format' => $thermal ? [$tw, $th] : 'A4',
            'margin_top' => 0, 'margin_bottom' => 0, 'margin_left' => 0, 'margin_right' => 0,
            'margin_header' => 0, 'margin_footer' => 0,
            'tempDir' => $tmp,
            'default_font' => 'tajawal',
            'fontDir' => array_merge((new \Mpdf\Config\ConfigVariables())->getDefaults()['fontDir'], [resource_path('fonts/tajawal')]),
            'fontdata' => (new \Mpdf\Config\FontVariables())->getDefaults()['fontdata'] + [
                'tajawal' => ['R' => 'Tajawal-Regular.ttf', 'B' => 'Tajawal-Bold.ttf', 'useOTL' => 0xFF],
            ],
        ]);
        $mpdf->autoScriptToLang = true;
        $mpdf->autoLangToFont = true;
        $mpdf->SetTitle("Shelf labels {$wh}");
        $mpdf->WriteHTML($css, \Mpdf\HTMLParserMode::HEADER_CSS);

        if ($thermal) {
            foreach ($locs->values() as $i => $l) {
                if ($i > 0) {
                    $mpdf->AddPage();
                }
                $mpdf->WriteHTML($label($l, 0, 0, $th, $tw), \Mpdf\HTMLParserMode::HTML_BODY);
            }
        } else {
            // A4: 3 columns × 8 rows of 70 × 37 mm (24 labels per sheet), or
            // a4x30: 3 × 10 of 70 × 29.7 mm (the common 30-up sticker sheet).
            [$perPage, $rowH] = $format === 'a4x30' ? [30, 29.7] : [24, 37];
            foreach ($locs->values()->chunk($perPage) as $p => $page) {
                if ($p > 0) {
                    $mpdf->AddPage();
                }
                $html = '';
                foreach ($page->values() as $i => $l) {
                    $html .= $label($l, ($i % 3) * 70, intdiv($i, 3) * $rowH, $rowH);
                }
                $mpdf->WriteHTML($html, \Mpdf\HTMLParserMode::HTML_BODY);
            }
        }

        $pdf = $mpdf->Output('', \Mpdf\Output\Destination::STRING_RETURN);
        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="labels-' . $wh . '.pdf"',
        ]);
    }

    public function export(Request $request, int $id, FullCountService $svc)
    {
        $c = InventoryCounting::where('counting_type', InventoryCounting::TYPE_FULL)->findOrFail($id);
        if ($request->query('kind') === 'expiry') {
            return $this->exportExpiry($c, $svc);
        }
        $res = $svc->result($c);
        $out = fopen('php://temp', 'w+');
        fwrite($out, "\xEF\xBB\xBF");
        fputcsv($out, ['ItemCode', 'ItemName', 'Barcode', 'WarehouseCode', 'SystemQty', 'CountedQty', 'Variance', 'UnitCost', 'VarianceValue']);
        foreach ($res['rows'] as $r) {
            fputcsv($out, [
                $r['item_code'], $r['item_name'], $r['piece_barcode'], $c->warehouse_code,
                $r['system_qty'], $r['counted_qty'], $r['variance'], $r['unit_cost'], $r['variance_value'],
            ]);
        }
        rewind($out);
        $csv = stream_get_contents($out);
        $name = 'full-count-' . $c->warehouse_code . '-' . $c->id . '.csv';
        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="' . $name . '"',
        ]);
    }

    /** Every date the counters read, one row per item × date, nearest first. */
    private function exportExpiry(InventoryCounting $c, FullCountService $svc)
    {
        $res = $svc->expiry($c, true);
        $out = fopen('php://temp', 'w+');
        fwrite($out, "\xEF\xBB\xBF");
        fputcsv($out, ['ItemCode', 'ItemName', 'ItemNameAr', 'Barcode', 'WarehouseCode', 'Shelves', 'ExpiryDate', 'DaysLeft', 'Bucket', 'Qty', 'Value', 'InSapBatches', 'SapBatchDates']);
        foreach ($res['rows'] as $r) {
            fputcsv($out, [
                $r['item_code'], $r['item_name'], $r['item_name_ar'], $r['piece_barcode'], $c->warehouse_code,
                implode(' ', $r['locations']), $r['date'], $r['days'], $r['bucket'] ?? '', $r['qty'], $r['value'],
                $r['in_sap'] === null ? '' : ($r['in_sap'] ? 'yes' : 'no'), implode(' ', $r['sap_dates']),
            ]);
        }
        rewind($out);
        $csv = stream_get_contents($out);
        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="full-count-expiry-' . $c->warehouse_code . '-' . $c->id . '.csv"',
        ]);
    }
}
