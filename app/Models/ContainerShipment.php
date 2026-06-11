<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A snapshot of one Traqo ocean-freight shipment.
 *
 * Lifecycle/state is DERIVED here, not trusted from the API: Traqo's own
 * `is_delayed` flag was observed to read 0 on containers already days past ETA,
 * so {@see isOverdue()} recomputes lateness from remaining_days. "Pending" means
 * Traqo has accepted the number but not yet resolved its route (empty status /
 * null origin), and must render as a calm "being prepared" state, not an error.
 */
class ContainerShipment extends Model
{
    protected $guarded = [];

    protected $casts = [
        'eta'               => 'datetime',
        'remote_synced_at'  => 'datetime',
        'detail_fetched_at' => 'datetime',
        'fetched_at'        => 'datetime',
        'is_active'         => 'boolean',
        'is_delayed'        => 'boolean',
        'detail'            => 'array',
        'latitude'          => 'float',
        'longitude'         => 'float',
    ];

    // How many days before ETA we flag a shipment as "arriving soon".
    public const ARRIVING_SOON_DAYS = 2;

    /* -------------------- Derived lifecycle state -------------------- */

    /** Traqo accepted the number but hasn't resolved a route yet. */
    public function isPending(): bool
    {
        return blank($this->status) || blank($this->origin);
    }

    public function isDelivered(): bool
    {
        return $this->status === 'DELIVERED';
    }

    public function isInTransit(): bool
    {
        return $this->status === 'IN_TRANSIT';
    }

    /** Past ETA and still not delivered — computed by us, NOT Traqo's is_delayed. */
    public function isOverdue(): bool
    {
        return $this->is_active
            && !$this->isDelivered()
            && !$this->isPending()
            && $this->remaining_days !== null
            && $this->remaining_days < 0;
    }

    /** Due to arrive within ARRIVING_SOON_DAYS and not yet overdue/delivered. */
    public function isArrivingSoon(): bool
    {
        return $this->is_active
            && $this->isInTransit()
            && $this->remaining_days !== null
            && $this->remaining_days >= 0
            && $this->remaining_days <= self::ARRIVING_SOON_DAYS;
    }

    /** Stable machine key for filtering/badges. One shipment maps to exactly one state. */
    public function state(): string
    {
        if ($this->isPending())      return 'pending';
        if ($this->isDelivered())    return 'delivered';
        if ($this->isOverdue())      return 'overdue';
        if ($this->isArrivingSoon()) return 'arriving';
        return 'in_transit';
    }

    public function stateLabel(): string
    {
        return [
            'pending'    => 'قيد التهيئة',
            'delivered'  => 'وصلت',
            'overdue'    => 'متأخرة',
            'arriving'   => 'تصل قريباً',
            'in_transit' => 'في الطريق',
        ][$this->state()];
    }

    /** Tailwind-ish accent key consumed by the blade for chips/borders. */
    public function stateColor(): string
    {
        return [
            'pending'    => 'slate',
            'delivered'  => 'emerald',
            'overdue'    => 'rose',
            'arriving'   => 'amber',
            'in_transit' => 'cyan',
        ][$this->state()];
    }

    public function lane(): string
    {
        $from = $this->origin ?: '—';
        $to   = $this->destination ?: '—';
        return "{$from}  ←  {$to}";
    }

    /* -------------------- Display helpers (cards / banner / drawer) -------------------- */

    public function originShort(): string { return $this->shortPlace($this->origin); }
    public function destinationShort(): string { return $this->shortPlace($this->destination); }
    public function originFlag(): string { return static::flag($this->countryOf($this->origin)); }
    public function destinationFlag(): string { return static::flag($this->countryOf($this->destination)); }

    protected function shortPlace(?string $place): string
    {
        if (blank($place)) return '—';
        return trim(explode(',', $place)[0]);
    }

    protected function countryOf(?string $place): string
    {
        if (blank($place)) return '';
        $parts = explode(',', $place);
        return trim(end($parts));
    }

    /** Country name → flag emoji. Falls back to a globe for unmapped countries. */
    public static function flag(string $country): string
    {
        return [
            'Germany' => '🇩🇪', 'Belgium' => '🇧🇪', 'China' => '🇨🇳', 'Saudi Arabia' => '🇸🇦',
            'Thailand' => '🇹🇭', 'India' => '🇮🇳', 'Kenya' => '🇰🇪', 'France' => '🇫🇷',
            'Netherlands' => '🇳🇱', 'Italy' => '🇮🇹', 'Spain' => '🇪🇸', 'Turkey' => '🇹🇷',
            'United Arab Emirates' => '🇦🇪', 'Egypt' => '🇪🇬', 'United States' => '🇺🇸',
            'United Kingdom' => '🇬🇧', 'Vietnam' => '🇻🇳', 'Malaysia' => '🇲🇾',
            'Singapore' => '🇸🇬', 'South Korea' => '🇰🇷', 'Japan' => '🇯🇵',
            'Dominican Republic' => '🇩🇴', 'Algeria' => '🇩🇿', 'Indonesia' => '🇮🇩',
        ][$country] ?? '🌍';
    }

    /** Single Arabic phrase for the time-to-arrival, used across cards/rows/hero. */
    public function remainingLabel(): string
    {
        if ($this->isPending())   return 'قيد التهيئة';
        if ($this->isDelivered()) return 'وصلت';
        if ($this->remaining_days === null) return '—';
        $r = $this->remaining_days;
        if ($r < 0)  return 'متأخرة ' . abs($r) . ' يوم';
        if ($r === 0) return 'تصل اليوم';
        if ($r === 1) return 'تصل غداً';
        return 'باقٍ ' . $r . ' يوم';
    }

    /** Surface in the "needs attention" hero: overdue, or arriving within N days. */
    public function needsAttention(int $withinDays = 3): bool
    {
        if ($this->isOverdue()) return true;
        return $this->isInTransit()
            && $this->remaining_days !== null
            && $this->remaining_days >= 0
            && $this->remaining_days <= $withinDays;
    }

    /**
     * Approximate shipment / departure date = ETA minus the total voyage days.
     * On real data this matches the earliest actual event (origin pickup), so it
     * is a reliable "start of journey" without needing the detail tables.
     */
    public function shipDate(): ?\Illuminate\Support\Carbon
    {
        if ($this->eta && $this->total_days) {
            return $this->eta->copy()->subDays($this->total_days);
        }
        return null;
    }

    /** How many times the carrier moved the ETA (>0 = the date slipped). */
    public function etaChangeCount(): int
    {
        $etas = collect($this->detail['eta_history_table'] ?? [])->pluck('eta')->filter()->unique();
        return max(0, $etas->count() - 1);
    }

    /**
     * Derived "physical shipment" key for grouping containers that travel together.
     *
     * Traqo tracks each container as its own SHP record with no shared booking
     * number, so we group on: same carrier + same ORIGIN + same destination + same
     * ETA-to-the-minute. Origin is part of the key by company decision: boxes that
     * share a vessel + ETA but were loaded at different origins (e.g. Antwerp vs
     * Germersheim) are SEPARATE bookings in Muntajat's records, even though they
     * consolidate onto the same ship. Pending / no-ETA rows fall back to their own
     * unique key (one group of one).
     */
    public function shipmentGroupKey(): string
    {
        $eta = $this->eta?->format('Y-m-d H:i');
        if (blank($eta) || $this->isPending()) {
            return 'solo:' . $this->name;
        }
        return ($this->sealine ?: 'NA') . '|' . ($this->origin ?: 'NA') . '|' . ($this->destination ?: 'NA') . '|' . $eta;
    }

    /** 0–100 voyage progress for the card bar (0 when totals unknown). */
    public function progressPercent(): int
    {
        if (!$this->total_days || $this->remaining_days === null) {
            return $this->isDelivered() ? 100 : 0;
        }
        $done = $this->total_days - max($this->remaining_days, 0);
        return (int) max(0, min(100, round($done / $this->total_days * 100)));
    }

    /* -------------------- Detail accessors (from `detail` json) -------------------- */

    public function events(): array
    {
        return $this->detail['events_table'] ?? [];
    }

    public function vessels(): array
    {
        return $this->detail['vessels_table'] ?? [];
    }

    /** The vessel currently carrying the box, if Traqo flags one. */
    public function currentVessel(): ?array
    {
        foreach ($this->vessels() as $v) {
            if (($v['is_current'] ?? 0)) return $v;
        }
        return $this->vessels()[0] ?? null;
    }

    public function containers(): array
    {
        return $this->detail['containers_table'] ?? [];
    }

    /** Decoded route segments ([{path:[[lat,lon]...], type, transport_type}, ...]). */
    public function routeSegments(): array
    {
        if (blank($this->route_json)) return [];
        $decoded = is_array($this->route_json) ? $this->route_json : json_decode($this->route_json, true);
        return is_array($decoded) ? $decoded : [];
    }
}
