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

        // Do store orders move stock inside sapconnect?
        //
        // `warehouse_item_stocks` is a READ-ONLY MIRROR of SAP, refreshed by
        // sap:sync-recent-stock every 10 minutes. Deducting a Zooboxi order
        // from it therefore (a) never reaches SAP, and (b) is erased at the
        // next sync — so while it lasts it only makes the mirror disagree with
        // SAP. Owner decision 2026-09-06: store orders must NOT touch stock.
        // Flip to true only if sapconnect ever becomes the stock authority.
        'deduct_stock' => env('WOO_DEDUCT_STOCK', false),
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

    /*
    |--------------------------------------------------------------------------
    | SFDA developer API — official product-registry lookup (READ-ONLY)
    |--------------------------------------------------------------------------
    | https://developer.sfda.gov.sa — WSO2 gateway, OAuth2 client_credentials
    | (Consumer Key = username, Consumer Secret = password), Bearer, JSON, token
    | valid 24h. We ONLY GET the PUBLIC registry (search food products by
    | barcode/keyword) to cross-check our SAP catalog — mirroring the SAP/Traqo
    | no-write rule. It does NOT touch the private GHAD workflow (submissions and
    | pipeline statuses have no public API and stay manual in sapconnect).
    |
    | token_url / base_url / food_path / *_param are BEST-GUESS WSO2 defaults —
    | confirm the exact values from your app's "Technical" tab on the portal
    | (visible after the app is created) and override via .env if they differ.
    */
    'sfda' => [
        'key'        => env('SFDA_CONSUMER_KEY'),
        'secret'     => env('SFDA_CONSUMER_SECRET'),
        // Apigee gateway on port 9002 (verified live 2026-07-09). Token proxy:
        // POST /accesstoken?grant_type=client_credentials with HTTP Basic (key:secret).
        'token_url'  => env('SFDA_TOKEN_URL', 'https://apis.sfda.gov.sa:9002/v2/oauth/accesstoken'),
        // Food registry base. Lookup by barcode = GET {base}/product/barcode/{barcode}
        // (barcode is a PATH segment, digits only). Response envelope: {code,message,data,metadata}
        // where code 200 = registered, 404 = not found. NOTE: the barcode endpoint emits
        // slightly MALFORMED JSON (unquoted string values) — SfdaClient parses it tolerantly.
        'base_url'   => env('SFDA_API_BASE_URL', 'https://apis.sfda.gov.sa:9002/v2/Food'),
        'timeout'    => env('SFDA_API_TIMEOUT', 30),
        'ssl_verify' => env('SFDA_SSL_VERIFY', true),
        // Politeness delay (ms) between sweep calls — the gateway has a Spike-arrest
        // rate limit that returns HTTP 429 / code 429-01 when exceeded.
        'sweep_delay_ms' => env('SFDA_SWEEP_DELAY_MS', 300),
    ],

    /*
    |--------------------------------------------------------------------------
    | Mrsool (مرسول) — express last-mile courier (LaaS API)
    |--------------------------------------------------------------------------
    | Powers the manual "طلب مندوب مرسول" button in the branch-manager app for
    | Zooboxi EXPRESS orders. Every write is guarded: the master switch is OFF
    | by default, only the pilot warehouses may request a courier, COD orders
    | are excluded, and a calendar-day cap bounds the blast radius of any bug.
    | The webhook has no signature — we authenticate by a secret token in the
    | URL path and always re-fetch the order before trusting the payload.
    */
    'mrsool' => [
        'enabled'       => env('MRSOOL_ENABLED', false),
        'base_url'      => env('MRSOOL_API_BASE_URL', 'https://logistics.staging.mrsool.co'),
        'api_key'       => env('MRSOOL_API_KEY'),
        'timeout'       => env('MRSOOL_API_TIMEOUT', 20),
        // Random secret embedded in the webhook URL path (POST /api/webhooks/mrsool/{token}).
        'webhook_token' => env('MRSOOL_WEBHOOK_TOKEN'),
        // Pilot gate: comma-separated Zooboxi warehouse_codes allowed to request a courier.
        'warehouses'    => env('MRSOOL_WAREHOUSES', 'RUH010'),
        // Hard ceiling on courier requests per calendar day (all branches).
        'daily_cap'     => env('MRSOOL_DAILY_CAP', 20),
        'allow_cod'     => env('MRSOOL_ALLOW_COD', false),
        'store_name'    => env('MRSOOL_STORE_NAME', 'Zooboxi'),
        'store_phone'   => env('MRSOOL_STORE_PHONE'),
        // A customer watching the map needs a fresher position than the once-a-minute
        // sync gives. A read of a LIVE delivery re-fetches from Mrsool when the row is
        // older than this many seconds; 0 disables the on-demand refresh entirely.
        'live_refresh_seconds' => env('MRSOOL_LIVE_REFRESH_SECONDS', 25),
        // How long we tell the customer to expect the search for a rider to
        // take. Mrsool's merchant portal quotes ~9 minutes but exposes NO such
        // field in the API (verified against a live COURIER_PENDING order,
        // 2026-09-08), so this is our own promise: their figure plus five
        // minutes of headroom, on the principle that a countdown that runs out
        // is worse than one that finishes early.
        'assignment_minutes' => env('MRSOOL_ASSIGNMENT_MINUTES', 14),
    ],

];
