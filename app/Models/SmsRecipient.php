<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SmsRecipient extends Model
{
    use HasFactory;

    protected $fillable = [
        'sms_campaign_id',
        'mobile_number',
        'variables',
        'status',
        'response_id',
        'error_message',
    ];

    protected $casts = [
        'variables' => 'array',
    ];

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(SmsCampaign::class);
    }
}
