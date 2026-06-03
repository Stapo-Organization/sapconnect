<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class QualityTask extends Model
{
    protected $fillable = [
        'warehouse_code', 'title', 'description',
        'proof_type', 'min_photos', 'require_comment', 'checklist_items',
        'recurrence', 'days_of_week', 'slots', 'priority', 'is_active',
        'start_date', 'end_date', 'assignment', 'last_generated_at', 'created_by',
    ];

    protected $casts = [
        'checklist_items' => 'array',
        'days_of_week' => 'array',
        'slots' => 'array',
        'require_comment' => 'boolean',
        'is_active' => 'boolean',
        'min_photos' => 'integer',
        'start_date' => 'date',
        'end_date' => 'date',
        'last_generated_at' => 'datetime',
    ];

    const PROOF_ACKNOWLEDGE = 'acknowledge';
    const PROOF_PHOTO = 'photo';
    const PROOF_CHECKLIST = 'checklist';

    const REC_ONCE = 'once';
    const REC_DAILY = 'daily';
    const REC_WEEKLY = 'weekly';

    // ─── Relationships ──────────────────────────────────────────
    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class, 'warehouse_code', 'warehouse_code');
    }

    public function instances()
    {
        return $this->hasMany(QualityTaskInstance::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    // ─── Scopes ─────────────────────────────────────────────────
    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    public function scopeForWarehouses(Builder $query, array $codes): Builder
    {
        return $query->whereIn('warehouse_code', $codes);
    }

    // ─── Helpers ────────────────────────────────────────────────

    /**
     * The slots to generate for; defaults to a single slot-less '_default'.
     */
    public function effectiveSlots(): array
    {
        $slots = $this->slots;
        if (empty($slots)) {
            return [['key' => '_default', 'label_ar' => '', 'label_en' => '']];
        }
        return array_map(fn ($s) => [
            'key' => $s['key'] ?? '_default',
            'label_ar' => $s['label_ar'] ?? '',
            'label_en' => $s['label_en'] ?? '',
        ], $slots);
    }

    /**
     * Whether this task should generate an instance on the given date —
     * considers recurrence, weekly days, the active window and (for 'once')
     * whether it was already generated.
     */
    public function runsOn(Carbon $date): bool
    {
        $d = $date->copy()->startOfDay();

        if ($this->start_date && $d->lt($this->start_date->copy()->startOfDay())) {
            return false;
        }
        if ($this->end_date && $d->gt($this->end_date->copy()->startOfDay())) {
            return false;
        }

        return match ($this->recurrence) {
            self::REC_ONCE => $this->last_generated_at === null,
            self::REC_WEEKLY => collect($this->days_of_week ?? [])
                ->map(fn ($x) => (int) $x)
                ->contains($d->dayOfWeek),
            default => true, // daily
        };
    }

    /**
     * Snapshot of the proof requirements + slot, stored on each instance.
     */
    public function buildSnapshot(array $slot): array
    {
        return [
            'proof_type' => $this->proof_type,
            'min_photos' => (int) $this->min_photos,
            'require_comment' => (bool) $this->require_comment,
            'checklist_items' => $this->checklist_items ?? [],
            'priority' => $this->priority,
            'slot' => $slot,
        ];
    }
}
