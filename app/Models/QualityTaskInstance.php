<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class QualityTaskInstance extends Model
{
    protected $fillable = [
        'quality_task_id', 'warehouse_code', 'warehouse_name',
        'title', 'description', 'requirements_snapshot',
        'status', 'scheduled_date', 'slot_key', 'priority',
        'comment', 'checklist_results', 'submitted_by', 'submitted_at', 'last_reminded_at',
    ];

    protected $casts = [
        'requirements_snapshot' => 'array',
        'checklist_results' => 'array',
        'scheduled_date' => 'date',
        'submitted_at' => 'datetime',
        'last_reminded_at' => 'datetime',
    ];

    const STATUS_PENDING = 'pending';
    const STATUS_SUBMITTED = 'submitted';
    const STATUS_CANCELLED = 'cancelled';

    // ─── Relationships ──────────────────────────────────────────
    public function task()
    {
        return $this->belongsTo(QualityTask::class, 'quality_task_id');
    }

    public function photos()
    {
        return $this->hasMany(QualityTaskPhoto::class);
    }

    public function submitter()
    {
        return $this->belongsTo(User::class, 'submitted_by');
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

    public function scopePending(Builder $query): Builder
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeDueToday(Builder $query): Builder
    {
        return $query->pending()->whereDate('scheduled_date', '<=', now()->toDateString());
    }

    public function scopeOverdue(Builder $query): Builder
    {
        return $query->pending()->whereDate('scheduled_date', '<', now()->toDateString());
    }

    // ─── Helpers ────────────────────────────────────────────────
    public function proofType(): string
    {
        return $this->requirements_snapshot['proof_type'] ?? 'photo';
    }

    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function isSubmitted(): bool
    {
        return $this->status === self::STATUS_SUBMITTED;
    }

    public function isCompleted(): bool
    {
        return $this->isSubmitted();
    }

    public function isOverdue(): bool
    {
        return $this->isPending()
            && $this->scheduled_date
            && $this->scheduled_date->lt(now()->startOfDay());
    }

    public function slotLabel(bool $arabic): ?string
    {
        $slot = $this->requirements_snapshot['slot'] ?? null;
        if (!$slot || ($slot['key'] ?? '_default') === '_default') {
            return null;
        }
        $label = $arabic ? ($slot['label_ar'] ?? '') : ($slot['label_en'] ?? '');
        return $label !== '' ? $label : null;
    }

    public function markAsSubmitted(User $user): void
    {
        $this->update([
            'status' => self::STATUS_SUBMITTED,
            'submitted_by' => $user->id,
            'submitted_at' => now(),
        ]);
    }
}
