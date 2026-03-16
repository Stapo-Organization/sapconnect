
// To be piped to tinker
$mapping = [
    ['csv_header' => 'SAP Code', 'sap_field' => 'InventoryCountingLines.ItemCode'],
    ['csv_header' => 'Batch Number', 'sap_field' => 'InventoryCountingLines.BatchNumbers.BatchNumber'],
    ['csv_header' => 'Expiry Date', 'sap_field' => 'InventoryCountingLines.BatchNumbers.ExpiryDate'],
    ['csv_header' => 'Qty', 'sap_field' => 'InventoryCountingLines.BatchNumbers.Quantity'],
    ['csv_header' => 'Warehouse', 'sap_field' => 'WhsCode'],
    ['csv_header' => 'Count Date', 'sap_field' => 'CountDate']
];
App\Models\SapImport::updateOrCreate(
    ['name' => 'Inventory Counting'],
    [
        'resource' => 'InventoryCountings',
        'import_mode' => 'Document',
        'mapping' => $mapping
    ]
);
echo 'Seeding Complete';
