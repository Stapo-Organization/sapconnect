import 'package:flutter/foundation.dart';

import '../../data/models/retail_models.dart';
import '../../data/retail_dashboard_repository.dart';

/// State for the Retail Dashboard overview: period + sort filters, tri-state
/// loading, safe-notify guard. Mirrors ShowroomPulseController's pattern.
class RetailDashboardController extends ChangeNotifier {
  RetailDashboardController({RetailDashboardRepository? repository})
      : _repo = repository ?? RetailDashboardRepository();

  final RetailDashboardRepository _repo;

  bool _loading = true;
  bool _hasError = false;
  RetailOverview? _data;
  bool _disposed = false;

  String _period = 'month'; // today | week | month | custom
  String _sort = 'revenue'; // revenue | score | bleeding
  String? _from;
  String? _to;

  bool get loading => _loading;
  bool get hasError => _hasError;
  RetailOverview? get data => _data;
  String get period => _period;
  String get sort => _sort;

  /// Branches sorted client-side by [_sort], descending — mirrors the backend's
  /// sort. The full branch set is already loaded, so re-sorting is instant with
  /// no network round-trip (and therefore needs no loading state).
  List<BranchCard> get sortedBranches {
    final list = [...?_data?.branches];
    double key(BranchCard c) => switch (_sort) {
          'score' => c.score ?? -1,
          'bleeding' => c.bleedingMonthlySar,
          'profit' => c.profit.profit,
          _ => c.revenue.net,
        };
    list.sort((a, b) => key(b).compareTo(key(a)));
    return list;
  }
  String? get from => _from;
  String? get to => _to;

  Future<void> load() => _fetch(showSkeleton: true);
  Future<void> refresh() => _fetch(showSkeleton: _data == null);

  Future<void> setPeriod(String period, {String? from, String? to}) {
    _period = period;
    _from = from;
    _to = to;
    return _fetch(showSkeleton: true);
  }

  /// Re-sort locally and instantly — no fetch, so no waiting and no spinner.
  void setSort(String sort) {
    if (_sort == sort) return;
    _sort = sort;
    _safeNotify();
  }

  Future<void> _fetch({required bool showSkeleton}) async {
    if (showSkeleton) {
      _loading = true;
      _hasError = false;
      _safeNotify();
    }
    final result = await _repo.getOverview(period: _period, from: _from, to: _to, sort: _sort);
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
