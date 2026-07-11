import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

import '../../data/models/product_models.dart';
import '../../data/product_search_repository.dart';

/// Debounced product-search state. The page feeds it keystrokes via [onQuery];
/// it fires the API ~350ms after typing stops and notifies with results.
class ProductSearchController extends ChangeNotifier {
  ProductSearchController({ProductSearchRepository? repository})
      : _repo = repository ?? ProductSearchRepository();

  final ProductSearchRepository _repo;

  static const _debounce = Duration(milliseconds: 350);
  static const _minChars = 2;

  Timer? _timer;
  int _seq = 0; // guards against out-of-order responses

  String _query = '';
  List<ProductHit> _results = const [];
  bool _loading = false;
  String? _error;

  String get query => _query;
  List<ProductHit> get results => _results;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasError => _error != null;

  /// `true` once the user has typed enough to expect results (drives the
  /// "type to search" hint vs the "no results" empty state).
  bool get isSearching => _query.trim().length >= _minChars;

  void onQuery(String value) {
    _query = value;
    _timer?.cancel();
    final trimmed = value.trim();

    if (trimmed.length < _minChars) {
      _seq++; // cancel any in-flight result
      _results = const [];
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();
    _timer = Timer(_debounce, () => _run(trimmed));
  }

  Future<void> _run(String q) async {
    final mySeq = ++_seq;
    final res = await _repo.search(q);
    if (mySeq != _seq) return; // a newer query superseded this one

    _loading = false;
    if (res.success) {
      _results = res.items;
      _error = null;
    } else {
      _results = const [];
      _error = res.error ?? AppLocalizations.translate('ps_search_failed');
    }
    notifyListeners();
  }

  /// One-shot lookup for a scanned code: returns the product whose barcode or
  /// SAP code matches exactly, or null (so a scan jumps straight to its product
  /// only when there's an unambiguous hit).
  Future<ProductHit?> findExact(String code) async {
    final res = await _repo.search(code);
    if (!res.success) return null;
    for (final h in res.items) {
      if (h.barcode == code || h.itemCode == code) return h;
    }
    return null;
  }

  void clear() {
    _timer?.cancel();
    _seq++;
    _query = '';
    _results = const [];
    _loading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
