<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Goods Receipt PO (GRPO) header — imported from SAP `PurchaseDeliveryNotes`.
 * @see \App\Services\GoodsReceiptService
 */
class SapGoodsReceipt extends Model
{
    use HasFactory;

    protected $fillable = [
        'sap_database',
        'doc_entry',
        'doc_num',
        'card_code',
        'doc_date',
        'update_date',
    ];

    protected $casts = [
        'doc_date' => 'date',
        'update_date' => 'datetime',
    ];

    public function lines()
    {
        return $this->hasMany(SapGoodsReceiptLine::class);
    }
}
