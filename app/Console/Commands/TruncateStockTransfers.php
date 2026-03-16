<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use App\Models\StockTransfer;
use App\Models\StockTransferLine;
use App\Services\SAP\SapClient;

class TruncateStockTransfers extends Command
{
    protected $signature = 'stock:truncate';
    protected $description = 'Truncate Stock Transfer tables (both headers and lines) for the current connection';

    public function handle()
    {
        $databases = ['PPTC_V5_PROD'];
        $sap = app(SapClient::class);

        if (!$this->confirm("This will TRUNCATE Stock Transfer tables for ALL databases: " . implode(', ', $databases) . ". Are you really sure?")) {
            $this->info("Operation cancelled.");
            return;
        }

        // Bind the instance so Models resolve THIS modified instance
        app()->instance(SapClient::class, $sap);

        DB::statement('SET FOREIGN_KEY_CHECKS=0;');

        try {
            foreach ($databases as $db) {
                $this->info("Switching context to DB: $db");
                $sap->setCompanyDb($db);

                // Re-instantiate models to get dynamic table name based on new SapClient state
                $headerTable = (new StockTransfer)->getTable();
                $lineTable = (new StockTransferLine)->getTable();

                $this->info("  - Truncating Lines Table: $lineTable");
                DB::table($lineTable)->truncate();

                $this->info("  - Truncating Header Table: $headerTable");
                DB::table($headerTable)->truncate();
            }

            $this->info("All tables in all databases truncated successfully.");
        } finally {
            DB::statement('SET FOREIGN_KEY_CHECKS=1;');
        }
    }
}
