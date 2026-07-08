<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Brand-level SFDA registration priority (the "FDA Registration Priority" tab).
 * Keyed by `brand_code` string — see the migration for why it is not on `brands`.
 */
class RegistrationPriority extends Model
{
    protected $fillable = [
        'brand_code',
        'priority',
        'brand_name',
        'notes',
    ];

    protected $casts = [
        'priority' => 'integer',
    ];
}
