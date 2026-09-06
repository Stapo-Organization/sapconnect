import 'dart:async';

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
import 'package:zooboxi_app/features/location/presentation/location_sheet.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The address book, as a signed-in customer's shop would hand it over.
const _home = Address(
  id: 'a-home',
  label: 'المنزل',
  name: 'محمد',
  phone: '0500000000',
  city: 'الرياض',
  district: 'الملك فهد',
  addressLine: 'شارع التخصصي',
  lat: 24.7494,
  lng: 46.6678,
  isDefault: true,
);

const _work = Address(
  id: 'a-work',
  label: 'العمل',
  name: 'محمد',
  phone: '0500000000',
  city: 'الرياض',
  district: 'العليا',
  addressLine: 'برج المملكة',
  lat: 24.7118,
  lng: 46.6745,
);

class _Session extends SessionController {
  _Session({required this.signedIn});

  final bool signedIn;

  @override
  SessionState build() => SessionState(
        status: signedIn ? AuthStatus.authenticated : AuthStatus.guest,
        guestId: 'g-1',
      );
}

class _Book extends AddressesController {
  _Book(this.list, {this.refuseSave = false});

  final List<Address> list;

  /// The server saying no — the case where the customer's address must not be
  /// lost and must not be quoted under an id the server does not hold.
  final bool refuseSave;

  static Address? saveAttempt;

  @override
  Future<List<Address>> build() async => list;

  @override
  Future<Address> save(Address address) async {
    saveAttempt = address;
    if (refuseSave) throw Exception('refused');
    final stored = address.copyWith(id: 'a-new');
    state = AsyncValue.data([...list, stored]);
    return stored;
  }
}

/// Records what the sheet asked the store to deliver to, without a network.
class _RecordingLocation extends LocationController {
  static ({double lat, double lng, String? addressId, String? label})? applied;
  static int resolves = 0;

  /// When set, resolves hang until the test completes it — the only way to
  /// stand inside the window where a second tap could race the first.
  static Completer<bool>? gate;

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
    resolves++;
    applied = (lat: lat, lng: lng, addressId: addressId, label: label);
    final held = gate;
    if (held != null) return held.future;
    return true;
  }
}

/// The device's own storage for the test that needs to look inside it.
late LocalStore store;

Future<void> _open(
  WidgetTester tester, {
  required bool signedIn,
  List<Address> addresses = const [],
  bool refuseSave = false,
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
        addressesControllerProvider
            .overrideWith(() => _Book(addresses, refuseSave: refuseSave)),
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
                onPressed: () => showLocationSheet(context),
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
    _RecordingLocation.resolves = 0;
    _RecordingLocation.gate = null;
    _Book.saveAttempt = null;
  });

  testWidgets('a signed-in customer picks between their own addresses',
      (tester) async {
    await _open(tester, signedIn: true, addresses: const [_home, _work]);

    expect(find.text('عناويني'), findsOneWidget);
    expect(find.text('المنزل'), findsWidgets);
    expect(find.text('العمل'), findsOneWidget);
    // The one being delivered to is ticked, and only that one.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('choosing an address delivers there, by id and by name',
      (tester) async {
    await _open(tester, signedIn: true, addresses: const [_home, _work]);

    await tester.tap(find.text('العمل'));
    await tester.pumpAndSettle();

    expect(_RecordingLocation.applied?.addressId, 'a-work');
    expect(_RecordingLocation.applied?.label, 'العمل');
    expect(_RecordingLocation.applied?.lat, 24.7118);
    // Chosen and done — the sheet closes rather than waiting for a confirm.
    expect(find.text('عناويني'), findsNothing);
  });

  testWidgets('there is no city list anywhere in the sheet', (tester) async {
    await _open(tester, signedIn: true, addresses: const [_home]);

    expect(find.text('أختار مدينتي بنفسي'), findsNothing);
    expect(find.text('اختر مدينتك'), findsNothing);
    expect(find.text('عنوان جديد على الخريطة'), findsOneWidget);
  });

  testWidgets('a guest is offered the map, and an account to keep it in',
      (tester) async {
    await _open(tester, signedIn: false);

    expect(find.text('حدّد موقعي على الخريطة'), findsOneWidget);
    expect(find.text('سجّل الدخول لتحفظ عناوينك'), findsOneWidget);
    expect(find.text('عناويني'), findsNothing);
  });

  testWidgets('a second tap cannot race the first', (tester) async {
    // The store is slow to answer, which is exactly when an impatient
    // customer taps the other address.
    _RecordingLocation.gate = Completer<bool>();
    await _open(tester, signedIn: true, addresses: const [_home, _work]);

    await tester.tap(find.text('العمل'));
    await tester.pump();
    await tester.tap(find.text('المنزل'), warnIfMissed: false);
    await tester.pump();

    expect(_RecordingLocation.resolves, 1, reason: 'the first choice owns the sheet');
    expect(_RecordingLocation.applied?.addressId, 'a-work');

    _RecordingLocation.gate!.complete(true);
    await tester.pumpAndSettle();

    // Popped exactly once: the page underneath is still there.
    expect(find.text('افتح'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused save keeps the address without claiming the server has it',
      (tester) async {
    await _open(
      tester,
      signedIn: true,
      addresses: const [_home],
      refuseSave: true,
      editorReturns: const Address(
        id: 'a-home',
        label: 'المنزل',
        name: 'محمد',
        phone: '0500000000',
        city: 'الرياض',
        district: 'حطين',
        addressLine: 'شارع الأمير سلطان',
        lat: 24.77,
        lng: 46.62,
      ),
    );

    await tester.tap(find.text('عنوان جديد على الخريطة'));
    await tester.pumpAndSettle();

    // The new pin is where we deliver — but not under the id of an entry the
    // server never updated, or the order would go to the old building.
    expect(_RecordingLocation.applied?.lat, 24.77);
    expect(_RecordingLocation.applied?.addressId, isNull);
    expect(_Book.saveAttempt, isNotNull);
    // And the device is holding it, so checkout still has the address the
    // customer typed even though the book refused it.
    expect(store.pendingAddress, isNotNull);
    expect(
      find.text('تعذّر حفظ العنوان في دفترك — سنوصّل إليه الآن، وتقدر تحفظه لاحقًا'),
      findsOneWidget,
    );
    // Still open, so the customer can see what happened and try again.
    expect(find.text('عناويني'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
