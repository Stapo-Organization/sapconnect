import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/account/presentation/account_screen.dart';
import 'package:zooboxi_app/features/account/data/account_repository.dart';
import 'package:zooboxi_app/features/account/data/account_models.dart';
import 'package:zooboxi_app/features/account/data/addresses_controller.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_repository.dart';
import 'package:zooboxi_app/features/orders/data/live_tracking.dart';
import 'package:zooboxi_app/features/orders/data/order_models.dart';
import 'package:zooboxi_app/features/orders/data/orders_repository.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// «حسابي» in the states it actually ships in: a guest, a member with a
/// standing and a wallet, and a member with a parcel on the way.

class _NoAddresses extends AddressesController {
  @override
  Future<List<Address>> build() async => const [];
}

class _Session extends SessionController {
  _Session({required this.signedIn});

  final bool signedIn;

  @override
  SessionState build() => SessionState(
        status: signedIn ? AuthStatus.authenticated : AuthStatus.guest,
        guestId: 'g-1',
        user: signedIn
            ? const ZbUser(id: 7, name: 'محمد المهجوب', phone: '966500000000')
            : null,
      );
}

const _summary = LoyaltySummary(
  paws: PawsBalance(balance: 1240),
  tier: TierInfo(
    key: 'friend',
    name: 'صديق',
    orders12m: 4,
    min: 3,
    next: NextTier(key: 'special', name: 'مميّز', min: 6),
  ),
  pets: [Pet(id: 1, name: 'لونا', species: PetSpecies.cat)],
  counters: LoyaltyCounters(ordersTotal: 12),
);

final _active = ActiveOrder(
  order: OrderSummary(
    id: 32579,
    number: '32579',
    status: 'processing',
    statusLabel: 'قيد التجهيز',
    total: 240,
    date: DateTime(2026, 9, 9),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required bool signedIn,
  LoyaltySummary? summary,
  ActiveOrder? active,
  double textScale = 1.0,
  List<Override> extra = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore(prefs)),
        sessionProvider.overrideWith(() => _Session(signedIn: signedIn)),
        loyaltySummaryProvider.overrideWith((ref) => Future.value(summary)),
        activeOrderProvider.overrideWith((ref) => Stream.value([?active])),
        buyAgainProvider.overrideWith((ref) => Future.value(const [])),
        addressesControllerProvider.overrideWith(_NoAddresses.new),
        ...extra,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const AccountScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a guest is invited to join, never shown empty counters', (tester) async {
    await _pump(tester, signedIn: false);

    expect(find.text('انضم لعائلة زوبوكسي'), findsOneWidget);
    expect(find.text('سجّل برقم جوالك'), findsOneWidget);
    // Nothing is counted for someone the shop has never served.
    expect(find.text('بصمة'), findsNothing);
    expect(find.text('0'), findsNothing);
    // What signing in gives, in plain lines.
    expect(find.text('تتبّع طلبك لحظة بلحظة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a member sees their card: name, standing, paws and the next rung',
      (tester) async {
    await _pump(tester, signedIn: true, summary: _summary);

    expect(find.text('محمد المهجوب'), findsOneWidget);
    expect(find.text('صديق'), findsOneWidget);
    expect(find.text('1,240'), findsOneWidget);
    // Two orders short of «مميّز», said in words rather than as a percentage.
    expect(find.textContaining('مميّز'), findsWidgets);
    // Her cat has a card of its own.
    expect(find.text('لونا'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('طلباتي'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('طلباتي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a member who has not ordered yet sees no zeros', (tester) async {
    await _pump(
      tester,
      signedIn: true,
      summary: const LoyaltySummary(tier: TierInfo(key: 'start', name: 'بداية الرحلة')),
    );

    expect(find.text('أول طلب يبدأ رصيد بصماتك'), findsOneWidget);
    expect(find.text('مين معك في البيت؟'), findsOneWidget);
    expect(find.text('أول طلب يبدأ رحلتك'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a parcel on the way outranks everything else', (tester) async {
    await _pump(tester, signedIn: true, summary: _summary, active: _active);

    expect(find.text('طلبك في الطريق'), findsOneWidget);

    // Above the pets and the shortcuts, because it is the thing that expires.
    final order = tester.getTopLeft(find.text('طلبك في الطريق')).dy;
    final pets = tester.getTopLeft(find.text('حيواناتي')).dy;
    expect(order, lessThan(pets));
  });

  // Tiles sit two to a row and the card carries a big number; Arabic labels
  // at accessibility text sizes are exactly where rows like that break.
  testWidgets('the screen holds together at large text', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester, signedIn: true, summary: _summary, textScale: 1.6);

    expect(tester.takeException(), isNull);
  });
}
