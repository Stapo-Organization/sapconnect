<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * One shelf on a showroom's map (G04-R2 = gondola 4, 2nd shelf from the top).
 * A map for counting and finding items — not a stock ledger.
 */
class StoreLocation extends Model
{
    public const KINDS = [
        'gondola' => 'G',
        'wall' => 'W',
        'endcap' => 'E',
        'cashier' => 'C',
        'backroom' => 'B',
        'other' => 'X',
    ];

    protected $fillable = [
        'warehouse_code',
        'code',
        'unit_code',
        'kind',
        'name',
        'shelf_no',
        'sort',
        'labeled_at',
    ];

    protected $casts = [
        'shelf_no' => 'integer',
        'sort' => 'integer',
        'labeled_at' => 'datetime',
    ];

    /** The text encoded in a shelf label's QR code. */
    public function qrPayload(): string
    {
        return 'LOC:' . $this->warehouse_code . ':' . $this->code;
    }

    /**
     * Parse a scanned label: «LOC:RUH010:G04-R2» or a bare «G04-R2».
     * Returns [warehouse_code|null, code] or null when it is not a location.
     */
    public static function parseScan(string $raw): ?array
    {
        $v = strtoupper(trim($raw));
        if (preg_match('/^LOC:([A-Z0-9]+):([A-Z][0-9]{2}-R[0-9]{1,2})$/', $v, $m)) {
            return [$m[1], $m[2]];
        }
        if (preg_match('/^([A-Z][0-9]{2}-R[0-9]{1,2})$/', $v, $m)) {
            return [null, $m[1]];
        }
        return null;
    }
}
