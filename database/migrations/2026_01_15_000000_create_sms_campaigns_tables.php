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
        Schema::create('sms_campaigns', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('message_body');
            $table->string('file_path')->nullable();
            $table->string('status')->default('draft'); // draft, processing, completed, failed
            $table->integer('total_recipients')->default(0);
            $table->integer('sent_count')->default(0);
            $table->integer('failed_count')->default(0);
            $table->timestamps();
        });

        Schema::create('sms_recipients', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sms_campaign_id')->constrained()->onDelete('cascade');
            $table->string('mobile_number');
            $table->json('variables')->nullable();
            $table->string('status')->default('pending'); // pending, sent, failed
            $table->string('response_id')->nullable();
            $table->text('error_message')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sms_recipients');
        Schema::dropIfExists('sms_campaigns');
    }
};
