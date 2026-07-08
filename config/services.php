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

    // ShipGo WMS read API (catalog mirror) — Bearer token + which SAP price
    // list is the wholesale/selling price exposed to ShipGo (convention: 1).
    'shipgo' => [
        'api_token' => env('SHIPGO_API_TOKEN'),
        'price_list' => env('SHIPGO_PRICE_LIST', 1),
    ],

    /*
    |--------------------------------------------------------------------------
    | Marketing — AI Creative Generation (Replicate)
    |--------------------------------------------------------------------------
    | Server-side image generation for ad banners. The driver produces the
    | VISUAL BASE only; the Arabic headline/CTA/logo are composited on top by
    | App\Services\Marketing\BannerCompositor (Chrome) — never by the AI model.
    */
    'replicate' => [
        'token' => env('REPLICATE_API_TOKEN'),
        // Scene model (image-to-image) — places the REAL product image into a scene.
        'scene_model' => env('REPLICATE_SCENE_MODEL', 'google/nano-banana'),
        // Text-to-image model — for campaigns with no product image (seasonal/category).
        'txt2img_model' => env('REPLICATE_TXT2IMG_MODEL', 'google/imagen-4-ultra'),
        // Cheap fallback (kept for low-cost mode).
        'image_model' => env('REPLICATE_IMAGE_MODEL', 'black-forest-labs/flux-schnell'),
        // gpt-image-2: renders the COMPLETE banner (scene + product + correct Arabic
        // + logo) in one step — the production creative engine.
        'gpt_image_model' => env('REPLICATE_GPT_IMAGE_MODEL', 'openai/gpt-image-2'),
        'gpt_image_quality' => env('REPLICATE_GPT_IMAGE_QUALITY', 'high'),
        'gpt_image_timeout' => env('REPLICATE_GPT_IMAGE_TIMEOUT', 300),
        'base_url' => env('REPLICATE_BASE_URL', 'https://api.replicate.com/v1'),
        'timeout' => env('REPLICATE_TIMEOUT', 120),
    ],

    'creative' => [
        // 'replicate' (real AI) or 'placeholder' (no external call, typographic base)
        'driver' => env('CREATIVE_DRIVER', 'replicate'),
        // Node rasterises the Arabic banner SVG via @resvg/resvg-js (no browser).
        'node_binary' => env('NODE_BINARY', 'node'),
        // hard daily ceiling on AI generations (cost guard)
        'max_generations_per_day' => env('CREATIVE_MAX_PER_DAY', 60),
    ],

    /*
    |--------------------------------------------------------------------------
    | Traqo Container — Ocean Freight Tracking (READ-ONLY)
    |--------------------------------------------------------------------------
    | Powers the "تتبّع الحاويات" supply-chain board. We ONLY issue GETs against
    | this API (list / track / vessel / voyage); nothing is ever written back —
    | mirroring the SAP read-only rule. Note: looking up a BRAND-NEW container/BL
    | number consumes a "shipment slot" on Traqo's side, so the daily sync reads
    | the already-tracked /shipments list and never registers new numbers.
    */
    'traqo' => [
        'base_url' => env('TRAQO_API_BASE_URL', 'https://traqocontainer.com/api/v1'),
        'token'    => env('TRAQO_API_TOKEN'),
        'timeout'  => env('TRAQO_API_TIMEOUT', 30),

        // Auto-track (the ONLY write to Traqo). Off by default; guarded by a
        // monthly budget + per-run cap so accidental over-registration is bounded.
        'auto_track_enabled'        => env('TRAQO_AUTO_TRACK_ENABLED', false),
        'auto_track_monthly_budget' => env('TRAQO_AUTO_TRACK_MONTHLY_BUDGET', 40),
        'auto_track_per_run'        => env('TRAQO_AUTO_TRACK_PER_RUN', 5),
    ],

    /*
    |--------------------------------------------------------------------------
    | Google Sheets — Shipment ledger sync (service account)
    |--------------------------------------------------------------------------
    | Writes Traqo arrival/ship dates into the procurement sheet (and later reads
    | container numbers from it). credentials = path to the service-account JSON
    | (relative to base_path or absolute). Keep the JSON OUT of git.
    */
    'google_sheets' => [
        'credentials'    => env('GOOGLE_SHEETS_CREDENTIALS', 'storage/app/google/traqo-sheets.json'),
        'spreadsheet_id' => env('GOOGLE_SHEETS_SPREADSHEET_ID'),
        'tab'            => env('GOOGLE_SHEETS_TAB'), // null = first tab
    ],

];
