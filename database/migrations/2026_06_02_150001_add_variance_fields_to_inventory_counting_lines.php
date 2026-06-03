<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_counting_lines', function (Blueprint $table) {
            $table->decimal('system_quantity', 15, 4)->default(0)->after('counted_quantity');
            $table->decimal('variance', 15, 4)->default(0)->after('system_quantity');
            $table->decimal('variance_percentage', 8, 4)->default(0)->after('variance');
            $table->string('variance_status')->default('uncounted')->after('variance_percentage');
            // variance_status: match | within_tolerance | over | short | not_in_system | uncounted
            $table->text('investigation_note')->nullable()->after('variance_status');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_counting_lines', function (Blueprint $table) {
            $table->dropColumn([
                'system_quantity',
                'variance',
                'variance_percentage',
                'variance_status',
                'investigation_note',
            ]);
        });
    }
};
