<?php

namespace App\Services\SAP;

use App\Models\ApiLog;
use App\Models\DraftInvoiceChunk;
use App\Models\DraftInvoiceRun;
use App\Services\SAP\SapClient;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use OpenSpout\Reader\XLSX\Reader as XlsxReader;

/**
 * Turns a flat sales-report file (one row = one sold line) into SAP **draft**
 * invoices (Service Layer `Drafts`, DocObjectCode=oInvoices).
 *
 * Pipeline: parse -> net returns off the same customer's sales -> check the
 * customers and items exist in SAP -> group by customer + warehouse -> split
 * each group into chunks of N document-lines -> one draft per chunk. For
 * batch-managed items the nearest expiry batches (FEFO) for that warehouse are
 * attached. Freight is summed per chunk and sent as a header Additional Expense.
 *
 * Returns (negative quantity) are never uploaded: each one is subtracted from
 * the same customer's sales of the same item in the same warehouse (100 sold,
 * 10 returned -> 90 on the draft), preferring the return's own order, then a
 * line at the same price and discount, then any other line.
 *
 * Multi-customer files (e.g. the ShipGo stores report, one BP Code per row)
 * get one group per customer, so a draft never mixes two customers' sales.
 * A "Disc.%" column is sent as the line DiscountPercent on top of the verbatim
 * UnitPrice.
 *
 * SAFETY:
 *  - Drafts never post to the ledger/inventory until a human opens them in SAP
 *    and clicks Add.
 *  - A post refuses to start while the file has blocking errors (unknown
 *    customer or item, a row with no item/warehouse).
 *  - Idempotent: the (file_hash, warehouse, chunk_index) ledger guarantees a
 *    chunk is posted at most once; re-runs only fill gaps / retry failures.
 *    The ledger "warehouse" holds the group key: the bare warehouse code for a
 *    single-customer file (unchanged from before), "BP|WH" for multi-customer.
 *  - UnitPrice is taken verbatim from the file (no SAP price-list recompute).
 *
 * Batch note: on-hand from `batchesitems` is a *current snapshot*, while the
 * file is historical sales, so we do NOT decrement batch balances across lines
 * — each batch-managed line is simply labelled with its warehouse's nearest
 * expiry batch(es). Lines whose qty exceeds current on-hand are flagged but
 * still produced (it is a draft for human review).
 */
class DraftInvoiceImportService
{
    public const DOC_OBJECT_CODE = 'oInvoices';

    /**
     * Canonical column => accepted header aliases (lowercased), in priority
     * order: the first alias present in the header wins, whatever its column
     * position ("WHS Code" = RUH003 must beat a trailing "Warehouse" = RUH).
     */
    protected array $headerAliases = [
        'card_code'    => ['bp code', 'cardcode', 'bp', 'customer'],
        'store_name'   => ['stores', 'store', 'store name', 'customer name', 'cardname'],
        'warehouse'    => ['wh code', 'whs code', 'warehousecode', 'whscode', 'warehouse'],
        'order_date'   => ['order date', 'docdate', 'date'],
        'order_number' => ['order number', 'order no', 'ordernumber', 'numatcard'],
        'item_code'    => ['item upc', 'itemcode', 'item code', 'sap code'],
        'barcode'      => ['seller sku', 'barcode', 'upc'],
        'item_name'    => ['item name', 'itemname', 'description', 'name'],
        'uom'          => ['uom', 'uomcode'],
        'qty'          => ['ordered quantity', 'quantity', 'qty'],
        'unit_price'   => ['unit price', 'unitprice', 'price'],
        'discount_pct' => ['disc.%', 'disc %', 'discount %', 'discount percent', 'discountpercent'],
        'line_total'   => ['line total', 'linetotal', 'total'],
        'freight'      => ['freight', 'shipping'],
    ];

    /** Exception types that stop a post until the file is fixed. */
    public const BLOCKING = ['missing_key', 'unknown_customer', 'unknown_item'];

    /** Per-run caches (item-level), avoid hammering SAP. */
    protected array $batchRowCache = [];
    protected array $itemInfoCache = [];

    public function __construct(protected SapClient $sap)
    {
    }

    /**
     * Execute a run. $post=false => dry-run preview (no SAP writes at all).
     * $progress is an optional callable(string $message) for CLI/UI feedback.
     */
    public function run(DraftInvoiceRun $run, string $filePath, bool $post, ?callable $progress = null): array
    {
        $log = fn (string $m) => $progress ? $progress($m) : null;

        $this->sap->setCompanyDb($run->company_db);

        $fileHash = hash_file('sha256', $filePath);
        $run->forceFill(['file_hash' => $fileHash])->save();

        $log("Parsing file...");
        [$rows, $exceptions, $duplicates] = $this->parseAndMap($filePath);
        $log("Parsed " . count($rows) . " line(s); " . count($exceptions) . " row exception(s); " . count($duplicates['groups']) . " duplicated line(s).");

        // A customer typed on the run applies to the whole file, so the file
        // must not name any other customer (else their sales would be booked
        // to the wrong BP).
        $fileCards = array_values(array_unique(array_filter(array_column($rows, 'card_code'))));
        if ($run->card_code && array_diff($fileCards, [$run->card_code])) {
            throw new \RuntimeException(
                "The run customer is {$run->card_code} but the file names other customers: " .
                implode(', ', array_diff($fileCards, [$run->card_code])) . '. Leave the customer empty to split the file per customer.'
            );
        }
        $multiCustomer = !$run->card_code && count($fileCards) > 1;

        $scoped = [];
        foreach ($rows as $r) {
            if ($run->warehouse_filter && $r['warehouse'] !== $run->warehouse_filter) {
                continue;
            }
            $r['card_code'] = $run->card_code ?: $r['card_code'];
            if (!$r['card_code']) {
                throw new \RuntimeException("No customer for item {$r['item_code']} in {$r['warehouse']} (row {$r['row']}): set the run customer or fill the file's BP Code column.");
            }
            $scoped[] = $r;
        }

        $log("Netting returns against the same customer's sales...");
        [$sales, $netting, $unmatched] = $this->netReturns($scoped);
        $exceptions = array_merge($exceptions, $unmatched);
        $log(count($netting) . " return line(s) netted; " . count($unmatched) . " could not be fully matched.");

        $log("Checking customers and items in SAP...");
        [$customers, $masterExceptions] = $this->checkMasterData($sales);
        $exceptions = array_merge($exceptions, $masterExceptions);

        $blocking = array_values(array_filter($exceptions, fn ($e) => in_array($e['type'], self::BLOCKING, true)));
        if ($post && $blocking) {
            throw new \RuntimeException(count($blocking) . ' blocking error(s) in the file (' . implode(', ', array_unique(array_column($blocking, 'type'))) . '). Fix the file and analyse it again before uploading.');
        }

        // Group by customer + warehouse.
        $groups = [];
        foreach ($sales as $r) {
            $key = $this->groupKey($r['card_code'], $r['warehouse'], $multiCustomer);
            $groups[$key] ??= ['card_code' => $r['card_code'], 'warehouse' => $r['warehouse'], 'rows' => []];
            $groups[$key]['rows'][] = $r;
        }
        ksort($groups);

        // Guard: a file already partially POSTED must keep the same chunk_size,
        // otherwise re-chunking would create duplicate drafts of the same sales.
        if ($post) {
            $this->assertChunkSizeStable($run, $fileHash);
        }

        $chunkSize = max(1, (int) $run->chunk_size);
        $docDate   = optional($run->doc_date)->format('Y-m-d') ?? now()->format('Y-m-d');

        $results = [];
        $previews = [];
        $totals = [
            'rows' => count($rows),
            'drafts' => 0,
            'posted' => 0,
            'skipped' => 0,
            'failed' => 0,
            'lines' => 0,
            'qty' => 0.0,
            'freight_total' => 0.0,
            'net_total' => 0.0,
            'exceptions' => 0,
            'errors' => 0,
            'warnings' => 0,
            'warehouses' => [],
            'returns' => ['lines' => count($netting), 'qty' => 0.0, 'value' => 0.0, 'unmatched' => count($unmatched)],
            'duplicates' => ['groups' => count($duplicates['groups']), 'extra_lines' => $duplicates['extra_lines'], 'value' => $duplicates['value']],
            'period' => $this->period($rows),
            'file_path' => $filePath,
        ];

        foreach ($netting as $n) {
            $totals['returns']['qty'] += $n['netted_qty'];
            $totals['returns']['value'] += $n['value'];
        }
        // The first 200 for the review screen; the Excel report has them all.
        $totals['returns']['detail'] = array_map(function ($n) {
            $n['from_label'] = implode('، ', array_map(fn ($f) => "{$f['order_number']} × {$f['qty']}", $n['from']));
            unset($n['from']);
            return $n;
        }, array_slice($netting, 0, 200));

        foreach ($groups as $wh => $group) {
            $chunks = array_chunk($group['rows'], $chunkSize);
            $qty = array_sum(array_column($group['rows'], 'qty'));
            $net = round(array_sum(array_map(fn ($r) => $this->netLineValue($r, $r['qty']), $group['rows'])), 2);
            $groupReturns = array_filter($netting, fn ($n) => $this->groupKey($n['card_code'], $n['warehouse'], $multiCustomer) === $wh);

            $totals['qty'] += $qty;
            $totals['net_total'] += $net;
            $totals['warehouses'][$wh] = [
                'card_code' => $group['card_code'],
                'name' => $customers[$group['card_code']]['name'] ?? null,
                'warehouse' => $group['warehouse'],
                'lines' => count($group['rows']),
                'qty' => $qty,
                'net' => $net,
                'returns_qty' => array_sum(array_column($groupReturns, 'netted_qty')),
                'returns_value' => round(array_sum(array_column($groupReturns, 'value')), 2),
                'chunks' => count($chunks),
                'posted' => 0, 'skipped' => 0, 'failed' => 0,
                'doc_nums' => [],
            ];
            $log("Group $wh: " . count($group['rows']) . " line(s), net $net -> " . count($chunks) . " draft(s).");

            foreach ($chunks as $idx => $chunkRows) {
                [$payload, $chunkExceptions, $freightTotal] = $this->buildDraftPayload(
                    $chunkRows, $group['warehouse'], $idx, $group['card_code'], $docDate, $run
                );

                $lineCount = count($payload['DocumentLines']);
                $payloadHash = hash('sha256', json_encode($payload));

                $totals['drafts']++;
                $totals['lines'] += $lineCount;
                $totals['freight_total'] += $freightTotal;
                $exceptions = array_merge($exceptions, $chunkExceptions);

                // Ledger row (idempotent on file_hash+warehouse+chunk_index).
                $chunk = DraftInvoiceChunk::firstOrNew([
                    'file_hash' => $fileHash,
                    'warehouse' => $wh,
                    'chunk_index' => $idx,
                ]);
                $chunk->fill([
                    'run_id' => $run->id,
                    'company_db' => $run->company_db,
                    'lines_count' => $lineCount,
                    'freight_total' => $freightTotal,
                    'payload_hash' => $payloadHash,
                    'exceptions' => $chunkExceptions ?: null,
                ]);

                if (!$post) {
                    // Dry-run: record structure only, never call SAP.
                    if (!$chunk->status || $chunk->status === 'built') {
                        $chunk->status = 'built';
                    }
                    $chunk->save();
                    $previews[] = ['warehouse' => $wh, 'chunk_index' => $idx, 'lines' => $lineCount, 'freight' => $freightTotal, 'payload' => $payload];
                    continue;
                }

                // Real post: skip chunks already posted (idempotency).
                if ($chunk->status === 'posted' && $chunk->doc_entry) {
                    $totals['skipped']++;
                    $totals['warehouses'][$wh]['skipped']++;
                    $totals['warehouses'][$wh]['doc_nums'][] = $chunk->doc_num ?: $chunk->doc_entry;
                    $chunk->save();
                    $log("  chunk $idx already posted (DocEntry {$chunk->doc_entry}) - skipped.");
                    $results[] = ['warehouse' => $wh, 'chunk_index' => $idx, 'status' => 'skipped', 'doc_entry' => $chunk->doc_entry, 'doc_num' => $chunk->doc_num];
                    continue;
                }

                try {
                    $response = $this->sap->post('Drafts', $payload);
                    $docEntry = $response['DocEntry'] ?? null;
                    $docNum = $response['DocNum'] ?? null;

                    if (!$docEntry) {
                        throw new \RuntimeException('SAP did not return DocEntry');
                    }

                    $chunk->fill(['status' => 'posted', 'doc_entry' => $docEntry, 'doc_num' => $docNum, 'posted_at' => now(), 'error' => null])->save();
                    $this->logActivity('Drafts', $payload, $response, 201);

                    $totals['posted']++;
                    $totals['warehouses'][$wh]['posted']++;
                    $totals['warehouses'][$wh]['doc_nums'][] = $docNum ?: $docEntry;
                    $log("  chunk $idx posted -> DocEntry $docEntry (DocNum $docNum), $lineCount line(s).");
                    $results[] = ['warehouse' => $wh, 'chunk_index' => $idx, 'status' => 'posted', 'doc_entry' => $docEntry, 'doc_num' => $docNum, 'lines' => $lineCount, 'freight' => $freightTotal];
                } catch (\Throwable $e) {
                    $chunk->fill(['status' => 'failed', 'error' => $e->getMessage()])->save();
                    $this->logActivity('Drafts', $payload, ['error' => $e->getMessage()], 500);

                    $totals['failed']++;
                    $totals['warehouses'][$wh]['failed']++;
                    $log("  chunk $idx FAILED: " . $e->getMessage());
                    $results[] = ['warehouse' => $wh, 'chunk_index' => $idx, 'status' => 'failed', 'error' => $e->getMessage(), 'lines' => $lineCount];
                }
            }
        }

        $totals['exceptions'] = count($exceptions);
        $totals['errors'] = count(array_filter($exceptions, fn ($e) => in_array($e['type'], self::BLOCKING, true)));
        $totals['warnings'] = $totals['exceptions'] - $totals['errors'];
        $totals['freight_total'] = round($totals['freight_total'], 2);
        $totals['net_total'] = round($totals['net_total'], 2);
        $totals['returns']['value'] = round($totals['returns']['value'], 2);

        // Persist artifacts.
        $stamp = now()->format('Ymd_His');
        $exPath = "draft_invoices/run_{$run->id}_{$stamp}_exceptions.json";
        Storage::disk('local')->put($exPath, json_encode($exceptions, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));

        $paths = ['exceptions_path' => $exPath];
        if (!$post) {
            $pvPath = "draft_invoices/run_{$run->id}_{$stamp}_preview.json";
            Storage::disk('local')->put($pvPath, json_encode($previews, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
            $paths['preview_path'] = $pvPath;
        } else {
            $rsPath = "draft_invoices/run_{$run->id}_{$stamp}_result.json";
            Storage::disk('local')->put($rsPath, json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
            $paths['result_path'] = $rsPath;
        }

        $reportPath = "draft_invoices/run_{$run->id}_{$stamp}_report.xlsx";
        try {
            (new DraftInvoiceReport())->write(Storage::disk('local')->path($reportPath), $run, $post, $totals, $netting, $duplicates, $exceptions);
            $totals['report_path'] = $reportPath;
        } catch (\Throwable $e) {
            Log::warning("DraftInvoiceImport: report for run {$run->id} failed: " . $e->getMessage());
        }

        $run->forceFill(array_merge($paths, [
            'totals' => $totals,
            'status' => 'done',
            'finished_at' => now(),
        ]))->save();

        $log("Done. drafts={$totals['drafts']} posted={$totals['posted']} skipped={$totals['skipped']} failed={$totals['failed']} errors={$totals['errors']} warnings={$totals['warnings']}.");

        return $totals;
    }

    /** Ledger group key: bare warehouse for single-customer files, "BP|WH" otherwise. */
    protected function groupKey(string $cardCode, string $warehouse, bool $multiCustomer): string
    {
        return $multiCustomer ? "$cardCode|$warehouse" : $warehouse;
    }

    protected function netLineValue(array $row, float $qty): float
    {
        return $qty * $row['unit_price'] * (1 - $row['discount_pct'] / 100);
    }

    /**
     * Subtract every return from the same customer's sales of the same item in
     * the same warehouse. Candidate sale lines are tried in this order: the
     * return's own order ("123-R1" matches order "123"), then a line at the
     * same price and discount, then any other line (file order within a tier).
     * Lines netted down to zero are dropped.
     *
     * @return array{0: array, 1: array, 2: array} [sales, netting, unmatchedExceptions]
     */
    protected function netReturns(array $rows): array
    {
        $sales = [];
        $returns = [];
        foreach ($rows as $i => $r) {
            if ($r['kind'] === 'return') {
                $returns[] = $r;
            } else {
                $sales[$i] = $r;
            }
        }

        $index = [];
        foreach ($sales as $i => $r) {
            $index["{$r['card_code']}|{$r['warehouse']}|{$r['item_code']}"][] = $i;
        }

        $netting = [];
        $unmatched = [];
        foreach ($returns as $ret) {
            $baseOrder = preg_replace('/-R\d+$/i', '', (string) $ret['order_number']);
            $candidates = $index["{$ret['card_code']}|{$ret['warehouse']}|{$ret['item_code']}"] ?? [];

            $tier = function (int $i) use ($sales, $baseOrder, $ret): int {
                $s = $sales[$i];
                if ($baseOrder !== '' && $s['order_number'] === $baseOrder) {
                    return 0;
                }
                if (abs($s['unit_price'] - $ret['unit_price']) < 0.0001 && abs($s['discount_pct'] - $ret['discount_pct']) < 0.0001) {
                    return 1;
                }
                return 2;
            };
            usort($candidates, fn ($a, $b) => [$tier($a), $a] <=> [$tier($b), $b]);

            $left = $ret['qty'];
            $value = 0.0;
            $from = [];
            foreach ($candidates as $i) {
                if ($left <= 0) {
                    break;
                }
                $take = min($left, $sales[$i]['qty']);
                if ($take <= 0) {
                    continue;
                }
                $sales[$i]['qty'] = round($sales[$i]['qty'] - $take, 6);
                $left = round($left - $take, 6);
                $value += $this->netLineValue($sales[$i], $take);
                $from[] = ['row' => $sales[$i]['row'], 'order_number' => $sales[$i]['order_number'], 'qty' => $take];
            }

            $netting[] = [
                'row' => $ret['row'],
                'card_code' => $ret['card_code'],
                'store_name' => $ret['store_name'],
                'warehouse' => $ret['warehouse'],
                'order_number' => $ret['order_number'],
                'item_code' => $ret['item_code'],
                'item_name' => $ret['item_name'],
                'return_qty' => $ret['qty'],
                'netted_qty' => round($ret['qty'] - $left, 6),
                'unmatched_qty' => $left,
                'value' => round($value, 2),
                'from' => $from,
            ];

            if ($left > 0) {
                $unmatched[] = [
                    'type' => 'return_unmatched', 'row' => $ret['row'], 'card_code' => $ret['card_code'],
                    'warehouse' => $ret['warehouse'], 'item_code' => $ret['item_code'], 'item_name' => $ret['item_name'],
                    'order_number' => $ret['order_number'], 'qty' => $left,
                ];
            }
        }

        $kept = array_values(array_filter($sales, fn ($r) => $r['qty'] > 0));

        return [$kept, $netting, $unmatched];
    }

    /**
     * Every customer and item must exist in SAP before anything is uploaded.
     * Also resolves each customer's display name (file "Stores" column, else
     * the SAP BP name).
     *
     * @return array{0: array, 1: array} [customers(card => [name]), exceptions]
     */
    protected function checkMasterData(array $sales): array
    {
        $customers = [];
        $exceptions = [];

        foreach ($sales as $r) {
            $customers[$r['card_code']] ??= ['name' => null];
            if (!$customers[$r['card_code']]['name'] && $r['store_name']) {
                $customers[$r['card_code']]['name'] = $r['store_name'];
            }
        }

        foreach ($customers as $card => &$c) {
            try {
                $bp = $this->sap->get("BusinessPartners('" . str_replace("'", "''", $card) . "')", ['$select' => 'CardCode,CardName']);
                $c['name'] ??= $bp['CardName'] ?? null;
            } catch (\Throwable $e) {
                $exceptions[] = ['type' => 'unknown_customer', 'card_code' => $card, 'name' => $c['name'], 'message' => $e->getMessage()];
            }
        }
        unset($c);

        $items = [];
        foreach ($sales as $r) {
            $items[$r['item_code']] ??= ['name' => $r['item_name'], 'rows' => []];
            $items[$r['item_code']]['rows'][] = $r['row'];
        }
        foreach ($items as $code => $item) {
            $info = $this->itemInfo($code);
            if (!$info['exists']) {
                $exceptions[] = [
                    'type' => 'unknown_item', 'item_code' => $code, 'item_name' => $item['name'],
                    'rows' => array_slice($item['rows'], 0, 20), 'lines' => count($item['rows']), 'message' => $info['error'],
                ];
            }
        }

        return [$customers, $exceptions];
    }

    /** Earliest/latest order date that parses unambiguously (Y-m-d or d/m/Y). */
    protected function period(array $rows): array
    {
        $dates = [];
        foreach ($rows as $r) {
            $d = trim((string) $r['order_date']);
            if (preg_match('/^(\d{4})-(\d{2})-(\d{2})/', $d, $m)) {
                $dates[] = "$m[1]-$m[2]-$m[3]";
            } elseif (preg_match('#^(\d{1,2})/(\d{1,2})/(\d{4})$#', $d, $m)) {
                $dates[] = sprintf('%04d-%02d-%02d', $m[3], $m[2], $m[1]);
            }
        }

        return $dates ? ['from' => min($dates), 'to' => max($dates)] : ['from' => null, 'to' => null];
    }

    /**
     * Build a single draft-invoice payload for one chunk of rows.
     * @return array{0: array, 1: array, 2: float} [payload, exceptions, freightTotal]
     */
    protected function buildDraftPayload(array $chunkRows, string $wh, int $idx, string $cardCode, string $docDate, DraftInvoiceRun $run): array
    {
        $lines = [];
        $exceptions = [];
        $freightTotal = 0.0;

        foreach ($chunkRows as $row) {
            $itemCode = $row['item_code'];
            $qty = (float) $row['qty'];
            $freightTotal += (float) ($row['freight'] ?? 0);

            $info = $this->itemInfo($itemCode);

            $line = [
                'ItemCode' => $itemCode,
                'Quantity' => $qty,
                'UnitPrice' => round((float) $row['unit_price'], 4), // verbatim from file
                'WarehouseCode' => $wh,
                // Cost center (Dimension 1) = warehouse code, so the sale books
                // against the right store/warehouse cost center in SAP.
                'CostingCode' => $wh,
                // Force the base inventory unit (PC / حبة) so qty & price are
                // per-piece, NOT the item's default sales carton.
                'UoMEntry' => (int) ($info['uom_entry'] ?? config('draft_invoices.uom_entry', 58)),
            ];
            if ($row['discount_pct'] > 0) {
                $line['DiscountPercent'] = round($row['discount_pct'], 4);
            }
            if ($run->tax_code) {
                $line['TaxCode'] = $run->tax_code;
            }

            // Attach FEFO batches for batch-managed items (unless batches are
            // explicitly disabled for this run, e.g. the Panda upload).
            if (!$run->no_batches) {
                $alloc = $this->allocateBatches($itemCode, $wh, $qty);
                if ($alloc['is_batch_item']) {
                    if (!empty($alloc['batches'])) {
                        $line['BatchNumbers'] = $alloc['batches'];
                    }
                    if ($alloc['shortfall'] > 0) {
                        $exceptions[] = [
                            'type' => $alloc['available'] <= 0 ? 'no_batch_in_warehouse' : 'qty_over_onhand',
                            'row' => $row['row'], 'card_code' => $cardCode,
                            'warehouse' => $wh, 'chunk_index' => $idx, 'item_code' => $itemCode,
                            'item_name' => $row['item_name'] ?? null,
                            'requested_qty' => $qty, 'available_qty' => $alloc['available'],
                            'shortfall' => round($alloc['shortfall'], 3),
                        ];
                    }
                }
            }

            $lines[] = $line;
        }

        $payload = [
            'DocObjectCode' => self::DOC_OBJECT_CODE,
            'CardCode' => $cardCode,
            'DocDate' => $docDate,
            'DocDueDate' => $docDate,
            'Comments' => sprintf('Sales import | %s | %s | part %d | %s', $run->source_file, $wh, $idx + 1, $cardCode),
            'DocumentLines' => $lines,
        ];

        // Freight summed into the header as an Additional Expense.
        $freightTotal = round($freightTotal, 2);
        if ($run->expense_code && $freightTotal > 0) {
            $payload['DocumentAdditionalExpenses'] = [[
                'ExpenseCode' => (int) $run->expense_code,
                'LineTotal' => $freightTotal,
            ]];
        }

        return [$payload, $exceptions, $freightTotal];
    }

    /**
     * FEFO allocation of a line quantity across a warehouse's batches.
     * Returns batches summing to $qty when >=1 batch exists (remainder, if the
     * line exceeds current on-hand, is placed on the nearest-expiry batch so the
     * draft stays internally consistent; the shortfall is reported separately).
     *
     * @return array{batches: array, allocated: float, shortfall: float, available: float, is_batch_item: bool}
     */
    protected function allocateBatches(string $itemCode, string $whsCode, float $qty): array
    {
        $rows = $this->batchRowsForWarehouse($itemCode, $whsCode);

        if (empty($rows)) {
            $isBatch = $this->isBatchManaged($itemCode);
            return [
                'batches' => [], 'allocated' => $isBatch ? 0.0 : $qty,
                'shortfall' => $isBatch ? $qty : 0.0, 'available' => 0.0,
                'is_batch_item' => $isBatch,
            ];
        }

        $available = array_sum(array_column($rows, 'Quantity'));
        $batches = [];
        $remaining = $qty;

        foreach ($rows as $r) {
            if ($remaining <= 0) {
                break;
            }
            $take = min($remaining, (float) $r['Quantity']);
            if ($take <= 0) {
                continue;
            }
            $batches[] = ['BatchNumber' => (string) $r['BatchNumber'], 'Quantity' => $take];
            $remaining -= $take;
        }

        $shortfall = max(0.0, $remaining);
        // Keep BatchNumbers sum == line qty: dump any remainder on nearest-expiry batch.
        if ($shortfall > 0 && !empty($batches)) {
            $batches[0]['Quantity'] += $shortfall;
        }

        return [
            'batches' => $batches,
            'allocated' => $qty,
            'shortfall' => $shortfall,
            'available' => (float) $available,
            'is_batch_item' => true,
        ];
    }

    /** Batch rows for an item filtered to one warehouse, sorted FEFO (nearest expiry first). */
    protected function batchRowsForWarehouse(string $itemCode, string $whsCode): array
    {
        if (!array_key_exists($itemCode, $this->batchRowCache)) {
            try {
                $resp = $this->sap->get("SQLQueries('batchesitems')/List", ['ItemCode' => "'$itemCode'"]);
                $this->batchRowCache[$itemCode] = $resp['value'] ?? [];
            } catch (\Throwable $e) {
                Log::warning("DraftInvoiceImport: batch query failed for $itemCode: " . $e->getMessage());
                $this->batchRowCache[$itemCode] = [];
            }
        }

        $rows = array_values(array_filter($this->batchRowCache[$itemCode], function ($r) use ($whsCode) {
            return ($r['WhsCode'] ?? null) === $whsCode
                && !empty($r['BatchNumber'])
                && (float) ($r['Quantity'] ?? 0) > 0;
        }));

        usort($rows, fn ($a, $b) => strcmp((string) ($a['ExpiryDate'] ?? '99999999'), (string) ($b['ExpiryDate'] ?? '99999999')));

        return $rows;
    }

    /** Whether SAP manages this item by batch. */
    protected function isBatchManaged(string $itemCode): bool
    {
        return $this->itemInfo($itemCode)['batch'];
    }

    /**
     * Per-item master info needed for lines (cached): batch-managed flag and
     * the base inventory UoM AbsEntry (PC / حبة).
     *
     * @return array{exists: bool, error: ?string, batch: bool, uom_entry: int|null}
     */
    protected function itemInfo(string $itemCode): array
    {
        if (!array_key_exists($itemCode, $this->itemInfoCache)) {
            try {
                $d = $this->sap->get("Items('" . str_replace("'", "''", $itemCode) . "')", ['$select' => 'ManageBatchNumbers,InventoryUoMEntry']);
                $this->itemInfoCache[$itemCode] = [
                    'exists' => true,
                    'error' => null,
                    'batch' => ($d['ManageBatchNumbers'] ?? 'tNO') === 'tYES',
                    'uom_entry' => isset($d['InventoryUoMEntry']) ? (int) $d['InventoryUoMEntry'] : null,
                ];
            } catch (\Throwable $e) {
                $this->itemInfoCache[$itemCode] = ['exists' => false, 'error' => $e->getMessage(), 'batch' => false, 'uom_entry' => null];
            }
        }

        return $this->itemInfoCache[$itemCode];
    }

    /**
     * Parse the upload (.xlsx or .csv) and map columns to canonical keys.
     * Rows identical in every column are reported as duplicates (they are
     * still uploaded; the report lists them for the customer to confirm).
     *
     * @return array{0: array, 1: array, 2: array} [validRows, exceptions, duplicates]
     */
    protected function parseAndMap(string $filePath): array
    {
        $ext = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
        $raw = $ext === 'csv' ? $this->readCsv($filePath) : $this->readXlsx($filePath);

        if (empty($raw)) {
            throw new \RuntimeException('File is empty or unreadable.');
        }

        $headerRow = array_shift($raw);
        $colMap = $this->mapHeaders($headerRow);

        foreach (['item_code', 'warehouse', 'qty', 'unit_price'] as $required) {
            if (!isset($colMap[$required])) {
                throw new \RuntimeException("Required column for '$required' not found in header: " . implode(', ', $headerRow));
            }
        }

        $rows = [];
        $exceptions = [];
        $seen = [];
        foreach ($raw as $n => $cells) {
            $get = fn (string $key) => isset($colMap[$key]) ? trim((string) ($cells[$colMap[$key]] ?? '')) : null;
            $num = fn (string $key) => (float) str_replace(',', '', (string) $get($key));

            // Skip fully empty rows.
            if (count(array_filter($cells, fn ($v) => trim((string) $v) !== '')) === 0) {
                continue;
            }

            $seen[md5(json_encode(array_map(fn ($v) => trim((string) $v), $cells)))][] = $n;

            $itemCode = $get('item_code');
            $wh = $get('warehouse');
            $qty = $num('qty');

            if ($itemCode === '' || $wh === '') {
                $exceptions[] = ['type' => 'missing_key', 'row' => $n + 2, 'item_code' => $itemCode, 'warehouse' => $wh];
                continue;
            }
            if ($qty == 0) {
                $exceptions[] = ['type' => 'zero_qty', 'row' => $n + 2, 'item_code' => $itemCode, 'qty' => $qty];
                continue;
            }

            // A negative quantity is a customer return, netted off the sales.
            $rows[] = [
                'row' => $n + 2,
                'kind' => $qty < 0 ? 'return' : 'sale',
                'card_code' => $get('card_code'),
                'store_name' => $get('store_name'),
                'warehouse' => $wh,
                'order_date' => $get('order_date'),
                'order_number' => $get('order_number'),
                'item_code' => $itemCode,
                'item_name' => $get('item_name'),
                'uom' => $get('uom'),
                'qty' => abs($qty),
                'unit_price' => $num('unit_price'),
                'discount_pct' => $num('discount_pct'),
                'freight' => $num('freight'),
            ];
        }

        $duplicates = ['header' => $headerRow, 'groups' => [], 'extra_lines' => 0, 'value' => 0.0];
        $priceCol = $colMap['unit_price'];
        foreach ($seen as $indexes) {
            if (count($indexes) < 2) {
                continue;
            }
            $cells = $raw[$indexes[0]];
            $qty = (float) str_replace(',', '', (string) ($cells[$colMap['qty']] ?? 0));
            $price = (float) str_replace(',', '', (string) ($cells[$priceCol] ?? 0));
            $disc = isset($colMap['discount_pct']) ? (float) str_replace(',', '', (string) ($cells[$colMap['discount_pct']] ?? 0)) : 0.0;
            $duplicates['groups'][] = array_map(fn ($i) => ['row' => $i + 2, 'cells' => $raw[$i]], $indexes);
            $duplicates['extra_lines'] += count($indexes) - 1;
            $duplicates['value'] += (count($indexes) - 1) * $qty * $price * (1 - $disc / 100);
        }
        $duplicates['value'] = round($duplicates['value'], 2);

        return [$rows, $exceptions, $duplicates];
    }

    protected function readXlsx(string $filePath): array
    {
        $reader = new XlsxReader();
        $reader->open($filePath);
        $out = [];
        foreach ($reader->getSheetIterator() as $sheet) {
            foreach ($sheet->getRowIterator() as $row) {
                $out[] = array_map(fn ($v) => $v instanceof \DateTimeInterface ? $v->format('Y-m-d') : $v, $row->toArray());
            }
            break; // first sheet only
        }
        $reader->close();
        return $out;
    }

    protected function readCsv(string $filePath): array
    {
        $out = [];
        if (($h = fopen($filePath, 'r')) !== false) {
            while (($data = fgetcsv($h)) !== false) {
                $out[] = $data;
            }
            fclose($h);
        }
        // Strip BOM from first header cell.
        if (isset($out[0][0])) {
            $out[0][0] = preg_replace('/^\xEF\xBB\xBF/', '', $out[0][0]);
        }
        return $out;
    }

    /** Map a header row to canonical-key => column-index. */
    protected function mapHeaders(array $headerRow): array
    {
        $normalized = [];
        foreach ($headerRow as $idx => $name) {
            $norm = strtolower(trim((string) $name));
            if ($norm !== '' && !isset($normalized[$norm])) {
                $normalized[$norm] = $idx;
            }
        }

        $map = [];
        foreach ($this->headerAliases as $canonical => $aliases) {
            foreach ($aliases as $alias) {
                if (isset($normalized[$alias])) {
                    $map[$canonical] = $normalized[$alias];
                    break;
                }
            }
        }
        return $map;
    }

    /**
     * Refuse to post a file under a different chunk_size than the one already
     * used to post some of its chunks (would otherwise duplicate sales).
     */
    protected function assertChunkSizeStable(DraftInvoiceRun $run, string $fileHash): void
    {
        $priorPostedRun = DraftInvoiceRun::query()
            ->where('file_hash', $fileHash)
            ->where('mode', 'post')
            ->whereIn('status', ['running', 'done'])
            ->where('id', '!=', $run->id)
            ->whereHas('chunks', fn ($q) => $q->where('status', 'posted'))
            ->orderBy('id')
            ->first();

        if ($priorPostedRun && (int) $priorPostedRun->chunk_size !== (int) $run->chunk_size) {
            throw new \RuntimeException(
                "This file was already partially posted with chunk size {$priorPostedRun->chunk_size}. " .
                "Re-run with --chunk={$priorPostedRun->chunk_size} to stay idempotent (different chunking would duplicate drafts)."
            );
        }
    }

    protected function logActivity(string $resource, array $payload, $response, int $status): void
    {
        try {
            ApiLog::create([
                'user_id' => auth()->id(),
                'method' => 'POST (DraftInvoice)',
                'endpoint' => $resource,
                'status_code' => $status,
                'request_payload' => json_encode($payload),
                'response_body' => json_encode($response),
                'database_name' => $this->sap->getCompanyDb(),
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);
        } catch (\Throwable $e) {
            // best-effort logging
        }
    }
}
