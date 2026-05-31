<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'taqnyat' => [
        'bearer_token' => env('TAQNYAT_BEARER_TOKEN'),
        'sender' => env('TAQNYAT_SENDER', 'PPTCO'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Zooboxi WooCommerce Integration
    |--------------------------------------------------------------------------
    */
    'woo' => [
        'api_token' => env('WOO_API_TOKEN'),
        'store_url' => env('WOO_STORE_URL', 'https://store.zooboxi.com'),
        'consumer_key' => env('WOO_CONSUMER_KEY'),
        'consumer_secret' => env('WOO_CONSUMER_SECRET'),
        'webhook_secret' => env('WOO_WEBHOOK_SECRET'),

        // Delivery fees (SAR)
        'express_fee' => env('WOO_EXPRESS_FEE', 15),
        'standard_fee' => env('WOO_STANDARD_FEE', 10),
        'shipping_fee' => env('WOO_SHIPPING_FEE', 25),
        'free_shipping_min' => env('WOO_FREE_SHIPPING_MIN', 200),

        // Default price list to use for WooCommerce regular price
        'default_price_list' => env('WOO_DEFAULT_PRICE_LIST', 1),
    ],

];
