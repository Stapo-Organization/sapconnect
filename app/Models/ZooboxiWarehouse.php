<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class ZooboxiWarehouse extends Model
{
    use HasFactory;

    protected $table = 'zooboxi_warehouses';

    protected $fillable = [
        'warehouse_code',
        'sap_warehouse_codes',
        'display_name_ar',
        'display_name_en',
        'city',
        'address_ar',
        'address_en',
        'latitude',
        'longitude',
        'express_radius_km',
        'is_central',
        'is_main_hub',
        'is_pickup_enabled',
        'is_active',
        'working_hours',
        'phone',
    ];

    protected $casts = [
        'latitude' => 'float',
        'longitude' => 'float',
        'express_radius_km' => 'float',
        'is_central' => 'boolean',
        'is_main_hub' => 'boolean',
        'is_pickup_enabled' => 'boolean',
        'is_active' => 'boolean',
        'working_hours' => 'array',
        'sap_warehouse_codes' => 'array',
    ];

    // ─── Relationships ──────────────────────────────────────────

    /**
     * Get the base warehouse record from SAP.
     */
    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class, 'warehouse_code', 'warehouse_code');
    }

    /**
     * Get all stock records for this warehouse.
     */
    public function stocks()
    {
        return $this->hasMany(WarehouseItemStock::class, 'warehouse_code', 'warehouse_code');
    }

    /**
     * Get all Zooboxi orders assigned to this warehouse.
     */
    public function orders()
    {
        return $this->hasMany(ZooboxiOrder::class, 'warehouse_code', 'warehouse_code');
    }

    // ─── Scopes ─────────────────────────────────────────────────

    /**
     * Only active warehouses.
     */
    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    /**
     * Central warehouses (for same-day delivery).
     */
    public function scopeCentral(Builder $query): Builder
    {
        return $query->where('is_central', true);
    }

    /**
     * Warehouses in a specific city.
     */
    public function scopeInCity(Builder $query, string $city): Builder
    {
        return $query->where('city', $city);
    }

    /**
     * Warehouses that support Click & Collect.
     */
    public function scopePickupEnabled(Builder $query): Builder
    {
        return $query->where('is_pickup_enabled', true);
    }

    // ─── Helpers ────────────────────────────────────────────────

    /**
     * Get the display name based on the current locale.
     */
    public function getDisplayNameAttribute(): string
    {
        $locale = app()->getLocale();
        if ($locale === 'en' && $this->display_name_en) {
            return $this->display_name_en;
        }
        return $this->display_name_ar;
    }

    /**
     * Get the address based on the current locale.
     */
    public function getAddressAttribute(): ?string
    {
        $locale = app()->getLocale();
        if ($locale === 'en' && $this->address_en) {
            return $this->address_en;
        }
        return $this->address_ar;
    }

    /**
     * Check if a given GPS coordinate is within the express delivery radius.
     */
    public function isWithinExpressRadius(float $lat, float $lng): bool
    {
        $distance = $this->distanceTo($lat, $lng);
        return $distance <= $this->express_radius_km;
    }

    /**
     * Calculate the distance to a given GPS coordinate using Haversine formula.
     *
     * @return float Distance in kilometers
     */
    public function distanceTo(float $lat, float $lng): float
    {
        $earthRadius = 6371; // km

        $dLat = deg2rad($lat - $this->latitude);
        $dLng = deg2rad($lng - $this->longitude);

        $a = sin($dLat / 2) * sin($dLat / 2) +
            cos(deg2rad($this->latitude)) * cos(deg2rad($lat)) *
            sin($dLng / 2) * sin($dLng / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return round($earthRadius * $c, 2);
    }

    /**
     * Check if the warehouse is currently open.
     */
    public function isOpenNow(): bool
    {
        if (!$this->working_hours) {
            return true; // If no hours set, assume always open
        }

        $now = now();
        $dayName = strtolower($now->format('l'));

        if (!isset($this->working_hours[$dayName])) {
            return false;
        }

        $hours = $this->working_hours[$dayName];
        $open = $now->copy()->setTimeFromTimeString($hours['open']);
        $close = $now->copy()->setTimeFromTimeString($hours['close']);

        return $now->between($open, $close);
    }

    /**
     * Check if this warehouse has stock for a given item.
     */
    public function hasStock(string $itemCode, float $quantity = 1): bool
    {
        $stock = WarehouseItemStock::where('item_code', $itemCode)
            ->where('warehouse_code', $this->warehouse_code)
            ->first();

        return $stock && $stock->in_stock >= $quantity;
    }

    /**
     * Check if this warehouse has stock for all given items.
     */
    public function hasAllItems(array $items): bool
    {
        foreach ($items as $item) {
            if (!$this->hasStock($item['item_code'], $item['quantity'] ?? 1)) {
                return false;
            }
        }
        return true;
    }
}
