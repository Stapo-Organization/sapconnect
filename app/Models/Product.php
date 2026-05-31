<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    use HasFactory;

    protected $fillable = [
        'item_code',
        'item_name',
        'foreign_name',
        'items_group_code',
        'inventory_uom',
        'piece_barcode',
        'sales_items_per_unit',
        'create_date',
        'update_date',
        'source',
        'prices',
        'u_portal_sync',
        'u_proprt1',
        'u_proprt2',
        'u_proprt3',
        'u_proprt4',
        'u_proprt5',
        'woo_sync',
        'woo_product_id',
        'woo_synced_at',
    ];

    protected $casts = [
        'prices' => 'array',
        'woo_sync' => 'boolean',
        'woo_synced_at' => 'datetime',
    ];

    protected $appends = [
        'image_url',
    ];

    public function getImageUrlAttribute()
    {
        return 'https://gal.holeno.com/imghd/' . $this->item_code . '.png';
    }


    public function scopeProduction($query)
    {
        return $query->where('source', 'production');
    }

    /**
     * Scope: products flagged for WooCommerce sync (Zooboxi store).
     */
    public function scopeWooSyncable($query)
    {
        return $query->where('woo_sync', true);
    }

    /**
     * Get the brand that owns the product.
     */
    public function brand()
    {
        return $this->belongsTo(Brand::class, 'items_group_code', 'code');
    }

    /**
     * Get stock levels across all warehouses.
     */
    public function warehouseStocks()
    {
        return $this->hasMany(WarehouseItemStock::class, 'item_code', 'item_code');
    }
}
