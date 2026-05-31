<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$unlinkedBrands = App\Models\Brand::doesntHave('suppliers')->get();
dump(['unlinked_count' => $unlinkedBrands->count(), 'sample' => $unlinkedBrands->pluck('name')->take(10)]);
