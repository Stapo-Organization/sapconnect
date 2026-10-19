<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Read-only mirror of an A/R invoice header of the ShipGo SAP company.
 * Lines, totals and the ZATCA e-invoice are fetched from SAP when the PDF is
 * printed. Refreshed by `shipgo:sync-invoices`.
 */
class ShipGoInvoice extends Model
{
    protected $table = 'shipgo_invoices';

    /** @var class-string<ShipGoCustomer> */
    protected static string $customerModel = ShipGoCustomer::class;

    protected $guarded = ['id'];

    protected $casts = [
        'doc_entry'         => 'integer',
        'doc_date'          => 'date',
        'doc_due_date'      => 'date',
        'tax_date'          => 'date',
        'doc_total'         => 'decimal:2',
        'vat_sum'           => 'decimal:2',
        'paid_to_date'      => 'decimal:2',
        'cancelled'         => 'boolean',
        'zatca_reported'    => 'boolean',
        'zatca_reported_at' => 'datetime',
        'sap_update_date'   => 'date',
        'synced_at'         => 'datetime',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(static::$customerModel, 'card_code', 'card_code');
    }

    public function getBalanceAttribute(): float
    {
        return round((float) $this->doc_total - (float) $this->paid_to_date, 2);
    }

    /** open | paid | cancelled — for badges and filters. */
    public function getStateAttribute(): string
    {
        if ($this->cancelled) {
            return 'cancelled';
        }
        return $this->status === 'closed' ? 'paid' : 'open';
    }

    public static function attributesFromSap(array $d): array
    {
        $date = fn ($v) => ShipGoCustomer::sapDate($v);
        $zdt  = $d['U_ZTRPTDT'] ?? null;

        return [
            'doc_entry'         => (int) $d['DocEntry'],
            'doc_num'           => (string) ($d['DocNum'] ?? ''),
            'card_code'         => $d['CardCode'] ?? null,
            'card_name'         => $d['CardName'] ?? null,
            'doc_date'          => $date($d['DocDate'] ?? null),
            'doc_time'          => $d['DocTime'] ?? null,
            'doc_due_date'      => $date($d['DocDueDate'] ?? null),
            'tax_date'          => $date($d['TaxDate'] ?? null),
            'doc_total'         => round((float) ($d['DocTotal'] ?? 0), 2),
            'vat_sum'           => round((float) ($d['VatSum'] ?? 0), 2),
            'paid_to_date'      => round((float) ($d['PaidToDate'] ?? 0), 2),
            'doc_currency'      => $d['DocCurrency'] ?? 'SAR',
            'status'            => ($d['DocumentStatus'] ?? '') === 'bost_Close' ? 'closed' : 'open',
            'cancelled'         => ($d['Cancelled'] ?? 'tNO') === 'tYES',
            'num_at_card'       => $d['NumAtCard'] ?? null,
            'comments'          => $d['Comments'] ?? null,
            'buyer_vat'         => $d['FederalTaxID'] ?? null,
            'zatca_reported'    => ($d['U_ZTRPTFLG'] ?? null) === 'Y',
            'zatca_reported_at' => $zdt && strtotime($zdt) ? date('Y-m-d H:i:s', strtotime($zdt)) : null,
            'sap_update_date'   => $date($d['UpdateDate'] ?? null),
            'synced_at'         => now(),
        ];
    }
}
