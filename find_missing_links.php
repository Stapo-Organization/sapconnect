<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "Searching for unlinked brands from Purchase Orders...\n";

$pos = \App\Models\PurchaseOrder::with(['lines.product.brand'])->get();
$unlinkedCount = 0;
$missingExamples = [];

foreach ($pos as $po) {
    if (!$po->supplier_id) continue;
    $supplier = \App\Models\Supplier::find($po->supplier_id);
    if (!$supplier) continue;
    
    // Get the brands linked to this supplier
    $linkedBrandIds = $supplier->brands->pluck('id')->toArray();
    
    foreach ($po->lines as $line) {
        if ($line->product && $line->product->brand) {
            $brandId = $line->product->brand->id;
            if (!in_array($brandId, $linkedBrandIds)) {
                $unlinkedCount++;
                if (count($missingExamples) < 5) {
                    $missingExamples[] = "PO #{$po->sap_doc_num} (Local ID: {$po->id}) -> Supplier '{$supplier->name}' -> Product '{$line->product->item_code}' -> Brand '{$line->product->brand->name}' (ID: $brandId)";
                }
            }
        }
    }
}

echo "Total unlinked occurrences found: $unlinkedCount\n";
if ($unlinkedCount > 0) {
    echo "Examples:\n";
    foreach ($missingExamples as $ex) {
        echo "- $ex\n";
    }
} else {
    echo "No missing links found. All brands in POs are linked to their suppliers.\n";
}
