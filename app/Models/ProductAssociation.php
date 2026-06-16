<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Directed product association (a→b). @see \App\Console\Commands\BuildAssociations
 */
class ProductAssociation extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $guarded = ['id'];

    protected $casts = [
        'co_count' => 'integer',
        'support' => 'float',
        'confidence' => 'float',
        'lift' => 'float',
        'score' => 'float',
        'computed_at' => 'datetime',
    ];

    public function scopeType($query, string $type)
    {
        return $query->where('rule_type', $type);
    }
}
