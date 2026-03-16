<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BrandTest extends Model
{
    use HasFactory;

    protected $table = 'brands_test';

    protected $fillable = [
        'code',
        'name',
    ];
}
