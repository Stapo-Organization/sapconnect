<?php

use App\Models\StockTransfer;
use App\Models\StockTransferLine;
use Illuminate\Support\Facades\DB;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "Verifying StockTransfer Lines in DB...\n";

// Check valid databases
$databases = ['TEST_RETAIL01', 'PPTC_V5_PROD'];
// But models are dynamic based on ACTIVE SAP SESSION. 
// We need to simulate the environment.
// However, the Model uses:
//     public function getTable()
//    {
//        $db = app(SapClient::class)->getCompanyDb();
//        $suffix = ($db === 'TEST_RETAIL01') ? '_test' : '_prod';
//        return 'sap_stock_transfers' . $suffix;
//    }

// Let's iterate both manually by setting the company DB in the client
$sap = new \App\Services\SAP\SapClient();
// CRITICAL: Bind this instance to the container so Models use it!
$app->instance(\App\Services\SAP\SapClient::class, $sap);

foreach ($databases as $db) {
    echo "\n------------------------------------------------\n";
    echo "Checking Context: $db\n";
    $sap->setCompanyDb($db);

    $transferCount = StockTransfer::count();
    echo "StockTransfers found: $transferCount\n";

    if ($transferCount > 0) {
        $last = StockTransfer::latest('id')->first();
        echo "Last Transfer ID: " . $last->id . " | DocNum: " . $last->doc_num . "\n";

        $lines = $last->lines()->get();
        echo "Lines Count: " . $lines->count() . "\n";

        if ($lines->count() > 0) {
            echo "First Line Item: " . $lines->first()->item_code . " | Qty: " . $lines->first()->quantity . "\n";
        } else {
            // Check table directly to be sure relationship isn't broken
            $suffix = ($db === 'TEST_RETAIL01') ? '_test' : '_prod';
            $table = 'sap_stock_transfer_lines' . $suffix;
            $directCount = DB::table($table)->where('stock_transfer_id', $last->id)->count();
            echo "Direct Query on $table: $directCount\n";
        }
    }
}
