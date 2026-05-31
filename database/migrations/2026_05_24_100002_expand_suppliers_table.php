<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('suppliers', function (Blueprint $table) {
            $table->string('contract_copy_url')->nullable()->after('performance_notes')->comment('URL/path to contract document');
            $table->text('general_comments')->nullable()->after('contract_copy_url')->comment('General comments separate from performance notes');
            $table->string('country')->nullable()->after('currency')->comment('Supplier country from SAP');
            $table->string('payment_terms_code')->nullable()->after('country')->comment('SAP PayTermsGrpCode');
        });
    }

    public function down(): void
    {
        Schema::table('suppliers', function (Blueprint $table) {
            $table->dropColumn(['contract_copy_url', 'general_comments', 'country', 'payment_terms_code']);
        });
    }
};
