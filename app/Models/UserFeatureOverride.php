<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * استثناء صلاحية لمستخدم معيّن (allow / deny) فوق افتراضي دوره.
 */
class UserFeatureOverride extends Model
{
    protected $fillable = [
        'user_id',
        'ability',
        'effect',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
