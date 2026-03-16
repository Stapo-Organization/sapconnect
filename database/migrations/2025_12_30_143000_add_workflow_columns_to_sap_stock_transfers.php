<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $environments = ['test', 'prod'];

        foreach ($environments as $env) {
            $tableName = "sap_stock_transfers_{$env}";
            $linesTableName = "sap_stock_transfer_lines_{$env}";

            if (Schema::hasTable($tableName)) {
                Schema::table($tableName, function (Blueprint $table) {
                    $table->string('internal_status')->default('New')->after('document_status');
                });
            }

            if (Schema::hasTable($linesTableName)) {
                Schema::table($linesTableName, function (Blueprint $table) {
                    $table->float('sent_quantity')->default(0)->after('quantity');
                    $table->float('actual_received_quantity')->default(0)->after('received_quantity');
                });
            }
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        $environments = ['test', 'prod'];

        foreach ($environments as $env) {
            $tableName = "sap_stock_transfers_{$env}";
            $linesTableName = "sap_stock_transfer_lines_{$env}";

            if (Schema::hasTable($tableName)) {
                Schema::table($tableName, function (Blueprint $table) {
                    $table->dropColumn('internal_status');
                });
            }

            if (Schema::hasTable($linesTableName)) {
                Schema::table($linesTableName, function (Blueprint $table) {
                    $table->dropColumn(['sent_quantity', 'actual_received_quantity']);
                });
            }
        }
    }
};
