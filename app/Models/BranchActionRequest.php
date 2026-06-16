<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A manager-initiated request raised from نبض المعرض (transfer / discount).
 * Suggest-only: the owner reviews and acts centrally — see the migration note.
 */
class BranchActionRequest extends Model
{
    protected $guarded = [];

    protected $casts = [
        'meta' => 'array',
        'quantity' => 'decimal:2',
    ];

    public function requester()
    {
        return $this->belongsTo(User::class, 'requested_by');
    }
}
