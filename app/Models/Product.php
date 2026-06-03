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
        // Zooboxi (ZID) fields
        'zooboxi_active',
        'zb_name_ar',
        'zb_name_en',
        'zb_description_ar',
        'zb_description_en',
        'zb_short_description_ar',
        'zb_short_description_en',
        'zb_categories_ar',
        'zb_categories_en',
        'zb_keywords',
        'zb_seo_title_ar',
        'zb_seo_description_ar',
        'zb_seo_title_en',
        'zb_seo_description_en',
        'zb_images',
        'zb_weight',
        'zb_weight_unit',
    ];

    protected $casts = [
        'prices' => 'array',
        'woo_sync' => 'boolean',
        'woo_synced_at' => 'datetime',
        'zooboxi_active' => 'boolean',
        'zb_images' => 'array',
        'zb_weight' => 'decimal:3',
    ];

    protected $appends = [
        'image_url',
    ];

    public function getImageUrlAttribute()
    {
        return 'https://gal.holeno.com/imghd/' . $this->item_code . '.png';
    }

    /**
     * Display name: prefer Arabic ZID name, fallback to SAP item_name.
     */
    public function getDisplayNameAttribute(): string
    {
        return $this->zb_name_ar ?: ($this->item_name ?: $this->item_code);
    }

    /**
     * Get the first ZID image URL, or fallback to holeno.
     */
    public function getPrimaryImageAttribute(): string
    {
        $images = $this->zb_images;
        if (!empty($images) && is_array($images)) {
            return $images[0];
        }
        return $this->image_url;
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
     * Scope: products active in the Zooboxi store (have ZID data).
     */
    public function scopeZooboxiActive($query)
    {
        return $query->where('zooboxi_active', true);
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
