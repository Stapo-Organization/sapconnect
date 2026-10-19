<?php

return [
    /*
    |--------------------------------------------------------------------------
    | SAP Service Layer URL
    |--------------------------------------------------------------------------
    |
    | The base URL for the SAP Business One Service Layer.
    | Example: https://sap.muntajat.sa:50000/b1s/v1
    |
    */
    'url' => env('SAP_URL', 'https://sap.muntajat.sa:50000/b1s/v1'),

    /*
    |--------------------------------------------------------------------------
    | SAP Company Database
    |--------------------------------------------------------------------------
    |
    | The name of the SAP Company Database (schema) you want to connect to.
    |
    */
    'company_db' => env('SAP_COMPANY_DB', env('SAP_DB')),

    /*
    |--------------------------------------------------------------------------
    | Authentication Credentials
    |--------------------------------------------------------------------------
    |
    | The username and password for the SAP B1 user.
    |
    */
    'username' => env('SAP_USERNAME', env('SAP_USER')),
    'password' => env('SAP_PASSWORD'),

    /*
    |--------------------------------------------------------------------------
    | SSL Verification
    |--------------------------------------------------------------------------
    |
    | Set to false if you are using self-signed certificates.
    |
    */
    'ssl_verify' => env('SAP_SSL_VERIFY', false),

    /*
    |--------------------------------------------------------------------------
    | Session Timeout (Minutes)
    |--------------------------------------------------------------------------
    |
    | How long to cache the B1SESSION in Redis. SAP default is usually 30m.
    | We set it slightly lower to ensure we refresh before it expires.
    |
    */
    'session_timeout' => 29,

    /*
    |--------------------------------------------------------------------------
    | Database Specific Credentials
    |--------------------------------------------------------------------------
    |
    | Override defaults for specific databases.
    |
    */
    'databases' => [
        'PPTC_V5_PROD' => [
            'username' => 'ppte\C001111.29',
            'password' => '$>B1$Sap4VA0',
        ],
        // ShipGo company (read-only) — same SAP user as the main company.
        'SHIPGO_LIVE_V1' => [
            'username' => env('SAP_SHIPGO_USERNAME', 'ppte\C001111.29'),
            'password' => env('SAP_SHIPGO_PASSWORD', '$>B1$Sap4VA0'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | ShipGo Company Database
    |--------------------------------------------------------------------------
    */
    'shipgo_company_db' => env('SAP_SHIPGO_DB', 'SHIPGO_LIVE_V1'),

    /*
    |--------------------------------------------------------------------------
    | ShipGo Customer Statement
    |--------------------------------------------------------------------------
    |
    | statement_query: code of the SAP user query (Query Manager → Service
    | Layer `SQLQueries`) that returns the customer's JDT1 lines. The main
    | company already has `SqlCustomerStatementOCRD01`; the same query must
    | exist in the ShipGo company for the exact ledger statement. When it is
    | missing, the service falls back to a documents-based statement
    | (invoices + credit memos + incoming payments).
    |
    */
    'shipgo' => [
        'statement_query' => env('SAP_SHIPGO_STATEMENT_QUERY', 'SqlCustomerStatementOCRD01'),
        'company_name'    => env('SHIPGO_COMPANY_NAME', 'ShipGo'),
        'company_name_ar' => env('SHIPGO_COMPANY_NAME_AR', 'شركة شيب قو'),
        'company_address' => env('SHIPGO_COMPANY_ADDRESS', 'الرياض، المملكة العربية السعودية'),
        'company_vat'     => env('SHIPGO_COMPANY_VAT', ''),
        'company_phone'   => env('SHIPGO_COMPANY_PHONE', ''),
        'company_email'   => env('SHIPGO_COMPANY_EMAIL', ''),
        // statement PDF branding (ShipGo official statement layout)
        'logo'            => 'images/shipgo-logo.png',
        'color_primary'   => '#1F2358',   // navy title band
        'color_accent'    => '#F26A21',   // orange subtitle + total band
        'color_on_accent' => '#FFFFFF',
        'color_head'      => '#D9E7F5',   // table header row
        // customer codes whose invoices are NOT mirrored in the Invoices section
        'invoice_exclude_cards' => [],
    ],

    /*
    |--------------------------------------------------------------------------
    | Muntajat Customers (main company, read-only)
    |--------------------------------------------------------------------------
    |
    | Same screen + statement as ShipGo, reading the main company. The ledger
    | query SqlCustomerStatementOCRD01 exists here, so statements come from
    | the journal (JDT1), including manual journal entries.
    |
    */
    'muntajat_company_db' => env('SAP_MUNTAJAT_DB', 'PPTC_V5_PROD'),

    'muntajat' => [
        'statement_query' => env('SAP_MUNTAJAT_STATEMENT_QUERY', 'SqlCustomerStatementOCRD01'),
        'company_name'    => 'Muntajat',
        'company_name_ar' => 'شركة منتجات',
        'company_address' => 'الرياض، المملكة العربية السعودية',
        'company_vat'     => env('MUNTAJAT_COMPANY_VAT', ''),
        'company_phone'   => '',
        'company_email'   => '',
        'logo'            => 'images/muntajat-logo.png',
        'logo_width'      => '22mm',
        'color_primary'   => '#3C72B6',   // brand blue
        'color_accent'    => '#F0BC49',   // brand yellow
        'color_on_accent' => '#1F2937',
        'color_head'      => '#FBF1DE',   // warm cream
        // C0000001 = retail cash register (≈400k POS invoices, printed by the POS)
        'invoice_exclude_cards' => ['C0000001'],
    ],
];
