<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PaymentPolicy extends Model
{
    use HasFactory;

    protected $fillable = [
        'supplier_id',
        'name'
    ];

    /**
     * Get the supplier that owns the payment policy.
     */
    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    /**
     * Get the lines for the payment policy.
     */
    public function lines(): HasMany
    {
        return $this->hasMany(PaymentPolicyLine::class);
    }
}
