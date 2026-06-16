import 'package:flutter/foundation.dart';

import '../../data/models/pulse_overview.dart';
import '../../data/showroom_pulse_repository.dart';

/// Holds the نبض المعرض screen state (load / refresh / switch branch) and
/// proxies the two write actions. Mirrors the app's HomeController pattern:
/// a single ChangeNotifier with tri-state (loading / error / data) and a
/// safe-notify guard against use-after-dispose.
class ShowroomPulseController extends ChangeNotifier {
  ShowroomPulseController({ShowroomPulseRepository? repository})
      : _repo = repository ?? ShowroomPulseRepository();

  final ShowroomPulseRepository _repo;

  bool _loading = true;
  bool _hasError = false;
  PulseOverview? _data;
  String? _warehouse;
  bool _disposed = false;

  bool get loading => _loading;
  bool get hasError => _hasError;
  PulseOverview? get data => _data;
  String? get warehouse => _warehouse ?? _data?.warehouse.code;

  Future<void> load() => _fetch(showSkeleton: true);
  Future<void> refresh() => _fetch(showSkeleton: _data == null);

  Future<void> switchWarehouse(String code) {
    _warehouse = code;
    return _fetch(showSkeleton: true);
  }

  Future<void> _fetch({required bool showSkeleton}) async {
    if (showSkeleton) {
      _loading = true;
      _hasError = false;
      _safeNotify();
    }
    final result = await _repo.getPulse(warehouse: _warehouse);
    if (_disposed) return;
    if (result.success && result.data != null) {
      _data = result.data;
      _warehouse = result.data!.warehouse.code;
      _hasError = false;
    } else {
      _hasError = _data == null; // keep stale data on a refresh failure
    }
    _loading = false;
    _safeNotify();
  }

  Future<({bool success, String? message, String? error})> requestTransfer(String itemCode) {
    return _repo.requestTransfer(itemCode: itemCode, warehouseCode: warehouse ?? '');
  }

  Future<({bool success, String? message, String? error})> suggestDiscount(String itemCode) {
    return _repo.suggestDiscount(itemCode: itemCode, warehouseCode: warehouse ?? '');
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
