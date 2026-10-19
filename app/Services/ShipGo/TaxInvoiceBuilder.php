<?php

namespace App\Services\ShipGo;

use App\Support\ArabicAmount;
use DOMDocument;
use DOMXPath;

/**
 * Turns a full SAP A/R invoice (Service Layer JSON) into the data printed on
 * a Saudi tax invoice.
 *
 * Source of truth for everything ZATCA regulates (seller/buyer legal names,
 * VAT and CR numbers, national addresses, issue date/time, supply date,
 * totals, VAT breakdown, QR) is the e-invoice XML stored by the SAP ZATCA
 * add-on: the ZATCA-*cleared* XML (UDF U_ERRPRINV.clearedInvoice) when
 * present, else the signed XML (U_SIGNDINV). SAP document fields are the
 * fallback and supply what the XML lacks (item codes, barcodes, units).
 * Nothing is recomputed or re-signed: the QR is printed exactly as issued.
 */
class TaxInvoiceBuilder
{
    private const NS = [
        'i'   => 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2',
        'cac' => 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2',
        'cbc' => 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2',
    ];

    public function __construct(private ShipGoSapService $sap) {}

    public function build(array $doc): array
    {
        $zatca = $this->zatca($doc);
        $x     = $zatca['xpath'];
        $brand = $this->sap->brand();

        $v = fn (string $q) => $x ? $this->text($x, $q) : null;

        // ---- invoice type: 01xxxxx standard (B2B), 02xxxxx simplified (B2C)
        $typeName = $x ? ($x->query('/i:Invoice/cbc:InvoiceTypeCode')->item(0)?->getAttribute('name')) : null;
        $simplified = $typeName ? str_starts_with($typeName, '02') : empty($doc['FederalTaxID']);

        // ---- parties
        $seller = $x ? $this->party($x, 'AccountingSupplierParty') : [];
        $seller += [
            'name'    => $doc['BPLName'] ?? ($brand['company_name_ar'] ?? null),
            'vat'     => $doc['VATRegNum'] ?? ($brand['company_vat'] ?? null),
            'ids'     => [],
            'address' => $brand['company_address'] ?? null,
        ];

        $buyer = $x ? $this->party($x, 'AccountingCustomerParty') : [];
        $bill  = $doc['AddressExtension'] ?? [];
        $buyer += [
            'name'    => $doc['CardName'] ?? null,
            'vat'     => $doc['FederalTaxID'] ?? null,
            'ids'     => [],
            'address' => $this->joinAddress([
                trim(($bill['BillToBuilding'] ?? '') . ' ' . ($bill['BillToStreetNo'] ?? $bill['BillToStreet'] ?? '')),
                $bill['BillToCounty'] ?? null, $bill['BillToCity'] ?? null, $bill['BillToZipCode'] ?? null,
            ]) ?: str_replace("\r", '، ', (string) ($doc['Address2'] ?? $doc['Address'] ?? '')),
        ];
        $buyer['code'] = $doc['CardCode'] ?? null;

        // ---- lines (SAP: item code, barcode, unit; amounts as cleared)
        $lines = [];
        foreach ($doc['DocumentLines'] ?? [] as $l) {
            if (($l['LineType'] ?? 'dlt_Regular') !== 'dlt_Regular') {
                continue;
            }
            $net = round((float) ($l['LineTotal'] ?? 0), 2);
            $vat = round((float) ($l['TaxTotal'] ?? 0), 2);
            $unit = $l['UoMCode'] ?? $l['MeasureUnit'] ?? null;
            $lines[] = [
                'no'          => count($lines) + 1,
                'code'        => $l['ItemCode'] ?? null,
                'barcode'     => $l['BarCode'] ?? null,
                'description' => $l['ItemDescription'] ?? '',
                'qty'         => (float) ($l['Quantity'] ?? 0),
                'unit'        => in_array($unit, ['Manual', ''], true) ? null : $unit,
                'unit_price'  => (float) ($l['UnitPrice'] ?? $l['Price'] ?? 0),
                'discount'    => (float) ($l['DiscountPercent'] ?? 0),
                'net'         => $net,
                'vat_rate'    => (float) ($l['TaxPercentagePerRow'] ?? 0),
                'vat'         => $vat,
                'total'       => round($net + $vat, 2),
            ];
        }

        // ---- document-level charges (freight …) and discount
        $charges = [];
        foreach ($doc['DocumentAdditionalExpenses'] ?? [] as $e) {
            $amount = round((float) ($e['LineTotal'] ?? 0), 2);
            if (abs($amount) < 0.005) {
                continue;
            }
            $name = $this->sap->expenseName((int) ($e['ExpenseCode'] ?? 0));
            $charges[] = [
                'name'     => $name ?: 'مصاريف إضافية',
                'net'      => $amount,
                'vat_rate' => (float) ($e['TaxPercent'] ?? 0),
                'vat'      => round((float) ($e['TaxSum'] ?? 0), 2),
            ];
        }

        $linesNet   = round(array_sum(array_column($lines, 'net')), 2);
        $chargesNet = round(array_sum(array_column($charges, 'net')), 2);
        $discount   = round((float) ($doc['TotalDiscount'] ?? 0), 2);

        // ---- totals: as cleared by ZATCA when available
        $num = fn ($q) => ($t = $v($q)) !== null && $t !== '' ? round((float) $t, 2) : null;
        $taxable = $num('/i:Invoice/cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount') ?? round($linesNet - $discount + $chargesNet, 2);
        $vatSum  = $num('/i:Invoice/cac:TaxTotal[cac:TaxSubtotal]/cbc:TaxAmount') ?? round((float) ($doc['VatSum'] ?? 0), 2);
        $total   = $num('/i:Invoice/cac:LegalMonetaryTotal/cbc:TaxInclusiveAmount') ?? round((float) ($doc['DocTotal'] ?? 0), 2);
        $payable = $num('/i:Invoice/cac:LegalMonetaryTotal/cbc:PayableAmount') ?? round((float) ($doc['DocTotal'] ?? 0), 2);
        $prepaid = $num('/i:Invoice/cac:LegalMonetaryTotal/cbc:PrepaidAmount') ?? 0.0;
        $rounding = round((float) ($doc['RoundingDiffAmount'] ?? 0), 2);
        $paid     = round((float) ($doc['PaidToDate'] ?? 0), 2);

        $vatBreakdown = [];
        if ($x) {
            foreach ($x->query('/i:Invoice/cac:TaxTotal/cac:TaxSubtotal') as $sub) {
                $vatBreakdown[] = [
                    'category' => $this->text($x, 'cac:TaxCategory/cbc:ID', $sub),
                    'rate'     => (float) $this->text($x, 'cac:TaxCategory/cbc:Percent', $sub),
                    'taxable'  => round((float) $this->text($x, 'cbc:TaxableAmount', $sub), 2),
                    'vat'      => round((float) $this->text($x, 'cbc:TaxAmount', $sub), 2),
                    'reason'   => $this->text($x, 'cac:TaxCategory/cbc:TaxExemptionReason', $sub),
                ];
            }
        }

        $issueDate = $v('/i:Invoice/cbc:IssueDate') ?? $this->sapDate($doc['DocDate'] ?? null);
        $issueTime = $v('/i:Invoice/cbc:IssueTime') ?? ($doc['DocTime'] ?? null);

        return [
            'simplified'   => $simplified,
            'title_ar'     => $simplified ? 'فاتورة ضريبية مبسطة' : 'فاتورة ضريبية',
            'title_en'     => $simplified ? 'Simplified Tax Invoice' : 'Tax Invoice',
            'number'       => (string) ($doc['DocNum'] ?? ''),
            'doc_entry'    => (int) ($doc['DocEntry'] ?? 0),
            'issue_date'   => $issueDate,
            'issue_time'   => $issueTime ? substr($issueTime, 0, 8) : null,
            'supply_date'  => $v('/i:Invoice/cac:Delivery/cbc:ActualDeliveryDate') ?? $this->sapDate($doc['TaxDate'] ?? null),
            'due_date'     => $this->sapDate($doc['DocDueDate'] ?? null),
            'customer_ref' => $doc['NumAtCard'] ?? null,
            'currency'     => $v('/i:Invoice/cbc:DocumentCurrencyCode') ?? ($doc['DocCurrency'] ?? 'SAR'),
            'seller'       => $seller,
            'buyer'        => $buyer,
            'lines'        => $lines,
            'charges'      => $charges,
            'totals'       => [
                'lines_net' => $linesNet,
                'discount'  => $discount,
                'charges'   => $chargesNet,
                'taxable'   => $taxable,
                'vat'       => $vatSum,
                'total'     => $total,
                'prepaid'   => $prepaid,
                'rounding'  => $rounding,
                'payable'   => $payable,
                'paid'      => $paid,
                'balance'   => round($payable - $paid, 2),
            ],
            'vat_breakdown' => $vatBreakdown,
            'amount_words'  => ArabicAmount::riyals($payable),
            'notes'         => $this->notes($doc['Comments'] ?? null),
            'cancelled'     => ($doc['Cancelled'] ?? 'tNO') === 'tYES',
            'zatca'         => array_diff_key($zatca, ['xpath' => 1]),
            'brand'         => $brand,
        ];
    }

    /** ZATCA e-invoice data from the SAP add-on UDFs. */
    private function zatca(array $doc): array
    {
        $status = null;
        $xml    = null;
        if (!empty($doc['U_ERRPRINV'])) {
            $j = json_decode($doc['U_ERRPRINV'], true);
            if (is_array($j)) {
                $status = $j['clearanceStatus'] ?? $j['reportingStatus'] ?? null;
                if (!empty($j['clearedInvoice'])) {
                    $xml = base64_decode($j['clearedInvoice'], true) ?: null;
                }
            }
        }
        $source = $xml ? 'cleared' : null;
        if (!$xml && !empty($doc['U_SIGNDINV'])) {
            $xml    = base64_decode($doc['U_SIGNDINV'], true) ?: null;
            $source = $xml ? 'signed' : null;
        }

        $xpath = null;
        if ($xml) {
            $dom = new DOMDocument();
            if (@$dom->loadXML($xml, LIBXML_NONET)) {
                $xpath = new DOMXPath($dom);
                foreach (self::NS as $p => $ns) {
                    $xpath->registerNamespace($p, $ns);
                }
            }
        }

        $qr = $xpath ? $this->text($xpath, "/i:Invoice/cac:AdditionalDocumentReference[cbc:ID='QR']/cac:Attachment/cbc:EmbeddedDocumentBinaryObject") : null;
        $qr = $qr ?: ($doc['U_PH2QRCD'] ?? null);

        return [
            'xpath'       => $xpath,
            'source'      => $source,                                  // cleared | signed | null
            'status'      => $status,                                  // CLEARED | REPORTED | …
            'reported'    => ($doc['U_ZTRPTFLG'] ?? null) === 'Y',
            'reported_at' => $doc['U_ZTRPTDT'] ?? null,
            'qr'          => $qr ?: null,
            'qr_png'      => $qr ? self::qrPng($qr) : null,
            'hash'        => $doc['U_INVHASH'] ?? null,
            'icv'         => $xpath ? $this->text($xpath, "/i:Invoice/cac:AdditionalDocumentReference[cbc:ID='ICV']/cbc:UUID") : null,
        ];
    }

    /**
     * QR as a PNG data URI. Rendered here (not via mPDF's <barcode> tag, whose
     * attribute parser breaks on base64 values ending in "=") — the payload is
     * the ZATCA base64 TLV text exactly as issued.
     */
    public static function qrPng(string $payload): ?string
    {
        try {
            $qr  = new \Mpdf\QrCode\QrCode($payload, 'M');
            $png = (new \Mpdf\QrCode\Output\Png())->output($qr, 320, [255, 255, 255], [0, 0, 0], 9);
            return 'data:image/png;base64,' . base64_encode($png);
        } catch (\Throwable) {
            return null;
        }
    }

    private function party(DOMXPath $x, string $role): array
    {
        $p = $x->query("/i:Invoice/cac:{$role}/cac:Party")->item(0);
        if (!$p) {
            return [];
        }
        $t = fn (string $q) => $this->text($x, $q, $p);

        $ids = [];
        foreach ($x->query('cac:PartyIdentification/cbc:ID', $p) as $id) {
            $val = trim($id->textContent);
            if ($val !== '') {
                $ids[] = ['scheme' => $id->getAttribute('schemeID'), 'value' => $val];
            }
        }

        $addr = 'cac:PostalAddress/';
        $parts = [
            'building' => $t($addr . 'cbc:BuildingNumber'),
            'street'   => $this->ar($t($addr . 'cbc:StreetName')),
            'extra'    => $this->ar($t($addr . 'cbc:AdditionalStreetName')),
            'district' => $this->ar($t($addr . 'cbc:CitySubdivisionName')),
            'city'     => $this->ar($t($addr . 'cbc:CityName')),
            'postal'   => $t($addr . 'cbc:PostalZone'),
            'plot'     => $t($addr . 'cbc:PlotIdentification'),
            'country'  => $t($addr . 'cac:Country/cbc:IdentificationCode'),
        ];

        return array_filter([
            'name'    => $t('cac:PartyLegalEntity/cbc:RegistrationName'),
            'vat'     => $t('cac:PartyTaxScheme/cbc:CompanyID'),
            'ids'     => $ids,
            'address' => $this->joinAddress([
                trim(($parts['building'] ?? '') . ' ' . ($parts['street'] ?? '')),
                $parts['extra'], $parts['district'], $parts['city'],
                $parts['postal'] ? 'ر.ب ' . $parts['postal'] : null,
                $parts['plot'] ? 'الرقم الإضافي ' . $parts['plot'] : null,
                $parts['country'] === 'SA' ? 'المملكة العربية السعودية' : $parts['country'],
            ]),
        ], fn ($val) => $val !== null && $val !== '' && $val !== []);
    }

    /** "الرياض | Riyadh" → "الرياض" (the add-on stores AR | EN pairs). */
    private function ar(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }
        $value = trim(explode('|', $value)[0]);
        return $value === '' ? null : $value;
    }

    private function joinAddress(array $parts): ?string
    {
        $parts = array_filter(array_map(fn ($p) => $p === null ? null : trim((string) $p), $parts), fn ($p) => $p !== null && $p !== '');
        return $parts ? implode('، ', $parts) : null;
    }

    /** Internal import markers are not customer-facing notes. */
    private function notes(?string $comments): ?string
    {
        $comments = trim((string) $comments);
        if ($comments === '' || preg_match('/^Sales import \|/i', $comments)) {
            return null;
        }
        return $comments;
    }

    private function text(DOMXPath $x, string $query, ?\DOMNode $ctx = null): ?string
    {
        $n = $x->query($query, $ctx)->item(0);
        if (!$n) {
            return null;
        }
        $t = trim($n->textContent);
        return $t === '' ? null : $t;
    }

    private function sapDate(?string $value): ?string
    {
        return $value ? substr($value, 0, 10) : null;
    }
}
