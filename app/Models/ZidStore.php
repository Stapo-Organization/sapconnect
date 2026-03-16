<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ZidStore extends Model
{
    protected $fillable = [
        'name',
        'store_id',
        'x_manager_token',
        'authorization_token',
    ];
}
