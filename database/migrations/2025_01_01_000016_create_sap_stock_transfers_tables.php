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

            if (!Schema::hasTable($tableName)) {
                Schema::create($tableName, function (Blueprint $table) {
                    $table->id();
                    $table->integer('doc_entry')->unique(); // SAP DocEntry
                    $table->integer('doc_num');
                    $table->string('from_warehouse')->nullable();
                    $table->string('to_warehouse')->nullable();
                    $table->date('doc_date')->nullable();
                    $table->string('document_status')->nullable();
                    $table->dateTime('creation_date')->nullable(); // From SAP
                    $table->dateTime('update_date')->nullable();   // From SAP
                    $table->timestamps(); // Internal created_at/updated_at
                });
            }

            if (!Schema::hasTable($linesTableName)) {
                Schema::create($linesTableName, function (Blueprint $table) use ($tableName) {
                    $table->id();
                    $table->foreignId('stock_transfer_id')->constrained($tableName)->cascadeOnDelete();

                    $table->string('item_code');
                    $table->string('item_description')->nullable();
                    $table->string('from_warehouse_code')->nullable();
                    $table->string('warehouse_code')->nullable();
                    $table->float('quantity')->default(0);
                    $table->float('received_quantity')->default(0);

                    $table->string('line_status')->nullable();

                    $table->timestamps();
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
            Schema::dropIfExists("sap_stock_transfer_lines_{$env}");
            Schema::dropIfExists("sap_stock_transfers_{$env}");
        }
    }
};
