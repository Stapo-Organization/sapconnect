<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Every barcode an item answers to: SAP's piece/carton/other barcodes
 * (source=sap, mirrored hourly by sap:sync-products) plus barcodes the POS has
 * actually scanned for the item (source=pos_invoice) and manual ones.
 * products.piece_barcode stays the single canonical piece barcode.
 */
class ProductBarcode extends Model
{
    protected $fillable = [
        'item_code',
        'barcode',
        'barcode_norm',
        'kind',        // piece | carton | other | pos
        'source',      // sap | pos_invoice | manual
        'uom_entry',
        'free_text',
        'is_primary',
        'scan_count',
    ];

    protected $casts = [
        'is_primary' => 'boolean',
        'uom_entry' => 'integer',
        'scan_count' => 'integer',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }
}
