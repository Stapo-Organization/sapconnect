import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/zooboxi_tokens.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/loyalty_art.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/features/pets/presentation/widgets/species_avatar.dart';

/// The family program's art sheet.
///
/// A *design* golden, not a regression net: every portrait, sticker and mark
/// at the sizes they are actually used, on both grounds, so the whole hand can
/// be judged on one page. Refresh with
/// `flutter test test/family_art_sheet_test.dart --update-goldens`.

Widget _cell(Widget child, String caption, Color ink, {double width = 96, double height = 110}) =>
    SizedBox(
      width: width,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          child,
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(fontSize: 7, color: ink.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );

Widget _sheet({required Brightness brightness, required Color background, required Color ink}) {
  final theme = ThemeData(brightness: brightness, useMaterial3: true);
  return Theme(
    data: theme,
    child: ColoredBox(
      color: background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final s in PetSpecies.values)
                _cell(SpeciesAvatar(species: s, size: 72, selected: s == PetSpecies.cat), s.name, ink),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final s in PetSpecies.values)
                _cell(SpeciesAvatar(species: s, size: 40), '${s.name} 40', ink, height: 70),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in const ['gift_product', 'express_free', 'free_delivery', 'paws'])
                _cell(RewardSticker(kind: k, size: 64), k, ink),
              _cell(const PawCoin(size: 22), 'coin 22', ink, width: 64),
              _cell(const PawCoin(size: 16, muted: true), 'coin muted', ink, width: 64),
              for (final k in const ['profile', 'welcome', 'frequency', 'trial', 'category', 'care'])
                _cell(MissionSticker(kind: k, size: 56), k, ink),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final m in FamilyMark.values)
                _cell(FamilyMarkIcon(m, size: 28), m.name, ink, width: 72, height: 80),
              const SizedBox(width: 24),
              _cell(
                ProgressRing(
                  value: 0.66,
                  color: ZbTokens.teal,
                  size: 56,
                  animate: false,
                  child: Text('2/3', style: TextStyle(fontSize: 12, color: ink, fontWeight: FontWeight.w800)),
                ),
                'ring',
                ink,
                width: 80,
                height: 90,
              ),
              const SizedBox(width: 24),
              _cell(
                SizedBox(
                  width: 260,
                  height: 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFE8A765), Color(0xFFD48644)]),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: const PawPattern(opacity: 0.14, scale: 0.9),
                      ),
                    ],
                  ),
                ),
                'pattern',
                ink,
                width: 280,
                height: 130,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 4),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                width: 420,
                child: TierLadder(currentKey: 'star', progressToNext: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('family art sheet', (tester) async {
    tester.view.physicalSize = const Size(1400, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                _sheet(brightness: Brightness.light, background: ZbTokens.canvasLight, ink: ZbTokens.ink),
                _sheet(brightness: Brightness.dark, background: ZbTokens.graphite, ink: ZbTokens.inkDark),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    await expectLater(
      find.byType(SingleChildScrollView),
      matchesGoldenFile('goldens/family_art_sheet.png'),
    );
  });
}
