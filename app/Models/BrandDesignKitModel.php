<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Stored per-brand design overrides (Eloquent). Resolution + house defaults live
 * in \App\Services\Marketing\BrandDesignKit. Named *Model to avoid clashing with
 * the service class.
 */
class BrandDesignKitModel extends Model
{
    protected $table = 'brand_design_kits';
    protected $guarded = ['id'];

    protected $casts = [
        'is_active' => 'boolean',
        'sources' => 'array',
    ];
}
