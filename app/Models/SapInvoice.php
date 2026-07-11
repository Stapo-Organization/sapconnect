<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SapInvoice extends Model
{
    use HasFactory;

    protected $fillable = [
        'doc_num',
        'card_code',
        'doc_date',
        'doc_time',
        'sales_employee_code',
        'doc_total',
        'cancelled',
    ];

    protected $casts = [
        'doc_date' => 'date',
    ];

    public function lines()
    {
        return $this->hasMany(SapInvoiceLine::class);
    }
}
