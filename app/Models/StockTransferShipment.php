<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StockTransferShipment extends Model
{
    use HasFactory;

    protected $table = 'sap_stock_transfer_shipments';

    protected $fillable = [
        'stock_transfer_id',
        'tracking_number',
        'is_received',
        'received_at',
    ];

    protected $casts = [
        'is_received' => 'boolean',
        'received_at' => 'datetime',
    ];

    public function stockTransfer()
    {
        return $this->belongsTo(StockTransfer::class, 'stock_transfer_id');
    }
}
