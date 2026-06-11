<?php

namespace App\Services\Traqo;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Read-only client for the Traqo Container ocean-freight tracking API.
 *
 * Mirrors the house HTTP style (Laravel Http facade, config-based creds,
 * best-effort: logs + returns [] on failure rather than throwing).
 *
 * READ-ONLY: every method is a GET. We never create, modify or delete anything
 * on Traqo. The only side-effect to be aware of is that Traqo consumes a
 * "shipment slot" the first time a NEW container/BL number is looked up via
 * container()/bl() — so the daily sync drives off shipments() (already-tracked,
 * slot-free) and only re-reads detail for numbers Traqo already knows.
 *
 * Base + token live in config/services.php → 'traqo'.
 */
class TraqoClient
{
    protected string $baseUrl;
    protected ?string $token;
    protected int $timeout;

    public function __construct()
    {
        $this->baseUrl = rtrim((string) config('services.traqo.base_url'), '/');
        $this->token   = config('services.traqo.token');
        $this->timeout = (int) config('services.traqo.timeout', 30);
    }

    public function configured(): bool
    {
        return $this->baseUrl !== '' && !empty($this->token);
    }

    /**
     * List already-tracked shipments (paginated, max 100/page). Slot-free.
     *
     * @return array The decoded body: ['success','total','page','pageSize','data'=>[...]]
     */
    public function shipments(int $page = 1, int $pageSize = 100): array
    {
        return $this->get('/shipments', ['page' => $page, 'pageSize' => min($pageSize, 100)]);
    }

    /**
     * Full tracking detail for a container number (route, events, vessel, ports).
     * Re-reading an already-tracked number is slot-free; a brand-new number
     * consumes a slot — callers must only pass numbers from shipments().
     */
    public function container(string $number, ?string $sealine = null): array
    {
        return $this->get('/container/' . rawurlencode($number), $sealine ? ['sealine' => $sealine] : []);
    }

    /** Full tracking detail for a bill-of-lading number. Same slot caveat as container(). */
    public function bl(string $number, ?string $sealine = null): array
    {
        return $this->get('/bl/' . rawurlencode($number), $sealine ? ['sealine' => $sealine] : []);
    }

    /** Real-time AIS vessel position by IMO (7-digit) + MMSI (9-digit). Slot-free lookup. */
    public function vesselTrack(string $imo, string $mmsi): array
    {
        return $this->get('/vessel/track', ['imo' => $imo, 'mmsi' => $mmsi]);
    }

    /** Sailing schedules between two UN/LOCODE ports. Slot-free lookup. */
    public function voyageSchedules(string $origin, string $destination, string $date, int $weekRange = 1, string $dateType = 'departure'): array
    {
        return $this->get('/voyage/schedules', [
            'origin'      => $origin,
            'destination' => $destination,
            'date'        => $date,
            'week_range'  => $weekRange,
            'date_type'   => $dateType,
        ]);
    }

    /**
     * Issue a GET and return the decoded JSON body, or [] on any failure.
     * Never throws — failures are logged and the caller degrades gracefully.
     */
    protected function get(string $path, array $query = []): array
    {
        if (!$this->configured()) {
            Log::warning('TraqoClient: missing credentials (services.traqo.token / base_url)');
            return [];
        }

        try {
            $response = Http::withToken($this->token)
                ->acceptJson()
                ->timeout($this->timeout)
                ->get($this->baseUrl . $path, $query);

            if ($response->successful()) {
                return $response->json() ?? [];
            }

            Log::warning('TraqoClient: request rejected', [
                'path'   => $path,
                'status' => $response->status(),
                'body'   => $response->json() ?? $response->body(),
            ]);
            return [];
        } catch (\Throwable $e) {
            Log::warning('TraqoClient: request failed: ' . $e->getMessage(), ['path' => $path]);
            return [];
        }
    }
}
