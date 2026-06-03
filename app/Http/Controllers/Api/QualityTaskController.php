<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\QualityTaskInstanceApiResource;
use App\Http\Resources\QualityTaskPhotoApiResource;
use App\Models\QualityTaskInstance;
use App\Models\QualityTaskPhoto;
use App\Services\Gamification\QualityScoringService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class QualityTaskController extends Controller
{
    /**
     * List quality-task instances for the user's warehouses.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $codes = $this->getUserWarehouseCodes($user);

        $query = QualityTaskInstance::query()->with('photos')->latest('scheduled_date');
        if (!empty($codes)) {
            $query->whereIn('warehouse_code', $codes);
        }
        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }
        if ($request->filled('date')) {
            $query->whereDate('scheduled_date', $request->date);
        }

        return QualityTaskInstanceApiResource::collection(
            $query->paginate($request->get('per_page', 20))
        );
    }

    /**
     * Home summary — due + overdue counts and the next due tasks.
     */
    public function summary(Request $request)
    {
        $user = $request->user();
        $codes = $this->getUserWarehouseCodes($user);

        $base = QualityTaskInstance::query()->pending()
            ->whereDate('scheduled_date', '<=', now()->toDateString());
        if (!empty($codes)) {
            $base->whereIn('warehouse_code', $codes);
        }

        $due = (clone $base)
            ->with('photos')
            ->orderBy('scheduled_date', 'asc')
            ->limit(10)
            ->get();

        $overdue = (clone $base)->whereDate('scheduled_date', '<', now()->toDateString())->count();

        return response()->json([
            'due_count' => (clone $base)->count(),
            'overdue_count' => $overdue,
            'due' => QualityTaskInstanceApiResource::collection($due),
        ]);
    }

    public function show(Request $request, $id)
    {
        $instance = $this->getAuthorizedInstance($request->user(), $id);
        return new QualityTaskInstanceApiResource($instance);
    }

    /**
     * Upload one or more photos (multipart). Optionally tied to a checklist item.
     */
    public function uploadPhotos(Request $request, $id)
    {
        $user = $request->user();
        $instance = $this->getAuthorizedInstance($user, $id);

        if ($instance->isSubmitted()) {
            return response()->json(['message' => 'لا يمكن تعديل مهمة مكتملة'], 422);
        }

        $request->validate([
            'photos' => 'required|array|min:1',
            'photos.*' => 'image|mimes:jpeg,jpg,png,webp|max:8192',
            'checklist_item_key' => 'nullable|string',
        ]);

        $itemKey = $request->input('checklist_item_key');
        if ($itemKey) {
            $keys = collect($instance->requirements_snapshot['checklist_items'] ?? [])->pluck('key')->all();
            if (!in_array($itemKey, $keys, true)) {
                return response()->json(['message' => 'عنصر قائمة غير صالح'], 422);
            }
        }

        $created = [];
        foreach ($request->file('photos') as $file) {
            $path = $file->store("quality/{$instance->id}", 'public');
            $created[] = QualityTaskPhoto::create([
                'quality_task_instance_id' => $instance->id,
                'checklist_item_key' => $itemKey,
                'disk' => 'public',
                'path' => $path,
                'original_name' => $file->getClientOriginalName(),
                'size' => $file->getSize(),
                'uploaded_by' => $user->id,
            ]);
        }

        return response()->json([
            'message' => 'تم رفع الصور',
            'photos' => QualityTaskPhotoApiResource::collection(collect($created)),
        ], 201);
    }

    public function deletePhoto(Request $request, $id, $photoId)
    {
        $user = $request->user();
        $instance = $this->getAuthorizedInstance($user, $id);

        if ($instance->isSubmitted()) {
            return response()->json(['message' => 'لا يمكن تعديل مهمة مكتملة'], 422);
        }

        $photo = $instance->photos()->findOrFail($photoId);
        Storage::disk($photo->disk ?? 'public')->delete($photo->path);
        $photo->delete();

        return response()->json(['message' => 'تم حذف الصورة']);
    }

    /**
     * Submit the task. Server-side proof validation is authoritative.
     */
    public function submit(Request $request, $id)
    {
        $user = $request->user();
        $instance = $this->getAuthorizedInstance($user, $id);

        if ($instance->isSubmitted()) {
            return response()->json([
                'message' => 'تم إكمال هذه المهمة مسبقاً',
                'data' => new QualityTaskInstanceApiResource($instance),
            ], 422);
        }

        $request->validate([
            'comment' => 'nullable|string|max:2000',
        ]);

        $snap = $instance->requirements_snapshot;
        $proofType = $snap['proof_type'] ?? 'photo';
        $instance->load('photos');

        // ─── Proof completeness gate ─────────────────────────────
        if ($proofType === 'photo') {
            $generalCount = $instance->photos->whereNull('checklist_item_key')->count();
            $min = (int) ($snap['min_photos'] ?? 1);
            if ($generalCount < $min) {
                return response()->json(['message' => "يلزم رفع {$min} صورة على الأقل"], 422);
            }
            if (($snap['require_comment'] ?? false) && trim((string) $request->comment) === '') {
                return response()->json(['message' => 'التعليق مطلوب'], 422);
            }
        }

        $checklistResults = [];
        if ($proofType === 'checklist') {
            foreach ($snap['checklist_items'] ?? [] as $item) {
                $key = $item['key'];
                $photoIds = $instance->photos->where('checklist_item_key', $key)->pluck('id')->values()->all();
                if (($item['require_photo'] ?? false) && empty($photoIds)) {
                    $label = $item['label'] ?? $key;
                    return response()->json(['message' => "الصورة مطلوبة لـ: {$label}"], 422);
                }
                $checklistResults[$key] = ['checked' => true, 'photo_ids' => $photoIds];
            }
        }

        $instance->update([
            'comment' => $request->comment,
            'checklist_results' => $checklistResults ?: null,
        ]);
        $instance->markAsSubmitted($user);

        // Gamification (never blocks completion).
        $gamification = null;
        try {
            $gamification = (new QualityScoringService())->award($instance->fresh(), $user);
        } catch (\Throwable $e) {
            Log::warning('Quality scoring failed: ' . $e->getMessage());
        }

        return response()->json([
            'message' => 'تم إكمال مهمة الجودة بنجاح',
            'data' => new QualityTaskInstanceApiResource($instance->fresh('photos')),
            'gamification' => $gamification,
        ]);
    }

    // ─── Authorization helpers (mirror InventoryCountingController) ──
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

    protected function getAuthorizedInstance($user, $id): QualityTaskInstance
    {
        $codes = $this->getUserWarehouseCodes($user);
        $query = QualityTaskInstance::query()->with('photos');
        if (!empty($codes)) {
            $query->whereIn('warehouse_code', $codes);
        }
        return $query->findOrFail($id);
    }
}
