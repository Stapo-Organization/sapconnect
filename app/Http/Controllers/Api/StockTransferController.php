<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\StockTransfer;
use App\Models\StockTransferLog;
use App\Http\Resources\StockTransferResource;
use App\Http\Resources\StockTransferListResource;
use App\Http\Resources\StockTransferLogResource;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class StockTransferController extends Controller
{
    protected NotificationService $notificationService;

    public function __construct(NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    /**
     * Get the active SAP database from config (set by middleware).
     */
    protected function getActiveDb(): string
    {
        return config('sap.company_db', 'PPTC_V5_PROD');
    }

    /**
     * List stock transfers with filters.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $db = $this->getActiveDb();

        $query = StockTransfer::query()
            ->where('sap_database', $db)
            ->with('lines.product');

        // Filter by user's warehouse if they have one
        $codes = $this->getUserWarehouseCodes($user);
        if (!empty($codes)) {
            $query->where(function ($q) use ($codes) {
                $q->whereIn('from_warehouse', $codes)
                  ->orWhereIn('to_warehouse', $codes);
            });
        }

        // ─── Filters ────────────────────────────────────────────

        // SAP Document Status (bost_Open, bost_Close)
        if ($request->has('status')) {
            $query->where('document_status', $request->status);
        }

        // Internal Status (New, Shipped, Received, Completed)
        if ($request->has('internal_status')) {
            $query->where('internal_status', $request->internal_status);
        }

        // Hide Completed Transfers
        if ($request->boolean('hide_completed')) {
            $query->where('internal_status', '!=', 'Completed');
        }

        // Warehouse filters
        if ($request->has('from_warehouse')) {
            $query->where('from_warehouse', $request->from_warehouse);
        }
        if ($request->has('to_warehouse')) {
            $query->where('to_warehouse', $request->to_warehouse);
        }

        // Date filters
        if ($request->has('date_from')) {
            $query->whereDate('doc_date', '>=', $request->date_from);
        }
        if ($request->has('date_to')) {
            $query->whereDate('doc_date', '<=', $request->date_to);
        }

        // Search by doc_num
        if ($request->has('search')) {
            $query->where('doc_num', 'LIKE', '%' . $request->search . '%');
        }

        $transfers = $query->latest('doc_date')->paginate($request->get('per_page', 20));

        return StockTransferListResource::collection($transfers);
    }

    /**
     * Show a single stock transfer with full details.
     */
    public function show(Request $request, $id)
    {
        $db = $this->getActiveDb();

        $transfer = StockTransfer::where('sap_database', $db)
            ->where(function ($q) use ($id) {
                $q->where('id', $id)->orWhere('doc_num', $id);
            })
            ->with('lines.product', 'sender', 'receiver')
            ->firstOrFail();

        return new StockTransferResource($transfer);
    }

    /**
     * Send items: update sent_quantity for each line.
     * Called by sender warehouse user.
     */
    public function sendItems(Request $request, $id)
    {
        $request->validate([
            'items' => 'required|array',
            'items.*.item_code' => 'required|string',
            'items.*.quantity' => 'required|numeric|min:0',
            'notes' => 'nullable|string',
        ]);

        $user = $request->user();
        $db = $this->getActiveDb();

        $transfer = StockTransfer::where('sap_database', $db)->findOrFail($id);

        // Check permissions: user must be associated with from_warehouse
        if (!$this->userCanSend($user, $transfer)) {
            return response()->json([
                'message' => 'غير مصرح لك بإرسال هذا التحويل. يجب أن تكون مرتبطاً بمستودع المرسل.'
            ], 403);
        }

        // Check status
        if (!$transfer->canSend()) {
            return response()->json([
                'message' => 'لا يمكن إرسال هذا التحويل. الحالة الحالية: ' . $transfer->internal_status
            ], 422);
        }

        return DB::transaction(function () use ($request, $transfer, $user) {
            $oldStatus = $transfer->internal_status;

            foreach ($request->items as $item) {
                $line = $transfer->lines()->where('item_code', $item['item_code'])->first();
                if ($line) {
                    $line->update(['sent_quantity' => $item['quantity']]);
                }
            }

            // Save sender info
            $transfer->update([
                'sender_notes' => $request->notes,
            ]);

            // Log the action
            StockTransferLog::record(
                $transfer->id,
                $user->id,
                StockTransferLog::ACTION_ITEMS_SENT,
                $oldStatus,
                $oldStatus, // Status doesn't change yet
                [
                    'items' => $request->items,
                    'notes' => $request->notes,
                ],
                $request->ip()
            );

            return response()->json([
                'message' => 'تم حفظ الكميات المرسلة بنجاح',
                'transfer' => new StockTransferResource($transfer->fresh(['lines.product', 'sender', 'receiver'])),
            ]);
        });
    }

    /**
     * Confirm send: marks transfer as Shipped.
     * Called by sender warehouse user after reviewing items.
     */
    public function confirmSend(Request $request, $id)
    {
        $user = $request->user();
        $db = $this->getActiveDb();

        $transfer = StockTransfer::where('sap_database', $db)->findOrFail($id);

        if (!$this->userCanSend($user, $transfer)) {
            return response()->json([
                'message' => 'غير مصرح لك بتأكيد إرسال هذا التحويل.'
            ], 403);
        }

        if (!$transfer->canSend()) {
            return response()->json([
                'message' => 'لا يمكن تأكيد إرسال هذا التحويل. الحالة الحالية: ' . $transfer->internal_status
            ], 422);
        }

        // Validate that at least some items have sent_quantity > 0
        $totalSent = $transfer->lines()->sum('sent_quantity');
        if ($totalSent <= 0) {
            return response()->json([
                'message' => 'يجب تحديد كميات مرسلة قبل تأكيد الإرسال.'
            ], 422);
        }

        return DB::transaction(function () use ($request, $transfer, $user) {
            $oldStatus = $transfer->internal_status;

            $transfer->update([
                'internal_status' => StockTransfer::STATUS_SHIPPED,
                'sent_by' => $user->id,
                'sent_at' => now(),
            ]);

            // Log
            StockTransferLog::record(
                $transfer->id,
                $user->id,
                StockTransferLog::ACTION_SEND_CONFIRMED,
                $oldStatus,
                StockTransfer::STATUS_SHIPPED,
                [
                    'total_sent_qty' => $transfer->lines()->sum('sent_quantity'),
                    'sender_notes' => $transfer->sender_notes,
                ],
                $request->ip()
            );

            // Notify receiver warehouse users
            try {
                $this->notificationService->notifyWarehouseUsers(
                    $transfer->to_warehouse,
                    'شحنة جديدة في الطريق',
                    "تحويل المخزون #{$transfer->doc_num} تم شحنه من {$transfer->from_warehouse}. يرجى مراجعة واستلام البضاعة.",
                    ['transfer_id' => $transfer->id, 'doc_num' => $transfer->doc_num]
                );
            } catch (\Exception $e) {
                Log::error("Failed to notify receiver: " . $e->getMessage());
            }

            return response()->json([
                'message' => 'تم تأكيد الإرسال بنجاح وتم إشعار المستودع المستقبل.',
                'transfer' => new StockTransferResource($transfer->fresh(['lines.product', 'sender', 'receiver'])),
            ]);
        });
    }

    /**
     * Receive items: update actual_received_quantity for each line.
     * Called by receiver warehouse user.
     */
    public function receiveItems(Request $request, $id)
    {
        $request->validate([
            'items' => 'required|array',
            'items.*.item_code' => 'required|string',
            'items.*.quantity' => 'required|numeric|min:0',
            'notes' => 'nullable|string',
        ]);

        $user = $request->user();
        $db = $this->getActiveDb();

        $transfer = StockTransfer::where('sap_database', $db)->findOrFail($id);

        if (!$this->userCanReceive($user, $transfer)) {
            return response()->json([
                'message' => 'غير مصرح لك باستلام هذا التحويل. يجب أن تكون مرتبطاً بمستودع المستقبل.'
            ], 403);
        }

        if (!$transfer->canReceive()) {
            return response()->json([
                'message' => 'لا يمكن استلام هذا التحويل. الحالة الحالية: ' . $transfer->internal_status
            ], 422);
        }

        return DB::transaction(function () use ($request, $transfer, $user) {
            $oldStatus = $transfer->internal_status;

            foreach ($request->items as $item) {
                $line = $transfer->lines()->where('item_code', $item['item_code'])->first();
                if ($line) {
                    $line->update(['actual_received_quantity' => $item['quantity']]);
                }
            }

            $transfer->update([
                'receiver_notes' => $request->notes,
            ]);

            StockTransferLog::record(
                $transfer->id,
                $user->id,
                StockTransferLog::ACTION_ITEMS_RECEIVED,
                $oldStatus,
                $oldStatus,
                [
                    'items' => $request->items,
                    'notes' => $request->notes,
                ],
                $request->ip()
            );

            return response()->json([
                'message' => 'تم حفظ الكميات المستلمة بنجاح',
                'transfer' => new StockTransferResource($transfer->fresh(['lines.product', 'sender', 'receiver'])),
            ]);
        });
    }

    /**
     * Confirm receive: marks transfer as Received.
     */
    public function confirmReceive(Request $request, $id)
    {
        $user = $request->user();
        $db = $this->getActiveDb();

        $transfer = StockTransfer::where('sap_database', $db)->findOrFail($id);

        if (!$this->userCanReceive($user, $transfer)) {
            return response()->json([
                'message' => 'غير مصرح لك بتأكيد استلام هذا التحويل.'
            ], 403);
        }

        if (!$transfer->canReceive()) {
            return response()->json([
                'message' => 'لا يمكن تأكيد استلام هذا التحويل. الحالة الحالية: ' . $transfer->internal_status
            ], 422);
        }

        return DB::transaction(function () use ($request, $transfer, $user) {
            $oldStatus = $transfer->internal_status;

            $transfer->update([
                'internal_status' => StockTransfer::STATUS_RECEIVED,
                'received_by' => $user->id,
                'received_at' => now(),
            ]);

            StockTransferLog::record(
                $transfer->id,
                $user->id,
                StockTransferLog::ACTION_RECEIVE_CONFIRMED,
                $oldStatus,
                StockTransfer::STATUS_RECEIVED,
                [
                    'total_received_qty' => $transfer->lines()->sum('actual_received_quantity'),
                    'receiver_notes' => $transfer->receiver_notes,
                ],
                $request->ip()
            );

            // Notify sender that the shipment was received
            try {
                $this->notificationService->notifyWarehouseUsers(
                    $transfer->from_warehouse,
                    'تم استلام الشحنة',
                    "تحويل المخزون #{$transfer->doc_num} تم استلامه في {$transfer->to_warehouse}.",
                    ['transfer_id' => $transfer->id, 'doc_num' => $transfer->doc_num]
                );
            } catch (\Exception $e) {
                Log::error("Failed to notify sender: " . $e->getMessage());
            }

            return response()->json([
                'message' => 'تم تأكيد الاستلام بنجاح. تم إشعار المستودع المرسل.',
                'transfer' => new StockTransferResource($transfer->fresh(['lines.product', 'sender', 'receiver'])),
            ]);
        });
    }

    /**
     * Get audit logs for a stock transfer.
     */
    public function logs(Request $request, $id)
    {
        $db = $this->getActiveDb();
        $transfer = StockTransfer::where('sap_database', $db)->findOrFail($id);

        $logs = $transfer->logs()->with('user')->latest()->get();

        return StockTransferLogResource::collection($logs);
    }

    // ─── Authorization Helpers ──────────────────────────────────

    protected function getUserWarehouseCodes($user): array
    {
        if (!$user || !$user->warehouse_code) return [];
        $codes = $user->warehouse_code;
        if (is_string($codes)) {
            $decoded = json_decode($codes, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $codes = $decoded;
            }
        }
        return is_array($codes) ? $codes : [$codes];
    }

    protected function userCanSend($user, StockTransfer $transfer): bool
    {
        $codes = $this->getUserWarehouseCodes($user);
        if (empty($codes)) return true; // Admin (no warehouse restriction)
        return in_array($transfer->from_warehouse, $codes);
    }

    protected function userCanReceive($user, StockTransfer $transfer): bool
    {
        $codes = $this->getUserWarehouseCodes($user);
        if (empty($codes)) return true; // Admin
        return in_array($transfer->to_warehouse, $codes);
    }
}
