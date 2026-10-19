<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminSavedView extends Model
{
    protected $fillable = ['user_id', 'page_class', 'name', 'query', 'columns', 'is_shared', 'is_pinned', 'position'];

    protected $casts = [
        'columns' => 'array',
        'is_shared' => 'boolean',
        'is_pinned' => 'boolean',
        'position' => 'integer',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Views a user may open on a page: their own plus the ones others shared. */
    public function scopeVisibleTo(Builder $query, int $userId, string $pageClass): Builder
    {
        return $query->where('page_class', $pageClass)
            ->where(fn (Builder $q) => $q->where('user_id', $userId)->orWhere('is_shared', true));
    }

    /** The list page's index URL, or null when the page class is gone. */
    public function baseUrl(): ?string
    {
        $page = $this->page_class;
        if (! class_exists($page) || ! method_exists($page, 'getResource')) {
            return null;
        }

        return $page::getResource()::getUrl('index');
    }

    public function url(): ?string
    {
        $base = $this->baseUrl();
        if ($base === null) {
            return null;
        }
        $query = trim((string) $this->query, '?&');

        return $base . '?' . ($query !== '' ? $query . '&' : '') . 'sv=' . $this->id;
    }
}
