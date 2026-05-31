<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Forwarder extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'contact_person',
        'contact_email',
        'contact_phone',
        'address',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    /**
     * Get the shipments handled by this forwarder.
     */
    public function shipments(): HasMany
    {
        return $this->hasMany(Shipment::class);
    }

    /**
     * Scope to only active forwarders.
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }
}
