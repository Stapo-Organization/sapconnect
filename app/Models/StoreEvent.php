<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * One captured B2C storefront event (capture-only at launch).
 */
class StoreEvent extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $guarded = ['id'];

    protected $casts = [
        'payload' => 'array',
        'occurred_at' => 'datetime',
        'created_at' => 'datetime',
    ];
}
