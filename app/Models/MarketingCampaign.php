<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Owner-approved, channel-safe ad campaign. Suggested by
 * \App\Console\Commands\SuggestCampaigns; published only after in-app approval.
 */
class MarketingCampaign extends Model
{
    use HasFactory;

    protected $guarded = ['id'];

    protected $casts = [
        'companion_item_codes' => 'array',
        'zones' => 'array',
        'rationale' => 'array',
        'brief' => 'array',
        'discount_pct' => 'float',
        'floor_price' => 'float',
        'base_price' => 'float',
        'effective_price_min' => 'float',
        'score' => 'float',
        'revenue' => 'float',
        'target_express_only' => 'boolean',
        'ab_enabled' => 'boolean',
        'priority' => 'integer',
        'impressions' => 'integer',
        'clicks' => 'integer',
        'add_to_carts' => 'integer',
        'purchases' => 'integer',
        'coupon_wc_id' => 'integer',
        'owner_approved_by' => 'integer',
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
        'owner_approved_at' => 'datetime',
        'published_at' => 'datetime',
        'perf_synced_at' => 'datetime',
        'computed_at' => 'datetime',
    ];

    public function creatives()
    {
        return $this->hasMany(CampaignCreative::class, 'campaign_id');
    }

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    public function scopeSuggested($query)
    {
        return $query->where('status', 'suggested');
    }

    /** Scheduled/active and within the (open-ended) schedule window. */
    public function scopeLive($query)
    {
        $now = now();
        return $query->whereIn('status', ['scheduled', 'active'])
            ->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', $now))
            ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>=', $now));
    }

    public function isVisibilityOnly(): bool
    {
        return $this->scope === 'visibility';
    }
}
