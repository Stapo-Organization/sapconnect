import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/location/presentation/delivery_when.dart';
import 'package:zooboxi_app/features/location/presentation/location_sheet.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

class _AtKingFahd extends LocationController {
  _AtKingFahd(this._type);

  final String _type;

  @override
  LocationState build() => LocationState(
        location: ZbLocation(
          lat: 24.75,
          lng: 46.66,
          city: 'الرياض',
          district: 'الملك فهد',
          deliveryType: _type,
        ),
      );
}

const _hours = ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60);

CatalogScope _scope(String tier, {String date = ''}) => CatalogScope(
      tier: tier,
      note: 'كل ما هنا يصلك',
      date: date,
      expressHours: _hours,
    );

/// Renders whatever `deliveryWhenLabel` answers at a **fixed** moment, so the
/// assertion does not drift with the hour the suite happens to run at.
class _Answer extends ConsumerWidget {
  const _Answer({required this.scope, required this.now});

  final CatalogScope? scope;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
        deliveryWhenLabel(
          context,
          scope: scope,
          location: ref.watch(currentLocationProvider),
          now: now,
        ),
      );
}

Future<void> _pump(
  WidgetTester tester, {
  required String deliveryType,
  CatalogScope? scope,
  Widget? child,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    localStoreProvider.overrideWithValue(LocalStore(prefs)),
    locationProvider.overrideWith(() => _AtKingFahd(deliveryType)),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: child ?? LocationChip(scope: scope),
          ),
        ),
      ),
    ),
  );
}

/// The arrival sentence in either of its two express shapes.
Finder _arrival() => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          ((w.data ?? '').startsWith('الساعة ') || (w.data ?? '').startsWith('غدًا ')),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the header says where it lands, not how fast we are', (tester) async {
    await _pump(tester, deliveryType: 'express', scope: _scope('express'));

    expect(find.text('يوصلك في المنزل'), findsOneWidget);
    expect(find.text('حي الملك فهد، الرياض'), findsOneWidget);
    // The hour itself moves with the real clock — that it is *an* arrival
    // sentence is what the header owes; the exact wording is asserted below
    // at fixed moments.
    expect(_arrival(), findsOneWidget);
    expect(find.text('خلال ساعتين'), findsNothing);
  });

  testWidgets('express answers with a clock time', (tester) async {
    await _pump(
      tester,
      deliveryType: 'express',
      scope: _scope('express'),
      child: _Answer(scope: _scope('express'), now: DateTime(2026, 9, 6, 15)),
    );

    expect(find.text('الساعة 5:30 م'), findsOneWidget);
  });

  testWidgets('a late order names the hour after midnight, honestly', (tester) async {
    await _pump(
      tester,
      deliveryType: 'express',
      scope: _scope('express'),
      child: _Answer(scope: _scope('express'), now: DateTime(2026, 9, 6, 22, 40)),
    );

    expect(find.text('غدًا 1:10 ص'), findsOneWidget);
  });

  testWidgets('the زوبكسي shelf says tomorrow even inside an express zone',
      (tester) async {
    // The saved location is express — the shelf is not, and the shelf wins.
    await _pump(
      tester,
      deliveryType: 'express',
      scope: _scope('same_day'),
      child: _Answer(scope: _scope('same_day'), now: DateTime(2026, 9, 6, 15)),
    );

    expect(find.text('غدًا'), findsOneWidget);
  });

  testWidgets('out of town it names the delivery date', (tester) async {
    await _pump(
      tester,
      deliveryType: 'shipping',
      scope: _scope('shipping', date: 'الخميس 10 سبتمبر'),
      child: _Answer(
        scope: _scope('shipping', date: 'الخميس 10 سبتمبر'),
        now: DateTime(2026, 9, 6, 15),
      ),
    );

    expect(find.text('بحلول الخميس 10 سبتمبر'), findsOneWidget);
  });
}
