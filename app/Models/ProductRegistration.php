<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One current SFDA registration record per SKU (dedup key = item_code).
 *
 * The status vocabulary lives here as the single source of truth (mirroring the
 * ContainerShipment::state() pattern): the raw Arabic SFDA statuses from the sheets
 * are normalized to a small set of canonical keys, each with a label + badge color
 * shared by the import command, the Filament resource, and the API.
 */
class ProductRegistration extends Model
{
    protected $fillable = [
        'item_code',
        'product_id',
        'brand_code',
        'brand_id',
        'item_name',
        'name_ar',
        'range',
        'vendor_code',
        'reference_number',
        'certificate_number',
        'status',
        'is_registered',
        'request_date',
        'received_date',
        'expiry_date',
        'remarks',
        'source_sheet',
    ];

    protected $casts = [
        'is_registered' => 'boolean',
        'request_date'  => 'date',
        'received_date' => 'date',
        'expiry_date'   => 'date',
    ];

    /** Flag a registration as "expiring soon" this many days ahead. */
    public const EXPIRING_SOON_DAYS = 90;

    /* -------------------- Status vocabulary (single source of truth) -------------------- */

    /** Canonical status key => human label (Arabic). Order = lifecycle order. */
    public static function statusOptions(): array
    {
        return [
            'new'                    => 'جديد',
            'under_process'          => 'تحت الإجراء',
            'referred_for_amendment' => 'مرجع للتعديل',
            'returned_to_applicant'  => 'عاد لمقدم الطلب',
            'preliminary_approved'   => 'معتمد أولي',
            'complete'               => 'مكتمل',
            'certificate_printed'    => 'تمت طباعة الشهادة',
            'rejected'               => 'مرفوض',
        ];
    }

    /** Filament/badge color per canonical status. */
    public static function statusColor(string $key): string
    {
        return [
            'new'                    => 'gray',
            'under_process'          => 'warning',
            'referred_for_amendment' => 'warning',
            'returned_to_applicant'  => 'warning',
            'preliminary_approved'   => 'info',
            'complete'               => 'success',
            'certificate_printed'    => 'success',
            'rejected'               => 'danger',
        ][$key] ?? 'gray';
    }

    /** Rank for dedup "keep the most-advanced status" (higher wins). */
    public static function statusRank(string $key): int
    {
        return array_flip(array_keys(self::statusOptions()))[$key] ?? 0;
    }

    /**
     * Map a raw sheet status (Arabic, with spelling variants) to a canonical key.
     * Unknown / blank / "#N/A" values fall back to 'new'.
     */
    public static function normalizeStatus(?string $raw): string
    {
        $raw = trim((string) $raw);
        if ($raw === '' || $raw === '#N/A') {
            return 'new';
        }

        // Exact canonical key passthrough (idempotent for already-normalized data).
        if (array_key_exists($raw, self::statusOptions())) {
            return $raw;
        }

        // Raw Arabic → canonical, covering every variant observed in the sheets.
        $map = [
            'مكتمل'                 => 'complete',
            'تمت طباعة الشهادة'      => 'certificate_printed',
            'معتمد أولي'            => 'preliminary_approved',
            'جديد'                  => 'new',
            'تحت الاجراء'           => 'under_process',
            'تحت الإجراء'           => 'under_process',
            'مرجع للتعديل'          => 'referred_for_amendment',
            'عاد لمقدم الطلب'       => 'returned_to_applicant',
            'عاد الي مقدم الطلب'    => 'returned_to_applicant',
            'اعادة الطلب'           => 'returned_to_applicant',
            'مرفوض'                 => 'rejected',
            'رفض'                   => 'rejected',
            'رفض الطلب'             => 'rejected',
            'رفض التس'              => 'rejected',
            'REJECTED'              => 'rejected',
        ];

        if (isset($map[$raw])) {
            return $map[$raw];
        }

        // Fuzzy fallback on the Arabic root, so any unlisted variant still lands sanely.
        if (str_contains($raw, 'رفض') || str_contains($raw, 'مرفوض')) return 'rejected';
        if (str_contains($raw, 'طباعة'))                              return 'certificate_printed';
        if (str_contains($raw, 'مكتمل'))                              return 'complete';
        if (str_contains($raw, 'اجراء') || str_contains($raw, 'إجراء')) return 'under_process';
        if (str_contains($raw, 'عاد'))                                return 'returned_to_applicant';
        if (str_contains($raw, 'تعديل'))                              return 'referred_for_amendment';

        return 'new';
    }

    public function statusLabel(): string
    {
        return self::statusOptions()[$this->status] ?? $this->status;
    }

    /* -------------------- Expiry helpers -------------------- */

    public function isExpired(): bool
    {
        return $this->expiry_date !== null && $this->expiry_date->isPast();
    }

    public function isExpiringSoon(): bool
    {
        return $this->expiry_date !== null
            && !$this->isExpired()
            && $this->expiry_date->lte(now()->addDays(self::EXPIRING_SOON_DAYS));
    }

    /* -------------------- Best-effort relations (nullable) -------------------- */

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function brand(): BelongsTo
    {
        return $this->belongsTo(Brand::class);
    }
}
