<?php

use Dedoc\Scramble\Support\Generator\OpenApi;
use Dedoc\Scramble\Support\Generator\SecurityScheme;

return [
    /*
     * Your API path. By default, all routes starting with this path will be added to the docs.
     */
    'api_path' => 'api',

    /*
     * Your API domain.
     */
    'api_domain' => null,

    /*
     * The path where your OpenAPI specification will be exported.
     */
    'export_path' => 'api.json',

    'info' => [
        'title' => 'SAP Middleware API',
        'version' => '1.0.0',
        'description' => 'API Gateway for SAP Business One Service Layer.',
    ],

    'ui' => [
        'title' => 'SAP Create API Docs',
        'theme' => 'id-auto', // 'light' or 'dark' or 'id-auto'? using default
        'hide_try_it' => false,
        'try_it_credentials_policy' => 'include',
    ],

    'servers' => [
        'Live Server' => 'https://sapapi.muntajat.sa/api',
    ],

    'middleware' => [
        'web',
        'auth', // Require login to view docs
    ],

    'extensions' => [],
];
