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
        Schema::create('sap_imports', function (Blueprint $table) {
            $table->id();
            $table->string('name'); // e.g. Stock Take
            $table->string('resource'); // e.g. InventoryCountings
            $table->string('import_mode')->default('Document'); // Single = 1 req/row, Document = 1 req/all rows
            $table->json('mapping'); // [{"csv_header": "Item", "sap_field": "ItemCode"}]
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sap_imports');
    }
};
