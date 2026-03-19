<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Supplier extends Model
{
    use HasFactory;

    protected $fillable = [
        'sap_code',
        'name',
        'currency',
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
    ];

    /**
     * Get the account manager assigned to this supplier.
     */
    public function accountManager(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Get the payment policies for the supplier.
     */
    public function paymentPolicies(): HasMany
    {
        return $this->hasMany(PaymentPolicy::class);
    }

    /**
     * Get the purchase orders for the supplier.
     */
    public function purchaseOrders(): HasMany
    {
        return $this->hasMany(PurchaseOrder::class);
    }
}
