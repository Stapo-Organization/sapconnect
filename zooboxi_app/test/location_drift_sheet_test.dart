import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/account/data/account_models.dart';
import 'package:zooboxi_app/features/account/data/addresses_controller.dart';
import 'package:zooboxi_app/features/account/presentation/widgets/map_pin_picker.dart';
import 'package:zooboxi_app/features/location/data/location_models.dart';
import 'package:zooboxi_app/features/location/data/location_repository.dart';
import 'package:zooboxi_app/features/location/presentation/location_drift_sheet.dart';
import 'package:zooboxi_app/features/location/presentation/location_sheet.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The phone says the customer is in العليا; the saved address is in الملك فهد.
const _drift = LocationDrift(
  lat: 24.6980,
  lng: 46.6850,
  city: 'الرياض',
  district: 'العليا',
  promiseLabel: 'خلال ساعتين',
);

class _Session extends SessionController {
  _Session({this.signedIn = true});

  final bool signedIn;

  @override
  SessionState build() => SessionState(
        status: signedIn ? AuthStatus.authenticated : AuthStatus.guest,
        guestId: 'g-1',
      );
}

class _Book extends AddressesController {
  static Address? saveAttempt;

  @override
  Future<List<Address>> build() async => const [];

  @override
  Future<Address> save(Address address) async {
    saveAttempt = address;
    final stored = address.copyWith(id: 'a-new');
    state = AsyncValue.data([stored]);
    return stored;
  }
}

/// Records what the sheet asked the store to deliver to, without a network.
class _RecordingLocation extends LocationController {
  static ({double lat, double lng, String? addressId, String? label})? applied;

  @override
  LocationState build() => const LocationState(
        location: ZbLocation(
          lat: 24.7494,
          lng: 46.6678,
          city: 'الرياض',
          district: 'الملك فهد',
          deliveryType: 'express',
          addressId: 'a-home',
          label: 'المنزل',
        ),
      );

  @override
  Future<bool> resolve(double lat, double lng, {String? addressId, String? label}) async {
    applied = (lat: lat, lng: lng, addressId: addressId, label: label);
    return true;
  }
}

late LocalStore store;

Future<void> _open(
  WidgetTester tester, {
  bool signedIn = true,
  Address? editorReturns,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  store = LocalStore(prefs);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        sessionProvider.overrideWith(() => _Session(signedIn: signedIn)),
        locationProvider.overrideWith(_RecordingLocation.new),
        addressesControllerProvider.overrideWith(_Book.new),
        // The card's answer, without the wire.
        pinPlaceProvider.overrideWith(
          (ref, point) async => const ResolveResult(
            city: 'الرياض',
            district: 'العليا',
            best: DeliveryOption(deliveryType: 'express', etaLabel: 'خلال ساعتين'),
          ),
        ),
        if (editorReturns != null)
          addressEditorProvider.overrideWithValue(
            (context, {initial, contactOptional = false, autoLocate = false}) async =>
                (address: editorReturns, save: true),
          ),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showLocationDriftSheet(context, _drift),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('افتح'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _RecordingLocation.applied = null;
    _Book.saveAttempt = null;
  });

  // The whole point of the rebuild: a fix the customer cannot see is a claim,
  // not an address. The map is the offer.
  testWidgets('being somewhere new opens a map, not a yes/no', (tester) async {
    await _open(tester);

    expect(find.byType(MapPinPicker), findsOneWidget);
    expect(find.text('يبدو أنك في مكان جديد'), findsOneWidget);
    expect(find.text('وصّلوا إلى هذا الموقع'), findsOneWidget);
    expect(find.text('حفظه كعنوان جديد'), findsOneWidget);
    expect(find.text('إبقاء العنوان المحدد'), findsOneWidget);
    // And it says where the order is going *now*, so the choice is a choice.
    expect(find.textContaining('المنزل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delivering here sends the pin, under no saved address',
      (tester) async {
    await _open(tester);

    await tester.tap(find.text('وصّلوا إلى هذا الموقع'));
    await tester.pumpAndSettle();

    final applied = _RecordingLocation.applied;
    expect(applied, isNotNull);
    expect(applied!.lat, closeTo(_drift.lat, 0.0005));
    expect(applied.lng, closeTo(_drift.lng, 0.0005));
    // Where the customer *is* today is not «المنزل»: the label and the id of
    // the saved address must not travel with a pin that is not it.
    expect(applied.addressId, isNull);
    expect(applied.label, isNull);
  });

  // The correction is the feature: what the map ends up on is what gets used.
  testWidgets('a nudged pin is what the store is asked about', (tester) async {
    await _open(tester);

    await tester.drag(find.byType(MapPinPicker), const Offset(0, -80));
    // Past the picker's settle debounce.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('وصّلوا إلى هذا الموقع'));
    await tester.pumpAndSettle();

    final applied = _RecordingLocation.applied;
    expect(applied, isNotNull);
    // Dragging the tiles upward walks the camera south — the pin is now on a
    // point the device never reported, and that is the one that is used.
    expect(applied!.lat, lessThan(_drift.lat));
  });

  testWidgets('keeping the saved address waves away the device fix, not the pin',
      (tester) async {
    await _open(tester);

    await tester.tap(find.text('إبقاء العنوان المحدد'));
    await tester.pumpAndSettle();

    expect(_RecordingLocation.applied, isNull);
    final dismissed = store.driftDismissed;
    expect(dismissed, isNotNull);
    expect(dismissed!['lat'], _drift.lat);
    expect(dismissed['lng'], _drift.lng);
  });

  testWidgets('this place can be kept as an address of its own', (tester) async {
    await _open(
      tester,
      editorReturns: const Address(
        id: '',
        label: 'المكتب',
        name: 'محمد',
        phone: '0500000000',
        city: 'الرياض',
        district: 'العليا',
        addressLine: 'برج المملكة',
        lat: 24.6980,
        lng: 46.6850,
      ),
    );

    await tester.tap(find.text('حفظه كعنوان جديد'));
    await tester.pumpAndSettle();

    expect(_Book.saveAttempt?.label, 'المكتب');
    // And the shop is now delivering to it, under the id the book issued.
    expect(_RecordingLocation.applied?.addressId, 'a-new');
    expect(_RecordingLocation.applied?.label, 'المكتب');
  });
}
