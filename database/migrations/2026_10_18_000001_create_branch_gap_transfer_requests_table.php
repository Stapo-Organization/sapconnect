<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Every SAP inventory transfer request raised from «عجز الفروع»: who asked,
 * what was sent and what SAP answered (DocEntry/DocNum or the error).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('branch_gap_transfer_requests', function (Blueprint $table) {
            $table->id();
            $table->string('reference', 40)->unique();
            $table->string('from_warehouse', 20);
            $table->string('to_warehouse', 20);
            $table->json('lines');
            $table->unsignedInteger('total_quantity')->default(0);
            $table->string('status', 20)->default('pending');
            $table->unsignedBigInteger('doc_entry')->nullable();
            $table->unsignedBigInteger('doc_num')->nullable();
            $table->text('error')->nullable();
            $table->string('note', 500)->nullable();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();

            $table->index(['to_warehouse', 'status', 'created_at'], 'bgtr_to_status_created');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('branch_gap_transfer_requests');
    }
};
