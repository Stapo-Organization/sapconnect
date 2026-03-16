<?php

use App\Models\User;
use App\Models\StockTransfer;
use App\Models\StockTransferLine;
use App\Models\Product;
use Illuminate\Support\Facades\Auth;
use Illuminate\Http\Request;
use App\Http\Controllers\Api\StockTransferController;
use App\Http\Requests\StockTransferActionRequest;

require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "Starting Stock Transfer API Verification...\n";

// 1. Setup Users
$senderWarehouse = 'WH001';
$receiverWarehouse = 'WH002';

$sender = User::firstOrCreate(['email' => 'sender@example.com'], [
    'name' => 'Sender User',
    'password' => bcrypt('password'),
    'mobile_number' => '966500000001',
]);
$sender->warehouse_code = $senderWarehouse;
$sender->save();

$receiver = User::firstOrCreate(['email' => 'receiver@example.com'], [
    'name' => 'Receiver User',
    'password' => bcrypt('password'),
    'mobile_number' => '966500000002',
]);
$receiver->warehouse_code = $receiverWarehouse;
$receiver->save();

echo "Users Setup: Sender ({$sender->id}), Receiver ({$receiver->id})\n";

// 2. Setup Data
// Create a fake Stock Transfer
$transfer = StockTransfer::create([
    'doc_entry' => rand(1000, 9999),
    'doc_num' => rand(10000, 99999),
    'from_warehouse' => $senderWarehouse,
    'to_warehouse' => $receiverWarehouse,
    'doc_date' => now(),
    'document_status' => StockTransfer::STATUS_NEW,
]);

$product = Product::firstOrCreate(['item_code' => 'TEST-001'], ['item_name' => 'Test Product']);

$line = StockTransferLine::create([
    'stock_transfer_id' => $transfer->id,
    'item_code' => $product->item_code,
    'item_description' => $product->item_name,
    'quantity' => 10,
    'sent_quantity' => 0,
    'actual_received_quantity' => 0,
    'received_quantity' => 0,
]);

echo "Stock Transfer Created: ID {$transfer->id}\n";

// 3. Test Controller Actions

$controller = app()->make(StockTransferController::class);

// Test 3.1: Sender sends items
echo "Testing Send Items... ";
Auth::login($sender);
$sendRequest = StockTransferActionRequest::create("/api/stock-transfers/{$transfer->id}/send-items", 'POST', [
    'items' => [
        ['item_code' => 'TEST-001', 'quantity' => 10]
    ]
]);
$sendRequest->setUserResolver(function () use ($sender) {
    return $sender;
});

$response = $controller->sendItems($sendRequest, $transfer->id);
$data = $response->resource->toArray(request());

if ($data['total_sent_qty'] == 10) {
    echo "PASS\n";
} else {
    echo "FAIL (Sent: {$data['total_sent_qty']})\n";
}

// Test 3.2: Confirm Send
echo "Testing Confirm Send... ";
$confirmSendRequest = Request::create("/api/stock-transfers/{$transfer->id}/confirm-send", 'POST', []);
$confirmSendRequest->setUserResolver(function () use ($sender) {
    return $sender;
});
$response = $controller->confirmSend($confirmSendRequest, $transfer->id);
$data = $response->resource->toArray(request());

if ($data['status'] === StockTransfer::STATUS_SHIPPED) {
    echo "PASS\n";
} else {
    echo "FAIL (Status: {$data['status']})\n";
}

// Test 3.3: Receiver receives items
echo "Testing Receive Items... ";
Auth::login($receiver);
$receiveRequest = StockTransferActionRequest::create("/api/stock-transfers/{$transfer->id}/receive-items", 'POST', [
    'items' => [
        ['item_code' => 'TEST-001', 'quantity' => 8]
    ]
]);
$receiveRequest->setUserResolver(function () use ($receiver) {
    return $receiver;
});

$response = $controller->receiveItems($receiveRequest, $transfer->id);
$data = $response->resource->toArray(request());

if ($data['total_received_qty'] == 8 && $data['receiving_percentage'] > 0) {
    echo "PASS (Received: {$data['total_received_qty']}, Percentage: {$data['receiving_percentage']}%)\n";
} else {
    echo "FAIL (Received: {$data['total_received_qty']})\n";
}

// Test 3.4: Confirm Receive
echo "Testing Confirm Receive... ";
$confirmReceiveRequest = Request::create("/api/stock-transfers/{$transfer->id}/confirm-receive", 'POST', []);
$confirmReceiveRequest->setUserResolver(function () use ($receiver) {
    return $receiver;
});
$response = $controller->confirmReceive($confirmReceiveRequest, $transfer->id);
$data = $response->resource->toArray(request());

if ($data['status'] === StockTransfer::STATUS_RECEIVED) {
    echo "PASS\n";
} else {
    echo "FAIL (Status: {$data['status']})\n";
}


// Test 4: Environment Switching
echo "Testing Environment Switching (Test Mode)... ";
$testHeaderRequest = Request::create("/api/stock-transfers", 'GET');
$testHeaderRequest->headers->set('X-Environment', 'test');
$testHeaderRequest->setUserResolver(function () use ($sender) {
    return $sender; });

// Manually invoke middleware logic to verify config change (since we are not running full HTTP stack here easily)
$middleware = new \App\Http\Middleware\SetSapEnvironment();
$middleware->handle($testHeaderRequest, function ($req) {
    if (config('sap.company_db') === 'TEST_RETAIL01') {
        echo "PASS (Config set to TEST_RETAIL01)\n";
    } else {
        echo "FAIL (Config: " . config('sap.company_db') . ")\n";
    }
    return new \Illuminate\Http\Response();
});

echo "Testing Environment Switching (Production Default)... ";
$prodHeaderRequest = Request::create("/api/stock-transfers", 'GET');
// No header
$prodHeaderRequest->setUserResolver(function () use ($sender) {
    return $sender; });

$middleware->handle($prodHeaderRequest, function ($req) {
    if (config('sap.company_db') === 'PPTC_V5_PROD') {
        echo "PASS (Config set to PPTC_V5_PROD)\n";
    } else {
        echo "FAIL (Config: " . config('sap.company_db') . ")\n";
    }
    return new \Illuminate\Http\Response();
});

echo "Verification Complete.\n";
