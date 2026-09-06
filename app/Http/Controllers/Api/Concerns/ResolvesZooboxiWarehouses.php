<?php

namespace App\Http\Controllers\Api\Concerns;

use App\Models\ZooboxiOrder;
use App\Models\ZooboxiWarehouse;

/**
 * Warehouse scoping for the Zooboxi branch APIs.
 *
 * The user carries SAP warehouse codes; orders carry Zooboxi codes. We map via
 * ZooboxiWarehouse.sap_warehouse_codes and union with the raw SAP codes so it
 * works whether the codes are bridged or simply coincide.
 *
 * Shared by ZooboxiOrderController and MrsoolDeliveryController so a branch can
 * only ever act on its own orders through either surface.
 */
trait ResolvesZooboxiWarehouses
{
    /** Query limited to the orders the user's branch may act on. */
    protected function scopedZooboxiOrders($user)
    {
        $codes = $this->resolveZooboxiWarehouseCodes($user);

        return ZooboxiOrder::query()->whereIn('warehouse_code', $codes ?: ['__none__']);
    }

    /** Zooboxi warehouse codes visible to this user. */
    protected function resolveZooboxiWarehouseCodes($user): array
    {
        $sapCodes = $this->getUserWarehouseCodes($user);
        if (empty($sapCodes)) {
            return [];
        }

        $mapped = ZooboxiWarehouse::query()
            ->where(function ($q) use ($sapCodes) {
                foreach ($sapCodes as $code) {
                    $q->orWhereJsonContains('sap_warehouse_codes', $code);
                }
            })
            ->pluck('warehouse_code')
            ->all();

        return array_values(array_unique(array_merge($sapCodes, $mapped)));
    }

    /**
     * Decode the user's warehouse codes (JSON array or scalar).
     * Mirrors InventoryCountingController::getUserWarehouseCodes.
     */
    protected function getUserWarehouseCodes($user): array
    {
        if (!$user || !$user->warehouse_code) {
            return [];
        }

        $codes = $user->warehouse_code;
        if (is_string($codes)) {
            $decoded = json_decode($codes, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $codes = $decoded;
            }
        }

        return is_array($codes) ? $codes : [$codes];
    }
}
