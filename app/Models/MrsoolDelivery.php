<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * One courier request to Mrsool (مرسول) for a Zooboxi express order.
 *
 * Append-only ledger: an order may have several rows (a failed/cancelled
 * attempt followed by a retry), but at most ONE non-terminal row at a time.
 */
class MrsoolDelivery extends Model
{
    use HasFactory;

    protected $table = 'mrsool_deliveries';

    protected $guarded = [];

    protected $casts = [
        'mrsool_order_id' => 'integer',
        'is_partial'      => 'boolean',
        'price_quote'     => 'float',
        'courier_lat'     => 'float',
        'courier_lng'     => 'float',
        'events'          => 'array',
        'pickup_images'   => 'array',
        'dropoff_images'  => 'array',
        'raw_last'        => 'array',
        'requested_at'    => 'datetime',
        'assigned_at'     => 'datetime',
        'picked_up_at'    => 'datetime',
        'delivered_at'    => 'datetime',
        'failed_at'       => 'datetime',
        'last_synced_at'  => 'datetime',
    ];

    // ─── Phases (our own lifecycle, derived from the Mrsool status) ──

    const PHASE_SEARCHING  = 'searching';
    const PHASE_ASSIGNED   = 'assigned';
    const PHASE_IN_TRANSIT = 'in_transit';
    const PHASE_DELIVERED  = 'delivered';
    const PHASE_FAILED     = 'failed';

    const TERMINAL_PHASES = [self::PHASE_DELIVERED, self::PHASE_FAILED];

    // ─── Mrsool statuses (exact API strings) ────────────────────

    const S_COURIER_PENDING      = 'COURIER_PENDING';
    const S_COURIER_ASSIGNED     = 'COURIER_ASSIGNED';
    const S_COURIER_REASSIGNED   = 'COURIER_REASSIGNED';
    const S_PICKUP_ARRIVED       = 'PICKUP_ARRIVED';
    const S_COLLECTING           = 'COLLECTING';
    const S_CONFIRMED_PICKUP     = 'CONFIRMED_PICKUP';
    const S_WAITING_FOR_DELIVERY = 'WAITING_FOR_DELIVERY';
    const S_DELIVERING           = 'DELIVERING';
    const S_DROPOFF_ARRIVED      = 'DROPOFF_ARRIVED';
    const S_PARTIALLY_DELIVERED  = 'PARTIALLY_DELIVERED';
    const S_DELIVERED            = 'DELIVERED';
    const S_RETURN               = 'RETURN';
    const S_CANCELED             = 'CANCELED';
    const S_EXPIRED              = 'EXPIRED';

    /**
     * The ONE mapping from a Mrsool status to our phase. Anything unknown keeps
     * the delivery in its current phase (we never guess a terminal state).
     */
    const STATUS_PHASES = [
        self::S_COURIER_PENDING      => self::PHASE_SEARCHING,
        self::S_COURIER_ASSIGNED     => self::PHASE_ASSIGNED,
        self::S_COURIER_REASSIGNED   => self::PHASE_ASSIGNED,
        self::S_PICKUP_ARRIVED       => self::PHASE_ASSIGNED,
        self::S_COLLECTING           => self::PHASE_ASSIGNED,
        self::S_CONFIRMED_PICKUP     => self::PHASE_IN_TRANSIT,
        self::S_WAITING_FOR_DELIVERY => self::PHASE_IN_TRANSIT,
        self::S_DELIVERING           => self::PHASE_IN_TRANSIT,
        self::S_DROPOFF_ARRIVED      => self::PHASE_IN_TRANSIT,
        self::S_DELIVERED            => self::PHASE_DELIVERED,
        self::S_PARTIALLY_DELIVERED  => self::PHASE_DELIVERED,
        self::S_RETURN               => self::PHASE_FAILED,
        self::S_CANCELED             => self::PHASE_FAILED,
        self::S_EXPIRED              => self::PHASE_FAILED,
    ];

    /** Arabic labels for the 14 Mrsool statuses (shown in the app + Filament). */
    const STATUS_LABELS = [
        self::S_COURIER_PENDING      => 'جارٍ البحث عن مندوب',
        self::S_COURIER_ASSIGNED     => 'تم تعيين مندوب',
        self::S_COURIER_REASSIGNED   => 'تم تغيير المندوب',
        self::S_PICKUP_ARRIVED       => 'المندوب وصل الفرع',
        self::S_COLLECTING           => 'جارٍ استلام الطلب',
        self::S_CONFIRMED_PICKUP     => 'تم استلام الطلب',
        self::S_WAITING_FOR_DELIVERY => 'بانتظار التوصيل',
        self::S_DELIVERING           => 'في الطريق للعميل',
        self::S_DROPOFF_ARRIVED      => 'المندوب وصل للعميل',
        self::S_PARTIALLY_DELIVERED  => 'تم التوصيل جزئياً',
        self::S_DELIVERED            => 'تم التوصيل',
        self::S_RETURN               => 'مرتجع',
        self::S_CANCELED             => 'ملغي',
        self::S_EXPIRED              => 'منتهي (لم يُعثر على مندوب)',
    ];

    // ─── Relationships ──────────────────────────────────────────

    public function order()
    {
        return $this->belongsTo(ZooboxiOrder::class, 'zooboxi_order_id');
    }

    public function requestedBy()
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    // ─── Scopes ─────────────────────────────────────────────────

    /** Non-terminal deliveries — the ones the poller and the app care about. */
    public function scopeActive(Builder $query): Builder
    {
        return $query->whereNotIn('phase', self::TERMINAL_PHASES);
    }

    // ─── Helpers ────────────────────────────────────────────────

    public function isTerminal(): bool
    {
        return in_array($this->phase, self::TERMINAL_PHASES, true);
    }

    /** The branch may only pull the request back before the courier collects. */
    public function canCancel(): bool
    {
        return in_array($this->phase, [self::PHASE_SEARCHING, self::PHASE_ASSIGNED], true);
    }

    public function getStatusLabelAttribute(): ?string
    {
        return self::STATUS_LABELS[$this->status] ?? $this->status;
    }

    /** Map a raw Mrsool status to our phase (null when unknown). */
    public static function phaseFor(?string $status): ?string
    {
        return self::STATUS_PHASES[strtoupper((string) $status)] ?? null;
    }

    public static function labelFor(?string $status): ?string
    {
        if ($status === null || $status === '') {
            return null;
        }
        return self::STATUS_LABELS[strtoupper($status)] ?? $status;
    }
}
