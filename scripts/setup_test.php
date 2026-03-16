<?php
$u1 = \App\Models\User::firstOrCreate(['mobile_number' => '966580000001'], ['name' => 'Test Sender UZH001', 'otp_code' => '1111', 'email' => 'sender_uzh001@example.com', 'password' => bcrypt('password')]);
$u1->update(['warehouse_code' => ['UZH001']]);

$u2 = \App\Models\User::firstOrCreate(['mobile_number' => '966580000002'], ['name' => 'Test Receiver UZH002', 'otp_code' => '1111', 'email' => 'receiver_uzh002@example.com', 'password' => bcrypt('password')]);
$u2->update(['warehouse_code' => ['UZH002']]);

$st = \App\Models\StockTransfer::where('from_warehouse', 'UZH001')->where('to_warehouse', 'UZH002')->first();
if (!$st) {
    $st = \App\Models\StockTransfer::create([
        'sap_database' => config('sap.company_db', 'PPTC_V5_PROD'),
        'doc_entry' => 999999,
        'doc_num' => 999999,
        'doc_date' => now(),
        'from_warehouse' => 'UZH001',
        'to_warehouse' => 'UZH002',
        'document_status' => 'bost_Open',
        'internal_status' => 'New'
    ]);
    \App\Models\StockTransferLine::create([
        'stock_transfer_id' => $st->id,
        'item_code' => 'TEST_ITEM',
        'quantity' => 10,
        'received_quantity' => 0
    ]);
} else {
    $st->update(['internal_status' => 'New']);
    \App\Models\StockTransferLine::where('stock_transfer_id', $st->id)->update(['received_quantity' => 0]);
}
echo "Setup complete. Users: {$u1->mobile_number}, {$u2->mobile_number}. Transfer: {$st->doc_num}\n";
