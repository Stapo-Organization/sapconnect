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
        'started_by',
        'started_at',
        'notes',
        'completed_at',
        'counting_type',
        'scheduled_date',
        'priority',
        'cycle_plan_id',
        'target_items',
        'total_target_items',
    ];

    protected $casts = [
        'completed_at' => 'datetime',
        'started_at' => 'datetime',
        'scheduled_date' => 'date',
        'target_items' => 'array',
        'total_target_items' => 'integer',
    ];

    const TYPE_FULL = 'full';
    const TYPE_CYCLE = 'cycle';

    const STATUS_IN_PROGRESS = 'in_progress';
    const STATUS_CANCELLED = 'cancelled';
    const STATUS_COMPLETED = 'completed';

    // Backward compatibility alias
    const STATUS_DRAFT = 'in_progress';

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

    public function cyclePlan()
    {
        return $this->belongsTo(InventoryCyclePlan::class, 'cycle_plan_id');
    }

    // ─── Scopes ─────────────────────────────────────────────────

    public function scopeForWarehouse(Builder $query, array $codes): Builder
    {
        return $query->whereIn('warehouse_code', $codes);
    }

    public function scopeScheduled(Builder $query): Builder
    {
        return $query->where('counting_type', self::TYPE_CYCLE)
                     ->where('status', self::STATUS_IN_PROGRESS);
    }

    public function scopeOverdue(Builder $query): Builder
    {
        return $query->scheduled()
                     ->whereNotNull('scheduled_date')
                     ->where('scheduled_date', '<', now()->toDateString());
    }

    public function isCycleCount(): bool
    {
        return $this->counting_type === self::TYPE_CYCLE;
    }

    /**
     * Whether the given item_code belongs to this session's target list.
     * target_items is a JSON array of [{item_code, abc_class}, …].
     */
    public function isInTargets(string $itemCode): bool
    {
        return collect($this->target_items ?? [])
            ->pluck('item_code')
            ->filter()
            ->contains($itemCode);
    }

    // ─── Helpers ────────────────────────────────────────────────

    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    public function isInProgress(): bool
    {
        return $this->status === self::STATUS_IN_PROGRESS;
    }

    public function isCancelled(): bool
    {
        return $this->status === self::STATUS_CANCELLED;
    }

    /**
     * Backward compatibility: isDraft() now maps to isInProgress().
     */
    public function isDraft(): bool
    {
        return $this->isInProgress();
    }

    public function markAsCompleted(): void
    {
        $this->update([
            'status' => self::STATUS_COMPLETED,
            'completed_at' => now(),
        ]);
    }

    public function markAsCancelled(): void
    {
        $this->update([
            'status' => self::STATUS_CANCELLED,
        ]);
    }
}
