<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Read-only mirror of a ShipGo SAP company customer (OCRD, CardType = C).
 * Rows are refreshed by `shipgo:sync-customers`; the admin never edits them.
 */
class ShipGoCustomer extends Model
{
    protected $table = 'shipgo_customers';

    protected $fillable = [
        'card_code',
        'card_name',
        'card_foreign_name',
        'group_code',
        'currency',
        'phone1',
        'cellular',
        'email_address',
        'contact_person',
        'city',
        'country',
        'address',
        'federal_tax_id',
        'pay_terms_grp_code',
        'credit_limit',
        'current_account_balance',
        'open_orders_balance',
        'open_delivery_notes_balance',
        'valid',
        'frozen',
        'sap_create_date',
        'sap_update_date',
        'synced_at',
    ];

    protected $casts = [
        'credit_limit'                => 'decimal:2',
        'current_account_balance'     => 'decimal:2',
        'open_orders_balance'         => 'decimal:2',
        'open_delivery_notes_balance' => 'decimal:2',
        'valid'                       => 'boolean',
        'frozen'                      => 'boolean',
        'sap_create_date'             => 'date',
        'sap_update_date'             => 'date',
        'synced_at'                   => 'datetime',
    ];

    /**
     * Map one Service Layer BusinessPartners row to our columns.
     */
    public static function attributesFromSap(array $bp): array
    {
        $addr = array_filter([
            $bp['Address'] ?? null,
            $bp['ZipCode'] ?? null,
        ]);

        return [
            'card_name'                   => $bp['CardName'] ?? null,
            'card_foreign_name'           => $bp['CardForeignName'] ?? null,
            'group_code'                  => $bp['GroupCode'] ?? null,
            'currency'                    => $bp['Currency'] ?? null,
            'phone1'                      => $bp['Phone1'] ?? null,
            'cellular'                    => $bp['Cellular'] ?? null,
            'email_address'               => $bp['EmailAddress'] ?? null,
            'contact_person'              => $bp['ContactPerson'] ?? null,
            'city'                        => $bp['City'] ?? null,
            'country'                     => $bp['Country'] ?? null,
            'address'                     => $addr ? implode(' ', $addr) : null,
            'federal_tax_id'              => $bp['FederalTaxID'] ?? null,
            'pay_terms_grp_code'          => $bp['PayTermsGrpCode'] ?? null,
            'credit_limit'                => (float) ($bp['CreditLimit'] ?? 0),
            'current_account_balance'     => (float) ($bp['CurrentAccountBalance'] ?? 0),
            'open_orders_balance'         => (float) ($bp['OpenOrdersBalance'] ?? 0),
            'open_delivery_notes_balance' => (float) ($bp['OpenDeliveryNotesBalance'] ?? 0),
            'valid'                       => ($bp['Valid'] ?? 'tYES') === 'tYES',
            'frozen'                      => ($bp['Frozen'] ?? 'tNO') === 'tYES',
            'sap_create_date'             => self::sapDate($bp['CreateDate'] ?? null),
            'sap_update_date'             => self::sapDate($bp['UpdateDate'] ?? null),
            'synced_at'                   => now(),
        ];
    }

    public static function sapDate(?string $value): ?string
    {
        if (!$value) {
            return null;
        }
        // "2026-09-22T00:00:00Z" or "20260922"
        if (preg_match('/^(\d{4})(\d{2})(\d{2})$/', $value, $m)) {
            return "{$m[1]}-{$m[2]}-{$m[3]}";
        }
        return substr($value, 0, 10);
    }
}
