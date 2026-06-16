<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * اختيار صريح لقنوات تنبيه معيّن لمستخدم (يتجاوز افتراضي الكتالوج).
 */
class NotificationPreference extends Model
{
    protected $fillable = [
        'user_id',
        'event_key',
        'email',
        'push',
    ];

    protected $casts = [
        'email' => 'boolean',
        'push'  => 'boolean',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
