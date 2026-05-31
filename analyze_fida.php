<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$brandCode = 192; // Fida
echo "Analyzing Brand Code: $brandCode\n";

// Check Purchase Orders
$pos = \App\Models\PurchaseOrder::whereHas('lines.product', function($q) use ($brandCode) {
    $q->where('items_group_code', $brandCode);
})->get();
echo "Found {$pos->count()} Purchase Orders for this brand in local DB.\n";
foreach ($pos as $po) {
    echo "- PO #{$po->id} | Supplier ID: {$po->supplier_id}\n";
}
