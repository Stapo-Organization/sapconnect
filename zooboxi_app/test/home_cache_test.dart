import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';

/// Crossing the two storefronts used to land on an empty cache every single
/// time: one slot held one shelf, so the other always started from a shimmer.
/// A slot per shelf is what makes the tab paint instead of load — and the slot
/// is named after the shelf the payload DESCRIBES, because after closing time
/// an إكسبريس request comes back carrying the full store.
Future<LocalStore> _store([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return LocalStore(await SharedPreferences.getInstance());
}

Map<String, dynamic> _payload(String shelf) => {
      'scope': {'shelf': shelf, 'note': 'كل ما هنا يصلك اليوم'},
      'slots': const [],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the storefront each shelf remembers', () {
    test('both shelves keep their own snapshot', () async {
      final store = await _store();
      await store.setHomeCache(_payload('express'), shelf: 'express');
      await store.setHomeCache(_payload('all'), shelf: 'all');

      expect(store.homeCacheFor('express')!['scope']['shelf'], 'express');
      expect(store.homeCacheFor('all')!['scope']['shelf'], 'all');
    });

    test('a shelf never seen has nothing to show', () async {
      final store = await _store();
      await store.setHomeCache(_payload('all'), shelf: 'all');
      expect(store.homeCacheFor('express'), isNull);
    });

    test('a location change clears every shelf, not just the open one', () async {
      final store = await _store();
      await store.setHomeCache(_payload('express'), shelf: 'express');
      await store.setHomeCache(_payload('all'), shelf: 'all');

      await store.clearHttpCache();

      expect(store.homeCacheFor('express'), isNull);
      expect(store.homeCacheFor('all'), isNull);
    });
  });

  group('upgrading from the single-slot build', () {
    test('a snapshot that proves its shelf is carried over', () async {
      final store = await _store({
        'catalog.home_cache': jsonEncode({
          'shelf': 'all',
          'data': _payload('all'),
        }),
      });
      expect(store.homeCacheFor('all')!['scope']['shelf'], 'all');
    });

    test('a snapshot mis-stamped by the old build is discarded', () async {
      // The old build stamped the shelf it ASKED for. Request إكسبريس at 23:30
      // and the store answers with the full catalogue — filed under 'express'.
      // Trusting that stamp is how main-warehouse products end up painted in
      // ember under a two-hour promise. One shimmer beats one wrong promise.
      final store = await _store({
        'catalog.home_cache': jsonEncode({
          'shelf': 'express',
          'data': _payload('all'),
        }),
      });
      expect(store.homeCacheFor('express'), isNull);
      // …and it is not smuggled in under the other shelf either.
      expect(store.homeCacheFor('all')!['scope']['shelf'], 'all');
    });

    test('a snapshot that cannot say what it describes is dropped', () async {
      final store = await _store({
        'catalog.home_cache': jsonEncode({
          'shelf': 'express',
          'data': {'slots': []},
        }),
      });
      expect(store.homeCacheFor('express'), isNull);
      expect(store.homeCacheFor('all'), isNull);
    });
  });
}
