// Models for the Quality Control feature (GET /quality-tasks/*).

class QualityChecklistItem {
  final String key;
  final String label;
  final bool requirePhoto;

  QualityChecklistItem({required this.key, required this.label, this.requirePhoto = false});

  factory QualityChecklistItem.fromJson(Map<String, dynamic> json) => QualityChecklistItem(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        requirePhoto: json['require_photo'] == true,
      );
}

class QualityProofRequirements {
  final String proofType; // acknowledge | photo | checklist
  final int minPhotos;
  final bool requireComment;
  final List<QualityChecklistItem> checklistItems;

  QualityProofRequirements({
    this.proofType = 'photo',
    this.minPhotos = 1,
    this.requireComment = false,
    this.checklistItems = const [],
  });

  factory QualityProofRequirements.fromJson(Map<String, dynamic> json) => QualityProofRequirements(
        proofType: json['proof_type']?.toString() ?? 'photo',
        minPhotos: (json['min_photos'] ?? 1) is int ? (json['min_photos'] ?? 1) : int.tryParse('${json['min_photos']}') ?? 1,
        requireComment: json['require_comment'] == true,
        checklistItems: ((json['checklist_items'] as List?) ?? [])
            .map((e) => QualityChecklistItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  bool get isAcknowledge => proofType == 'acknowledge';
  bool get isPhoto => proofType == 'photo';
  bool get isChecklist => proofType == 'checklist';
}

class QualityTaskPhoto {
  final int id;
  final String url;
  final String? checklistItemKey;

  QualityTaskPhoto({required this.id, required this.url, this.checklistItemKey});

  factory QualityTaskPhoto.fromJson(Map<String, dynamic> json) => QualityTaskPhoto(
        id: json['id'] ?? 0,
        url: json['url']?.toString() ?? '',
        checklistItemKey: json['checklist_item_key']?.toString(),
      );
}

class QualityTaskInstance {
  final int id;
  final int qualityTaskId;
  final String warehouseCode;
  final String? warehouseName;
  final String title;
  final String? description;
  final String status; // pending | submitted | cancelled
  final String? scheduledDate;
  final String? slotKey;
  final String? slotLabelAr;
  final String? slotLabelEn;
  final String priority;
  final bool isOverdue;
  final QualityProofRequirements requirements;
  final String? comment;
  final Map<String, dynamic> checklistResults;
  final List<QualityTaskPhoto> photos;
  final int photosCount;

  QualityTaskInstance({
    required this.id,
    required this.qualityTaskId,
    required this.warehouseCode,
    this.warehouseName,
    required this.title,
    this.description,
    this.status = 'pending',
    this.scheduledDate,
    this.slotKey,
    this.slotLabelAr,
    this.slotLabelEn,
    this.priority = 'medium',
    this.isOverdue = false,
    required this.requirements,
    this.comment,
    this.checklistResults = const {},
    this.photos = const [],
    this.photosCount = 0,
  });

  factory QualityTaskInstance.fromJson(Map<String, dynamic> json) => QualityTaskInstance(
        id: json['id'] ?? 0,
        qualityTaskId: json['quality_task_id'] ?? 0,
        warehouseCode: json['warehouse_code']?.toString() ?? '',
        warehouseName: json['warehouse_name']?.toString(),
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString(),
        status: json['status']?.toString() ?? 'pending',
        scheduledDate: json['scheduled_date']?.toString(),
        slotKey: json['slot_key']?.toString(),
        slotLabelAr: json['slot_label_ar']?.toString(),
        slotLabelEn: json['slot_label_en']?.toString(),
        priority: json['priority']?.toString() ?? 'medium',
        isOverdue: json['is_overdue'] == true,
        requirements: QualityProofRequirements.fromJson(
            Map<String, dynamic>.from((json['requirements'] as Map?) ?? {})),
        comment: json['comment']?.toString(),
        // checklist_results is an object {key:{…}} when present, but PHP
        // serializes an empty value as `[]` — handle both shapes.
        checklistResults: json['checklist_results'] is Map
            ? Map<String, dynamic>.from(json['checklist_results'] as Map)
            : <String, dynamic>{},
        photos: ((json['photos'] as List?) ?? [])
            .map((e) => QualityTaskPhoto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        photosCount: json['photos_count'] ?? ((json['photos'] as List?)?.length ?? 0),
      );

  bool get isPending => status == 'pending';
  bool get isSubmitted => status == 'submitted';

  String slotLabel(bool isArabic) => isArabic ? (slotLabelAr ?? '') : (slotLabelEn ?? slotLabelAr ?? '');

  /// Photos not tied to a checklist item (general / min-N photos).
  List<QualityTaskPhoto> get generalPhotos =>
      photos.where((p) => p.checklistItemKey == null).toList();

  List<QualityTaskPhoto> photosForItem(String key) =>
      photos.where((p) => p.checklistItemKey == key).toList();
}
