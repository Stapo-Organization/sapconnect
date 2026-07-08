<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class Brand extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name',
        'source',
        'hidden_in_app',
    ];

    protected $casts = [
        'hidden_in_app' => 'boolean',
    ];

    protected $appends = [
        'image_url',
    ];

    /** Brands visible in the Muntajat HUB public app showcase. */
    public function scopeVisibleInApp($query)
    {
        return $query->where('hidden_in_app', false);
    }

    public function getImageUrlAttribute()
    {
        $firstProduct = $this->products()->first();
        if ($firstProduct && strlen($firstProduct->item_code) >= 4) {
            $prefix = substr($firstProduct->item_code, 0, 4);
            return 'https://ppte.sa/imghd/brands/' . $prefix . '.png';
        }
        return 'https://ppte.sa/imghd/brands/P' . $this->code . '.png';
    }

    /**
     * Get the table associated with the model.
     * Dynamically switches based on SAP Environment.
     */
    public function getTable()
    {
        $db = session('sap_company_db', \Illuminate\Support\Facades\Config::get('sap.company_db'));

        // If config is not set yet (e.g. during serialization), default to 'brands'
        if (!$db) {
            return 'brands';
        }

        // Heuristic: If DB name contains 'PROD', use 'brands' (Production)
        // Otherwise use 'brands_test' (Test)
        if (str_contains($db, 'PROD')) {
            return 'brands';
        }

        return 'brands_test';
    }

    /**
     * Get the products for the brand.
     */
    public function products()
    {
        return $this->hasMany(Product::class, 'items_group_code', 'code');
    }

    /**
     * Get the suppliers for the brand.
     */
    public function suppliers()
    {
        return $this->belongsToMany(Supplier::class)->withTimestamps();
    }
}
