<?php

namespace App\Services\Inventory;

use OpenSpout\Common\Entity\Row;
use OpenSpout\Common\Entity\Style\Style;
use OpenSpout\Writer\AutoFilter;
use OpenSpout\Writer\XLSX\Writer;

/**
 * «عجز الفروع» as Excel: sheet 1 is the filtered list with every figure,
 * sheet 2 only what can be transferred (code, barcode, name, qty) for SAP.
 */
class BranchGapExport
{
    /**
     * @param  array  $board  BranchStockGaps::board(everything: true)
     * @param  array  $f  the page filters, printed on top of the sheet
     * @return string absolute path of the written temp file
     */
    public static function write(array $board, array $f): string
    {
        $label = fn (string $c) => BranchGapService::warehouseLabel($c);
        $P = $board['params'];
        $T = $board['totals'];
        $tgt = $label($P['target']);
        $src = $label($P['source']);

        $title = (new Style())->setFontBold()->setFontSize(14);
        $head = (new Style())->setFontBold()->setFontColor('FFFFFF')->setBackgroundColor('303030')->setShouldWrapText();
        $bold = (new Style())->setFontBold();
        $muted = (new Style())->setFontColor('616161');

        $path = tempnam(sys_get_temp_dir(), 'gaps') . '.xlsx';
        $w = new Writer();
        $w->openToFile($path);

        // ── Sheet 1: the list ──
        $sheet = $w->getCurrentSheet();
        $sheet->setName('العجز');

        $focus = array_filter([
            match ($f['top'] ?? 'all') { '50' => 'أهم 50', '100' => 'أهم 100', '200' => 'أهم 200', 'p80' => '80% من الخسارة', default => null },
            ($f['pet'] ?? '') ?: null,
            ($f['dept'] ?? '') ? \Illuminate\Support\Str::after($f['dept'], ' › ') : null,
            ($f['brand'] ?? '') ?: null,
            match ($f['tab'] ?? 'all') { 'out' => 'نافد تماماً', 'transfer' => 'قابل للتحويل', 'none' => 'بدون فائض في المصدر', default => null },
            ($f['q'] ?? '') !== '' ? 'بحث: ' . $f['q'] : null,
        ]);

        $w->addRow(Row::fromValues(["عجز الفروع — {$tgt}، التحويل من {$src}"], $title));
        $w->addRow(Row::fromValues([
            'الفلتر: ' . ($focus ? implode(' · ', $focus) : 'الكل')
            . " · فترة المبيعات {$P['window']} يوم · يغطي {$P['cover']} يوم · يبقى في المصدر {$P['keep']} يوم · نصيب الأونلاين {$P['online_share']}% · يبيع من {$P['min_monthly']} حبة/شهر",
        ], $muted));
        $w->addRow(Row::fromValues([
            'أُنشئ ' . now()->format('Y-m-d H:i') . ' · بيانات شيب قو حتى ' . ($board['online_until'] ?? '—') . ' · المبالغ بالريال بدون ضريبة · أثر الفاتورة تقديري',
        ], $muted));
        $w->addRow(Row::fromValues([
            "أصناف: {$T['items']}", "نافدة: {$T['out']}", "قابلة للتحويل: {$T['transferable']} ({$T['transfer_pcs']} حبة)",
            "ضائع شهرياً: " . number_format($T['lost_value']), "أثر الفاتورة: " . number_format($T['halo_value']),
        ], $bold));
        $w->addRow(Row::fromValues(['']));

        $cols = [
            ['#', 6], ['كود الصنف', 12], ['الباركود', 16], ['اسم المنتج', 44], ['الحيوان', 10], ['القسم', 18], ['العلامة التجارية', 16],
            ['نافد', 7], ['يبيع في المعارض/شهر', 11], ['أونلاين/شهر', 10], ['عدد الفروع', 8], ["متوقع في {$tgt}/شهر", 12],
            ["مخزون {$tgt}", 10], ['بالطريق', 9], ['يكفي (يوم)', 9], ['الهدف', 8], ['العجز', 8],
            ["مخزون {$src}", 10], ["فائض {$src}", 10], ['المقترح للتحويل', 11], ['مصدر بديل', 18], ['فائض البديل', 10],
            ['سعر الحبة', 9], ['أيام بدون مخزون', 9], ['ضائع ريال/شهر', 11], ['أثر الفاتورة ريال/شهر (تقديري)', 13], ['الصنف الأغلى في % من فواتيره', 11], ['% تراكمي من الخسارة', 10],
        ];
        foreach ($cols as $i => [, $width]) {
            $sheet->setColumnWidth($width, $i + 1);
        }
        $w->addRow(Row::fromValues(array_column($cols, 0), $head));
        $headerRow = 6;

        foreach ($board['rows'] as $r) {
            $pet = ($f['pet'] ?? '') ?: ($r['pets'][0] ?? '');
            $dept = collect($r['depts'])->first(fn ($d) => $pet === '' || str_starts_with($d, $pet . ' › '));
            $w->addRow(Row::fromValues([
                $r['rank'] ?? '', $r['code'], (string) ($r['barcode'] ?? ''), $r['name'], $pet,
                $dept ? \Illuminate\Support\Str::after($dept, ' › ') : '', $r['brand'] ?? '',
                $r['out'] ? 'نعم' : '', $r['show_month'], $r['online_month'], $r['branches'], $r['est_month'],
                $r['on_hand'], $r['coming'], $r['out'] ? 0 : ($r['cover_days'] ?? ''), $r['goal'], $r['gap'],
                $r['source_on_hand'], $r['source_spare'], $r['suggest'], $r['alt']['name'] ?? '', $r['alt']['spare'] ?? '',
                $r['price'], $r['lost_days'], $r['lost_value'], $r['halo_value'], $r['anchor_pct'], $r['cum'] ?? '',
            ]));
        }
        $last = $headerRow + count($board['rows']);
        if ($board['rows']) {
            $sheet->setAutoFilter(new AutoFilter(0, $headerRow, count($cols) - 1, $last));
        }

        // ── Sheet 2: ready for the SAP transfer request ──
        $sheet = $w->addNewSheetAndMakeItCurrent();
        $sheet->setName('للتحويل');
        foreach ([12, 16, 44, 11, 10] as $i => $width) {
            $sheet->setColumnWidth($width, $i + 1);
        }
        $w->addRow(Row::fromValues(["طلب تحويل مقترح: من {$src} ({$P['source']}) إلى {$tgt} ({$P['target']})"], $title));
        $w->addRow(Row::fromValues(['الكميات بالحبة · المقترح = الأقل بين العجز وفائض المصدر'], $muted));
        $w->addRow(Row::fromValues(['']));
        $w->addRow(Row::fromValues(['كود الصنف', 'الباركود', 'اسم المنتج', 'الكمية (حبة)', 'العجز'], $head));
        $pcs = 0;
        foreach ($board['rows'] as $r) {
            if ($r['suggest'] > 0) {
                $w->addRow(Row::fromValues([$r['code'], (string) ($r['barcode'] ?? ''), $r['name'], $r['suggest'], $r['gap']]));
                $pcs += $r['suggest'];
            }
        }
        $w->addRow(Row::fromValues(['الإجمالي', '', '', $pcs, ''], $bold));

        $w->close();

        return $path;
    }
}
