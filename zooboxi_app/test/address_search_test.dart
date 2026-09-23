import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/location/data/location_models.dart';
import 'package:zooboxi_app/features/location/data/location_repository.dart';
import 'package:zooboxi_app/features/location/presentation/widgets/address_search_sheet.dart';
import 'package:zooboxi_app/features/location/presentation/widgets/pin_place_card.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

class _FakeLocations implements LocationRepository {
  final List<String> searched = [];
  final List<String> sessions = [];

  @override
  Future<List<PlaceSuggestion>> search(String query, {double? lat, double? lng, required String session}) async {
    searched.add(query);
    sessions.add(session);
    return const [
      PlaceSuggestion(id: 'p1', main: 'النرجس', secondary: 'الرياض السعودية', kind: 'area', distanceM: 2036),
      PlaceSuggestion(id: 'p2', main: 'النرجس سنتر', secondary: 'الرياض', kind: 'place', distanceM: 450),
    ];
  }

  @override
  Future<({double lat, double lng})> place(String id, {required String session}) async {
    sessions.add(session);
    return (lat: 24.8343, lng: 46.6791);
  }

  @override
  Future<ResolveResult> resolve({required double lat, required double lng}) async => const ResolveResult(
        city: 'الرياض',
        district: 'النرجس',
        best: DeliveryOption(deliveryType: 'express', etaLabel: 'خلال ساعتين'),
        door: DoorAddress(shortAddress: 'RANC2412', building: '2412', street: 'رقم 412', district: 'النرجس', postalCode: '13327'),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<LocalStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStore(await SharedPreferences.getInstance());
}

Widget _host(LocalStore store, _FakeLocations repo, Widget child) => ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        locationRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('typing searches once per pause, and a result flies the map there', (tester) async {
    final repo = _FakeLocations();
    AddressSearchPick? picked;
    await tester.pumpWidget(_host(
      await _store(),
      repo,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showAddressSearch(context, near: const LatLng(24.84, 46.66)),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ا');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.searched, isEmpty, reason: 'one letter is not a search');

    await tester.enterText(find.byType(TextField), 'النر');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'النرجس');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(repo.searched, ['النرجس'], reason: 'debounced: the pause is what is searched');

    expect(find.text('2 كم'), findsOneWidget, reason: 'distance, rounded for a person');
    expect(find.text('450 م'), findsOneWidget);
    expect(find.text('powered by Google', findRichText: true), findsOneWidget);

    await tester.tap(find.text('الرياض السعودية'));
    await tester.pumpAndSettle();
    expect(picked, isA<PickPoint>());
    expect((picked! as PickPoint).point.latitude, closeTo(24.8343, 1e-6));
    expect(repo.sessions.toSet(), hasLength(1), reason: 'the search and the place share one billing session');
  });

  testWidgets('«استخدم موقعي الحالي» asks the map for the device fix', (tester) async {
    final repo = _FakeLocations();
    AddressSearchPick? picked;
    await tester.pumpWidget(_host(
      await _store(),
      repo,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showAddressSearch(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('استخدم موقعي الحالي'));
    await tester.pumpAndSettle();
    expect(picked, isA<PickMyLocation>());
  });

  testWidgets('the pin card reads the door: national address, building and street', (tester) async {
    await tester.pumpWidget(_host(
      await _store(),
      _FakeLocations(),
      const PinPlaceCard(point: LatLng(24.8395, 46.6570)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('العنوان الوطني · RANC2412'), findsOneWidget);
    expect(find.text('مبنى 2412 · رقم 412'), findsOneWidget);
  });
}
