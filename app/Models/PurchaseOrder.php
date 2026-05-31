<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PurchaseOrder extends Model
{
    use HasFactory;

    protected $fillable = [
        'sap_doc_entry',
        'sap_doc_num',
        'supplier_id',
        'currency',
        'brand_id',
        'payment_policy_id',
        'pq_ref',
        'pq_value',
        'po_number',
        'po_value',
        'sync_status',
        'doc_status',
        'est_departure',
        'doc_date',
        'doc_due_date',
        'factory_name',
        'comments',
    ];

    protected $casts = [
        'est_departure' => 'date',
        'doc_date' => 'date',
        'doc_due_date' => 'date',
    ];

    /**
     * Get the supplier for the purchase order.
     */
    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    /**
     * Get the brand for the purchase order.
     */
    public function brand(): BelongsTo
    {
        return $this->belongsTo(Brand::class);
    }

    /**
     * Get the payment policy used for the purchase order.
     */
    public function paymentPolicy(): BelongsTo
    {
        return $this->belongsTo(PaymentPolicy::class);
    }

    /**
     * Get the lines for the purchase order.
     */
    public function lines(): HasMany
    {
        return $this->hasMany(PurchaseOrderLine::class);
    }
    
    /**
     * Get the shipments for the purchase order.
     */
    public function shipments(): HasMany
    {
        return $this->hasMany(Shipment::class);
    }

    /**
     * Get the payment alerts for the purchase order.
     */
    public function paymentAlerts(): HasMany
    {
        return $this->hasMany(PaymentAlert::class);
    }

    /**
     * Get computed brands from lines if brand_id is null.
     */
    public function getComputedBrandsAttribute()
    {
        if ($this->brand_id && $this->brand) {
            return [$this->brand->name];
        }
        return collect($this->lines)
            ->map(fn($line) => $line->product?->brand?->name)
            ->filter()
            ->unique()
            ->toArray();
    }
}
