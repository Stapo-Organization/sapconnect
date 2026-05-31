<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('customers', function (Blueprint $table) {
            $table->id();
            $table->string('card_code')->unique();
            $table->string('card_name')->nullable();
            $table->string('card_type')->nullable();
            $table->string('phone1')->nullable();
            $table->string('contact_person')->nullable();
            $table->string('vat_liable')->nullable();
            $table->string('federal_tax_id')->nullable();
            $table->string('cellular')->nullable();
            $table->string('city')->nullable();
            $table->string('county')->nullable();
            $table->string('country')->nullable();
            $table->string('mail_city')->nullable();
            $table->string('mail_county')->nullable();
            $table->string('mail_country')->nullable();
            $table->string('email_address')->nullable();
            $table->string('ship_to_default')->nullable();
            $table->string('company_registration_number')->nullable();
            $table->string('u_portal_sync')->nullable();
            $table->string('u_iban')->nullable();
            
            // Sync & Update tracking
            $table->date('create_date')->nullable();
            $table->time('create_time')->nullable();
            $table->date('update_date')->nullable();
            $table->time('update_time')->nullable();

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('customers');
    }
};
