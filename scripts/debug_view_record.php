<?php

use App\Models\ApiTransformer;

$t = ApiTransformer::where('resource', 'StockTransfers')->where('name', 'default')->first();
if ($t) {
    echo json_encode($t->mapping, JSON_PRETTY_PRINT);
} else {
    echo "Record not found.";
}
