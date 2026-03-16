<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ApiTransformer extends Model
{
    protected $fillable = [
        'name',
        'resource',
        'mapping',
        'is_active',
    ];

    protected $casts = [
        'mapping' => 'array',
        'is_active' => 'boolean',
    ];

    /**
     * Find a transformer configuration by Resource + View Name
     */
    public static function findByResourceAndView($resource, $view)
    {
        return self::where('resource', $resource)
            ->where('name', $view)
            ->where('is_active', true)
            ->first();
    }
}
