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
    ],
];
