import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/account/data/account_models.dart';
import 'package:zooboxi_app/features/account/presentation/address_editor_screen.dart';
import 'package:zooboxi_app/features/account/presentation/widgets/address_form.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// A pin alone gets a driver to the street; the building, floor and flat are
/// what get him to the door. These cover the three places that detail has to
/// survive: the wire shape, the form, and the editor a guest fills in before
/// the store knows their name.

const _kRiyadh = (lat: 24.7136, lng: 46.6753);

late LocalStore _store;

Address _pinned({String name = '', String phone = ''}) => Address(
      id: '',
      name: name,
      phone: phone,
      city: 'الرياض',
      addressLine: '',
      lat: _kRiyadh.lat,
      lng: _kRiyadh.lng,
    );

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      theme: AppTheme.light(const Locale('ar')),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner!,
      ),
      home: Scaffold(body: child),
    );

/// The TextField that owns a floating label — how a person picks the field out
/// of the form, and the only handle the widgets give a test.
Finder _fieldFor(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextField));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  group('Address', () {
    test('carries the unit fields both ways over the wire', () {
      final address = _pinned(name: 'محمد', phone: '0500000000').copyWith(
        building: '12',
        floor: 'الثالث',
        apartment: '7',
      );

      final json = address.toJson();
      expect(json['building'], '12');
      expect(json['floor'], 'الثالث');
      expect(json['apartment'], '7');

      final back = Address.fromJson({...json, 'id': 'a1'});
      expect(back.building, '12');
      expect(back.floor, 'الثالث');
      expect(back.apartment, '7');
    });

    test('leaves the unit fields out entirely when they are empty', () {
      final json = _pinned(name: 'محمد', phone: '0500000000').toJson();

      expect(json.containsKey('building'), isFalse);
      expect(json.containsKey('floor'), isFalse);
      expect(json.containsKey('apartment'), isFalse);
      expect(Address.fromJson(json).building, isNull);
    });
  });

  testWidgets('the form asks for building, floor and flat', (tester) async {
    await tester.pumpWidget(_host(const _FormHarness()));

    expect(find.text('رقم العمارة'), findsOneWidget);
    expect(find.text('الدور'), findsOneWidget);
    expect(find.text('الشقة'), findsOneWidget);
    expect(find.text('اسم المستلم'), findsOneWidget);
    expect(find.text('رقم الجوال'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The welcome journey asks where before it asks who — a guest has no account
  // to take a name from, so the two contact fields must not be on screen at all.
  testWidgets('contactHidden drops the recipient name and phone', (tester) async {
    await tester.pumpWidget(_host(const _FormHarness(contactHidden: true)));

    expect(find.text('اسم المستلم'), findsNothing);
    expect(find.text('رقم الجوال'), findsNothing);
    expect(find.text('رقم العمارة'), findsOneWidget);
    expect(find.text('المدينة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a guest can save a pinned address without a name or a phone',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    AddressDraft? captured;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(_store)],
        child: _host(
          Builder(
            builder: (context) => TextButton(
              // The initial pin is what keeps this on the details stage: the
              // map stage has nothing to assert and everything to load.
              onPressed: () async => captured = await showAddressEditor(
                context,
                initial: _pinned(),
                contactOptional: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // A prefilled draft with no id is still a *new* address, not an edit.
    expect(find.text('عنوان جديد'), findsOneWidget);
    expect(find.text('اسم المستلم'), findsNothing);

    await tester.enterText(_fieldFor('رقم العمارة'), '4821');
    await tester.enterText(_fieldFor('الدور'), 'الثاني');
    await tester.enterText(_fieldFor('الشقة'), '11');
    await tester.pump();

    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final address = captured?.address;
    expect(address, isNotNull, reason: 'a building number is address enough');
    expect(address!.building, '4821');
    expect(address.floor, 'الثاني');
    expect(address.apartment, '11');
    expect(address.city, 'الرياض');
    expect(address.addressLine, isEmpty);
    expect(address.name, isEmpty);
    expect(address.phone, isEmpty);
    expect(address.lat, _kRiyadh.lat);
    expect(tester.takeException(), isNull);
  });

  group('LocalStore.pendingAddress', () {
    test('holds a guest address until something claims it', () async {
      expect(_store.pendingAddress, isNull);

      final json = _pinned().copyWith(building: '12', floor: '3').toJson();
      await _store.setPendingAddress(json);

      final read = _store.pendingAddress;
      expect(read, isNotNull);
      expect(Address.fromJson(read!).building, '12');
      expect(Address.fromJson(read).city, 'الرياض');

      await _store.setPendingAddress(null);
      expect(_store.pendingAddress, isNull);
    });
  });
}

/// Owns the controllers the form takes, so the fields survive a rebuild the
/// way they do inside the editor.
class _FormHarness extends StatefulWidget {
  const _FormHarness({this.contactHidden = false});

  final bool contactHidden;

  @override
  State<_FormHarness> createState() => _FormHarnessState();
}

class _FormHarnessState extends State<_FormHarness> {
  final _controllers = List.generate(8, (_) => TextEditingController());
  AddressLabelChoice _choice = AddressLabelChoice.home;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AddressForm(
          name: _controllers[0],
          phone: _controllers[1],
          city: _controllers[2],
          district: _controllers[3],
          line: _controllers[4],
          building: _controllers[5],
          floor: _controllers[6],
          apartment: _controllers[7],
          customLabel: _controllers[0],
          labelChoice: _choice,
          onLabelChoice: (choice) => setState(() => _choice = choice),
          contactHidden: widget.contactHidden,
        ),
      );
}
