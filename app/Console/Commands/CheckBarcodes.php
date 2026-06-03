<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Product;

class CheckBarcodes extends Command
{
    protected $signature = 'zooboxi:check-barcodes';
    protected $description = 'Check SAP barcode coverage and ZID matching';

    public function handle()
    {
        $sap = app(\App\Services\SAP\SapClient::class);
        $sap->setCompanyDb('PPTC_V5_PROD');

        // 1. Check a known product
        $this->info("=== Checking P17900023 (ACANA) ===");
        try {
            $resp = $sap->get('Items', [
                '$filter' => "ItemCode eq 'P17900023'",
                '$select' => 'ItemCode,ItemName,BarCode,ItemBarCodeCollection'
            ]);
            $item = $resp['value'][0] ?? null;
            if ($item) {
                $this->line("  BarCode: '{$item['BarCode']}'");
                $this->line("  BarCodeCollection: " . json_encode($item['ItemBarCodeCollection'] ?? []));
            }
        } catch (\Exception $e) {
            $this->error("  Error: " . $e->getMessage());
        }

        // 2. Products with no barcode in sapconnect
        $this->info("\n=== Products with NO barcode in sapconnect ===");
        $noBarcode = Product::where('source', 'production')
            ->where(function($q) {
                $q->whereNull('piece_barcode')->orWhere('piece_barcode', '');
            })
            ->limit(5)
            ->get(['item_code', 'item_name', 'piece_barcode']);
        
        foreach ($noBarcode as $p) {
            $this->line("  {$p->item_code}: {$p->item_name}");
            try {
                $sapItem = $sap->get('Items', [
                    '$filter' => "ItemCode eq '{$p->item_code}'",
                    '$select' => 'ItemCode,BarCode,ItemBarCodeCollection'
                ]);
                $si = $sapItem['value'][0] ?? null;
                if ($si) {
                    $this->line("    SAP BarCode: '{$si['BarCode']}'");
                    $bcc = $si['ItemBarCodeCollection'] ?? [];
                    $this->line("    SAP BarCodeCollection (" . count($bcc) . " entries): " . json_encode(array_slice($bcc, 0, 3)));
                }
            } catch (\Exception $e) {
                $this->error("    Error: " . $e->getMessage());
            }
        }

        // 3. Stats
        $this->info("\n=== Barcode Stats in sapconnect ===");
        $total = Product::where('source', 'production')->count();
        $hasBarcode = Product::where('source', 'production')
            ->whereNotNull('piece_barcode')
            ->where('piece_barcode', '!=', '')
            ->count();
        $this->table(
            ['Metric', 'Count'],
            [
                ['Total SAP products', $total],
                ['Has barcode', $hasBarcode],
                ['No barcode', $total - $hasBarcode],
                ['Coverage %', round($hasBarcode / $total * 100, 1) . '%'],
            ]
        );

        // 4. Check ZID barcodes that don't match
        $this->info("\n=== ZID Barcodes that DON'T match sapconnect ===");
        $testBarcodes = ['048081073803', '8003507964129', '6291100291151', '8436586310196', '4000158153265'];
        foreach ($testBarcodes as $bc) {
            $p = Product::where('piece_barcode', $bc)->first();
            $status = $p ? "✅ MATCH → {$p->item_code}" : "❌ NO MATCH";
            $this->line("  $bc: $status");
            
            if (!$p) {
                // Try to find in SAP by BarCode
                try {
                    $sapResp = $sap->get('Items', [
                        '$filter' => "BarCode eq '$bc'",
                        '$select' => 'ItemCode,ItemName,BarCode'
                    ]);
                    $sapItems = $sapResp['value'] ?? [];
                    if (!empty($sapItems)) {
                        $this->line("    SAP found: {$sapItems[0]['ItemCode']} ({$sapItems[0]['ItemName']})");
                        $this->line("    ⚠️  SAP has this barcode but sapconnect doesn't!");
                    } else {
                        $this->line("    SAP: Not found either");
                    }
                } catch (\Exception $e) {
                    $this->error("    SAP API error: " . $e->getMessage());
                }
            }
        }
    }
}
