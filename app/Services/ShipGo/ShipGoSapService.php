<?php

namespace App\Services\ShipGo;

use App\Exceptions\SapException;
use App\Services\SAP\SapClient;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;

/**
 * READ-ONLY access to the ShipGo SAP company (SHIPGO_LIVE_V1).
 *
 * Only `SapClient::get()` is ever used here: customers are mirrored into
 * `shipgo_customers`, and account statements are read on demand. Nothing is
 * written to SAP.
 */
class ShipGoSapService
{
    /** SAP page size. The Service Layer may cap pages lower; we loop until empty. */
    public const PAGE = 100;

    /** JDT1.TransType → Arabic label. */
    public const TRANS_TYPES = [
        '13'  => 'فاتورة مبيعات',
        '14'  => 'إشعار دائن',
        '15'  => 'إشعار تسليم',
        '16'  => 'مرتجع',
        '18'  => 'فاتورة مشتريات',
        '19'  => 'إشعار دائن مشتريات',
        '24'  => 'دفعة واردة',
        '25'  => 'إيداع',
        '30'  => 'قيد يومية',
        '46'  => 'دفعة صادرة',
        '57'  => 'شيكات صادرة',
        '58'  => 'إيداع',
        '163' => 'إشعار دائن مشتريات (تصحيح)',
        '165' => 'إشعار دائن (تصحيح)',
        '203' => 'دفعة مقدمة (عميل)',
        '204' => 'دفعة مقدمة (مورد)',
        '321' => 'تسوية داخلية',
        '-2'  => 'رصيد افتتاحي',
        '-3'  => 'رصيد افتتاحي',
    ];

    /** JDT1.TransType → SAP origin code as printed on the official statement. */
    public const ORIGIN_CODES = [
        '13' => 'IN', '14' => 'CN', '15' => 'DN', '16' => 'RE', '18' => 'PU', '19' => 'PC',
        '24' => 'RC', '25' => 'DP', '30' => 'JE', '46' => 'PS', '57' => 'CP', '58' => 'DP',
        '163' => 'PC', '165' => 'CN', '203' => 'DT', '204' => 'DT', '321' => 'IR', '-2' => 'OB', '-3' => 'OB',
    ];

    protected ?SapClient $client = null;

    public function companyDb(): string
    {
        return (string) config('sap.shipgo_company_db', 'SHIPGO_LIVE_V1');
    }

    /**
     * A dedicated client bound to the ShipGo company. We build our own
     * instance so the request-scoped client (forced to PPTC_V5_PROD by the
     * SetSapEnvironment middleware) is never switched under other code.
     */
    public function client(): SapClient
    {
        if (!$this->client) {
            $this->client = new SapClient();
            $this->client->setCompanyDb($this->companyDb());
        }
        return $this->client;
    }

    // ------------------------------------------------------------------
    // Customers
    // ------------------------------------------------------------------

    public const BP_SELECT = 'CardCode,CardName,CardForeignName,CardType,GroupCode,Currency,Phone1,Cellular,EmailAddress,ContactPerson,City,Country,Address,ZipCode,FederalTaxID,PayTermsGrpCode,CreditLimit,CurrentAccountBalance,OpenOrdersBalance,OpenDeliveryNotesBalance,Valid,Frozen,CreateDate,UpdateDate';

    /**
     * Stream every customer of the ShipGo company. $each receives the raw
     * Service Layer row. Returns the number of rows seen.
     */
    public function eachCustomer(callable $each): int
    {
        $skip  = 0;
        $total = 0;

        while (true) {
            $resp = $this->client()->get('BusinessPartners', [
                '$filter'  => "CardType eq 'cCustomer'",
                '$select'  => self::BP_SELECT,
                '$orderby' => 'CardCode',
                '$top'     => self::PAGE,
                '$skip'    => $skip,
            ]);

            $rows = $resp['value'] ?? [];
            if (empty($rows)) {
                break;
            }

            foreach ($rows as $row) {
                $each($row);
                $total++;
            }

            $skip += count($rows);
        }

        return $total;
    }

    /**
     * Mirror every customer into `shipgo_customers` (used by the command and
     * the admin "Sync from SAP" button).
     *
     * @return array{total:int, created:int, updated:int}
     */
    public function syncCustomers(): array
    {
        $created = 0;
        $updated = 0;

        $total = $this->eachCustomer(function (array $bp) use (&$created, &$updated) {
            if (empty($bp['CardCode'])) {
                return;
            }
            $row = \App\Models\ShipGoCustomer::firstOrNew(['card_code' => $bp['CardCode']]);
            $row->fill(\App\Models\ShipGoCustomer::attributesFromSap($bp));
            $row->exists ? $updated++ : $created++;
            $row->save();
        });

        return ['total' => $total, 'created' => $created, 'updated' => $updated];
    }

    public function fetchCustomer(string $cardCode): ?array
    {
        $code = str_replace("'", "''", $cardCode);
        $resp = $this->client()->get("BusinessPartners('{$code}')", ['$select' => self::BP_SELECT]);
        return $resp ?: null;
    }

    // ------------------------------------------------------------------
    // Account statement
    // ------------------------------------------------------------------

    /**
     * Customer statement for [$from, $to] (inclusive), oldest first.
     *
     * Returns:
     *  [
     *    'source'  => 'ledger' | 'documents',
     *    'opening' => float,               // balance before $from (debit positive)
     *    'lines'   => [ ['date','trans_id','trans_type','type_label','ref_no','memo','debit','credit','balance'], ... ],
     *    'debit'   => float, 'credit' => float, 'closing' => float,
     *  ]
     *
     * `ledger` = exact JDT1 lines via the SAP user query configured in
     * sap.shipgo.statement_query. `documents` = fallback built from A/R
     * invoices, credit memos and incoming payments when that query does not
     * exist in the company (manual journal entries are then not included).
     */
    public function statement(string $cardCode, Carbon $from, Carbon $to): array
    {
        try {
            $raw = $this->ledgerRows($cardCode, $from, $to);
            return $this->buildStatement('ledger', $raw, $from);
        } catch (SapException $e) {
            if (!$this->isMissingQuery($e)) {
                throw $e;
            }
            Log::warning("ShipGo statement: user query missing in {$this->companyDb()}, falling back to documents. " . $e->getMessage());
        }

        $raw = $this->documentRows($cardCode, $to);
        return $this->buildStatement('documents', $raw, $from);
    }

    /**
     * Raw ledger rows from the SAP user query. Each row:
     * ['date' => 'YYYY-MM-DD', 'trans_id', 'trans_type', 'ref_no', 'memo', 'debit', 'credit'].
     * Rows on or before $to are returned (the query itself returns history
     * before $from as "Forwarded Balances"); the caller splits by date.
     */
    protected function ledgerRows(string $cardCode, Carbon $from, Carbon $to): array
    {
        $query = config('sap.shipgo.statement_query', 'SqlCustomerStatementOCRD01');
        $code  = str_replace("'", "''", $cardCode);

        $resp = $this->client()->get("SQLQueries('{$query}')/List", [
            'FromDate' => "'" . $from->toDateString() . "'",
            'ToDate'   => "'" . $to->toDateString() . "'",
            'CardCode' => "'{$code}'",
        ]);

        $rows = [];
        $seen = [];
        foreach ($resp['value'] ?? [] as $r) {
            $date = $this->sapDate($r['RefDate'] ?? null);
            // The query returns the rows dated exactly $from twice (forwarded +
            // transaction); keep one copy per (TransId, amounts, ref).
            $key = ($r['TransId'] ?? '') . '|' . ($r['TotalDebit'] ?? 0) . '|' . ($r['TotalCredit'] ?? 0) . '|' . ($r['RefNo'] ?? '') . '|' . $date;
            if (isset($seen[$key])) {
                // Prefer the "Transaction" copy because it carries the memo.
                if (($r['Remarks'] ?? '') === 'Transaction') {
                    $rows[$seen[$key]]['memo'] = $this->cleanMemo($r['JrnlMemo'] ?? null);
                }
                continue;
            }
            $seen[$key] = count($rows);
            $rows[] = [
                'date'           => $date,
                'due_date'       => $date,
                'trans_id'       => $r['TransId'] ?? null,
                'trans_type'     => (string) ($r['TransType'] ?? ''),
                'ref_no'         => $r['RefNo'] ?? null,
                'offset_account' => null,
                'memo'           => $this->cleanMemo($r['JrnlMemo'] ?? null),
                'debit'          => (float) ($r['TotalDebit'] ?? 0),
                'credit'         => (float) ($r['TotalCredit'] ?? 0),
            ];
        }

        return $rows;
    }

    /**
     * Fallback rows built from marketing documents (no JDT1 access needed).
     */
    protected function documentRows(string $cardCode, Carbon $to): array
    {
        $code  = str_replace("'", "''", $cardCode);
        $toStr = $to->toDateString();
        $rows  = [];

        // A/R invoices → debit
        foreach ($this->pages('Invoices', [
            '$filter'  => "CardCode eq '{$code}' and Cancelled eq 'tNO' and DocDate le '{$toStr}'",
            '$select'  => 'DocEntry,DocNum,DocDate,DocDueDate,DocTotal,NumAtCard,Comments,TransNum,DocumentLines',
            '$orderby' => 'DocDate,DocEntry',
        ]) as $d) {
            $rows[] = $this->docRow($d, '13', (float) $d['DocTotal'], 0.0, "A/R Invoices - {$cardCode}", $this->firstLineAccount($d));
        }

        // A/R credit memos → credit
        foreach ($this->pages('CreditNotes', [
            '$filter'  => "CardCode eq '{$code}' and Cancelled eq 'tNO' and DocDate le '{$toStr}'",
            '$select'  => 'DocEntry,DocNum,DocDate,DocDueDate,DocTotal,NumAtCard,Comments,TransNum,DocumentLines',
            '$orderby' => 'DocDate,DocEntry',
        ]) as $d) {
            $rows[] = $this->docRow($d, '14', 0.0, (float) $d['DocTotal'], "A/R Credit Memos - {$cardCode}", $this->firstLineAccount($d));
        }

        // Incoming payments → credit
        foreach ($this->pages('IncomingPayments', [
            '$filter'  => "CardCode eq '{$code}' and Cancelled eq 'tNO' and DocDate le '{$toStr}'",
            '$select'  => 'DocEntry,DocNum,DocDate,DueDate,CashSum,TransferSum,BillOfExchangeAmount,CashAccount,TransferAccount,Remarks,PaymentChecks,PaymentCreditCards',
            '$orderby' => 'DocDate,DocEntry',
        ]) as $d) {
            // Checks and credit cards live in child collections.
            $checks = array_sum(array_map(fn ($c) => (float) ($c['CheckSum'] ?? 0), $d['PaymentChecks'] ?? []));
            $cards  = array_sum(array_map(fn ($c) => (float) ($c['CreditSum'] ?? 0), $d['PaymentCreditCards'] ?? []));
            $amount = (float) ($d['CashSum'] ?? 0) + (float) ($d['TransferSum'] ?? 0)
                + (float) ($d['BillOfExchangeAmount'] ?? 0) + $checks + $cards;
            $offset = ($d['TransferSum'] ?? 0) > 0 ? ($d['TransferAccount'] ?? null) : null;
            $offset = $offset ?: (($d['CashSum'] ?? 0) > 0 ? ($d['CashAccount'] ?? null) : null);
            $offset = $offset ?: ($d['PaymentCreditCards'][0]['CreditAcct'] ?? null);
            $offset = $offset ?: ($d['PaymentChecks'][0]['CheckAccount'] ?? null);
            $rows[] = $this->docRow($d, '24', 0.0, $amount, "Incoming Payments - {$cardCode}", $offset);
        }

        usort($rows, fn ($a, $b) => [$a['date'], $a['trans_id']] <=> [$b['date'], $b['trans_id']]);

        return $rows;
    }

    protected function docRow(array $d, string $type, float $debit, float $credit, string $details, ?string $offset): array
    {
        $date = $this->sapDate($d['DocDate'] ?? null);
        return [
            'date'           => $date,
            'due_date'       => $this->sapDate($d['DocDueDate'] ?? $d['DueDate'] ?? null) ?: $date,
            'trans_id'       => $d['TransNum'] ?? $d['DocEntry'] ?? null,
            'trans_type'     => $type,
            'ref_no'         => $d['DocNum'] ?? null,
            'offset_account' => $offset,
            'memo'           => $details,
            'comments'       => $this->cleanMemo($d['Comments'] ?? $d['Remarks'] ?? null),
            'debit'          => $debit,
            'credit'         => $credit,
        ];
    }

    /** G/L account of the first document line (revenue account on service invoices). */
    protected function firstLineAccount(array $d): ?string
    {
        foreach ($d['DocumentLines'] ?? [] as $line) {
            if (!empty($line['AccountCode'])) {
                return $line['AccountCode'];
            }
        }
        return null;
    }

    /**
     * Split raw rows into opening balance + period lines with running balance.
     */
    public function buildStatement(string $source, array $rows, Carbon $from): array
    {
        $fromStr = $from->toDateString();
        $opening = 0.0;
        $lines   = [];

        foreach ($rows as $r) {
            if ($r['date'] !== null && $r['date'] < $fromStr) {
                $opening += $r['debit'] - $r['credit'];
                continue;
            }
            $lines[] = $r;
        }

        // Ledger rows carry the real JE number; document rows do not (payments
        // have no TransNum), so within a day SAP's posting order is approximated
        // as invoices/credit memos first, then payments, then document number.
        $rank = fn ($r) => $source === 'ledger'
            ? [$r['date'], (int) $r['trans_id']]
            : [$r['date'], in_array($r['trans_type'], ['13', '14'], true) ? 0 : 1, (int) $r['ref_no']];
        usort($lines, fn ($a, $b) => $rank($a) <=> $rank($b));

        $balance = $opening;
        $debit   = 0.0;
        $credit  = 0.0;
        foreach ($lines as &$l) {
            $debit   += $l['debit'];
            $credit  += $l['credit'];
            $balance += $l['debit'] - $l['credit'];
            $l['balance']    = round($balance, 2) + 0.0;
            $l['type_label'] = self::TRANS_TYPES[$l['trans_type']] ?? ('نوع ' . $l['trans_type']);
            $l['origin']     = self::ORIGIN_CODES[$l['trans_type']] ?? $l['trans_type'];
            $l['due_date']   = $l['due_date'] ?? $l['date'];
            $l['offset_account'] = $l['offset_account'] ?? null;
        }
        unset($l);

        return [
            'source'  => $source,
            'opening' => round($opening, 2) + 0.0,   // "+ 0.0" turns -0.0 into 0.0
            'lines'   => $lines,
            'debit'   => round($debit, 2) + 0.0,
            'credit'  => round($credit, 2) + 0.0,
            'closing' => round($balance, 2) + 0.0,
        ];
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------

    /** Iterate every row of a paged Service Layer collection. */
    protected function pages(string $resource, array $query): \Generator
    {
        $skip = 0;
        while (true) {
            $resp = $this->client()->get($resource, $query + ['$top' => self::PAGE, '$skip' => $skip]);
            $rows = $resp['value'] ?? [];
            if (empty($rows)) {
                return;
            }
            foreach ($rows as $row) {
                yield $row;
            }
            $skip += count($rows);
        }
    }

    protected function isMissingQuery(SapException $e): bool
    {
        $msg = strtolower($e->getMessage());
        return $e->getCode() === 404
            || str_contains($msg, 'not found')
            || str_contains($msg, 'does not exist')
            || str_contains($msg, 'invalid query')
            || str_contains($msg, 'no matching');
    }

    public function sapDate(?string $value): ?string
    {
        if (!$value) {
            return null;
        }
        if (preg_match('/^(\d{4})(\d{2})(\d{2})$/', $value, $m)) {
            return "{$m[1]}-{$m[2]}-{$m[3]}";
        }
        return substr($value, 0, 10);
    }

    protected function cleanMemo(?string $memo): ?string
    {
        if ($memo === null) {
            return null;
        }
        $memo = trim($memo);
        return ($memo === '' || $memo === 'NULL') ? null : $memo;
    }
}
