<?php

namespace App\Http\Resources;

use App\Models\MrsoolDelivery;
use App\Models\ZooboxiWarehouse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The courier, as the CUSTOMER sees it in the Zooboxi app.
 *
 * Deliberately not MrsoolDeliveryResource: that one is the branch's operational
 * view (price, cancel rights, raw errors, partner ids). This one crosses the
 * store and lands on a stranger's phone, so it carries only what a customer
 * waiting at the door needs — where the courier is, who he is, and how long.
 *
 * Every string is written in second person («مندوبك…»), because the branch app
 * narrates an operation while this narrates *your* order.
 */
class MrsoolCustomerTrackingResource extends JsonResource
{
    /**
     * How old a courier fix may be and still be treated as "where he is".
     *
     * Mrsool moves the dot on status events, not on a GPS feed, so anything
     * older than this is a place he HAS BEEN, not a place he is. Five minutes:
     * long enough that a fix taken at pickup still answers while he is pulling
     * away from the branch, short enough that it never answers mid-ride.
     */
    private const FIX_FRESH_SECONDS = 300;

    /**
     * Customer-facing wording per Mrsool status. The model's STATUS_LABELS are
     * the operations wording and stay as they are.
     */
    private const CUSTOMER_LABELS = [
        MrsoolDelivery::S_COURIER_PENDING      => 'جارٍ تحديد مندوب توصيل لطلبك',
        MrsoolDelivery::S_COURIER_ASSIGNED     => 'مندوبك في طريقه للفرع',
        MrsoolDelivery::S_COURIER_REASSIGNED   => 'تم تغيير المندوب',
        MrsoolDelivery::S_PICKUP_ARRIVED       => 'مندوبك وصل الفرع',
        MrsoolDelivery::S_COLLECTING           => 'جارٍ تسليم طلبك للمندوب',
        MrsoolDelivery::S_CONFIRMED_PICKUP     => 'مندوبك استلم طلبك',
        MrsoolDelivery::S_WAITING_FOR_DELIVERY => 'مندوبك استلم طلبك',
        MrsoolDelivery::S_DELIVERING           => 'مندوبك في الطريق إليك',
        MrsoolDelivery::S_DROPOFF_ARRIVED      => 'مندوبك وصل عندك',
        MrsoolDelivery::S_PARTIALLY_DELIVERED  => 'تم تسليم طلبك جزئياً',
        MrsoolDelivery::S_DELIVERED            => 'تم تسليم طلبك',
        MrsoolDelivery::S_RETURN               => 'رجع الطلب للفرع',
        MrsoolDelivery::S_CANCELED             => 'أُلغيت مهمة المندوب',
        MrsoolDelivery::S_EXPIRED              => 'لم نجد مندوباً متاحاً',
    ];

    public function __construct($resource, private ?ZooboxiWarehouse $warehouse = null, private ?array $dropoff = null)
    {
        parent::__construct($resource);
    }

    public function toArray(Request $request): array
    {
        /** @var MrsoolDelivery $d */
        $d = $this->resource;

        // Null Island is what a courier without a GPS fix looks like once his
        // payload has been through a (float) cast. Drawn on a map it puts him in
        // the Atlantic and makes the arrival estimate read in days.
        $hasFix = $d->courier_lat !== null && $d->courier_lng !== null
            && (abs((float) $d->courier_lat) > 0.01 || abs((float) $d->courier_lng) > 0.01);

        $courierLat = $hasFix ? (float) $d->courier_lat : null;
        $courierLng = $hasFix ? (float) $d->courier_lng : null;

        // The courier's phone is only useful while he is actually carrying the
        // order; after delivery it is just a stranger's number on a screen.
        $showCourier = !in_array($d->phase, MrsoolDelivery::TERMINAL_PHASES, true);

        // Until the courier has the box, the distance between him and the door
        // is not the distance to your order — he is riding the other way, to
        // the branch. Saying "300 m away" then is simply untrue.
        $inTransit = $d->phase === MrsoolDelivery::PHASE_IN_TRANSIT;

        // WHEN that position was taken, which is not when we last asked for it.
        // Mrsool's `courier_location` is the fix recorded at the last status
        // EVENT, not a live feed: between «استلم الطلب» and «وصل عندك» it can
        // sit unchanged for half an hour while the courier crosses the city.
        // Polling it every twenty seconds returns the same point, and reporting
        // our poll time as the update time made a stale dot look alive.
        $seenAt     = $this->courierSeenAt($d);
        $freshFix   = $seenAt !== null
            && (int) floor($seenAt->diffInSeconds(now())) <= self::FIX_FRESH_SECONDS;

        // Only a fix we believe gets to answer "how far": a distance measured
        // from where he was twenty-six minutes ago is not a distance.
        $distanceKm = $inTransit && $freshFix
            ? $this->distanceKm($courierLat, $courierLng)
            : null;

        return [
            'active'        => $showCourier,
            'phase'         => $d->phase,
            'status'        => $d->status,
            'status_label'  => self::CUSTOMER_LABELS[$d->status] ?? MrsoolDelivery::labelFor($d->status),
            'carrier'       => 'mrsool',
            'carrier_label' => 'مرسول',
            'number'        => $d->mrsool_order_id ? (string) $d->mrsool_order_id : null,
            'is_partial'    => (bool) $d->is_partial,

            'courier' => [
                'name'  => $showCourier ? $d->courier_name : null,
                'phone' => $showCourier ? $d->courier_phone : null,
                'lat'   => $showCourier ? $courierLat : null,
                'lng'   => $showCourier ? $courierLng : null,
            ],

            'pickup' => $this->warehouse && $this->warehouse->latitude !== null ? [
                'lat'   => (float) $this->warehouse->latitude,
                'lng'   => (float) $this->warehouse->longitude,
                'label' => $this->warehouse->display_name_ar ?: $this->warehouse->display_name_en,
            ] : null,

            'dropoff' => $this->dropoff,

            'distance_km' => $distanceKm,
            'eta_minutes' => $this->etaMinutes($distanceKm, $freshFix),

            // When the courier's dot was actually recorded. The app draws it as
            // a LAST KNOWN position once this is old, instead of implying he is
            // parked outside the branch he left twenty minutes ago.
            'courier_seen_at' => optional($seenAt)->toIso8601String(),

            // Which leg the courier is riding: the app draws the line to this
            // end, not always to the customer's door.
            'heading_to' => match ($d->phase) {
                MrsoolDelivery::PHASE_ASSIGNED   => 'pickup',
                MrsoolDelivery::PHASE_IN_TRANSIT => 'dropoff',
                default                          => null,
            },

            // When we expect to have found somebody. Only while we are actually
            // looking — after that the courier's own progress is the answer.
            'assignment_deadline' => $d->phase === MrsoolDelivery::PHASE_SEARCHING && $d->requested_at
                ? $d->requested_at
                    ->copy()
                    ->addMinutes((int) config('services.mrsool.assignment_minutes', 14))
                    ->toIso8601String()
                : null,

            'steps'        => $this->steps($d),
            'proof_images' => array_values($d->dropoff_images ?? []),
            'tracking_url' => $d->tracking_url,

            'requested_at' => optional($d->requested_at)->toIso8601String(),
            'delivered_at' => optional($d->delivered_at)->toIso8601String(),
            'updated_at'   => optional($d->last_synced_at ?: $d->updated_at)->toIso8601String(),
        ];
    }

    /**
     * The four milestones a customer actually recognises. Built from our own
     * phase timestamps rather than Mrsool's events_history, which is English,
     * noisy, and repeats a status every time the courier's app pings.
     */
    private function steps(MrsoolDelivery $d): array
    {
        $failed = $d->phase === MrsoolDelivery::PHASE_FAILED;

        return [
            [
                'key'   => 'requested',
                'label' => 'طلبنا مندوباً',
                'at'    => optional($d->requested_at)->toIso8601String(),
                'done'  => $d->requested_at !== null,
            ],
            [
                'key'   => 'assigned',
                'label' => 'تم تعيين المندوب',
                'at'    => optional($d->assigned_at)->toIso8601String(),
                'done'  => $d->assigned_at !== null,
            ],
            [
                'key'   => 'picked_up',
                'label' => 'استلم طلبك من الفرع',
                'at'    => optional($d->picked_up_at)->toIso8601String(),
                'done'  => $d->picked_up_at !== null,
            ],
            [
                'key'   => $failed ? 'failed' : 'delivered',
                'label' => $failed ? 'تعذّر التوصيل' : 'وصل إليك',
                'at'    => optional($failed ? $d->failed_at : $d->delivered_at)->toIso8601String(),
                'done'  => ($failed ? $d->failed_at : $d->delivered_at) !== null,
            ],
        ];
    }

    /** Straight-line courier → door, in km. Null unless both points are known. */
    private function distanceKm(?float $lat, ?float $lng): ?float
    {
        if ($lat === null || $lng === null || !$this->dropoff) {
            return null;
        }

        return $this->haversine(
            $lat,
            $lng,
            (float) ($this->dropoff['lat'] ?? 0),
            (float) ($this->dropoff['lng'] ?? 0),
        );
    }

    /** Straight-line kilometres, or null when either end is unknown. */
    private function haversine(float $lat1, float $lng1, float $lat2, float $lng2): ?float
    {
        if (!$lat2 || !$lng2) {
            return null;
        }

        $r = 6371.0;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return round(2 * $r * asin(min(1.0, sqrt($a))), 2);
    }

    /**
     * A deliberately rough arrival estimate: straight-line distance at ~22 km/h,
     * which is what a bike averages through Riyadh traffic once detours are
     * folded in. Shown to the customer as «تقريباً», never as a promise, and
     * only while the courier is genuinely moving toward the door.
     */
    private function etaMinutes(?float $distanceKm, bool $freshFix): ?int
    {
        /** @var MrsoolDelivery $d */
        $d = $this->resource;

        if ($d->phase !== MrsoolDelivery::PHASE_IN_TRANSIT) {
            return null;
        }

        if ($d->status === MrsoolDelivery::S_DROPOFF_ARRIVED) {
            return 0;
        }

        if ($freshFix && $distanceKm !== null) {
            return max(2, (int) ceil(($distanceKm / 22.0) * 60));
        }

        // No fix worth trusting — which is the NORMAL case for most of the
        // ride, because Mrsool only moves the dot on a status event. So the
        // clock answers instead of the map: the whole ride is the branch-to-
        // door distance, and what is left is that minus how long he has been
        // gone. It counts down honestly, which the frozen-distance estimate
        // never did — it read the same «٣٣ دقيقة» from pickup to doorstep.
        $ride = $this->rideMinutes();
        if ($ride === null || !$d->picked_up_at) {
            return null;
        }

        return max(2, $ride - (int) floor($d->picked_up_at->diffInMinutes(now())));
    }

    /** How long the whole branch → door ride should take, in minutes. */
    private function rideMinutes(): ?int
    {
        if (!$this->warehouse || $this->warehouse->latitude === null || !$this->dropoff) {
            return null;
        }

        $km = $this->haversine(
            (float) $this->warehouse->latitude,
            (float) $this->warehouse->longitude,
            (float) ($this->dropoff['lat'] ?? 0),
            (float) ($this->dropoff['lng'] ?? 0),
        );

        return $km === null ? null : max(2, (int) ceil(($km / 22.0) * 60));
    }

    /**
     * When the courier's position was recorded.
     *
     * Mrsool stamps the fix at the moment of the last status event, so the
     * newest entry in the event history is the honest age of the dot. Falls
     * back to our own phase timestamps for a delivery whose history we never
     * received.
     */
    private function courierSeenAt(MrsoolDelivery $d): ?\Carbon\CarbonInterface
    {
        $newest = null;
        foreach ((array) ($d->events ?? []) as $event) {
            $at = $event['created_at'] ?? null;
            if (!is_string($at) || $at === '') {
                continue;
            }
            try {
                $parsed = \Illuminate\Support\Carbon::parse($at);
            } catch (\Throwable) {
                continue;
            }
            if ($newest === null || $parsed->greaterThan($newest)) {
                $newest = $parsed;
            }
        }

        return $newest ?? $d->picked_up_at ?? $d->assigned_at;
    }
}
