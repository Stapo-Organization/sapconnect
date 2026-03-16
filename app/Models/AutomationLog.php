<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AutomationLog extends Model
{
    use HasFactory;

    protected $guarded = [];

    public function automation()
    {
        return $this->belongsTo(Automation::class);
    }
}
