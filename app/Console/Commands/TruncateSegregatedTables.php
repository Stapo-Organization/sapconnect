<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class TruncateSegregatedTables extends Command
{
    protected $signature = 'sap:truncate-segregated';
    protected $description = 'Truncate Prod and Test stock transfer tables';

    public function handle()
    {
        $tables = [
            'sap_stock_transfer_lines_prod',
            'sap_stock_transfers_prod',
            'sap_stock_transfer_lines_test',
            'sap_stock_transfers_test'
        ];

        DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        foreach ($tables as $table) {
            if (Schema::hasTable($table)) {
                $this->info("Truncating $table...");
                DB::table($table)->truncate();
            }
        }
        DB::statement('SET FOREIGN_KEY_CHECKS=1;');

        $this->info('Tables truncated successfully.');
    }
}
