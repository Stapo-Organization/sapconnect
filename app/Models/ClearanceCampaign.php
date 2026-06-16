<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * One channel-safe clearance suggestion per item. @see \App\Console\Commands\PlanClearance
 */
class ClearanceCampaign extends Model
{
    use HasFactory;

    protected $guarded = ['id'];

    protected $casts = [
        'lps' => 'float',
        'capital_tied_sar' => 'float',
        'days_of_cover' => 'float',
        'stagnation_days' => 'integer',
        'retail_price' => 'float',
        'cost_proxy' => 'float',
        'floor_price' => 'float',
        'recommended_discount_pct' => 'float',
        'recommended_sale_price' => 'float',
        'owner_approved_at' => 'datetime',
        'computed_at' => 'datetime',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    public function scopeSuggested($query)
    {
        return $query->where('status', 'suggested');
    }

    public function scopeRanked($query)
    {
        return $query->orderByDesc('lps');
    }
}
