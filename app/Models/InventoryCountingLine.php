<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class InventoryCountingLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'inventory_counting_id',
        'item_code',
        'item_name',
        'piece_barcode',
        'counted_quantity',
        'system_quantity',
        'variance',
        'variance_percentage',
        'variance_status',
        'investigation_note',
    ];

    protected $casts = [
        'counted_quantity' => 'decimal:4',
        'system_quantity' => 'decimal:4',
        'variance' => 'decimal:4',
        'variance_percentage' => 'decimal:4',
    ];

    protected $appends = [
        'image_url',
    ];

    // ─── Relationships ──────────────────────────────────────────

    public function counting()
    {
        return $this->belongsTo(InventoryCounting::class, 'inventory_counting_id');
    }

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    // ─── Accessors ──────────────────────────────────────────────

    public function getImageUrlAttribute(): string
    {
        $folder = substr($this->item_code, 0, 4);
        return 'https://ppte.sa/imghd/' . $folder . '/' . $this->item_code . '.png';
    }

    // ─── Helpers ────────────────────────────────────────────────

    /**
     * Calculate variance between counted and system quantities.
     *
     * @param float $tolerancePercent  Tolerance threshold
     * @return array  Returns calculated values
     */
    public function calculateVariance(float $tolerancePercent = 5.0): array
    {
        $counted = (float) $this->counted_quantity;
        $system = (float) $this->system_quantity;

        $variance = $counted - $system;
        $variancePercent = $system > 0
            ? round(abs($variance) / $system * 100, 4)
            : ($counted > 0 ? 100 : 0);

        // Determine status
        if ($system == 0 && $counted == 0) {
            $status = 'match';
        } elseif ($variance == 0) {
            $status = 'match';
        } elseif ($variancePercent <= $tolerancePercent) {
            $status = 'within_tolerance';
        } elseif ($variance > 0) {
            $status = 'over';
        } else {
            $status = 'short';
        }

        return [
            'variance' => $variance,
            'variance_percentage' => $variancePercent,
            'variance_status' => $status,
        ];
    }
}
