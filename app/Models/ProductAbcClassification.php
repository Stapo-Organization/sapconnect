<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class ProductAbcClassification extends Model
{
    use HasFactory;

    protected $fillable = [
        'item_code',
        'warehouse_code',
        'abc_class',
        'annual_sales_value',
        'annual_sales_qty',
        'current_stock',
        'last_counted_at',
        'count_in_cycle',
        'last_variance_pct',
        'last_calculated_at',
    ];

    protected $casts = [
        'annual_sales_value' => 'decimal:2',
        'annual_sales_qty' => 'decimal:4',
        'current_stock' => 'decimal:4',
        'last_counted_at' => 'datetime',
        'count_in_cycle' => 'integer',
        'last_variance_pct' => 'decimal:4',
        'last_calculated_at' => 'datetime',
    ];

    // ─── Relationships ──────────────────────────────────────────

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class, 'warehouse_code', 'warehouse_code');
    }

    // ─── Scopes ─────────────────────────────────────────────────

    public function scopeClassA(Builder $query): Builder
    {
        return $query->where('abc_class', 'A');
    }

    public function scopeClassB(Builder $query): Builder
    {
        return $query->where('abc_class', 'B');
    }

    public function scopeClassC(Builder $query): Builder
    {
        return $query->where('abc_class', 'C');
    }

    public function scopeForWarehouse(Builder $query, string $warehouseCode): Builder
    {
        return $query->where('warehouse_code', $warehouseCode);
    }

    /**
     * Items that need counting — sorted by priority:
     * 1. Never counted (last_counted_at IS NULL)
     * 2. Oldest counted first
     * 3. High variance items have priority
     */
    public function scopeNeedsCounting(Builder $query): Builder
    {
        return $query->orderByRaw('last_counted_at IS NULL DESC')
                     ->orderByRaw('ABS(COALESCE(last_variance_pct, 0)) DESC')
                     ->orderBy('last_counted_at', 'asc');
    }
}
