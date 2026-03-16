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
    ];

    protected $appends = [
        'image_url',
    ];

    public function getImageUrlAttribute()
    {
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

}
