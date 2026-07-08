<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tables for the "Sales report -> SAP Draft Invoices" importer.
 *
 * A *run* is one upload/execution (dry-run preview OR real post). Because a
 * single warehouse can hold tens of thousands of lines, each warehouse is split
 * into *chunks* of N document-lines, and every chunk becomes ONE SAP draft
 * invoice (Drafts / DocObjectCode=oInvoices).
 *
 * `draft_invoice_chunks` is a permanent idempotency ledger: the UNIQUE key
 * (file_hash, warehouse, chunk_index) guarantees the SAME file can never post
 * the same chunk twice — re-running only fills gaps. This is the hard guard
 * against accidental duplicate writes to SAP.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('draft_invoice_runs', function (Blueprint $table) {
            $table->id();
            $table->string('source_file');
            $table->string('file_hash', 64)->index();
            $table->string('company_db');                 // e.g. PPTC_V5_PROD
            $table->enum('mode', ['dry_run', 'post'])->default('dry_run');
            $table->string('card_code')->nullable();       // BP / customer, e.g. CAPP0004
            $table->date('doc_date')->nullable();
            $table->string('group_by')->default('warehouse');
            $table->unsignedInteger('chunk_size')->default(200);
            $table->unsignedInteger('expense_code')->nullable(); // SAP freight expense code (header)
            $table->string('tax_code')->nullable();              // optional; omit => SAP default
            $table->string('warehouse_filter')->nullable();      // run a single warehouse only
            $table->enum('status', ['pending', 'running', 'done', 'failed'])->default('pending');
            $table->json('totals')->nullable();                  // rows/lines/drafts/freight/exceptions + per-WH
            $table->string('preview_path')->nullable();
            $table->string('exceptions_path')->nullable();
            $table->string('result_path')->nullable();
            $table->text('command')->nullable();                 // exact CLI cmd (SSH fallback)
            $table->text('error')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->unsignedBigInteger('created_by')->nullable();
            $table->timestamps();
        });

        Schema::create('draft_invoice_chunks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('run_id')->nullable()->constrained('draft_invoice_runs')->nullOnDelete();
            $table->string('file_hash', 64);
            $table->string('company_db');
            $table->string('warehouse');
            $table->unsignedInteger('chunk_index');
            $table->unsignedInteger('lines_count')->default(0);
            $table->decimal('freight_total', 15, 2)->default(0);
            $table->string('payload_hash', 64)->nullable();
            $table->unsignedBigInteger('doc_entry')->nullable();  // SAP draft DocEntry once posted
            $table->string('doc_num')->nullable();                // SAP draft DocNum
            $table->enum('status', ['built', 'posted', 'failed', 'skipped'])->default('built');
            $table->json('exceptions')->nullable();
            $table->text('error')->nullable();
            $table->timestamp('posted_at')->nullable();
            $table->timestamps();

            // The hard idempotency guard: same file can never post a chunk twice.
            $table->unique(['file_hash', 'warehouse', 'chunk_index'], 'dic_file_wh_chunk_unique');
            $table->index(['file_hash', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('draft_invoice_chunks');
        Schema::dropIfExists('draft_invoice_runs');
    }
};
