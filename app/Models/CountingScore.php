<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CountingScore extends Model
{
    protected $fillable = [
        'user_id', 'inventory_counting_id', 'quality_task_instance_id', 'warehouse_code',
        'counting_type', 'category', 'base_points', 'accuracy_pct', 'on_time', 'streak_bonus',
        'points', 'completed_at', 'period_month',
    ];

    protected $casts = [
        'on_time' => 'boolean',
        'accuracy_pct' => 'decimal:2',
        'completed_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
