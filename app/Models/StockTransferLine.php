<?php

namespace App\Models;

use App\Services\SAP\SapClient;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StockTransferLine extends Model
{
    use HasFactory;

    protected $table = 'sap_stock_transfer_lines';
    protected $guarded = [];

    protected $casts = [
        'sent_quantity' => 'float',
        'actual_received_quantity' => 'float',
    ];

    public function transfer()
    {
        return $this->belongsTo(StockTransfer::class, 'stock_transfer_id');
    }

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }
}
