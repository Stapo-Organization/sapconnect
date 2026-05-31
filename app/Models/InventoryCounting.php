<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class InventoryCounting extends Model
{
    use HasFactory;

    protected $fillable = [
        'warehouse_code',
        'warehouse_name',
        'status',
        'counted_by',
        'notes',
        'completed_at',
    ];

    protected $casts = [
        'completed_at' => 'datetime',
    ];

    const STATUS_DRAFT = 'draft';
    const STATUS_COMPLETED = 'completed';

    // ─── Relationships ──────────────────────────────────────────

    public function lines()
    {
        return $this->hasMany(InventoryCountingLine::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'counted_by');
    }

    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class, 'warehouse_code', 'warehouse_code');
    }

    // ─── Scopes ─────────────────────────────────────────────────

    public function scopeForWarehouse(Builder $query, array $codes): Builder
    {
        return $query->whereIn('warehouse_code', $codes);
    }

    // ─── Helpers ────────────────────────────────────────────────

    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    public function isDraft(): bool
    {
        return $this->status === self::STATUS_DRAFT;
    }

    public function markAsCompleted(): void
    {
        $this->update([
            'status' => self::STATUS_COMPLETED,
            'completed_at' => now(),
        ]);
    }
}
