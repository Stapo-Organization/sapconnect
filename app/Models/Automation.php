<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Automation extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected $casts = [
        'is_active' => 'boolean',
        'notify_sms' => 'boolean',
        'last_run_at' => 'datetime',
    ];

    public function logs()
    {
        return $this->hasMany(AutomationLog::class)->latest();
    }
}
