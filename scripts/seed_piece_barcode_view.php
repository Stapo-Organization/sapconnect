<?php


require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\ApiTransformer;
use Illuminate\Support\Facades\DB;

// Ensure database connection is ready
if (!DB::getPDO()) {
    echo "Database connection failed.\n";
    exit(1);
}

$resource = 'Items';
$viewName = 'PieceBarcode';

// Define the mapping configuration
$mapping = [
    [
        'source' => 'ItemCode',
        'target' => 'ItemCode',
        'type' => 'string'
    ],
    [
        'source' => 'ItemName',
        'target' => 'ItemName',
        'type' => 'string'
    ],
    [
        'source' => 'ForeignName',
        'target' => 'ForeignName',
        'type' => 'string'
    ],
    [
        'source' => 'ItemsGroupCode',
        'target' => 'ItemsGroupCode',
        'type' => 'integer'
    ],
    [
        'source' => 'InventoryUOM',
        'target' => 'InventoryUOM',
        'type' => 'string'
    ],
    [
        'source' => 'ItemBarCodeCollection', // Source collection
        'target' => 'Piece_Barcode',
        'type' => 'collection_extraction', // New custom type
        'filter_key' => 'FreeText',
        'filter_value' => 'Piece',
        'value_key' => 'Barcode'
    ],
    [
        'source' => 'SalesItemsPerUnit',
        'target' => 'SalesItemsPerUnit',
        'type' => 'float'
    ]
];

// Update or Create the Transformer
$transformer = ApiTransformer::updateOrCreate(
    ['resource' => $resource, 'name' => $viewName],
    [
        'mapping' => $mapping,
        'is_active' => true
    ]
);

echo "Successfully created/updated view: {$resource} / {$viewName}\n";
