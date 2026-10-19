<?php

namespace App\Services\SAP;

use App\Models\DraftInvoiceRun;
use OpenSpout\Common\Entity\Row;
use OpenSpout\Common\Entity\Style\Style;
use OpenSpout\Writer\AutoFilter;
use OpenSpout\Writer\XLSX\Writer;

/**
 * (No SheetView: OpenSpout 4.28 writes a non-standard showZeroes attribute
 * that strict readers reject.)
 *
 * The Excel workbook behind one sales-report → draft-invoices run:
 * summary, per-customer totals (with the SAP draft numbers once uploaded),
 * the returns netted off the sales, lines duplicated in the source file (in
 * the file's own columns, ready to send back to the customer) and every
 * error / warning.
 */
class DraftInvoiceReport
{
    private const EXCEPTION_LABELS = [
        'missing_key' => 'سطر بدون كود صنف أو مستودع (لن يُرفع)',
        'unknown_customer' => 'العميل غير موجود في SAP',
        'unknown_item' => 'الصنف غير موجود في SAP',
        'zero_qty' => 'كمية صفر (تجاهلناه)',
        'return_unmatched' => 'مرتجع ما لقينا له مبيعات يُخصم منها (لم يُخصم)',
        'no_batch_in_warehouse' => 'لا توجد دفعة في المستودع',
        'qty_over_onhand' => 'الكمية أكبر من رصيد الدفعات',
    ];

    private Style $head;
    private Style $bold;

    public function write(string $absPath, DraftInvoiceRun $run, bool $post, array $totals, array $netting, array $duplicates, array $exceptions): void
    {
        @mkdir(dirname($absPath), 0775, true);

        $this->head = (new Style())->setFontBold()->setFontColor('FFFFFF')->setBackgroundColor('1F2358');
        $this->bold = (new Style())->setFontBold();

        $writer = new Writer();
        $writer->openToFile($absPath);

        $this->summary($writer, $run, $post, $totals);
        $this->customers($writer, $totals);
        $this->returns($writer, $netting);
        $this->duplicates($writer, $duplicates);
        $this->exceptions($writer, $exceptions);

        $writer->close();
    }

    private function summary(Writer $writer, DraftInvoiceRun $run, bool $post, array $t): void
    {
        $sheet = $writer->getCurrentSheet();
        $sheet->setName('الملخص');
        $sheet->setColumnWidth(34, 1);
        $sheet->setColumnWidth(40, 2);

        $writer->addRow(Row::fromValues(['تقرير مسودات الفواتير — ' . ($post ? 'رفع إلى SAP' : 'تحليل قبل الرفع')], $this->head));
        $period = ($t['period']['from'] ?? null) ? "{$t['period']['from']} → {$t['period']['to']}" : '—';

        $rows = [
            ['الملف', $run->source_file],
            ['قاعدة SAP', $run->company_db],
            ['تاريخ المستند', optional($run->doc_date)->format('Y-m-d')],
            ['فترة الطلبات في الملف', $period],
            ['أسطر الملف', $t['rows']],
            ['العملاء', count($t['warehouses'] ?? [])],
            ['المسودات', $t['drafts']],
            ['الأسطر في المسودات', $t['lines']],
            ['الكمية في المسودات', $t['qty'] ?? 0],
            ['الصافي بعد الخصم وقبل الضريبة', $t['net_total'] ?? 0],
            ['الشحن', $t['freight_total']],
            ['مرتجعات خُصمت من المبيعات (أسطر)', $t['returns']['lines'] ?? 0],
            ['كمية المرتجعات المخصومة', $t['returns']['qty'] ?? 0],
            ['قيمة المرتجعات المخصومة', $t['returns']['value'] ?? 0],
            ['أسطر مكررة في الملف (زائدة)', $t['duplicates']['extra_lines'] ?? 0],
            ['قيمة الأسطر المكررة', $t['duplicates']['value'] ?? 0],
            ['أخطاء تمنع الرفع', $t['errors'] ?? 0],
            ['تنبيهات', $t['warnings'] ?? 0],
        ];
        if ($post) {
            $rows[] = ['مسودات أُنشئت الآن', $t['posted']];
            $rows[] = ['مسودات كانت مرفوعة من قبل', $t['skipped']];
            $rows[] = ['مسودات فشلت', $t['failed']];
        }

        foreach ($rows as $r) {
            $writer->addRow(Row::fromValues($r));
        }
    }

    private function customers(Writer $writer, array $t): void
    {
        $sheet = $writer->addNewSheetAndMakeItCurrent();
        $sheet->setName('العملاء');
        $sheet->setColumnWidth(22, 1);
        $sheet->setColumnWidth(13, 2, 3, 4, 5, 6, 7, 9);
        $sheet->setColumnWidth(15, 8);
        $sheet->setColumnWidth(40, 10);

        $writer->addRow(Row::fromValues(['المتجر', 'كود العميل', 'المستودع', 'الأسطر', 'الكمية', 'مرتجع مخصوم (كمية)', 'قيمة المرتجع', 'الصافي', 'المسودات', 'أرقام المسودات في SAP'], $this->head));

        $sum = ['lines' => 0, 'qty' => 0, 'rq' => 0, 'rv' => 0, 'net' => 0, 'chunks' => 0];
        $groups = $t['warehouses'] ?? [];
        uasort($groups, fn ($a, $b) => ($b['net'] ?? 0) <=> ($a['net'] ?? 0));
        foreach ($groups as $key => $g) {
            $writer->addRow(Row::fromValues([
                $g['name'] ?? '', $g['card_code'] ?? $key, $g['warehouse'] ?? $key,
                $g['lines'] ?? 0, $g['qty'] ?? 0, $g['returns_qty'] ?? 0, $g['returns_value'] ?? 0,
                $g['net'] ?? 0, $g['chunks'] ?? 0, implode(', ', $g['doc_nums'] ?? []),
            ]));
            $sum['lines'] += $g['lines'] ?? 0;
            $sum['qty'] += $g['qty'] ?? 0;
            $sum['rq'] += $g['returns_qty'] ?? 0;
            $sum['rv'] += $g['returns_value'] ?? 0;
            $sum['net'] += $g['net'] ?? 0;
            $sum['chunks'] += $g['chunks'] ?? 0;
        }
        $writer->addRow(Row::fromValues(['الإجمالي', '', '', $sum['lines'], $sum['qty'], $sum['rq'], round($sum['rv'], 2), round($sum['net'], 2), $sum['chunks'], ''], $this->bold));
    }

    private function returns(Writer $writer, array $netting): void
    {
        $sheet = $writer->addNewSheetAndMakeItCurrent();
        $sheet->setName('المرتجعات المخصومة');
        $sheet->setColumnWidth(20, 1);
        $sheet->setColumnWidth(12, 2, 5, 7, 8, 9, 10);
        $sheet->setColumnWidth(22, 3, 11);
        $sheet->setColumnWidth(10, 4);
        $sheet->setColumnWidth(44, 6);

        $writer->addRow(Row::fromValues(['المتجر', 'كود العميل', 'طلب المرتجع', 'سطر الملف', 'الصنف', 'الاسم', 'كمية المرتجع', 'خُصم', 'لم يُخصم', 'القيمة المخصومة', 'خُصم من (طلب × كمية)'], $this->head));
        foreach ($netting as $n) {
            $from = implode(' ، ', array_map(fn ($f) => "{$f['order_number']} × {$f['qty']}", $n['from']));
            $writer->addRow(Row::fromValues([
                $n['store_name'] ?? '', $n['card_code'], $n['order_number'], $n['row'], $n['item_code'], $n['item_name'] ?? '',
                $n['return_qty'], $n['netted_qty'], $n['unmatched_qty'], $n['value'], $from,
            ]));
        }
        if (!$netting) {
            $writer->addRow(Row::fromValues(['لا توجد مرتجعات في الملف']));
        }
    }

    /** Duplicates keep the source file's own columns so they can go straight back to the customer. */
    private function duplicates(Writer $writer, array $duplicates): void
    {
        $sheet = $writer->addNewSheetAndMakeItCurrent();
        $sheet->setName('Duplicate lines');

        $header = array_values(array_filter(array_map(fn ($h) => trim((string) $h), $duplicates['header'] ?? []), fn ($h) => $h !== ''));
        $width = count($header);
        $writer->addRow(Row::fromValues(array_merge(['Group #', 'Row in file'], $header), $this->head));

        foreach ($duplicates['groups'] ?? [] as $g => $lines) {
            foreach ($lines as $line) {
                $writer->addRow(Row::fromValues(array_merge([$g + 1, $line['row']], array_slice(array_values($line['cells']), 0, $width))));
            }
        }
        if ($duplicates['groups'] ?? []) {
            $sheet->setAutoFilter(new AutoFilter(0, 1, $width + 1, $sheet->getWrittenRowCount()));
        } else {
            $writer->addRow(Row::fromValues(['No duplicated lines in the file.']));
        }
    }

    private function exceptions(Writer $writer, array $exceptions): void
    {
        $sheet = $writer->addNewSheetAndMakeItCurrent();
        $sheet->setName('الملاحظات');
        $sheet->setColumnWidth(12, 1, 3, 4);
        $sheet->setColumnWidth(40, 2, 6);
        $sheet->setColumnWidth(14, 5);
        $sheet->setColumnWidth(60, 7);

        $writer->addRow(Row::fromValues(['الخطورة', 'النوع', 'سطر الملف', 'العميل', 'الصنف', 'الاسم', 'التفاصيل'], $this->head));
        foreach ($exceptions as $e) {
            $blocking = in_array($e['type'], DraftInvoiceImportService::BLOCKING, true);
            $detail = $e['message'] ?? match ($e['type']) {
                'return_unmatched' => "طلب {$e['order_number']} — كمية لم تُخصم: {$e['qty']}",
                'no_batch_in_warehouse', 'qty_over_onhand' => "مطلوب {$e['requested_qty']} — متاح {$e['available_qty']}",
                default => '',
            };
            $writer->addRow(Row::fromValues([
                $blocking ? 'يمنع الرفع' : 'تنبيه',
                self::EXCEPTION_LABELS[$e['type']] ?? $e['type'],
                $e['row'] ?? (isset($e['rows']) ? implode(', ', $e['rows']) : ''),
                $e['card_code'] ?? '',
                $e['item_code'] ?? '',
                $e['item_name'] ?? ($e['name'] ?? ''),
                mb_substr((string) $detail, 0, 300),
            ]));
        }
        if (!$exceptions) {
            $writer->addRow(Row::fromValues(['', 'لا توجد ملاحظات']));
        }
    }
}
