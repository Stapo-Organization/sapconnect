<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$po = App\Models\PurchaseOrder::where('sap_doc_num', '2600087')->orWhere('po_number', '2600087')->with('supplier')->first();
if ($po) {
    dump(['po' => '2600087', 'supplier' => $po->supplier->name ?? null, 'supplier_sap_code' => $po->supplier->sap_code ?? null, 'brand_id' => $po->brand_id]);
}
