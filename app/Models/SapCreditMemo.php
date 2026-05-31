<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SapCreditMemo extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected $casts = [
        'doc_date' => 'date',
        'doc_total' => 'decimal:2',
    ];

    public function lines()
    {
        return $this->hasMany(SapCreditMemoLine::class);
    }
}
