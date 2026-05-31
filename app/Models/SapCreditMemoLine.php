<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SapCreditMemoLine extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected $casts = [
        'quantity' => 'decimal:2',
        'price' => 'decimal:2',
    ];

    public function creditMemo()
    {
        return $this->belongsTo(SapCreditMemo::class, 'sap_credit_memo_id');
    }
}
