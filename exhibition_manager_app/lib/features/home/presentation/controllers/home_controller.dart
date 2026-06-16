import 'package:flutter/foundation.dart';
import 'package:exhibition_manager_app/features/home/data/home_repository.dart';
import 'package:exhibition_manager_app/features/home/data/models/home_overview.dart';

/// Single source of truth for the home screen — replaces the page's eight
/// scattered state fields. Fetches `/home/overview` once and exposes a clean
/// loading / error / data tri-state. Stdlib [ChangeNotifier]; no extra deps.
class HomeController extends ChangeNotifier {
  HomeController({HomeRepository? repository})
      : _repo = repository ?? HomeRepository();

  final HomeRepository _repo;

  bool _loading = true;
  bool _hasError = false;
  HomeOverview? _overview;
  bool _disposed = false;

  bool get loading => _loading;
  bool get hasError => _hasError;
  HomeOverview? get overview => _overview;

  /// Initial load — shows the skeleton.
  Future<void> load() => _fetch(showSkeleton: true);

  /// Pull-to-refresh / return-from-detail — refresh without blanking the UI.
  Future<void> refresh() => _fetch(showSkeleton: _overview == null);

  Future<void> _fetch({required bool showSkeleton}) async {
    if (showSkeleton) {
      _loading = true;
      _hasError = false;
      _safeNotify();
    }

    final result = await _repo.getOverview();
    if (_disposed) return;

    if (result.success && result.data != null) {
      _overview = result.data;
      _hasError = false;
    } else {
      _hasError = _overview == null; // keep stale data on a failed refresh
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
