<?php

namespace Tests\Feature;

use App\Models\ShipGoInvoice;
use App\Models\User;
use App\Services\ShipGo\ShipGoSapService;
use App\Services\ShipGo\TaxInvoiceBuilder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * Tax-invoice rendering from a (synthetic) SAP document + ZATCA cleared XML.
 * SAP is faked; nothing leaves the test.
 */
class TaxInvoiceTest extends TestCase
{
    use RefreshDatabase;

    public static function ubl(string $qr = 'QRFROMCLEARED=='): string
    {
        return <<<XML
<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2" xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>26000999</cbc:ID>
  <cbc:IssueDate>2026-09-21</cbc:IssueDate>
  <cbc:IssueTime>15:44:23</cbc:IssueTime>
  <cbc:InvoiceTypeCode name="0100000">388</cbc:InvoiceTypeCode>
  <cbc:DocumentCurrencyCode>SAR</cbc:DocumentCurrencyCode>
  <cac:AdditionalDocumentReference><cbc:ID>ICV</cbc:ID><cbc:UUID>13</cbc:UUID></cac:AdditionalDocumentReference>
  <cac:AdditionalDocumentReference><cbc:ID>QR</cbc:ID><cac:Attachment><cbc:EmbeddedDocumentBinaryObject mimeCode="text/plain">{$qr}</cbc:EmbeddedDocumentBinaryObject></cac:Attachment></cac:AdditionalDocumentReference>
  <cac:AccountingSupplierParty><cac:Party>
    <cac:PartyIdentification><cbc:ID schemeID="CRN">7050000000</cbc:ID></cac:PartyIdentification>
    <cac:PostalAddress><cbc:StreetName>النصر الفرعي | Al Nasr Branch</cbc:StreetName><cbc:BuildingNumber>3678</cbc:BuildingNumber><cbc:CitySubdivisionName>حي العزيزية | Al-Aziziyah</cbc:CitySubdivisionName><cbc:CityName>الرياض | Riyadh</cbc:CityName><cbc:PostalZone>14512</cbc:PostalZone><cac:Country><cbc:IdentificationCode>SA</cbc:IdentificationCode></cac:Country></cac:PostalAddress>
    <cac:PartyTaxScheme><cbc:CompanyID>300000000000003</cbc:CompanyID><cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:PartyTaxScheme>
    <cac:PartyLegalEntity><cbc:RegistrationName>شركة البائع التجريبية</cbc:RegistrationName></cac:PartyLegalEntity>
  </cac:Party></cac:AccountingSupplierParty>
  <cac:AccountingCustomerParty><cac:Party>
    <cac:PostalAddress><cbc:StreetName>شارع المشتري</cbc:StreetName><cbc:BuildingNumber>7653</cbc:BuildingNumber><cbc:CityName>الرياض | Riyadh</cbc:CityName><cbc:PostalZone>13321</cbc:PostalZone><cac:Country><cbc:IdentificationCode>SA</cbc:IdentificationCode></cac:Country></cac:PostalAddress>
    <cac:PartyTaxScheme><cbc:CompanyID>311111111100003</cbc:CompanyID><cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:PartyTaxScheme>
    <cac:PartyLegalEntity><cbc:RegistrationName>مؤسسة المشتري</cbc:RegistrationName></cac:PartyLegalEntity>
  </cac:Party></cac:AccountingCustomerParty>
  <cac:Delivery><cbc:ActualDeliveryDate>2026-09-21</cbc:ActualDeliveryDate></cac:Delivery>
  <cac:TaxTotal><cbc:TaxAmount currencyID="SAR">172.50</cbc:TaxAmount></cac:TaxTotal>
  <cac:TaxTotal><cbc:TaxAmount currencyID="SAR">172.50</cbc:TaxAmount>
    <cac:TaxSubtotal><cbc:TaxableAmount currencyID="SAR">1150.00</cbc:TaxableAmount><cbc:TaxAmount currencyID="SAR">172.50</cbc:TaxAmount><cac:TaxCategory><cbc:ID>S</cbc:ID><cbc:Percent>15.00</cbc:Percent></cac:TaxCategory></cac:TaxSubtotal>
  </cac:TaxTotal>
  <cac:LegalMonetaryTotal>
    <cbc:LineExtensionAmount currencyID="SAR">1150.00</cbc:LineExtensionAmount>
    <cbc:TaxExclusiveAmount currencyID="SAR">1150.00</cbc:TaxExclusiveAmount>
    <cbc:TaxInclusiveAmount currencyID="SAR">1322.50</cbc:TaxInclusiveAmount>
    <cbc:PrepaidAmount currencyID="SAR">0.00</cbc:PrepaidAmount>
    <cbc:PayableAmount currencyID="SAR">1322.50</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
</Invoice>
XML;
    }

    /** SAP document: 1000 of goods + 150 freight = 1150 taxable, as cleared. */
    public static function doc(bool $withZatca = true): array
    {
        $doc = [
            'DocEntry' => 999, 'DocNum' => 26000999, 'CardCode' => 'SG0001', 'CardName' => 'مؤسسة المشتري',
            'DocDate' => '2026-09-21T00:00:00Z', 'DocTime' => '15:44:00', 'DocDueDate' => '2026-10-06T00:00:00Z',
            'TaxDate' => '2026-09-21T00:00:00Z', 'DocTotal' => 1322.5, 'VatSum' => 172.5, 'PaidToDate' => 322.5,
            'DocCurrency' => 'SAR', 'Cancelled' => 'tNO', 'FederalTaxID' => '311111111100003', 'NumAtCard' => 'PO-77',
            'Comments' => 'Sales import | file.csv | RUH003 | part 1',
            'DocumentLines' => [
                ['ItemCode' => 'P1', 'BarCode' => '628100000001', 'ItemDescription' => 'Cat food 2kg', 'Quantity' => 10, 'UnitPrice' => 100, 'DiscountPercent' => 0, 'LineTotal' => 1000, 'TaxPercentagePerRow' => 15, 'TaxTotal' => 150, 'UoMCode' => 'PC', 'LineType' => 'dlt_Regular'],
            ],
            'DocumentAdditionalExpenses' => [['ExpenseCode' => 1, 'LineTotal' => 150, 'TaxPercent' => 15, 'TaxSum' => 22.5]],
        ];
        if ($withZatca) {
            $doc += [
                'U_ZTRPTFLG' => 'Y', 'U_ZTRPTDT' => '2026-09-21 15:44:26', 'U_INVHASH' => 'HASH123=',
                'U_PH2QRCD' => 'QRFROMUDF==',
                'U_ERRPRINV' => json_encode(['clearanceStatus' => 'CLEARED', 'clearedInvoice' => base64_encode(self::ubl())]),
            ];
        }
        return $doc;
    }

    private function fakeSap(bool $withZatca = true): ShipGoSapService
    {
        $sap = new class extends ShipGoSapService {
            public bool $withZatca = true;
            public function fetchInvoice(int $docEntry): array { return TaxInvoiceTest::doc($this->withZatca); }
            public function expenseName(int $code): ?string { return 'Naqel'; }
        };
        $sap->withZatca = $withZatca;
        return $sap;
    }

    public function test_builder_uses_the_cleared_zatca_invoice(): void
    {
        $inv = (new TaxInvoiceBuilder($this->fakeSap()))->build(self::doc());

        $this->assertSame('فاتورة ضريبية', $inv['title_ar']);                    // 0100000 = standard B2B
        $this->assertSame('شركة البائع التجريبية', $inv['seller']['name']);
        $this->assertSame('300000000000003', $inv['seller']['vat']);
        $this->assertSame([['scheme' => 'CRN', 'value' => '7050000000']], $inv['seller']['ids']);
        $this->assertStringContainsString('الرياض', $inv['seller']['address']);
        $this->assertStringNotContainsString('Riyadh', $inv['seller']['address']);  // AR part of "AR | EN"
        $this->assertSame('311111111100003', $inv['buyer']['vat']);
        $this->assertSame('QRFROMCLEARED==', $inv['zatca']['qr']);               // ZATCA-stamped QR wins over the UDF
        $this->assertStringStartsWith('data:image/png;base64,', $inv['zatca']['qr_png']);
        $this->assertSame('CLEARED', $inv['zatca']['status']);
        $this->assertSame('13', $inv['zatca']['icv']);
        $this->assertSame(1000.0, $inv['totals']['lines_net']);
        $this->assertSame(150.0, $inv['totals']['charges']);
        $this->assertSame(1150.0, $inv['totals']['taxable']);
        $this->assertSame(172.5, $inv['totals']['vat']);
        $this->assertSame(1322.5, $inv['totals']['payable']);
        $this->assertSame(1000.0, $inv['totals']['balance']);                    // 1322.5 − 322.5 paid
        $this->assertNull($inv['notes']);                                         // internal import marker hidden
        $this->assertSame('فقط ألف وثلاثمائة واثنان وعشرون ريالاً سعودياً و50 هللة لا غير', $inv['amount_words']);
    }

    public function test_invoice_without_zatca_data_prints_no_qr_and_a_warning(): void
    {
        $sap = $this->fakeSap(false);
        $inv = (new TaxInvoiceBuilder($sap))->build(self::doc(false));
        $this->assertNull($inv['zatca']['qr']);
        $this->assertNull($inv['zatca']['status']);
        $this->assertSame(1322.5, $inv['totals']['payable']);                    // SAP totals as fallback

        $html = app(\App\Services\ShipGo\TaxInvoicePdf::class)->html($inv);
        $this->assertStringContainsString('ليست فاتورة إلكترونية معتمدة', $html);
        $this->assertStringNotContainsString('ZATCA QR', $html);
    }

    public function test_pdf_route_renders_for_mirrored_invoice_only(): void
    {
        config(['app.env' => 'local']);
        Role::findOrCreate('Accountant', 'web');
        $user = User::create(['name' => 'Acc', 'email' => 'acc@example.test', 'password' => bcrypt('x')]);
        $user->assignRole('Accountant');
        $this->app->instance(ShipGoSapService::class, $this->fakeSap());
        ShipGoInvoice::create(ShipGoInvoice::attributesFromSap(self::doc()));

        $html = $this->actingAs($user)->get(route('shipgo.invoices.pdf', ['docEntry' => 999, 'format' => 'html']));
        $html->assertOk()
            ->assertSee('فاتورة ضريبية')
            ->assertSee('300000000000003')
            ->assertSee('مصاريف شحن — Naqel')
            ->assertSee('data:image/png;base64,', false)
            ->assertSee('مُجازة من الهيئة');

        $pdf = $this->actingAs($user)->get(route('shipgo.invoices.pdf', ['docEntry' => 999]));
        $pdf->assertOk();
        $this->assertSame('application/pdf', $pdf->headers->get('Content-Type'));
        $this->assertStringStartsWith('%PDF', $pdf->getContent());

        $this->actingAs($user)->get(route('shipgo.invoices.pdf', ['docEntry' => 12345]))->assertNotFound();
    }

    public function test_accountant_sees_invoice_lists_in_a_grouped_sidebar(): void
    {
        config(['app.env' => 'local']);
        Role::findOrCreate('Accountant', 'web');
        $user = User::create(['name' => 'Acc', 'email' => 'acc2@example.test', 'password' => bcrypt('x')]);
        $user->assignRole('Accountant');
        ShipGoInvoice::create(ShipGoInvoice::attributesFromSap(self::doc()));

        $this->withSession([auth()->guard('web')->getName() => $user->getAuthIdentifier()])
            ->get('/admin/ship-go-invoices')
            ->assertOk()
            ->assertSee('26000999')
            ->assertSee('muntajat-invoices')
            ->assertSee('ship-go-customers')
            ->assertDontSee('SAP Management');

        $this->withSession([auth()->guard('web')->getName() => $user->getAuthIdentifier()])
            ->get('/admin/muntajat-invoices')
            ->assertOk();
    }
}
