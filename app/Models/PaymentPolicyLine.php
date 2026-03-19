<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentPolicyLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'payment_policy_id',
        'percentage',
        'condition',
        'due_days'
    ];

    /**
     * Get the payment policy that owns the line.
     */
    public function paymentPolicy(): BelongsTo
    {
        return $this->belongsTo(PaymentPolicy::class);
    }
}
