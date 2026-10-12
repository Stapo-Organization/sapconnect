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
    ],
];
