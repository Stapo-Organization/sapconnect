<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** One SAP inventory transfer request raised from «عجز الفروع». */
class BranchGapTransferRequest extends Model
{
    public const STATUS_PENDING = 'pending';

    public const STATUS_POSTED = 'posted';

    public const STATUS_FAILED = 'failed';

    protected $fillable = [
        'reference', 'from_warehouse', 'to_warehouse', 'lines', 'total_quantity',
        'status', 'doc_entry', 'doc_num', 'error', 'note', 'user_id',
    ];

    protected $casts = [
        'lines' => 'array',
        'total_quantity' => 'integer',
        'doc_entry' => 'integer',
        'doc_num' => 'integer',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
