<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$brand = \App\Models\Brand::where('name', 'like', '%kit%cat%')->orWhere('name', 'like', '%kitcat%')->first();
if ($brand) {
    echo "Brand Found:\n";
    echo "ID: {$brand->id}, Code: {$brand->code}, Name: {$brand->name}\n";
    
    $products = \App\Models\Product::where('items_group_code', $brand->code)->take(5)->get();
    echo "\nProducts under this Brand:\n";
    foreach ($products as $p) {
        echo "- {$p->item_code} | {$p->item_name} | ItemsGroupCode: {$p->items_group_code}\n";
    }
} else {
    echo "Brand Kitcat not found.\n";
}

$product126 = \App\Models\Product::where('item_code', 'like', 'P126%')->take(5)->get();
echo "\nProducts starting with P126:\n";
foreach ($product126 as $p) {
    echo "- {$p->item_code} | {$p->item_name} | ItemsGroupCode: {$p->items_group_code}\n";
}
