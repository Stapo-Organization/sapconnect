<?php

namespace App\Services\Mrsool;

use App\Models\MrsoolDelivery;
use App\Models\MrsoolWebhookEvent;
use App\Models\User;
use App\Models\ZooboxiOrder;
use App\Models\ZooboxiWarehouse;
use App\Services\NotificationRouter;
use App\Services\Woo\WooStoreClient;
use App\Support\NotificationAudience;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * The whole Mrsool (مرسول) courier lifecycle — the single source of truth for
 * status mapping, the guards around requesting a courier, and every side effect
 * (WooCommerce status push + branch notifications).
 *
 * Requesting a courier costs real money, so the write path is layered like the
 * Traqo auto-track:
 *   1. Master kill switch (services.mrsool.enabled), OFF by default.
 *   2. Pilot gate: only the warehouses listed in MRSOOL_WAREHOUSES.
 *   3. COD orders excluded (the courier would have to collect cash).
 *   4. Calendar-day cap across all branches.
 *   5. At most ONE non-terminal delivery per order, re-checked INSIDE a
 *      lockForUpdate transaction so a double-tap can't create two.
 *   6. Ledger-first atomic claim: the row is INSERTed before the API call, with
 *      a UNIQUE partner_order_id — a duplicate claim throws instead of dialling
 *      Mrsool twice.
 */
class MrsoolDeliveryService
{
    public function __construct(
        protected MrsoolClient $client,
        protected WooStoreClient $store,
        protected NotificationRouter $notifications,
    ) {
    }

    // ─── Gates ──────────────────────────────────────────────────

    public function enabled(): bool
    {
        return (bool) config('services.mrsool.enabled', false);
    }

    /** Zooboxi warehouse codes allowed to request a courier (pilot gate). */
    public function pilotWarehouses(): array
    {
        $raw = (string) config('services.mrsool.warehouses', '');

        return array_values(array_filter(array_map('trim', explode(',', $raw))));
    }

    /** Courier requests made today (all branches) — the daily cap counter. */
    public function requestsToday(): int
    {
        return MrsoolDelivery::whereDate('requested_at', now()->toDateString())->count();
    }

    /**
     * Cheap gate for list/detail payloads: everything except the daily cap and
     * the active-delivery lookup (no extra queries beyond the warehouse).
     */
    public function eligibleQuick(ZooboxiOrder $order): bool
    {
        return $this->enabled()
            && $order->delivery_type === ZooboxiOrder::DELIVERY_EXPRESS
            && in_array((string) $order->warehouse_code, $this->pilotWarehouses(), true)
            && ($this->allowsCod() || !$this->isCod($order))
            && $order->customer_latitude !== null
            && $order->customer_longitude !== null;
    }

    /**
     * Full eligibility with an Arabic reason for the app.
     *
     * @return array{ok: bool, reason: ?string}
     */
    public function eligibility(ZooboxiOrder $order): array
    {
        if (!$this->enabled()) {
            return $this->no('خدمة مرسول غير مفعّلة حالياً.');
        }

        if ($order->delivery_type !== ZooboxiOrder::DELIVERY_EXPRESS) {
            return $this->no('مرسول متاح للطلبات السريعة فقط.');
        }

        if (!in_array($order->delivery_status, [
            ZooboxiOrder::STATUS_READY_FOR_PICKUP,
            ZooboxiOrder::STATUS_OUT_FOR_DELIVERY,
        ], true)) {
            return $this->no('جهّز الطلب أولاً قبل طلب المندوب.');
        }

        if (!in_array((string) $order->warehouse_code, $this->pilotWarehouses(), true)) {
            return $this->no('مرسول غير مفعّل لهذا الفرع بعد.');
        }

        if ($this->isCod($order) && !$this->allowsCod()) {
            return $this->no('طلبات الدفع عند الاستلام غير مدعومة عبر مرسول.');
        }

        if ($order->customer_latitude === null || $order->customer_longitude === null) {
            return $this->no('لا يوجد موقع جغرافي للعميل على هذا الطلب.');
        }

        $warehouse = $this->warehouse($order);
        if (!$warehouse || $warehouse->latitude === null || $warehouse->longitude === null) {
            return $this->no('لا يوجد موقع جغرافي مسجّل للفرع.');
        }

        if ($this->activeDelivery($order)) {
            return $this->no('يوجد طلب مندوب قائم لهذا الطلب.');
        }

        $cap = (int) config('services.mrsool.daily_cap', 20);
        if ($cap > 0 && $this->requestsToday() >= $cap) {
            return $this->no('تم بلوغ الحد اليومي لطلبات مرسول.');
        }

        return ['ok' => true, 'reason' => null];
    }

    /** Delivery price for the order, or null when Mrsool cannot quote. Never throws. */
    public function quote(ZooboxiOrder $order): ?float
    {
        $warehouse = $this->warehouse($order);
        if (!$warehouse || $warehouse->latitude === null || $order->customer_latitude === null) {
            return null;
        }

        return $this->client->quote(
            ['latitude' => $warehouse->latitude, 'longitude' => $warehouse->longitude],
            ['latitude' => $order->customer_latitude, 'longitude' => $order->customer_longitude],
        );
    }

    // ─── Write path ─────────────────────────────────────────────

    /**
     * Request a courier: claim a ledger row, then call Mrsool.
     *
     * @throws MrsoolNotEligibleException  when one of our guards refuses (Arabic message)
     * @throws MrsoolException    when Mrsool rejects the create call
     */
    public function requestCourier(ZooboxiOrder $order, ?User $user = null): MrsoolDelivery
    {
        // Quote BEFORE the transaction — it is a read-only call and we do not
        // want a slow HTTP round-trip holding a row lock.
        $quote = $this->quote($order);

        /** @var MrsoolDelivery $delivery */
        $delivery = DB::transaction(function () use ($order, $user, $quote) {
            // Re-read the order under a row lock so two taps serialise here.
            $locked = ZooboxiOrder::whereKey($order->getKey())->lockForUpdate()->first();
            if (!$locked) {
                throw new MrsoolNotEligibleException('الطلب غير موجود.');
            }

            $check = $this->eligibility($locked);
            if (!$check['ok']) {
                throw new MrsoolNotEligibleException((string) $check['reason']);
            }

            // Atomic claim: UNIQUE partner_order_id means a racing insert throws.
            try {
                return MrsoolDelivery::create([
                    'zooboxi_order_id'  => $locked->id,
                    'woo_order_id'      => $locked->woo_order_id,
                    'partner_order_id'  => $this->nextPartnerOrderId($locked),
                    'environment'       => $this->client->environment(),
                    'phase'             => MrsoolDelivery::PHASE_SEARCHING,
                    'price_quote'       => $quote,
                    'requested_by'      => $user?->id,
                    'requested_at'      => now(),
                ]);
            } catch (QueryException $e) {
                Log::warning('mrsool: duplicate courier claim blocked', [
                    'context'  => 'mrsool',
                    'order_id' => $locked->id,
                ]);
                throw new MrsoolNotEligibleException('يوجد طلب مندوب قائم لهذا الطلب.');
            }
        });

        // Outside the transaction: the row is already claimed, so a failure here
        // is recorded on the row and never leaves a phantom courier behind.
        try {
            $remote = $this->client->createOrder($this->buildPayload($order, $delivery));
        } catch (MrsoolException $e) {
            // No Mrsool order exists, so leave `status` null — the row is a
            // failed claim, not a cancelled courier.
            $delivery->update([
                'phase'      => MrsoolDelivery::PHASE_FAILED,
                'last_error' => $e->getMessage(),
                'failed_at'  => now(),
            ]);
            throw $e;
        }

        // Fold in whatever the create response already tells us (id, courier, events…).
        $remote['status'] = $remote['status'] ?? MrsoolDelivery::S_COURIER_PENDING;
        $this->applyRemote($delivery, $remote);

        return $delivery->refresh();
    }

    /**
     * The payload sent to POST /api/v1/orders. Public so tests can assert its
     * exact shape (phone normalisation, string lat/lng, description length).
     */
    public function buildPayload(ZooboxiOrder $order, MrsoolDelivery $delivery): array
    {
        $warehouse = $this->warehouse($order);
        $order->loadMissing('lines');

        $number   = $this->orderNumber($order);
        $branch   = $warehouse?->display_name_ar ?: (string) config('services.mrsool.store_name', 'Zooboxi');
        $lines    = $order->lines ?? collect();
        $itemNames = $lines->take(3)->pluck('item_name')->filter()->implode('، ');
        $commodities = max(1, (int) round((float) $lines->sum('quantity')));

        $description = 'زوبوكسي ' . $number . ' · ' . $lines->count() . ' أصناف';
        if ($itemNames !== '') {
            $description .= ': ' . $itemNames;
        }
        $description = Str::limit($description, 250, '');

        return [
            'pickup' => [
                'latitude'  => (string) $warehouse?->latitude,
                'longitude' => (string) $warehouse?->longitude,
                'address'   => (string) ($warehouse?->address_ar ?: $branch),
            ],
            'dropoff' => [
                'latitude'  => (string) $order->customer_latitude,
                'longitude' => (string) $order->customer_longitude,
                'address'   => (string) ($order->customer_address ?: $order->customer_city),
            ],
            'buyer' => [
                'phone'     => $this->normalizePhone($order->customer_phone),
                'full_name' => (string) ($order->customer_name ?: 'عميل زوبوكسي'),
            ],
            'store' => [
                'name'  => $branch,
                'phone' => $this->normalizePhone($warehouse?->phone ?: config('services.mrsool.store_phone')),
            ],
            'shipment_value'   => (float) $order->total_amount,
            'partner_order_id' => $delivery->partner_order_id,
            'description'      => $description,
            'pickup_type'      => 'shop_pickup',
            'metadata' => [
                'commodities'          => $commodities,
                'pickup_instructions'  => Str::limit("استلام طلب زوبوكسي رقم {$number} من {$branch}", 500, ''),
                'delivery_instructions' => Str::limit((string) ($order->notes ?: ''), 500, ''),
            ],
        ];
    }

    /**
     * Fold a fetched Mrsool Order into the ledger row + the Zooboxi order.
     * Idempotent: re-applying the same payload changes nothing and fires no
     * duplicate push/notification (side effects hang off the PHASE change).
     *
     * @return bool whether anything changed
     */
    public function applyRemote(MrsoolDelivery $delivery, array $remote): bool
    {
        $remote = $remote['data'] ?? $remote;

        $status = isset($remote['status']) ? strtoupper((string) $remote['status']) : null;
        $phase  = MrsoolDelivery::phaseFor($status) ?? $delivery->phase;
        $from   = $delivery->phase;

        // A terminal phase never regresses (a late webhook can't undo delivery).
        if ($delivery->isTerminal() && !in_array($phase, MrsoolDelivery::TERMINAL_PHASES, true)) {
            $phase = $delivery->phase;
        }

        $attrs = [
            'phase'          => $phase,
            'last_synced_at' => now(),
            'raw_last'       => $remote,
        ];

        if ($status) {
            $attrs['status'] = $status;
            $attrs['is_partial'] = $status === MrsoolDelivery::S_PARTIALLY_DELIVERED
                ? true
                : (bool) $delivery->is_partial;
        }

        if (isset($remote['id']) && !$delivery->mrsool_order_id) {
            $attrs['mrsool_order_id'] = (int) $remote['id'];
        }

        // Courier identity may arrive under `courier` or `courier_info`.
        $courier = $remote['courier_info'] ?? $remote['courier'] ?? null;
        if (is_array($courier)) {
            $attrs['courier_name']  = $courier['full_name'] ?? $courier['name'] ?? $delivery->courier_name;
            $attrs['courier_phone'] = $courier['phone'] ?? $delivery->courier_phone;
        }

        $loc = $remote['courier_location'] ?? null;
        if (is_array($loc) && isset($loc['latitude'], $loc['longitude'])) {
            $attrs['courier_lat'] = (float) $loc['latitude'];
            $attrs['courier_lng'] = (float) $loc['longitude'];
        }

        // Mrsool's merchant tracking page (seen in webhook + GET payloads).
        if (!empty($remote['merchant_tracking_link']) && is_string($remote['merchant_tracking_link'])) {
            $attrs['tracking_url'] = $remote['merchant_tracking_link'];
        }

        foreach (['events_history' => 'events', 'pickup_confirmation_images' => 'pickup_images', 'dropoff_confirmation_images' => 'dropoff_images'] as $src => $col) {
            if (is_array($remote[$src] ?? null)) {
                $attrs[$col] = $remote[$src];
            }
        }

        // Phase timestamps — set once, on first entry into the phase.
        if ($phase === MrsoolDelivery::PHASE_ASSIGNED && !$delivery->assigned_at) {
            $attrs['assigned_at'] = now();
        }
        if ($phase === MrsoolDelivery::PHASE_IN_TRANSIT && !$delivery->picked_up_at) {
            $attrs['picked_up_at'] = now();
            $attrs['assigned_at'] = $delivery->assigned_at ?: now();
        }
        if ($phase === MrsoolDelivery::PHASE_DELIVERED && !$delivery->delivered_at) {
            $attrs['delivered_at'] = now();
            // Staging (and a fast courier) can jump straight to DELIVERED —
            // keep the earlier milestones non-null so the timeline reads sanely.
            $attrs['assigned_at']  = $delivery->assigned_at ?: now();
            $attrs['picked_up_at'] = $delivery->picked_up_at ?: now();
        }
        if ($phase === MrsoolDelivery::PHASE_FAILED && !$delivery->failed_at) {
            $attrs['failed_at'] = now();
            $attrs['last_error'] = $delivery->last_error ?: $this->failureReason($status);
        }

        $delivery->fill($attrs);
        // "Changed" ignores the heartbeat columns so callers can tell a real
        // update from a no-op poll.
        $changed = count(array_diff_key($delivery->getDirty(), ['last_synced_at' => 1, 'raw_last' => 1])) > 0;
        $delivery->save();

        if ($phase !== $from) {
            $this->onPhaseChange($delivery, $phase);
        }

        return $changed;
    }

    /** GET the order and fold it in. A 404 retires the row locally. */
    public function sync(MrsoolDelivery $delivery): bool
    {
        if (!$delivery->mrsool_order_id) {
            return false;
        }

        try {
            $remote = $this->client->getOrder((int) $delivery->mrsool_order_id);
        } catch (MrsoolException $e) {
            if ($e->httpStatus === 404) {
                $delivery->update([
                    'phase'      => MrsoolDelivery::PHASE_FAILED,
                    'last_error' => 'الطلب غير موجود لدى مرسول.',
                    'failed_at'  => $delivery->failed_at ?: now(),
                    'last_synced_at' => now(),
                ]);
                return true;
            }
            Log::warning('mrsool: sync failed: ' . $e->getMessage(), [
                'context'     => 'mrsool',
                'delivery_id' => $delivery->id,
            ]);
            return false;
        }

        return $this->applyRemote($delivery, $remote);
    }

    /** Pull the request back — only before the courier has collected. */
    public function cancel(MrsoolDelivery $delivery, ?User $user = null): MrsoolDelivery
    {
        if (!$delivery->canCancel()) {
            throw new MrsoolNotEligibleException('لا يمكن إلغاء الطلب بعد استلام المندوب له.');
        }

        if ($delivery->mrsool_order_id) {
            $this->client->cancel((int) $delivery->mrsool_order_id);
        }

        $delivery->update([
            'phase'      => MrsoolDelivery::PHASE_FAILED,
            'status'     => MrsoolDelivery::S_CANCELED,
            'last_error' => 'ألغي من الفرع',
            'failed_at'  => now(),
            'last_synced_at' => now(),
        ]);

        $this->onPhaseChange($delivery, MrsoolDelivery::PHASE_FAILED);

        return $delivery->refresh();
    }

    /**
     * Retire a delivery that Mrsool left searching for a courier far too long.
     * The caller must have just confirmed the remote state via sync().
     */
    public function retireStuck(MrsoolDelivery $delivery, string $reason = 'لم يُعثر على مندوب'): void
    {
        if ($delivery->isTerminal()) {
            return;
        }

        // Close it on Mrsool's side too (best effort) — otherwise a branch retry
        // could leave two live courier requests for one order.
        if ($delivery->mrsool_order_id) {
            try {
                $this->client->cancel((int) $delivery->mrsool_order_id);
            } catch (MrsoolException $e) {
                Log::info('mrsool: remote cancel on retire skipped: ' . $e->getMessage(), [
                    'context'     => 'mrsool',
                    'delivery_id' => $delivery->id,
                ]);
            }
        }

        $delivery->update([
            'phase'      => MrsoolDelivery::PHASE_FAILED,
            'status'     => MrsoolDelivery::S_EXPIRED,
            'last_error' => $reason,
            'failed_at'  => now(),
        ]);

        $this->onPhaseChange($delivery, MrsoolDelivery::PHASE_FAILED);
    }

    /**
     * Process an (unsigned) webhook body: log it, apply the lightweight status,
     * then re-fetch from the API so nothing but {id,status} is ever trusted.
     *
     * @return bool whether the order id was known to us
     */
    public function handleWebhook(array $payload): bool
    {
        $remoteId = isset($payload['id']) ? (int) $payload['id'] : 0;
        $status   = isset($payload['status']) ? strtoupper((string) $payload['status']) : null;

        $event = MrsoolWebhookEvent::create([
            'mrsool_order_id' => $remoteId ?: null,
            'status'          => $status,
            'payload'         => $payload,
            'processed'       => false,
            'created_at'      => now(),
        ]);

        $delivery = $remoteId ? MrsoolDelivery::where('mrsool_order_id', $remoteId)->first() : null;
        if (!$delivery) {
            Log::info('mrsool: webhook for unknown order', [
                'context'         => 'mrsool',
                'mrsool_order_id' => $remoteId,
                'status'          => $status,
            ]);
            return false;
        }

        // Verify BEFORE acting: re-fetch the order so the phase change (and the
        // Woo push / notification it triggers) carries the courier, photos and
        // tracking link. Only if Mrsool cannot be reached do we fall back to
        // the webhook's own {id,status} hint.
        $synced = false;
        try {
            $synced = $this->sync($delivery);
        } catch (\Throwable $e) {
            Log::info('mrsool: webhook re-fetch failed: ' . $e->getMessage(), ['context' => 'mrsool']);
        }

        if (!$synced && $status) {
            $this->applyRemote($delivery, $payload + ['id' => $remoteId, 'status' => $status]);
        }

        $event->update(['processed' => true]);

        return true;
    }

    // ─── Side effects ───────────────────────────────────────────

    /**
     * Everything that must happen exactly once per phase transition: the
     * Zooboxi delivery_status move, the WooCommerce push, the branch push.
     */
    protected function onPhaseChange(MrsoolDelivery $delivery, string $phase): void
    {
        $order = $delivery->order()->first();
        if (!$order) {
            return;
        }

        $number = $this->orderNumber($order);

        switch ($phase) {
            case MrsoolDelivery::PHASE_ASSIGNED:
                $this->notify($delivery, $order, 'تم تعيين مندوب مرسول', trim(
                    'الطلب ' . $number . ' — المندوب: ' . ($delivery->courier_name ?: 'قيد التعيين')
                ));
                break;

            case MrsoolDelivery::PHASE_IN_TRANSIT:
                if ($order->delivery_status !== ZooboxiOrder::STATUS_DELIVERED) {
                    $order->update(['delivery_status' => ZooboxiOrder::STATUS_OUT_FOR_DELIVERY]);
                    $this->pushWoo($order, 'zb-out-for-delivery', $delivery);
                }
                $this->notify($delivery, $order, 'الطلب في الطريق', 'المندوب استلم الطلب ' . $number . ' وهو في الطريق للعميل.');
                break;

            case MrsoolDelivery::PHASE_DELIVERED:
                $order->update(['delivery_status' => ZooboxiOrder::STATUS_DELIVERED]);
                $this->pushWoo($order, 'completed', $delivery);
                $this->notify(
                    $delivery,
                    $order,
                    $delivery->is_partial ? 'تم التوصيل جزئياً' : 'تم توصيل الطلب',
                    'الطلب ' . $number . ' وصل للعميل.'
                );
                break;

            case MrsoolDelivery::PHASE_FAILED:
                // Hand the order back to the branch, but never un-deliver it.
                if ($order->delivery_status !== ZooboxiOrder::STATUS_DELIVERED) {
                    $order->update(['delivery_status' => ZooboxiOrder::STATUS_READY_FOR_PICKUP]);
                }
                $reason = $delivery->last_error ?: $this->failureReason($delivery->status);
                $this->notify($delivery, $order, 'تعذّر توصيل الطلب عبر مرسول', 'الطلب ' . $number . ' — ' . $reason);
                break;
        }
    }

    /** Push the store status, carrying the Mrsool tracking meta along with it. */
    protected function pushWoo(ZooboxiOrder $order, string $status, MrsoolDelivery $delivery): void
    {
        if (!$order->woo_order_id) {
            return;
        }

        $ok = $this->store->setOrderStatus((int) $order->woo_order_id, $status, [
            'mrsool' => array_filter([
                'order_id'      => $delivery->mrsool_order_id,
                'status'        => $delivery->status,
                'courier_name'  => $delivery->courier_name,
                'courier_phone' => $delivery->courier_phone,
                'tracking_url'  => $delivery->tracking_url ?: $delivery->awb_url,
            ], fn ($v) => $v !== null && $v !== ''),
        ]);

        if ($ok) {
            $order->update(['woo_status_synced_at' => now()]);
        }
    }

    /** Push to the branch users of this warehouse (deduped per delivery+phase). */
    protected function notify(MrsoolDelivery $delivery, ZooboxiOrder $order, string $title, string $body): void
    {
        $codes = array_filter(array_merge(
            [(string) $order->warehouse_code],
            (array) ($this->warehouse($order)?->sap_warehouse_codes ?? []),
        ));

        try {
            $this->notifications->route(
                'mrsool_delivery_update',
                NotificationAudience::warehouseUsers($codes),
                [
                    'title' => $title,
                    'body'  => $body,
                    'data'  => [
                        'type'     => 'zooboxi_order',
                        'order_id' => (string) $order->id,
                    ],
                ],
                ['dedupe_key' => "mrsool:notify:{$delivery->id}:{$delivery->phase}", 'dedupe_ttl' => 180],
            );
        } catch (\Throwable $e) {
            Log::warning('mrsool: notification failed: ' . $e->getMessage(), ['context' => 'mrsool']);
        }
    }

    // ─── Lookups & helpers ──────────────────────────────────────

    public function activeDelivery(ZooboxiOrder $order): ?MrsoolDelivery
    {
        return MrsoolDelivery::where('zooboxi_order_id', $order->id)
            ->active()
            ->latest('id')
            ->first();
    }

    public function latestDelivery(ZooboxiOrder $order): ?MrsoolDelivery
    {
        return MrsoolDelivery::where('zooboxi_order_id', $order->id)->latest('id')->first();
    }

    public function warehouse(ZooboxiOrder $order): ?ZooboxiWarehouse
    {
        if (!$order->warehouse_code) {
            return null;
        }

        return ZooboxiWarehouse::where('warehouse_code', $order->warehouse_code)->first();
    }

    /** ZB-1234 for the first attempt, then -R2, -R3 … per retry. */
    public function nextPartnerOrderId(ZooboxiOrder $order): string
    {
        $base = $this->orderNumber($order);
        $attempt = MrsoolDelivery::where('zooboxi_order_id', $order->id)->count() + 1;

        return $attempt === 1 ? $base : $base . '-R' . $attempt;
    }

    /**
     * Normalise a Saudi mobile to the local 05XXXXXXXX form Mrsool expects,
     * accepting +9665…, 009665…, 9665… and bare 5….
     */
    public function normalizePhone(?string $phone): string
    {
        $digits = preg_replace('/\D+/', '', (string) $phone) ?? '';
        if ($digits === '') {
            return '';
        }

        $digits = preg_replace('/^00/', '', $digits);
        if (str_starts_with($digits, '966')) {
            $digits = substr($digits, 3);
        }
        if (str_starts_with($digits, '0')) {
            $digits = ltrim($digits, '0');
        }

        return str_starts_with($digits, '5') ? '0' . $digits : $digits;
    }

    protected function orderNumber(ZooboxiOrder $order): string
    {
        return (string) ($order->woo_order_number ?: 'ZB-' . $order->woo_order_id);
    }

    protected function isCod(ZooboxiOrder $order): bool
    {
        return str_contains(strtolower((string) $order->payment_method), 'cod');
    }

    protected function allowsCod(): bool
    {
        return (bool) config('services.mrsool.allow_cod', false);
    }

    protected function failureReason(?string $status): string
    {
        return match (strtoupper((string) $status)) {
            MrsoolDelivery::S_EXPIRED  => 'لم يُعثر على مندوب',
            MrsoolDelivery::S_CANCELED => 'ألغي الطلب',
            MrsoolDelivery::S_RETURN   => 'مرتجع للفرع',
            default                    => 'تعذّر إتمام التوصيل',
        };
    }

    /** @return array{ok: bool, reason: string} */
    protected function no(string $reason): array
    {
        return ['ok' => false, 'reason' => $reason];
    }
}
