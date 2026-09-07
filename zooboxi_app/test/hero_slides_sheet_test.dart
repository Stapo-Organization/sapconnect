import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/hero_auto_slide.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/hero_carousel.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The two sliders, side by side.
///
/// A *design* golden: إكسبريس sells the next two hours and زوبكسي sells
/// tomorrow's breadth, so their slides must not be able to drift into looking
/// like each other. This page is where that is judged — one column per
/// storefront, every slide the server can compose, drawn at hero size.
///
/// Product photography is deliberately absent (a test has no network), so what
/// this sheet shows is the part that must hold on its own: the field, the
/// copy, the live pill and the mark.
///
/// The bottom row is the one that matters: the slide band on a real phone is
/// `width / HeroMetrics.aspect` — about 123pt, half the height of the cards
/// above — and at the 1.3 text-scale cap it is 183pt. A comfortable 220pt
/// card hid a headline losing its «م» and a pill overflowing its column, so
/// both live sizes are drawn here, with the longest branch name in the fleet.
///
/// Refresh with
/// `flutter test test/hero_slides_sheet_test.dart --update-goldens --dart-define=ZB_FONT_DIR=$HOME/Library/Fonts`.

/// The real Arabic face, so type can be judged as the customer sees it.
const String _fontDir = String.fromEnvironment('ZB_FONT_DIR');

Future<void> _loadFonts() async {
  if (_fontDir.isEmpty) return;
  final loader = FontLoader('ZbPreview');
  for (final file in ['Tajawal-Regular', 'Tajawal-Medium', 'Tajawal-Bold', 'Tajawal-ExtraBold']) {
    final f = File('$_fontDir/$file.ttf');
    if (!f.existsSync()) continue;
    loader.addFont(Future.value(ByteData.view((await f.readAsBytes()).buffer)));
  }
  await loader.load();
}

ThemeData _theme() {
  final base = AppTheme.light(const Locale('ar'));
  if (_fontDir.isEmpty) return base;
  return base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'ZbPreview'));
}

const _expressScope = CatalogScope(
  tier: 'express',
  note: '',
  expressBranch: 'فرع الملك فهد',
  expressHours: ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60),
  standardCutoffMinutes: 13 * 60,
);

const _storeScope = CatalogScope(
  tier: 'same_day',
  note: '',
  expressHours: ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60),
  standardCutoffMinutes: 13 * 60,
);

/// The clock is pinned, per column, at the hour each slider is worth judging:
/// إكسبريس in the evening, where the arrival time and the closing countdown
/// are both live; زوبكسي before one o'clock, where the cut-off is ticking.
/// Without this the sheet would print the wall clock and fail by lunchtime.
final _expressAt = DateTime(2026, 9, 7, 20, 12);
final _storeAt = DateTime(2026, 9, 7, 11, 40);

HeroSlide _slide(
  String theme, {
  required String title,
  required String subtitle,
  String cta = 'تسوّق الآن',
  String? badge,
  BrandRef? brand,
}) =>
    HeroSlide(
      kind: 'auto',
      theme: theme,
      title: title,
      subtitle: subtitle,
      ctaLabel: cta,
      badge: badge,
      brand: brand,
    );

/// The إكسبريس slider, in the order the server composes it.
final _express = <HeroSlide>[
  _slide('express_clock',
      title: 'يوصلك خلال ساعتين',
      subtitle: 'من فرع الملك فهد — أقرب فرع إليك',
      cta: 'اطلب الآن'),
  _slide('express_top',
      title: 'الأكثر طلباً في فرعك',
      subtitle: 'موجود الآن على رفوف فرع الملك فهد',
      cta: 'تصفّح القائمة'),
  _slide('express_new',
      title: 'وصل حديثاً إلى فرعك',
      subtitle: 'جديد على الرف، ويوصلك خلال ساعتين',
      cta: 'شاهد الجديد'),
  _slide('express_hours',
      title: 'الفرع مفتوح حتى 11\u00A0م',
      subtitle: 'اطلب قبل الإغلاق ويوصلك الليلة',
      cta: 'اطلب الآن'),
];

/// The زوبكسي slider. Nothing here is teal, and nothing here is a branch.
final _store = <HeroSlide>[
  _slide('cutoff',
      title: 'اطلب من مستودعنا الرئيسي',
      subtitle: 'آخر موعد للطلب اليوم الساعة 1\u00A0م'),
  _slide('bundles',
      title: 'بكجات زوبكسي',
      subtitle: 'باقات جاهزة بسعر أقل من شراء القطع منفردة',
      cta: 'شاهد البكجات',
      badge: 'وفّر حتى 24%'),
  _slide('brand',
      title: 'ماركة Applaws',
      subtitle: 'منتجات أصلية مستوردة مباشرة',
      cta: 'تسوّق الماركة',
      brand: const BrandRef(name: 'Applaws', slug: 'applaws')),
  _slide('clearance',
      title: 'عروض التصفية',
      subtitle: 'أسعار مخفّضة على منتجات مختارة بكميات محدودة',
      cta: 'اكتشف العروض',
      badge: 'خصم حتى 45%'),
];

Widget _column(String caption, List<HeroSlide> slides, CatalogScope scope, DateTime now) =>
    Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            caption,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: _fontDir.isEmpty ? null : 'ZbPreview',
            ),
          ),
        ),
        for (final slide in slides)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 360,
                height: 220,
                child: HeroAutoCard(slide: slide, scope: scope, now: now),
              ),
            ),
          ),
      ],
    );

/// The slide band exactly as the phone draws it: 393pt wide (iPhone 15/16),
/// at scale 1.0 and at the 1.3 cap.
Widget _production(HeroSlide slide, CatalogScope scope, DateTime now, double scale) {
  const width = 393.0;
  final height = width / HeroMetrics.aspect + (scale - 1) * HeroMetrics.scaleHeadroom;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '${slide.theme}  ·  ${width.toInt()}pt  ·  ×$scale',
          style: TextStyle(
            fontSize: 10,
            fontFamily: _fontDir.isEmpty ? null : 'ZbPreview',
          ),
        ),
      ),
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: width,
            height: height,
            child: HeroAutoCard(slide: slide, scope: scope, now: now),
          ),
        ),
      ),
      const SizedBox(height: 10),
    ],
  );
}

/// The longest branch name the fleet actually has — «فرع السليمانية - الرياض».
const _longBranchScope = CatalogScope(
  tier: 'express',
  note: '',
  expressBranch: 'فرع السليمانية - الرياض',
  expressHours: ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60),
  standardCutoffMinutes: 13 * 60,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await _loadFonts();
  });

  testWidgets('hero slides sheet', (tester) async {
    tester.view.physicalSize = const Size(880, 3300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ColoredBox(
            color: const Color(0xFFF2F2F2),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _column('إكسبريس', _express, _expressScope, _expressAt),
                      const SizedBox(width: 16),
                      _column('زوبكسي', _store, _storeScope, _storeAt),
                    ],
                  ),
                  const Divider(height: 24),
                  // What the phone really draws.
                  // Every shape that ships, at the size that ships: a slide
                  // with a live pill, one with a badge and a CTA, and one with
                  // neither — at both ends of the text-scale range.
                  for (final scale in const [1.0, 1.3]) ...[
                    _production(_express.first, _longBranchScope, _expressAt, scale),
                    _production(_express.last, _longBranchScope, _expressAt, scale),
                    _production(_express[1], _longBranchScope, _expressAt, scale),
                    _production(_store.first, _storeScope, _storeAt, scale),
                    _production(_store[1], _storeScope, _storeAt, scale),
                    _production(_store.last, _storeScope, _storeAt, scale),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hero_slides_sheet.png'),
    );
  });
}
