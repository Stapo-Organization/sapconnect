<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SapImport extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'resource',
        'import_mode',
        'mapping',
        'prompts',
        'auto_batch_enrichment',
    ];

    protected $casts = [
        'mapping' => 'array',
        'prompts' => 'array',
        'auto_batch_enrichment' => 'boolean',
    ];
}
