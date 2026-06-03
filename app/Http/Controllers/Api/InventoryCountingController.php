<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\InventoryCountingApiResource;
use App\Models\InventoryCounting;
use App\Models\InventoryCountingLine;
use App\Models\Product;
use App\Models\WarehouseItemStock;
use App\Services\Counting\VarianceCalculationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryCountingController extends Controller
{
    /**
     * List inventory counting sessions for the authenticated user.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $codes = $this->getUserWarehouseCodes($user);

        $query = InventoryCounting::query()
            ->with(['user', 'lines'])
            ->latest();

        // Filter by user's warehouses
        if (!empty($codes)) {
            $query->whereIn('warehouse_code', $codes);
        }

        // Status filter
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Warehouse filter
        if ($request->has('warehouse_code')) {
            $query->where('warehouse_code', $request->warehouse_code);
        }

        $countings = $query->paginate($request->get('per_page', 20));

        return InventoryCountingApiResource::collection($countings);
    }

    /**
     * Create a new inventory counting session.
     */
    public function store(Request $request)
    {
        $request->validate([
            'warehouse_code' => 'required|string|exists:warehouses,warehouse_code',
            'notes' => 'nullable|string|max:1000',
        ]);

        $user = $request->user();
        $codes = $this->getUserWarehouseCodes($user);

        // Verify user has access to this warehouse
        if (!empty($codes) && !in_array($request->warehouse_code, $codes)) {
            return response()->json([
                'message' => 'غير مصرح لك بإنشاء جرد لهذا المستودع.'
            ], 403);
        }

        $warehouse = \App\Models\Warehouse::where('warehouse_code', $request->warehouse_code)->first();

        $counting = InventoryCounting::create([
            'warehouse_code' => $request->warehouse_code,
            'warehouse_name' => $warehouse?->warehouse_name,
            'status' => InventoryCounting::STATUS_IN_PROGRESS,
            'counted_by' => $user->id,
            'notes' => $request->notes,
        ]);

        $counting->load(['user', 'lines']);

        return response()->json([
            'message' => 'تم إنشاء سجل الجرد بنجاح',
            'data' => new InventoryCountingApiResource($counting),
        ], 201);
    }

    /**
     * Show a single inventory counting session with all lines.
     */
    public function show(Request $request, $id)
    {
        $user = $request->user();
        $codes = $this->getUserWarehouseCodes($user);

        $query = InventoryCounting::with(['user', 'lines']);

        if (!empty($codes)) {
            $query->whereIn('warehouse_code', $codes);
        }

        $counting = $query->findOrFail($id);

        return new InventoryCountingApiResource($counting);
    }

    /**
     * Scan a barcode and look up the product.
     * Returns product info and any existing line in this counting session.
     */
    public function scan(Request $request, $id)
    {
        $request->validate([
            'barcode' => 'required|string',
        ]);

        $user = $request->user();
        $codes = $this->getUserWarehouseCodes($user);

        $query = InventoryCounting::query();
        if (!empty($codes)) {
            $query->whereIn('warehouse_code', $codes);
        }

        $counting = $query->findOrFail($id);

        // Only allow scanning on in-progress countings
        if (!$counting->isInProgress()) {
            return response()->json([
                'message' => 'لا يمكن إضافة منتجات لسجل جرد ' . ($counting->isCompleted() ? 'مكتمل' : 'ملغي')
            ], 422);
        }

        $barcode = $request->barcode;

        // Search by piece_barcode or item_code
        $product = Product::where('piece_barcode', $barcode)
            ->orWhere('item_code', $barcode)
            ->first();

        if (!$product) {
            return response()->json([
                'message' => 'لم يتم العثور على منتج بهذا الباركود',
                'barcode' => $barcode,
            ], 404);
        }

        $folder = substr($product->item_code, 0, 4);

        // Return existing_line as null so frontend always adds a new record
        return response()->json([
            'product' => [
                'item_code' => $product->item_code,
                'item_name' => $product->item_name,
                'item_name_ar' => $product->foreign_name ?: ($product->zb_name_ar ?: $product->item_name),
                'item_name_en' => $product->item_name ?: ($product->zb_name_en ?: $product->item_name),
                'piece_barcode' => $product->piece_barcode,
                'image_url' => "https://ppte.sa/imghd/{$folder}/{$product->item_code}.png",
            ],
            'existing_line' => null,
        ]);
    }

    /**
     * Add a new line to the inventory counting session.
     */
    public function addLine(Request $request, $id)
    {
        $request->validate([
            'item_code' => 'required|string',
            'counted_quantity' => 'required|numeric|min:0',
        ]);

        $user = $request->user();
        $counting = $this->getAuthorizedCounting($user, $id);

        if (!$counting->isInProgress()) {
            return response()->json([
                'message' => 'لا يمكن تعديل سجل جرد غير جاري'
            ], 422);
        }

        // Attribute cycle execution to the manager who actually counts.
        $this->claimIfCycle($counting, $user);

        $product = Product::where('item_code', $request->item_code)->first();

        // Snapshot system quantity from WarehouseItemStock (Blind Count — not shown to user)
        $systemQty = WarehouseItemStock::where('warehouse_code', $counting->warehouse_code)
            ->where('item_code', $request->item_code)
            ->value('in_stock') ?? 0;

        // Always create a new line (as requested, do not update quantity of existing line)
        $line = $counting->lines()->create([
            'item_code' => $request->item_code,
            'item_name' => $product?->item_name ?? $request->item_code,
            'piece_barcode' => $product?->piece_barcode,
            'counted_quantity' => $request->counted_quantity,
            'system_quantity' => (float) $systemQty,
        ]);
        $message = 'تم إضافة المنتج بنجاح';

        return response()->json([
            'message' => $message,
            'line' => new \App\Http\Resources\InventoryCountingLineApiResource($line),
        ]);
    }

    /**
     * Update the quantity of an existing line.
     */
    public function updateLine(Request $request, $id, $lineId)
    {
        $request->validate([
            'counted_quantity' => 'required|numeric|min:0',
        ]);

        $user = $request->user();
        $counting = $this->getAuthorizedCounting($user, $id);

        if (!$counting->isInProgress()) {
            return response()->json([
                'message' => 'لا يمكن تعديل سجل جرد غير جاري'
            ], 422);
        }

        $line = $counting->lines()->findOrFail($lineId);

        $line->update([
            'counted_quantity' => $request->counted_quantity,
        ]);

        return response()->json([
            'message' => 'تم تحديث الكمية بنجاح',
            'line' => new \App\Http\Resources\InventoryCountingLineApiResource($line),
        ]);
    }

    /**
     * Delete a line from the counting session.
     */
    public function deleteLine(Request $request, $id, $lineId)
    {
        $user = $request->user();
        $counting = $this->getAuthorizedCounting($user, $id);

        if (!$counting->isInProgress()) {
            return response()->json([
                'message' => 'لا يمكن تعديل سجل جرد غير جاري'
            ], 422);
        }

        $line = $counting->lines()->findOrFail($lineId);
        $line->delete();

        return response()->json([
            'message' => 'تم حذف المنتج من سجل الجرد',
        ]);
    }

    /**
     * Mark counting as completed.
     */
    public function complete(Request $request, $id)
    {
        $user = $request->user();
        $counting = $this->getAuthorizedCounting($user, $id);

        if (!$counting->isInProgress()) {
            return response()->json([
                'message' => 'لا يمكن إكمال سجل جرد غير جاري. الحالة الحالية: ' . $counting->status
            ], 422);
        }

        if ($counting->lines()->count() === 0) {
            return response()->json([
                'message' => 'لا يمكن إكمال سجل جرد فارغ. قم بإضافة منتجات أولاً.'
            ], 422);
        }

        $counting->markAsCompleted();

        // Calculate variances automatically
        $varianceService = new VarianceCalculationService();
        $varianceSummary = $varianceService->calculateForSession($counting);

        $counting->load(['user', 'lines']);

        return response()->json([
            'message' => 'تم إكمال الجرد بنجاح',
            'data' => new InventoryCountingApiResource($counting),
            'variance_summary' => $varianceSummary,
        ]);
    }

    /**
     * Cancel a counting session.
     */
    public function cancel(Request $request, $id)
    {
        $user = $request->user();
        $counting = $this->getAuthorizedCounting($user, $id);

        if (!$counting->isInProgress()) {
            return response()->json([
                'message' => 'لا يمكن إلغاء سجل جرد غير جاري. الحالة الحالية: ' . $counting->status
            ], 422);
        }

        $counting->markAsCancelled();
        $counting->load(['user', 'lines']);

        return response()->json([
            'message' => 'تم إلغاء سجل الجرد',
            'data' => new InventoryCountingApiResource($counting),
        ]);
    }

    /**
     * Look up a product by barcode (standalone, not tied to a counting session).
     */
    public function lookupBarcode(Request $request, $barcode)
    {
        $product = Product::where('piece_barcode', $barcode)
            ->orWhere('item_code', $barcode)
            ->first();

        if (!$product) {
            return response()->json([
                'message' => 'لم يتم العثور على منتج بهذا الباركود',
            ], 404);
        }

        $folder = substr($product->item_code, 0, 4);

        return response()->json([
            'product' => [
                'item_code' => $product->item_code,
                'item_name' => $product->item_name,
                'item_name_ar' => $product->foreign_name ?: ($product->zb_name_ar ?: $product->item_name),
                'item_name_en' => $product->item_name ?: ($product->zb_name_en ?: $product->item_name),
                'piece_barcode' => $product->piece_barcode,
                'image_url' => "https://ppte.sa/imghd/{$folder}/{$product->item_code}.png",
            ],
        ]);
    }

    // ─── Helpers ────────────────────────────────────────────────

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

    protected function getAuthorizedCounting($user, $id): InventoryCounting
    {
        $codes = $this->getUserWarehouseCodes($user);

        $query = InventoryCounting::query();
        if (!empty($codes)) {
            $query->whereIn('warehouse_code', $codes);
        }

        return $query->findOrFail($id);
    }

    // ─── Cycle Counting Endpoints ───────────────────────────────

    /**
     * Get variance report for a completed counting session.
     */
    public function varianceReport(Request $request, $id)
    {
        $user = $request->user();
        $counting = $this->getAuthorizedCounting($user, $id);

        if (!$counting->isCompleted()) {
            return response()->json([
                'message' => 'تقرير الفروقات متاح فقط للجرود المكتملة'
            ], 422);
        }

        $counting->load(['lines.product', 'user']);

        $varianceService = new VarianceCalculationService();
        $report = $varianceService->getVarianceReport($counting);

        // Include uncounted items for admin awareness
        $uncountedItems = $varianceService->getUncountedItems($counting);

        return response()->json([
            'report' => $report,
            'uncounted_items' => $uncountedItems->take(100)->values(),
            'uncounted_count' => $uncountedItems->count(),
        ]);
    }

    /**
     * Add an investigation note to a counting line.
     */
    public function investigate(Request $request, $id, $lineId)
    {
        $request->validate([
            'note' => 'required|string|max:2000',
        ]);

        $user = $request->user();
        $counting = $this->getAuthorizedCounting($user, $id);

        $line = $counting->lines()->findOrFail($lineId);

        $line->update([
            'investigation_note' => $request->note,
        ]);

        return response()->json([
            'message' => 'تم حفظ ملاحظة التحقيق',
            'line' => new \App\Http\Resources\InventoryCountingLineApiResource($line),
        ]);
    }

    /**
     * Get scheduled and overdue counting sessions for the user's warehouses.
     */
    public function schedule(Request $request)
    {
        $user = $request->user();
        $codes = $this->getUserWarehouseCodes($user);

        // Get overdue cycle sessions
        $overdueQuery = InventoryCounting::overdue()->with('user')->latest('scheduled_date');
        if (!empty($codes)) {
            $overdueQuery->whereIn('warehouse_code', $codes);
        }
        $overdue = $overdueQuery->get();

        // Get upcoming scheduled sessions
        $upcomingQuery = InventoryCounting::scheduled()
            ->whereNotNull('scheduled_date')
            ->where('scheduled_date', '>=', now()->toDateString())
            ->with('user')
            ->orderBy('scheduled_date');
        if (!empty($codes)) {
            $upcomingQuery->whereIn('warehouse_code', $codes);
        }
        $upcoming = $upcomingQuery->get();

        // Get cycle plans
        $plansQuery = \App\Models\InventoryCyclePlan::active();
        if (!empty($codes)) {
            $plansQuery->whereIn('warehouse_code', $codes);
        }
        $plans = $plansQuery->get();

        return response()->json([
            'overdue' => InventoryCountingApiResource::collection($overdue),
            'overdue_count' => $overdue->count(),
            'upcoming' => InventoryCountingApiResource::collection($upcoming),
            'plans' => $plans,
        ]);
    }

    /**
     * Get ABC classification summary for a warehouse.
     */
    public function abcSummary(Request $request, $warehouseCode)
    {
        $service = new \App\Services\Counting\AbcClassificationService();
        $summary = $service->getWarehouseSummary($warehouseCode);

        return response()->json($summary);
    }

    /**
     * Get cycle counting progress for a warehouse.
     */
    public function cycleProgress(Request $request, $warehouseCode)
    {
        $user = $request->user();

        // Get active plan
        $plan = \App\Models\InventoryCyclePlan::active()
            ->where('warehouse_code', $warehouseCode)
            ->first();

        if (!$plan) {
            return response()->json(['message' => 'لا توجد خطة جرد دوري لهذا المستودع'], 404);
        }

        // Get completed sessions this cycle
        $sessions = InventoryCounting::where('cycle_plan_id', $plan->id)
            ->where('counting_type', 'cycle')
            ->where('status', 'completed')
            ->where('created_at', '>=', $plan->current_cycle_start ?? now()->subWeeks($plan->cycle_length_weeks))
            ->get();

        // Count items counted per class
        $countedByClass = \App\Models\ProductAbcClassification::where('warehouse_code', $warehouseCode)
            ->whereNotNull('last_counted_at')
            ->where('last_counted_at', '>=', $plan->current_cycle_start ?? now()->subWeeks($plan->cycle_length_weeks))
            ->selectRaw("abc_class, COUNT(*) as counted")
            ->groupBy('abc_class')
            ->pluck('counted', 'abc_class')
            ->toArray();

        $totalByClass = \App\Models\ProductAbcClassification::where('warehouse_code', $warehouseCode)
            ->selectRaw("abc_class, COUNT(*) as total")
            ->groupBy('abc_class')
            ->pluck('total', 'abc_class')
            ->toArray();

        return response()->json([
            'plan' => $plan,
            'cycle_week' => $plan->current_week_number,
            'cycle_length' => $plan->cycle_length_weeks,
            'sessions_completed' => $sessions->count(),
            'progress' => [
                'A' => [
                    'counted' => $countedByClass['A'] ?? 0,
                    'total' => $totalByClass['A'] ?? 0,
                    'target' => ($totalByClass['A'] ?? 0) * $plan->a_frequency,
                ],
                'B' => [
                    'counted' => $countedByClass['B'] ?? 0,
                    'total' => $totalByClass['B'] ?? 0,
                    'target' => ($totalByClass['B'] ?? 0) * $plan->b_frequency,
                ],
                'C' => [
                    'counted' => $countedByClass['C'] ?? 0,
                    'total' => $totalByClass['C'] ?? 0,
                    'target' => ($totalByClass['C'] ?? 0) * $plan->c_frequency,
                ],
            ],
            'next_due_date' => $plan->next_due_date,
        ]);
    }

    /**
     * Return the target items for a cycle session with per-item counted status
     * and a progress summary. Powers the guided cycle-count experience in the app.
     *
     * "Counted" is computed as DISTINCT item_codes intersected with target_items
     * (addLine always inserts a new row, so we group + sum, never count rows).
     */
    public function targets(Request $request, $id)
    {
        $user = $request->user();
        $counting = $this->getAuthorizedCounting($user, $id);

        $targetItems = collect($counting->target_items ?? []);
        $targetCodes = $targetItems->pluck('item_code')->filter()->values();

        // Names + images
        $products = Product::whereIn('item_code', $targetCodes)->get()->keyBy('item_code');

        // Counted aggregation: distinct item_code, summed qty, scan count
        $countedRows = $counting->lines()
            ->select('item_code', DB::raw('SUM(counted_quantity) as qty'), DB::raw('COUNT(*) as scans'))
            ->groupBy('item_code')
            ->get()
            ->keyBy('item_code');

        $items = $targetItems->map(function ($t) use ($products, $countedRows) {
            $code = $t['item_code'] ?? null;
            $product = $code ? $products->get($code) : null;
            $counted = $code ? $countedRows->get($code) : null;
            $folder = $code ? substr($code, 0, 4) : '';

            return [
                'item_code' => $code,
                'abc_class' => $t['abc_class'] ?? null,
                'item_name' => $product?->item_name,
                'item_name_ar' => $product ? ($product->foreign_name ?: ($product->zb_name_ar ?: $product->item_name)) : null,
                'item_name_en' => $product ? ($product->item_name ?: ($product->zb_name_en ?: $product->item_name)) : null,
                'piece_barcode' => $product?->piece_barcode,
                'image_url' => $code ? "https://ppte.sa/imghd/{$folder}/{$code}.png" : null,
                'counted' => $counted !== null,
                'counted_quantity' => $counted ? (float) $counted->qty : 0,
                'scan_count' => $counted ? (int) $counted->scans : 0,
            ];
        })->values();

        // Progress summary
        $total = $targetCodes->count();
        $countedTargetCodes = $countedRows->keys()->intersect($targetCodes);
        $countedCount = $countedTargetCodes->count();
        $offList = $countedRows->keys()->diff($targetCodes)->count();

        $byClass = [];
        foreach (['A', 'B', 'C'] as $cls) {
            $clsCodes = $targetItems->where('abc_class', $cls)->pluck('item_code');
            $byClass[$cls] = [
                'total' => $clsCodes->count(),
                'counted' => $clsCodes->intersect($countedTargetCodes)->count(),
            ];
        }

        $plan = $counting->cyclePlan;

        return response()->json([
            'session' => [
                'id' => $counting->id,
                'warehouse_code' => $counting->warehouse_code,
                'warehouse_name' => $counting->warehouse_name,
                'counting_type' => $counting->counting_type ?? 'full',
                'status' => $counting->status,
                'scheduled_date' => $counting->scheduled_date,
                'priority' => $counting->priority ?? 'medium',
                'plan_name' => $plan?->plan_name,
            ],
            'progress' => [
                'total_targets' => $total,
                'counted_targets' => $countedCount,
                'percent' => $total > 0 ? round($countedCount / $total * 100, 1) : 0,
                'by_class' => $byClass,
                'off_list_scans' => $offList,
            ],
            'items' => $items,
        ]);
    }

    /**
     * Mark who is executing a cycle session (first count action), since
     * cron-generated cycle sessions have counted_by = null.
     */
    protected function claimIfCycle(InventoryCounting $counting, $user): void
    {
        if (($counting->counting_type ?? 'full') === 'cycle' && $counting->started_by === null) {
            $counting->update(['started_by' => $user->id, 'started_at' => now()]);
        }
    }
}
