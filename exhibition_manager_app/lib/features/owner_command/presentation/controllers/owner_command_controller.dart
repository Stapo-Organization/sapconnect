import 'package:flutter/foundation.dart';

import '../../data/owner_command_repository.dart';
import '../../data/models/owner_command_models.dart';

/// حالة «مركز القيادة»: تحميل ثلاثي الحالة (loading/error/data) مع حارس
/// safe-notify. يتبع نمط RetailDashboardController. يعرض خطأً كاملاً فقط حين
/// تفشل كل المصادر؛ غير ذلك يبقى snapshot قابلاً للعرض جزئياً.
class OwnerCommandController extends ChangeNotifier {
  OwnerCommandController({OwnerCommandRepository? repository})
      : _repo = repository ?? OwnerCommandRepository();

  final OwnerCommandRepository _repo;

  bool _loading = true;
  bool _hasError = false;
  OwnerCommandSnapshot? _data;
  bool _disposed = false;

  bool get loading => _loading;
  bool get hasError => _hasError;
  OwnerCommandSnapshot? get data => _data;

  Future<void> load() => _fetch(showSkeleton: true);
  Future<void> refresh() => _fetch(showSkeleton: _data == null);

  Future<void> _fetch({required bool showSkeleton}) async {
    if (showSkeleton) {
      _loading = true;
      _hasError = false;
      _safeNotify();
    }
    try {
      final snap = await _repo.loadSnapshot();
      if (_disposed) return;
      _data = snap;
      _hasError = snap.allFailed;
    } catch (_) {
      if (_disposed) return;
      _hasError = _data == null;
    }
    _loading = false;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
