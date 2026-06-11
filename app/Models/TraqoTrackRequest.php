<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Permanent ledger row: one per container/BL number EVER submitted to Traqo.
 * The unique `container_number` is the anti-duplicate guard — see the migration.
 */
class TraqoTrackRequest extends Model
{
    protected $fillable = [
        'container_number', 'sealine', 'shipment_type', 'source', 'status',
        'attempts', 'response_status', 'note', 'sheet_row', 'registered_at',
    ];

    protected $casts = [
        'attempts'      => 'integer',
        'sheet_row'     => 'integer',
        'registered_at' => 'datetime',
    ];

    /** Normalize a raw container/BL number to the ledger key form. */
    public static function norm(?string $cn): string
    {
        return strtoupper(trim((string) $cn));
    }

    /** True if this number was ever submitted (any status) — never resubmit. */
    public static function alreadyHandled(?string $cn): bool
    {
        return self::where('container_number', self::norm($cn))->exists();
    }

    /**
     * Auto-initiated registrations this calendar month that actually consumed a
     * slot — `failed` attempts don't (Traqo rejects without registering), so
     * they don't count against the monthly budget.
     */
    public static function autoSpentThisMonth(): int
    {
        return self::where('source', 'auto')
            ->whereIn('status', ['tracked', 'pending'])
            ->where('created_at', '>=', now()->startOfMonth())
            ->count();
    }
}
