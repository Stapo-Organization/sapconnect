<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Company news / announcement shown on the public landing screen of the
 * Muntajat HUB app (pre-login). Managed by the owner via Filament.
 */
class Announcement extends Model
{
    protected $fillable = [
        'title_ar',
        'title_en',
        'body_ar',
        'body_en',
        'image_path',
        'link_url',
        'is_published',
        'sort_order',
        'published_at',
    ];

    protected $casts = [
        'is_published' => 'boolean',
        'sort_order' => 'integer',
        'published_at' => 'datetime',
    ];

    /**
     * Only published items whose publish time has arrived, newest-curated first.
     */
    public function scopePublished(Builder $query): Builder
    {
        return $query
            ->where('is_published', true)
            ->where(function ($q) {
                $q->whereNull('published_at')
                  ->orWhere('published_at', '<=', now());
            })
            ->orderBy('sort_order')
            ->orderByDesc('published_at')
            ->orderByDesc('id');
    }

    /**
     * Absolute URL to the news image, served through the public API route so
     * it works regardless of whether `storage:link` exists on the server.
     */
    public function getImageUrlAttribute(): ?string
    {
        if (empty($this->image_path)) {
            return null;
        }

        return url('/api/store/news-image/' . $this->id);
    }
}
