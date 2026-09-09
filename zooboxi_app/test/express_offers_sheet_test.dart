import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_offers.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';

/// إكسبريس's offer strip, drawn the way the customer sees it: the real Arabic
/// face, the three slides the server actually composes for the branch, in both
/// themes and at the text scale where copy fights for room.
///
/// A *design* golden — refresh with
/// `flutter test test/express_offers_sheet_test.dart --update-goldens`.
const List<HeroSlide> _slides = [
  HeroSlide(
    kind: 'auto',
    theme: 'express_clock',
    title: 'يوصلك خلال ساعتين',
    subtitle: 'من فرع الملك فهد - الرياض — أقرب فرع إليك',
    ctaLabel: 'اطلب الآن',
  ),
  HeroSlide(
    kind: 'auto',
    theme: 'express_top',
    title: 'الأكثر طلباً في فرعك',
    subtitle: 'موجود الآن على رفوف فرع الملك فهد',
    ctaLabel: 'تصفّح القائمة',
    badge: 'الأكثر مبيعاً',
  ),
  HeroSlide(
    kind: 'auto',
    theme: 'express_new',
    title: 'وصل حديثاً إلى فرعك',
    subtitle: 'جديد على الرف، ويوصلك خلال ساعتين',
    ctaLabel: 'شاهد الجديد',
  ),
  HeroSlide(
    kind: 'auto',
    theme: 'clearance',
    title: 'عروض التصفية',
    subtitle: 'خصومات تنتهي بانتهاء الكمية',
    ctaLabel: 'اغتنمها',
    badge: 'خصم حتى ٤٥٪',
  ),
];

Widget _panel(String caption, Brightness brightness, double scale) {
  final theme = brightness == Brightness.dark
      ? AppTheme.dark(const Locale('ar'))
      : AppTheme.light(const Locale('ar'));
  return Theme(
    data: theme,
    child: Builder(
      builder: (context) => ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, bottom: 10),
                child: Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Tajawal',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: const ExpressOfferSlider(slides: _slides),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBrandFonts);

  testWidgets('express offers sheet', (tester) async {
    tester.view.physicalSize = const Size(393, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: ColoredBox(
          color: const Color(0xFFEFEFEF),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _panel('فاتح · مقياس النص ١', Brightness.light, 1),
              const SizedBox(height: 8),
              _panel('فاتح · مقياس النص ١٫٣', Brightness.light, 1.3),
              const SizedBox(height: 8),
              _panel('داكن · مقياس النص ١', Brightness.dark, 1),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/express_offers_sheet.png'),
    );
  });
}
