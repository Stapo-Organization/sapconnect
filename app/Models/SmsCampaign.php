<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SmsCampaign extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'message_body',
        'file_path',
        'status',
        'total_recipients',
        'sent_count',
        'failed_count',
    ];

    protected $casts = [
        'total_recipients' => 'integer',
        'sent_count' => 'integer',
        'failed_count' => 'integer',
    ];

    public function recipients(): HasMany
    {
        return $this->hasMany(SmsRecipient::class);
    }
}
