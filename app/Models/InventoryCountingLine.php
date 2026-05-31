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
    ];

    protected $casts = [
        'counted_quantity' => 'decimal:4',
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
}
