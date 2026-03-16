<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class Warehouse extends Model
{
    use HasFactory;

    protected $fillable = [
        'warehouse_code',
        'warehouse_name',
        'source',
    ];


    /**
     * Scope a query to only include production environment warehouses.
     */
    public function scopeProduction(Builder $query): void
    {
        $query->where('source', 'production');
    }
}
