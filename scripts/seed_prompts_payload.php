$import = \App\Models\SapImport::where('resource', 'InventoryCountings')->first();
if ($import) {
$import->prompts = [
[
'label' => 'Count Date',
'key' => 'CountDate',
'type' => 'date',
'default' => now()->format('Y-m-d'),
],
[
'label' => 'Count Time',
'key' => 'CountTime',
'type' => 'time',
'default' => now()->format('H:i:s'),
],
[
'label' => 'Branch ID',
'key' => 'BranchID',
'type' => 'number',
'default' => '1',
],
[
'label' => 'Document Status',
'key' => 'DocumentStatus',
'type' => 'text',
'default' => 'cds_Open',
],
];
$import->save();
echo "Prompts updated for InventoryCountings.\n";
} else {
echo "InventoryCountings profile not found.\n";
}