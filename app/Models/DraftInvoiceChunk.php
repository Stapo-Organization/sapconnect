<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One chunk = one SAP draft invoice (Drafts / oInvoices). The UNIQUE
 * (file_hash, warehouse, chunk_index) makes posting idempotent: a chunk that
 * already has a doc_entry is never re-posted on a re-run.
 */
class DraftInvoiceChunk extends Model
{
    protected $fillable = [
        'run_id', 'file_hash', 'company_db', 'warehouse', 'chunk_index',
        'lines_count', 'freight_total', 'payload_hash', 'doc_entry', 'doc_num',
        'status', 'exceptions', 'error', 'posted_at',
    ];

    protected $casts = [
        'exceptions' => 'array',
        'freight_total' => 'decimal:2',
        'posted_at' => 'datetime',
    ];

    public function run(): BelongsTo
    {
        return $this->belongsTo(DraftInvoiceRun::class, 'run_id');
    }
}
