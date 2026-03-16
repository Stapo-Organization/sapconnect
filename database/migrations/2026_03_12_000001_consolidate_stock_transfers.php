<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        // Step 1: Ensure the unified table has ALL needed columns
        if (Schema::hasTable('sap_stock_transfers')) {
            Schema::table('sap_stock_transfers', function (Blueprint $table) {
                if (!Schema::hasColumn('sap_stock_transfers', 'sap_database')) {
                    $table->string('sap_database')->nullable()->index()->after('id');
                }
                if (!Schema::hasColumn('sap_stock_transfers', 'internal_status')) {
                    $table->string('internal_status')->default('New')->after('document_status');
                }
                if (!Schema::hasColumn('sap_stock_transfers', 'sent_by')) {
                    $table->unsignedBigInteger('sent_by')->nullable()->after('update_date');
                }
                if (!Schema::hasColumn('sap_stock_transfers', 'sent_at')) {
                    $table->timestamp('sent_at')->nullable()->after('sent_by');
                }
                if (!Schema::hasColumn('sap_stock_transfers', 'received_by')) {
                    $table->unsignedBigInteger('received_by')->nullable()->after('sent_at');
                }
                if (!Schema::hasColumn('sap_stock_transfers', 'received_at')) {
                    $table->timestamp('received_at')->nullable()->after('received_by');
                }
                if (!Schema::hasColumn('sap_stock_transfers', 'sender_notes')) {
                    $table->text('sender_notes')->nullable()->after('received_at');
                }
                if (!Schema::hasColumn('sap_stock_transfers', 'receiver_notes')) {
                    $table->text('receiver_notes')->nullable()->after('sender_notes');
                }
            });
        }

        // Step 2: Ensure the unified lines table has workflow columns
        if (Schema::hasTable('sap_stock_transfer_lines')) {
            Schema::table('sap_stock_transfer_lines', function (Blueprint $table) {
                if (!Schema::hasColumn('sap_stock_transfer_lines', 'sent_quantity')) {
                    $table->float('sent_quantity')->default(0)->after('quantity');
                }
                if (!Schema::hasColumn('sap_stock_transfer_lines', 'actual_received_quantity')) {
                    $table->float('actual_received_quantity')->default(0)->after('received_quantity');
                }
            });
        }

        // Step 3: Migrate data from segregated tables to the unified one
        $envs = ['prod' => 'PPTC_V5_PROD', 'test' => 'TEST_RETAIL01'];

        foreach ($envs as $suffix => $sapDb) {
            $headerTable = "sap_stock_transfers_{$suffix}";
            $linesTable = "sap_stock_transfer_lines_{$suffix}";

            if (Schema::hasTable($headerTable)) {
                $rows = DB::table($headerTable)->get();

                foreach ($rows as $row) {
                    // Check if already exists in unified table
                    $exists = DB::table('sap_stock_transfers')
                        ->where('doc_entry', $row->doc_entry)
                        ->where('sap_database', $sapDb)
                        ->exists();

                    if (!$exists) {
                        $newId = DB::table('sap_stock_transfers')->insertGetId([
                            'sap_database' => $sapDb,
                            'doc_entry' => $row->doc_entry,
                            'doc_num' => $row->doc_num,
                            'from_warehouse' => $row->from_warehouse,
                            'to_warehouse' => $row->to_warehouse,
                            'doc_date' => $row->doc_date,
                            'document_status' => $row->document_status,
                            'internal_status' => $row->internal_status ?? 'New',
                            'creation_date' => $row->creation_date,
                            'update_date' => $row->update_date,
                            'created_at' => $row->created_at,
                            'updated_at' => $row->updated_at,
                        ]);

                        // Migrate lines
                        if (Schema::hasTable($linesTable)) {
                            $lines = DB::table($linesTable)
                                ->where('stock_transfer_id', $row->id)
                                ->get();

                            foreach ($lines as $line) {
                                DB::table('sap_stock_transfer_lines')->insert([
                                    'stock_transfer_id' => $newId,
                                    'item_code' => $line->item_code,
                                    'item_description' => $line->item_description,
                                    'from_warehouse_code' => $line->from_warehouse_code ?? null,
                                    'warehouse_code' => $line->warehouse_code ?? null,
                                    'quantity' => $line->quantity,
                                    'sent_quantity' => $line->sent_quantity ?? 0,
                                    'received_quantity' => $line->received_quantity ?? 0,
                                    'actual_received_quantity' => $line->actual_received_quantity ?? 0,
                                    'line_status' => $line->line_status,
                                    'created_at' => $line->created_at,
                                    'updated_at' => $line->updated_at,
                                ]);
                            }
                        }
                    }
                }
            }
        }
    }

    public function down(): void
    {
        Schema::table('sap_stock_transfers', function (Blueprint $table) {
            $table->dropColumn([
                'sent_by', 'sent_at', 'received_by', 'received_at',
                'sender_notes', 'receiver_notes',
            ]);
        });

        Schema::table('sap_stock_transfer_lines', function (Blueprint $table) {
            // Don't drop sent_quantity/actual_received_quantity as they may have existed before
        });
    }
};
