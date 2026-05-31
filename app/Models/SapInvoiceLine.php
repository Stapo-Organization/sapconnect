<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SapInvoiceLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'sap_invoice_id',
        'item_code',
        'quantity',
        'warehouse_code',
    ];

    public function invoice()
    {
        return $this->belongsTo(SapInvoice::class, 'sap_invoice_id');
    }

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }
}
