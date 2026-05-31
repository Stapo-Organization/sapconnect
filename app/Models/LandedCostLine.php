<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LandedCostLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'landed_cost_id',
        'purchase_order_line_id',
        'product_id',
        'country_of_origin',
        'quantity',
        'unit_price_foreign',
        'total_value_foreign',
        'value_participate_pct',
        'shipping_per_unit',
        'total_per_unit_foreign',
        'unit_cost_sar',
        'unit_cost_sar_with_vat',
        'po_unit_price',
        'po_unit_price_with_vat',
        'wholesale_price_with_vat',
        'wholesale_price',
        'gross_profit_pct',
        'profit_per_unit_sar',
        'old_sales_price',
        'new_price',
        'total_net_weight',
        'remark',
    ];

    protected $casts = [
        'unit_price_foreign' => 'decimal:4',
        'total_value_foreign' => 'decimal:2',
        'value_participate_pct' => 'decimal:6',
        'shipping_per_unit' => 'decimal:4',
        'total_per_unit_foreign' => 'decimal:4',
        'unit_cost_sar' => 'decimal:4',
        'unit_cost_sar_with_vat' => 'decimal:4',
        'po_unit_price' => 'decimal:4',
        'po_unit_price_with_vat' => 'decimal:4',
        'wholesale_price_with_vat' => 'decimal:4',
        'wholesale_price' => 'decimal:4',
        'gross_profit_pct' => 'decimal:4',
        'profit_per_unit_sar' => 'decimal:4',
        'old_sales_price' => 'decimal:4',
        'new_price' => 'decimal:4',
    ];

    public function landedCost(): BelongsTo
    {
        return $this->belongsTo(LandedCost::class);
    }

    public function purchaseOrderLine(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrderLine::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
