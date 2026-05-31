<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Supplier extends Model
{
    use HasFactory;

    protected $fillable = [
        'sap_code',
        'name',
        'currency',
        'country',
        'payment_terms_code',
        'credit_limit',
        'open_po_value',
        'achieved_amount',
        'category',
        'user_id',
        'email',
        'target_amount',
        'contract_ref',
        'start_date',
        'end_date',
        'renewal_conditions',
        'agreed_discount',
        'marketing_budget',
        'rebates_bonuses',
        'performance_notes',
        'contract_copy_url',
        'general_comments',
    ];

    /**
     * Get the account manager assigned to this supplier.
     */
    public function accountManager(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Get the payment policies for the supplier (legacy one-to-many).
     */
    public function paymentPolicies(): HasMany
    {
        return $this->hasMany(PaymentPolicy::class);
    }

    /**
     * Get the shared payment policies for the supplier (Many-to-Many via pivot).
     */
    public function sharedPaymentPolicies(): BelongsToMany
    {
        return $this->belongsToMany(PaymentPolicy::class, 'payment_policy_supplier')
            ->withTimestamps();
    }

    /**
     * Get the brands this supplier provides.
     */
    public function brands(): BelongsToMany
    {
        return $this->belongsToMany(Brand::class)->withTimestamps();
    }

    /**
     * Get the purchase orders for the supplier.
     */
    public function purchaseOrders(): HasMany
    {
        return $this->hasMany(PurchaseOrder::class);
    }

    /**
     * Computed: Total outstanding amount to pay (sum of pending payment alerts).
     */
    public function getAmountToPayAttribute(): float
    {
        return (float) PaymentAlert::whereHas('purchaseOrder', function ($q) {
            $q->where('supplier_id', $this->id);
        })->where('status', 'pending')->sum('due_amount');
    }

    /**
     * Computed: Remaining to achieve target.
     */
    public function getRemainingToTargetAttribute(): float
    {
        return max(0, (float) $this->target_amount - (float) $this->achieved_amount - (float) $this->open_po_value);
    }
}
