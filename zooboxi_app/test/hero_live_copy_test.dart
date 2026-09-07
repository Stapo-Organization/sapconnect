import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/hero_live_copy.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// A composed slide is cached for five minutes and read back off disk on the
/// next launch, so every clock on it is computed here, on the device. These
/// are the sentences that must never be stale.

const _hours = ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60);

const _scope = CatalogScope(
  tier: 'express',
  note: '',
  expressHours: _hours,
  expressBranch: 'فرع الملك فهد',
  standardCutoffMinutes: 13 * 60,
);

/// زوبكسي in a city the main warehouse delivers to next day.
const _store = CatalogScope(
  tier: 'same_day',
  note: '',
  expressHours: _hours,
  standardCutoffMinutes: 13 * 60,
);

/// A city we only ship to: it has a DATE, not a cut-off.
const _shipping = CatalogScope(tier: 'shipping', note: '', date: 'الأحد 13 سبتمبر');

Future<L> _l(WidgetTester tester) async {
  late L out;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar')],
      home: Builder(builder: (context) {
        out = L.of(context);
        return const SizedBox.shrink();
      }),
    ),
  );
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('ar'));

  testWidgets('the إكسبريس slide names the clock time, not the window',
      (tester) async {
    final l = await _l(tester);
    final live = HeroLive.of(
      'express_clock',
      _scope,
      l,
      'ar',
      now: DateTime(2026, 9, 7, 20, 0),
    );

    // 20:00 + 2h30 → 10:30 م, and the badge still carries the promise itself.
    expect(live.title, contains('10:30'));
    expect(live.badge, 'خلال ساعتين');
    expect(live.deadlineAt, isNull);
  });

  testWidgets('after closing the slide says tomorrow, in the header\'s words',
      (tester) async {
    final l = await _l(tester);
    final live = HeroLive.of(
      'express_clock',
      _scope,
      l,
      'ar',
      now: DateTime(2026, 9, 7, 23, 30),
    );

    // Both the header and this slide run the same arithmetic
    // (`resolveExpressEta`), so they land on the same sentence — «غدًا 2 ص» —
    // and the hero never falls back to «خلال ساعتين», a promise the shut
    // branch cannot keep. (In practice the server stops composing express
    // slides once no branch is serving; this is the belt.)
    expect(live.title, contains('غدًا'));
    expect(live.badge, isNull);
  });

  testWidgets('closing time ticks only inside the last four hours',
      (tester) async {
    final l = await _l(tester);

    final early = HeroLive.of('express_hours', _scope, l, 'ar',
        now: DateTime(2026, 9, 7, 14, 0));
    expect(early.deadlineAt, isNull, reason: 'nine hours out is not urgency');
    expect(early.hint, isNotNull, reason: 'it is simply the hours');

    final late = HeroLive.of('express_hours', _scope, l, 'ar',
        now: DateTime(2026, 9, 7, 21, 30));
    expect(late.deadline, HeroDeadline.branchCloses);
    expect(late.deadlineAt, DateTime(2026, 9, 7, 23, 0));
  });

  testWidgets('the زوبكسي cutoff counts down before one, and stops after',
      (tester) async {
    final l = await _l(tester);

    final before = HeroLive.of('cutoff', _store, l, 'ar',
        now: DateTime(2026, 9, 7, 12, 15));
    expect(before.deadline, HeroDeadline.todayCutoff);
    expect(before.deadlineAt, DateTime(2026, 9, 7, 13, 0));
    expect(before.title, 'اطلب الآن ويوصلك اليوم');

    // The DAY is written here and never on the server: the payload is cached
    // for five minutes and read again off disk at the next launch.
    final after = HeroLive.of('cutoff', _store, l, 'ar',
        now: DateTime(2026, 9, 7, 13, 1));
    expect(after.deadlineAt, isNull);
    expect(after.title, 'اطلب الآن ويوصلك غدًا');

    // Thursday afternoon: Friday is in the way, so the day gets a name.
    final thursday = HeroLive.of('cutoff', _store, l, 'ar',
        now: DateTime(2026, 9, 10, 14, 0));
    expect(thursday.title, contains('السبت'));
  });

  testWidgets('a city we only ship to gets no cut-off at all', (tester) async {
    final l = await _l(tester);
    // Its header says «بحلول الأحد 13 سبتمبر». A slide promising «اليوم» on
    // the same screen would be a second, contradicting promise.
    expect(HeroLive.of('cutoff', _shipping, l, 'ar').isEmpty, isTrue);
  });

  testWidgets('the closing slide leaves once the branch has shut', (tester) async {
    const slide = HeroSlide(kind: 'auto', theme: 'express_hours');
    expect(
      heroSlideIsStale(slide, _scope, now: DateTime(2026, 9, 7, 21, 0)),
      isFalse,
    );
    // Opened at half past eleven on a payload built at ten: «اطلب قبل الإغلاق»
    // is no longer true, so the carousel drops it rather than repeat it.
    expect(
      heroSlideIsStale(slide, _scope, now: DateTime(2026, 9, 7, 23, 30)),
      isTrue,
    );
  });

  testWidgets('a slide with nothing live keeps the server copy', (tester) async {
    final l = await _l(tester);
    expect(HeroLive.of('bundles', _store, l, 'ar').isEmpty, isTrue);
    expect(HeroLive.of(null, _scope, l, 'ar').isEmpty, isTrue);
  });
}
