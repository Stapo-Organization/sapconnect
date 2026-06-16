import 'package:flutter/foundation.dart';

import '../../data/container_tracking_repository.dart';
import '../../data/models/container_models.dart';

/// State for the Container Tracking board: state-filter + sort + free-text
/// search, tri-state loading, safe-notify guard. Mirrors RetailDashboardController.
class ContainerTrackingController extends ChangeNotifier {
  ContainerTrackingController({ContainerTrackingRepository? repository})
      : _repo = repository ?? ContainerTrackingRepository();

  final ContainerTrackingRepository _repo;

  bool _loading = true;
  bool _hasError = false;
  ContainerOverview? _data;
  bool _disposed = false;

  String _state = 'all'; // all | overdue | arriving | in_transit | pending | delivered
  String _sort = 'urgency'; // urgency | eta | added
  String _search = '';

  bool get loading => _loading;
  bool get hasError => _hasError;
  ContainerOverview? get data => _data;
  String get state => _state;
  String get sort => _sort;
  String get search => _search;

  Future<void> load() => _fetch(showSkeleton: true);
  Future<void> refresh() => _fetch(showSkeleton: _data == null);

  Future<void> setState(String state) {
    if (_state == state) return Future.value();
    _state = state;
    return _fetch(showSkeleton: false);
  }

  Future<void> setSort(String sort) {
    if (_sort == sort) return Future.value();
    _sort = sort;
    return _fetch(showSkeleton: false);
  }

  Future<void> setSearch(String search) {
    _search = search;
    return _fetch(showSkeleton: false);
  }

  Future<void> _fetch({required bool showSkeleton}) async {
    if (showSkeleton) {
      _loading = true;
      _hasError = false;
      _safeNotify();
    }
    final result = await _repo.getOverview(state: _state, sort: _sort, search: _search);
    if (_disposed) return;
    if (result.success && result.data != null) {
      _data = result.data;
      _hasError = false;
    } else {
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
