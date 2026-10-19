<?php
// Probe field names with $top=1 per resource (GET only). Prints top-level + first collection's property names.
require __DIR__ . '/_bootstrap.php';
$o = argv_opts($argv);
$client = sap_client(1);
$probes = [
  'Items' => ['$top'=>1, '$filter'=>"startswith(ItemCode,'P')", '$orderby'=>'ItemCode'],
  'StockTransfers' => ['$top'=>1, '$orderby'=>'DocEntry desc'],
  'InventoryGenEntries' => ['$top'=>1, '$orderby'=>'DocEntry desc'],
  'InventoryGenExits' => ['$top'=>1, '$orderby'=>'DocEntry desc'],
  'InventoryPostings' => ['$top'=>1, '$orderby'=>'DocumentEntry desc'],
  'InventoryCountings' => ['$top'=>1, '$orderby'=>'DocumentEntry desc'],
  'Invoices' => ['$top'=>1, '$orderby'=>'DocEntry desc'],
  'CreditNotes' => ['$top'=>1, '$orderby'=>'DocEntry desc'],
  'DeliveryNotes' => ['$top'=>1, '$orderby'=>'DocEntry desc'],
  'Returns' => ['$top'=>1, '$orderby'=>'DocEntry desc'],
  'InventoryTransferRequests' => ['$top'=>1, '$orderby'=>'DocEntry desc'],
];
$only = isset($o['only']) ? explode(',', $o['only']) : null;
foreach ($probes as $res => $q) {
    if ($only && !in_array($res, $only, true)) continue;
    echo "=== {$res} ===\n";
    try {
        $r = sap_get_retry($client, $res, $q, 1);
        $row = $r['value'][0] ?? null;
        if (!$row) { echo "  (no rows)\n"; continue; }
        $scalars = []; $colls = [];
        foreach ($row as $k => $v) { if (is_array($v)) $colls[$k] = $v; else $scalars[] = $k; }
        echo "  scalars: " . implode(',', $scalars) . "\n";
        foreach ($colls as $k => $v) {
            $first = $v[0] ?? null;
            if (is_array($first)) {
                $keys = array_keys($first);
                echo "  {$k}[" . count($v) . "]: " . implode(',', $keys) . "\n";
                // show sample values for quantity-ish fields
                $sample = [];
                foreach ($first as $fk => $fv) { if (!is_array($fv) && preg_match('/Quantity|UoM|Units|Warehouse|ItemCode|Measure|Variance|Counted|Entry|LineNum|BaseType|Date/i', $fk)) $sample[$fk] = $fv; }
                echo "    sample: " . json_encode($sample, JSON_UNESCAPED_UNICODE) . "\n";
            } else {
                echo "  {$k}: (empty or scalar list)\n";
            }
        }
        $hdr = [];
        foreach (['DocEntry','DocumentEntry','DocNum','DocumentNumber','DocDate','CountDate','PostingDate','DocumentStatus','FromWarehouse','ToWarehouse','Cancelled','CardCode','UpdateDate','Reference2','Remarks','Comments','JournalMemo','CountingType'] as $h) if (array_key_exists($h, $row)) $hdr[$h] = $row[$h];
        echo "  header sample: " . json_encode($hdr, JSON_UNESCAPED_UNICODE) . "\n";
    } catch (\Throwable $e) {
        echo "  ERROR [" . $e->getCode() . "] " . substr($e->getMessage(), 0, 300) . "\n";
    }
}
