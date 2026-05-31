<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PaymentPolicy extends Model
{
    use HasFactory;

    protected $fillable = [
        'supplier_id',
        'name'
    ];

    /**
     * Get the supplier that owns the payment policy (legacy one-to-many).
     */
    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    /**
     * Get all suppliers linked to this policy (Many-to-Many via pivot table).
     */
    public function suppliers(): BelongsToMany
    {
        return $this->belongsToMany(Supplier::class, 'payment_policy_supplier')
            ->withTimestamps();
    }

    /**
     * Get the lines for the payment policy.
     */
    public function lines(): HasMany
    {
        return $this->hasMany(PaymentPolicyLine::class);
    }
}
