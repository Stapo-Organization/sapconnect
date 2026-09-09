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
import 'package:zooboxi_app/features/account/presentation/widgets/account_quick_actions.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_repository.dart';
import 'package:zooboxi_app/features/orders/data/live_tracking.dart';
import 'package:zooboxi_app/features/orders/data/order_models.dart';
import 'package:zooboxi_app/features/orders/data/orders_repository.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// «حسابي» in the states it actually ships in: a guest, a member with a
/// standing and a wallet, and a member with a parcel on the way.

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
        activeOrderProvider.overrideWith((ref) => Stream.value(active)),
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

  testWidgets('a guest is invited, never shown empty counters', (tester) async {
    await _pump(tester, signedIn: false);

    expect(find.text('زائر'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    // Nothing is counted for someone the shop has never served.
    expect(find.text('طلب'), findsNothing);
    expect(find.text('بصمة'), findsNothing);
    // The shortcuts are still there — a guest may browse their wishlist.
    expect(find.byType(AccountQuickActions), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a member sees their name, standing and three real counts',
      (tester) async {
    await _pump(tester, signedIn: true, summary: _summary);

    expect(find.text('محمد المهجوب'), findsOneWidget);
    expect(find.text('صديق'), findsOneWidget);
    // orders / paws / pets, from the summary — not invented.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('1٬240'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    // Two orders short of «مميّز», said in words rather than as a percentage.
    expect(find.textContaining('مميّز'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a parcel on the way outranks everything else', (tester) async {
    await _pump(tester, signedIn: true, summary: _summary, active: _active);

    expect(find.text('طلبك في الطريق'), findsOneWidget);
    expect(find.text('قيد التجهيز'), findsOneWidget);

    // Above the shortcuts, because it is the thing that expires.
    final order = tester.getTopLeft(find.text('طلبك في الطريق')).dy;
    final shortcuts = tester.getTopLeft(find.byType(AccountQuickActions)).dy;
    expect(order, lessThan(shortcuts));
  });

  // The four shortcuts sit in one row; Arabic labels at accessibility text
  // sizes are exactly where a row like that breaks.
  testWidgets('the screen holds together at large text', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester, signedIn: true, summary: _summary, textScale: 1.6);

    expect(tester.takeException(), isNull);
  });
}
