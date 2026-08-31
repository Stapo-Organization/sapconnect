import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/zooboxi_tokens.dart';
import 'package:zooboxi_app/core/icons/zb_icons.dart';

/// The icon sheet.
///
/// This is a *design* golden, not a regression net: it renders every glyph in
/// both states, on both grounds, plus the states that only exist in motion, so
/// the whole language can be judged on one page. Refresh it with
/// `flutter test test/zb_icons_sheet_test.dart --update-goldens`.

const double _sheetWidth = 1200;
const double _sheetHeight = 880;

const List<ZbIconKind> _all = ZbIconKind.values;

Widget _label(String text, Color color) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(fontSize: 7, color: color.withValues(alpha: 0.45)),
    );

Widget _cell(Widget icon, String caption, Color ink, {double height = 74}) =>
    SizedBox(
      width: 96,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: 6),
          _label(caption, ink),
        ],
      ),
    );

/// [size] is the *optical* tier as much as a dimension: under 28pt the
/// painters drop their tertiary detail, so both tiers have to be on the sheet.
Widget _row(double fill, Color ink, {double size = 48, double height = 74}) =>
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final kind in _all)
          _cell(
            ZbIcon(kind, size: size, fill: fill, ink: ink, scanY: 0.5),
            kind.name,
            ink,
            height: height,
          ),
      ],
    );

Widget _section({
  required Brightness brightness,
  required Color background,
  required Color ink,
}) =>
    Theme(
      data: ThemeData(brightness: brightness),
      child: ColoredBox(
        color: background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _row(0, ink),
            _row(1, ink),
            // The tab tier: same glyphs, tertiary detail dropped.
            _row(0, ink, size: 22, height: 44),
            _row(1, ink, size: 22, height: 44),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

Widget _states(Color ink) => ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: SizedBox(
        height: 96,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final open in const [0.0, 0.5, 1.0])
              _cell(
                ZbIcon(
                  ZbIconKind.cart,
                  size: 48,
                  fill: 1,
                  ink: ink,
                  lidOpen: open,
                  smile: 1,
                ),
                'lid ${open.toStringAsFixed(1)}',
                ink,
              ),
            const SizedBox(width: 40),
            // The two glyphs whose highlight has a reading direction.
            for (final rtl in const [false, true])
              for (final kind in const [ZbIconKind.pin, ZbIconKind.heart])
                _cell(
                  Directionality(
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: ZbIcon(kind, size: 48, fill: 1, ink: ink),
                  ),
                  '${kind.name} ${rtl ? 'rtl' : 'ltr'}',
                  ink,
                ),
            const SizedBox(width: 40),
            for (final kind in const [ZbIconKind.search, ZbIconKind.bell])
              for (final rtl in const [false, true])
                _cell(
                  Directionality(
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: ZbIcon(kind, size: 48, fill: 0.5, ink: ink),
                  ),
                  '${kind.name} ${rtl ? 'rtl' : 'ltr'}',
                  ink,
                ),
          ],
        ),
      ),
    );

Widget _scaleStrip(Color ink) => ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: SizedBox(
        height: 74,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final size in const [16.0, 24.0, 48.0])
              for (final kind in const [
                ZbIconKind.home,
                ZbIconKind.cart,
                ZbIconKind.heart,
                ZbIconKind.plusBox,
              ])
                SizedBox(
                  width: 72,
                  child: Center(
                    child: ZbIcon(kind, size: size, fill: 1, ink: ink),
                  ),
                ),
          ],
        ),
      ),
    );

/// A large read of the glyphs that carry the most character — the detail that
/// decides whether the set feels drawn or generated only shows at this size.
Widget _heroStrip(Color ink) => ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: SizedBox(
        height: 128,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final kind in const [
              ZbIconKind.home,
              ZbIconKind.cart,
              ZbIconKind.account,
              ZbIconKind.plusBox,
              ZbIconKind.pin,
              ZbIconKind.categories,
              ZbIconKind.paw,
            ])
              SizedBox(
                width: 150,
                child: Center(
                  child: ZbIcon(kind, size: 104, fill: 1, ink: ink),
                ),
              ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('ZbIcons sheet', (tester) async {
    tester.view.physicalSize = const Size(_sheetWidth, _sheetHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(_sheetWidth, _sheetHeight)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const Key('sheet'),
            child: SizedBox(
              width: _sheetWidth,
              height: _sheetHeight,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Column(
                  children: [
                    _section(
                      brightness: Brightness.light,
                      background: const Color(0xFFFFFCF5),
                      ink: ZbTokens.inkWarm,
                    ),
                    _section(
                      brightness: Brightness.dark,
                      background: ZbTokens.graphite,
                      ink: ZbTokens.creamLogo.withValues(alpha: 0.92),
                    ),
                    _states(ZbTokens.inkWarm),
                    _scaleStrip(ZbTokens.inkWarm),
                    _heroStrip(ZbTokens.inkWarm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const Key('sheet')),
      matchesGoldenFile('goldens/zb_icons_sheet.png'),
    );
  });
}
