<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ZidOrder extends Model
{
    protected $guarded = [];

    protected $casts = [
        'order_date' => 'datetime',
        'zid_updated_at' => 'datetime',
        'payload' => 'array',
    ];

    public function store(): BelongsTo
    {
        return $this->belongsTo(ZidStore::class, 'store_id');
    }
}
