import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/hero_light_card.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';

/// «الحيّ الأبيض» — the زوبكسي slide cards the owner picked on 2026-09-18,
/// drawn at production width in both themes, at scale 1.0 and at the 1.3 cap.
///
/// A *design* golden — refresh with
/// `flutter test test/hero_light_sheet_test.dart --update-goldens`.
const _storeScope = CatalogScope(
  tier: 'same_day',
  note: '',
  expressHours: ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60),
  standardCutoffMinutes: 13 * 60,
);

final _storeAt = DateTime(2026, 9, 7, 11, 40);

HeroSlide _slide(
  String theme, {
  required String title,
  required String subtitle,
  String cta = 'تسوّق الآن',
  String? badge,
  int? value,
  BrandRef? brand,
  int photos = 2,
}) => HeroSlide(
  kind: 'auto',
  theme: theme,
  title: title,
  subtitle: subtitle,
  ctaLabel: cta,
  badge: badge,
  value: value,
  brand: brand,
  productImages: List.filled(photos, ''),
);

final _store = <HeroSlide>[
  _slide(
    'cutoff',
    title: 'اطلب من مستودعنا الرئيسي',
    subtitle: 'آخر موعد للطلب اليوم الساعة 1 م',
  ),
  _slide(
    'bundles',
    title: 'بكجات زوبكسي',
    subtitle: 'باقات جاهزة بسعر أقل من شراء القطع منفردة',
    cta: 'شاهد البكجات',
    badge: 'وفّر حتى 24%',
    value: 24,
  ),
  _slide(
    'brand',
    title: 'ماركة Applaws',
    subtitle: 'منتجات أصلية مستوردة مباشرة',
    cta: 'تسوّق الماركة',
    photos: 0,
    brand: const BrandRef(name: 'Applaws', slug: 'applaws', logo: ''),
  ),
  _slide(
    'clearance',
    title: 'عروض التصفية',
    subtitle: 'أسعار مخفّضة على منتجات مختارة بكميات محدودة',
    cta: 'اكتشف العروض',
    badge: 'خصم حتى 45%',
    value: 45,
  ),
];

Widget _card(HeroSlide slide, double scale) {
  const width = 393.0 - 2 * LightCardMetrics.margin;
  final height =
      LightCardMetrics.height + (scale - 1) * LightCardMetrics.scaleHeadroom;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, LightCardMetrics.spill + 12),
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: SizedBox(
        width: width,
        height: height,
        child: LightSlideCard(slide: slide, scope: _storeScope, now: _storeAt),
      ),
    ),
  );
}

Widget _column(ThemeData theme, Color canvas, double scale) => Theme(
  data: theme,
  child: ColoredBox(
    color: canvas,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final slide in _store) _card(slide, scale)],
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await loadBrandFonts();
  });

  testWidgets('light hero cards sheet', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _column(AppTheme.light(const Locale('ar')), const Color(0xFFFFF7EF), 1.0),
                _column(AppTheme.dark(const Locale('ar')), const Color(0xFF1A201E), 1.0),
                _column(AppTheme.light(const Locale('ar')), const Color(0xFFFFF7EF), 1.3),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SingleChildScrollView),
      matchesGoldenFile('goldens/hero_light_sheet.png'),
    );
  });
}
