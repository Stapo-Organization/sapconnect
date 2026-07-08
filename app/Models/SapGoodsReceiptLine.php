<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Goods Receipt PO (GRPO) line — one arrival of an item into a warehouse.
 * `unit_price` carries the actual SAP purchase cost (GRPO line `Price`).
 */
class SapGoodsReceiptLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'sap_goods_receipt_id',
        'line_num',
        'base_entry',
        'base_line',
        'base_type',
        'item_code',
        'quantity',
        'inventory_quantity',
        'warehouse_code',
        'unit_price',
        'line_total',
        'doc_date',
    ];

    protected $casts = [
        'quantity' => 'float',
        'inventory_quantity' => 'float',
        'unit_price' => 'float',
        'line_total' => 'float',
        'doc_date' => 'date',
    ];

    public function receipt()
    {
        return $this->belongsTo(SapGoodsReceipt::class, 'sap_goods_receipt_id');
    }

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    /**
     * The Purchase Order this receipt line draws down (via SAP BaseEntry → DocEntry).
     * Only meaningful when base_type = 22 (OPOR) and base_entry is populated.
     */
    public function purchaseOrder()
    {
        return $this->belongsTo(PurchaseOrder::class, 'base_entry', 'sap_doc_entry');
    }
}
