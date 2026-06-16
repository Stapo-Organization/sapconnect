<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * One rendered creative per (campaign, format, A/B variant). Renderable in the
 * store only when status='approved'.
 */
class CampaignCreative extends Model
{
    use HasFactory;

    protected $guarded = ['id'];

    protected $casts = [
        'generation_meta' => 'array',
        'attempts' => 'integer',
    ];

    public function campaign()
    {
        return $this->belongsTo(MarketingCampaign::class, 'campaign_id');
    }

    public function scopeApproved($query)
    {
        return $query->where('status', 'approved');
    }

    public function scopeReady($query)
    {
        return $query->where('status', 'ready');
    }
}
