<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentAlert extends Model
{
    use HasFactory;

    protected $fillable = [
        'shipment_id',
        'purchase_order_id',
        'payment_policy_line_id',
        'due_amount',
        'due_date',
        'status',
        'notes',
        'marked_by',
        'paid_at',
    ];

    protected $casts = [
        'due_date' => 'date',
        'paid_at' => 'datetime',
        'due_amount' => 'decimal:2',
    ];

    /**
     * Get the shipment that triggered this alert.
     */
    public function shipment(): BelongsTo
    {
        return $this->belongsTo(Shipment::class);
    }

    /**
     * Get the related purchase order.
     */
    public function purchaseOrder(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrder::class);
    }

    /**
     * Get the payment policy line this alert is based on.
     */
    public function paymentPolicyLine(): BelongsTo
    {
        return $this->belongsTo(PaymentPolicyLine::class);
    }

    /**
     * Get the user who marked this alert as paid.
     */
    public function markedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'marked_by');
    }

    /**
     * Check if the alert is overdue.
     */
    public function isOverdue(): bool
    {
        return $this->status === 'pending' && $this->due_date->isPast();
    }

    /**
     * Mark this alert as paid.
     */
    public function markAsPaid(?int $userId = null, ?string $notes = null): void
    {
        $this->update([
            'status' => 'paid',
            'marked_by' => $userId,
            'paid_at' => now(),
            'notes' => $notes ?? $this->notes,
        ]);
    }
}
