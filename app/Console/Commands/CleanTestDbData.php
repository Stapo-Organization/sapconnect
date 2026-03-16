<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class CleanTestDbData extends Command
{
    protected $signature = 'sap:clean-test-data';
    protected $description = 'Deletes all records originating from TEST_RETAIL01 or source=test';

    public function handle()
    {
        $this->info('Starting test data cleanup...');

        DB::transaction(function () {
            // Delete stock transfer children
            $this->info('Deleting stock transfer logs...');
            try {
                DB::table('sap_stock_transfer_logs')
                    ->whereIn('stock_transfer_id', function($q) {
                        $q->select('id')->from('sap_stock_transfers')->where('sap_database', 'TEST_RETAIL01');
                    })->delete();
            } catch (\Exception $e) {
                $this->warn('Could not delete logs: ' . $e->getMessage());
            }

            $this->info('Deleting stock transfer lines...');
            DB::table('sap_stock_transfer_lines')
                ->whereIn('stock_transfer_id', function($q) {
                    $q->select('id')->from('sap_stock_transfers')->where('sap_database', 'TEST_RETAIL01');
                })->delete();

            $this->info('Deleting stock transfers...');
            $deletedTransfers = DB::table('sap_stock_transfers')->where('sap_database', 'TEST_RETAIL01')->delete();
            $this->info("Deleted {$deletedTransfers} test stock transfers.");

            $this->info('Deleting test warehouses...');
            $deletedWarehouses = \App\Models\Warehouse::where('source', 'test')->delete();
            $this->info("Deleted {$deletedWarehouses} test warehouses.");

            $this->info('Deleting test products...');
            $deletedProducts = \App\Models\Product::where('source', 'test')->delete();
            $this->info("Deleted {$deletedProducts} test products.");
            
            $this->info('Cleaning up stale sessions (if any)...');
            DB::table('sessions')->truncate();
        });

        $this->info('Cleanup complete!');
    }
}
