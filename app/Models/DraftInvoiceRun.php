<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * One execution of the sales-report -> SAP draft-invoice importer
 * (either a dry-run preview or a real post).
 */
class DraftInvoiceRun extends Model
{
    protected $fillable = [
        'source_file', 'file_hash', 'company_db', 'mode', 'card_code', 'doc_date',
        'group_by', 'chunk_size', 'expense_code', 'tax_code', 'no_batches', 'warehouse_filter',
        'status', 'totals', 'preview_path', 'exceptions_path', 'result_path',
        'command', 'error', 'started_at', 'finished_at', 'created_by',
    ];

    protected $casts = [
        'doc_date' => 'date',
        'no_batches' => 'boolean',
        'totals' => 'array',
        'started_at' => 'datetime',
        'finished_at' => 'datetime',
    ];

    public function chunks(): HasMany
    {
        return $this->hasMany(DraftInvoiceChunk::class, 'run_id');
    }
}
