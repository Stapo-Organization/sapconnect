<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$linked = 0;
// 1. Link from PO lines
$pos = \App\Models\PurchaseOrder::with(['lines.product.brand'])->get();
foreach ($pos as $po) {
    if (!$po->supplier_id) continue;
    $supplier = \App\Models\Supplier::find($po->supplier_id);
    if (!$supplier) continue;
    
    $brandIds = [];
    foreach ($po->lines as $line) {
        if ($line->product && $line->product->brand) {
            $brandIds[] = $line->product->brand->id;
        }
    }
    
    // also if po has brand_id directly
    if ($po->brand_id) {
        $brandIds[] = $po->brand_id;
    }
    
    $brandIds = array_unique($brandIds);
    if (!empty($brandIds)) {
        $supplier->brands()->syncWithoutDetaching($brandIds);
        $linked += count($brandIds);
    }
}
echo "Linked $linked brand-supplier pairs based on POs.\n";

