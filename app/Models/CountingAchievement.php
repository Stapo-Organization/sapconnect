<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CountingAchievement extends Model
{
    protected $fillable = ['user_id', 'badge_code', 'awarded_at', 'meta'];

    protected $casts = [
        'awarded_at' => 'datetime',
        'meta' => 'array',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
