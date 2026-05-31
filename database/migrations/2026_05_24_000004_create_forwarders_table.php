<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Creates the forwarders master data table and adds
     * forwarder_id FK to shipments replacing the free-text forwarder_name.
     */
    public function up(): void
    {
        Schema::create('forwarders', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('contact_person')->nullable();
            $table->string('contact_email')->nullable();
            $table->string('contact_phone')->nullable();
            $table->text('address')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::table('shipments', function (Blueprint $table) {
            $table->foreignId('forwarder_id')->nullable()->after('forwarder_name')->constrained()->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropForeign(['forwarder_id']);
            $table->dropColumn('forwarder_id');
        });

        Schema::dropIfExists('forwarders');
    }
};
