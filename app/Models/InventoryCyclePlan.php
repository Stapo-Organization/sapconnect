<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class InventoryCyclePlan extends Model
{
    use HasFactory;

    protected $fillable = [
        'warehouse_code',
        'plan_name',
        'cycle_length_weeks',
        'counting_day',
        'weekly_cap',
        'a_frequency',
        'b_frequency',
        'c_frequency',
        'tolerance_a',
        'tolerance_b',
        'tolerance_c',
        'is_active',
        'current_cycle_start',
        'current_week_number',
        'last_generated_at',
        'next_due_date',
        'created_by',
    ];

    protected $casts = [
        'cycle_length_weeks' => 'integer',
        'weekly_cap' => 'integer',
        'a_frequency' => 'integer',
        'b_frequency' => 'integer',
        'c_frequency' => 'integer',
        'tolerance_a' => 'decimal:2',
        'tolerance_b' => 'decimal:2',
        'tolerance_c' => 'decimal:2',
        'is_active' => 'boolean',
        'current_cycle_start' => 'date',
        'current_week_number' => 'integer',
        'last_generated_at' => 'datetime',
        'next_due_date' => 'date',
    ];

    // ─── Relationships ──────────────────────────────────────────

    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class, 'warehouse_code', 'warehouse_code');
    }

    public function countings()
    {
        return $this->hasMany(InventoryCounting::class, 'cycle_plan_id');
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

    public function scopeOverdue(Builder $query): Builder
    {
        return $query->active()->whereNotNull('next_due_date')->where('next_due_date', '<=', now()->toDateString());
    }

    // ─── Helpers ────────────────────────────────────────────────

    public function isOverdue(): bool
    {
        return $this->is_active && $this->next_due_date && $this->next_due_date->lte(now());
    }

    /**
     * Get tolerance percentage for a given ABC class.
     */
    public function getToleranceForClass(string $abcClass): float
    {
        return match (strtoupper($abcClass)) {
            'A' => (float) $this->tolerance_a,
            'B' => (float) $this->tolerance_b,
            'C' => (float) $this->tolerance_c,
            default => 5.0,
        };
    }

    /**
     * Get frequency for a given ABC class.
     */
    public function getFrequencyForClass(string $abcClass): int
    {
        return match (strtoupper($abcClass)) {
            'A' => $this->a_frequency,
            'B' => $this->b_frequency,
            'C' => $this->c_frequency,
            default => 1,
        };
    }

    /**
     * Calculate the weekly quota per ABC class based on item counts and frequencies.
     */
    public function calculateWeeklyQuotas(int $countA, int $countB, int $countC): array
    {
        $weeks = $this->cycle_length_weeks;
        $cap = $this->weekly_cap;

        // Calculate ideal weekly items for each class
        $idealA = $weeks > 0 ? ceil($countA * $this->a_frequency / $weeks) : 0;
        $idealB = $weeks > 0 ? ceil($countB * $this->b_frequency / $weeks) : 0;
        $idealC = $weeks > 0 ? ceil($countC * $this->c_frequency / $weeks) : 0;

        $total = $idealA + $idealB + $idealC;

        // If total exceeds cap, scale down proportionally (A has priority)
        if ($total > $cap) {
            $quotaA = min($idealA, (int) floor($cap * 0.45));
            $remaining = $cap - $quotaA;
            $quotaB = min($idealB, (int) floor($remaining * 0.55));
            $quotaC = $cap - $quotaA - $quotaB;
        } else {
            $quotaA = $idealA;
            $quotaB = $idealB;
            $quotaC = $idealC;
        }

        return [
            'A' => max(0, $quotaA),
            'B' => max(0, $quotaB),
            'C' => max(0, $quotaC),
            'total' => $quotaA + $quotaB + $quotaC,
        ];
    }
}
