<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\QualityTask;
use App\Models\QualityTaskInstance;
use App\Services\Branch\BranchInsightsService;
use App\Services\Quality\QualityTaskGenerationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * QualityTaskAdmin (إدارة مهام الجودة) — owner-side authoring + monitoring of
 * quality tasks from the app. Kept separate from QualityTaskController (which
 * owns the branch-manager submission flow). Gated by feature:quality_admin.*.
 *
 * Recurring template = recurrence daily|weekly.
 * Immediate one-off   = recurrence 'once' + start_date today (+ POST .../generate
 *                       to materialise the instance straight away).
 *
 * Mirrors the normalisation done in Filament's QualityTaskResource: checklist
 * items and slots are auto-keyed, and one QualityTask row is created per
 * selected warehouse.
 */
class QualityTaskAdminController extends Controller
{
    public function __construct(private QualityTaskGenerationService $generator)
    {
    }

    /** GET /quality-tasks/manage — templates + instance stats. */
    public function index(Request $request): JsonResponse
    {
        $query = QualityTask::query()->withCount([
            'instances as pending_count' => fn ($q) => $q->where('status', QualityTaskInstance::STATUS_PENDING),
            'instances as submitted_count' => fn ($q) => $q->where('status', QualityTaskInstance::STATUS_SUBMITTED),
            'instances as overdue_count' => fn ($q) => $q
                ->where('status', QualityTaskInstance::STATUS_PENDING)
                ->whereDate('scheduled_date', '<', now()->toDateString()),
        ]);

        if ($wh = $request->query('warehouse')) {
            $query->where('warehouse_code', $wh);
        }
        if ($request->filled('active')) {
            $query->where('is_active', $request->boolean('active'));
        }

        $tasks = $query->orderByDesc('is_active')->orderBy('title')->get();

        return response()->json([
            'data' => $tasks->map(fn ($t) => $this->templateSummary($t))->all(),
        ]);
    }

    /** GET /quality-tasks/manage/{id} — one template + its recent instances. */
    public function show(int $id): JsonResponse
    {
        $task = QualityTask::findOrFail($id);
        $instances = $task->instances()
            ->orderByDesc('scheduled_date')
            ->limit(60)
            ->get();

        return response()->json([
            'data' => array_merge($this->templateSummary($task), [
                'description' => $task->description,
                'proof_type' => $task->proof_type,
                'min_photos' => (int) $task->min_photos,
                'require_comment' => (bool) $task->require_comment,
                'checklist_items' => $task->checklist_items ?? [],
                'days_of_week' => $task->days_of_week ?? [],
                'slots' => $task->slots ?? [],
                'start_date' => optional($task->start_date)->toDateString(),
                'end_date' => optional($task->end_date)->toDateString(),
                'instances' => $instances->map(fn ($i) => $this->instanceRow($i))->all(),
            ]),
        ]);
    }

    /** POST /quality-tasks/manage — create a template per selected warehouse. */
    public function store(Request $request): JsonResponse
    {
        $data = $this->validatePayload($request);

        $created = [];
        foreach ($data['warehouse_codes'] as $code) {
            $task = QualityTask::create([
                'warehouse_code' => $code,
                'title' => $data['title'],
                'description' => $data['description'] ?? null,
                'proof_type' => $data['proof_type'],
                'min_photos' => $data['proof_type'] === QualityTask::PROOF_PHOTO ? ($data['min_photos'] ?? 1) : 0,
                'require_comment' => $data['require_comment'] ?? false,
                'checklist_items' => $data['proof_type'] === QualityTask::PROOF_CHECKLIST ? $this->normalizeChecklist($data['checklist_items'] ?? []) : null,
                'recurrence' => $data['recurrence'],
                'days_of_week' => $data['recurrence'] === QualityTask::REC_WEEKLY ? array_map('intval', $data['days_of_week'] ?? []) : null,
                'slots' => $this->normalizeSlots($data['slots'] ?? []),
                'priority' => $data['priority'],
                'is_active' => $data['is_active'] ?? true,
                'start_date' => $data['start_date'] ?? now()->toDateString(),
                'end_date' => $data['end_date'] ?? null,
                'created_by' => $request->user()->id,
            ]);

            // For an immediate one-off, materialise today's instance right away so
            // the branch manager sees it without waiting for the daily generator.
            if ($task->recurrence === QualityTask::REC_ONCE) {
                $this->generator->generateForTask($task->fresh(), now());
            }

            $created[] = $this->templateSummary($task->fresh());
        }

        return response()->json([
            'success' => true,
            'created' => count($created),
            'data' => $created,
        ], 201);
    }

    /** PUT /quality-tasks/manage/{id} — edit a template / toggle active. */
    public function update(Request $request, int $id): JsonResponse
    {
        $task = QualityTask::findOrFail($id);

        // Lightweight toggle path (just is_active) — used by the list switch.
        if ($request->has('is_active') && count($request->keys()) === 1) {
            $task->update(['is_active' => $request->boolean('is_active')]);
            return response()->json(['success' => true, 'data' => $this->templateSummary($task->fresh())]);
        }

        $data = $this->validatePayload($request, requireWarehouses: false);

        $task->update([
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'proof_type' => $data['proof_type'],
            'min_photos' => $data['proof_type'] === QualityTask::PROOF_PHOTO ? ($data['min_photos'] ?? 1) : 0,
            'require_comment' => $data['require_comment'] ?? false,
            'checklist_items' => $data['proof_type'] === QualityTask::PROOF_CHECKLIST ? $this->normalizeChecklist($data['checklist_items'] ?? []) : null,
            'recurrence' => $data['recurrence'],
            'days_of_week' => $data['recurrence'] === QualityTask::REC_WEEKLY ? array_map('intval', $data['days_of_week'] ?? []) : null,
            'slots' => $this->normalizeSlots($data['slots'] ?? []),
            'priority' => $data['priority'],
            'is_active' => $data['is_active'] ?? $task->is_active,
            'start_date' => $data['start_date'] ?? $task->start_date,
            'end_date' => $data['end_date'] ?? null,
        ]);

        return response()->json(['success' => true, 'data' => $this->templateSummary($task->fresh())]);
    }

    /** POST /quality-tasks/manage/{id}/generate — materialise today's instance now. */
    public function generate(int $id): JsonResponse
    {
        $task = QualityTask::findOrFail($id);
        $count = $this->generator->generateForTask($task, now());

        return response()->json([
            'success' => true,
            'generated' => $count,
            'message' => $count > 0 ? 'تم إنشاء النسخة' : 'لا توجد نسخة مستحقة اليوم',
        ]);
    }

    /** GET /quality-tasks/manage/instances — cross-branch follow-up. */
    public function instances(Request $request): JsonResponse
    {
        $query = QualityTaskInstance::query()->with('task:id,title');

        if ($wh = $request->query('warehouse')) {
            $query->where('warehouse_code', $wh);
        }
        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }
        if ($date = $request->query('date')) {
            $query->whereDate('scheduled_date', $date);
        }

        $instances = $query->orderByDesc('scheduled_date')->limit(200)->get();

        return response()->json([
            'data' => $instances->map(fn ($i) => $this->instanceRow($i))->all(),
        ]);
    }

    // ─── Helpers ─────────────────────────────────────────────────

    private function validatePayload(Request $request, bool $requireWarehouses = true): array
    {
        $rules = [
            'title' => 'required|string|max:255',
            'description' => 'nullable|string|max:2000',
            'proof_type' => ['required', Rule::in([QualityTask::PROOF_ACKNOWLEDGE, QualityTask::PROOF_PHOTO, QualityTask::PROOF_CHECKLIST])],
            'min_photos' => 'nullable|integer|min:1|max:30',
            'require_comment' => 'nullable|boolean',
            'checklist_items' => 'nullable|array',
            'checklist_items.*.label' => 'required_with:checklist_items|string|max:255',
            'checklist_items.*.require_photo' => 'nullable|boolean',
            'recurrence' => ['required', Rule::in([QualityTask::REC_ONCE, QualityTask::REC_DAILY, QualityTask::REC_WEEKLY])],
            'days_of_week' => 'nullable|array',
            'days_of_week.*' => 'integer|min:0|max:6',
            'slots' => 'nullable|array',
            'slots.*.label_ar' => 'required_with:slots|string|max:120',
            'slots.*.label_en' => 'nullable|string|max:120',
            'priority' => ['required', Rule::in(['high', 'medium', 'low'])],
            'is_active' => 'nullable|boolean',
            'start_date' => 'nullable|date',
            'end_date' => 'nullable|date|after_or_equal:start_date',
        ];

        if ($requireWarehouses) {
            $rules['warehouse_codes'] = 'required|array|min:1';
            $rules['warehouse_codes.*'] = 'string|exists:warehouses,warehouse_code';
        }

        return $request->validate($rules);
    }

    /** Auto-key checklist items (item_1, item_2, …) like the Filament resource. */
    private function normalizeChecklist(array $items): array
    {
        $out = [];
        $i = 0;
        foreach ($items as $item) {
            $i++;
            $out[] = [
                'key' => $item['key'] ?? "item_{$i}",
                'label' => $item['label'] ?? '',
                'require_photo' => (bool) ($item['require_photo'] ?? true),
            ];
        }
        return $out;
    }

    /** Auto-key slots (slot_1, slot_2, …); empty array → no slots (single default). */
    private function normalizeSlots(array $slots): ?array
    {
        if (empty($slots)) {
            return null;
        }
        $out = [];
        $i = 0;
        foreach ($slots as $slot) {
            $i++;
            $out[] = [
                'key' => $slot['key'] ?? "slot_{$i}",
                'label_ar' => $slot['label_ar'] ?? '',
                'label_en' => $slot['label_en'] ?? '',
            ];
        }
        return $out;
    }

    private function templateSummary(QualityTask $t): array
    {
        return [
            'id' => $t->id,
            'title' => $t->title,
            'warehouse_code' => $t->warehouse_code,
            'warehouse_name' => BranchInsightsService::arName($t->warehouse_code, optional($t->warehouse)->warehouse_name),
            'proof_type' => $t->proof_type,
            'recurrence' => $t->recurrence,
            'priority' => $t->priority,
            'is_active' => (bool) $t->is_active,
            'pending_count' => (int) ($t->pending_count ?? 0),
            'submitted_count' => (int) ($t->submitted_count ?? 0),
            'overdue_count' => (int) ($t->overdue_count ?? 0),
            'last_generated_at' => optional($t->last_generated_at)->toIso8601String(),
        ];
    }

    private function instanceRow(QualityTaskInstance $i): array
    {
        $isOverdue = $i->status === QualityTaskInstance::STATUS_PENDING
            && $i->scheduled_date
            && $i->scheduled_date->lt(now()->startOfDay());

        return [
            'id' => $i->id,
            'quality_task_id' => $i->quality_task_id,
            'title' => $i->title,
            'warehouse_code' => $i->warehouse_code,
            'warehouse_name' => BranchInsightsService::arName($i->warehouse_code, $i->warehouse_name),
            'status' => $i->status,
            'priority' => $i->priority,
            'scheduled_date' => optional($i->scheduled_date)->toDateString(),
            'is_overdue' => $isOverdue,
            'submitted_at' => optional($i->submitted_at)->toIso8601String(),
        ];
    }
}
