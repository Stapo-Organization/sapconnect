import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';

/// The type families are bundled now, not fetched from fonts.gstatic.com on
/// first launch. That takes a network round trip off the first frame — and off
/// every frame on a blocked network, where the app used to stay in the system
/// font forever — but it moves weight matching out of `google_fonts` and into
/// the engine.
///
/// The two disagree on a weight a family does not draw. Tajawal has no 600 and
/// Manrope no 900, and the app asks for both: `google_fonts` answered a 600
/// with Tajawal Medium (500 and 700 score alike, first key wins), while CSS3
/// matching would answer it with Bold. So `pubspec.yaml` pins those slots to a
/// restamped copy of the drawing that was already being used, and the engine
/// can read the weight from the manifest or from inside the file and land in
/// the same place either way.
///
/// This test is what keeps that true. It cannot measure type — `flutter test`
/// answers every family with Ahem, bundled or not — so it reads the declaration
/// and the files instead: every weight the app asks for is declared, and every
/// declared file says that weight in its own `OS/2` table.
const List<int> _weightsTheAppAsksFor = [400, 500, 600, 700, 800, 900];

/// `usWeightClass`, read straight out of the sfnt: past the offset table, walk
/// the directory to `OS/2`, then past its version and xAvgCharWidth.
int _declaredWeightInside(File file) {
  final ByteData font = ByteData.sublistView(
    Uint8List.fromList(file.readAsBytesSync()),
  );
  final int tables = font.getUint16(4);
  for (int i = 0; i < tables; i++) {
    final int entry = 12 + i * 16;
    final String tag = String.fromCharCodes(
      Uint8List.sublistView(font, entry, entry + 4),
    );
    if (tag == 'OS/2') return font.getUint16(font.getUint32(entry + 8) + 4);
  }
  fail('${file.path} has no OS/2 table');
}

/// The `fonts:` block of `pubspec.yaml`, as family → {weight: asset path}.
Map<String, Map<int, String>> _declaredFamilies() {
  final out = <String, Map<int, String>>{};
  String? family;
  String? asset;
  bool inFonts = false;
  for (final String line in File('pubspec.yaml').readAsLinesSync()) {
    if (line.trimLeft().startsWith('#')) continue;
    if (RegExp(r'^  \w').hasMatch(line)) inFonts = line.startsWith('  fonts:');
    if (!inFonts) continue;
    final RegExpMatch? f = RegExp(r'^\s*- family:\s*(\S+)').firstMatch(line);
    if (f != null) {
      family = f.group(1);
      out[family!] = <int, String>{};
      continue;
    }
    final RegExpMatch? a = RegExp(r'^\s*- asset:\s*(\S+)').firstMatch(line);
    if (a != null) {
      asset = a.group(1);
      continue;
    }
    final RegExpMatch? w = RegExp(r'^\s*weight:\s*(\d+)').firstMatch(line);
    if (w != null && family != null && asset != null) {
      out[family]![int.parse(w.group(1)!)] = asset;
    }
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, Map<int, String>> families = _declaredFamilies();

  group('the bundled families', () {
    test('both are declared, and nothing is fetched at runtime', () {
      expect(families.keys, containsAll(<String>['Tajawal', 'Manrope']));
      expect(File('pubspec.yaml').readAsStringSync(),
          isNot(contains('google_fonts:')));
    });

    for (final String family in const ['Tajawal', 'Manrope']) {
      test('$family covers every weight the app asks for', () {
        expect(families[family]!.keys.toList()..sort(), _weightsTheAppAsksFor);
      });

      test('$family ships a distinct file per weight', () {
        // Two slots sharing a file would mean one of them silently renders
        // as the other — the very thing the restamped copies prevent.
        final Iterable<String> assets = families[family]!.values;
        expect(assets.toSet(), hasLength(assets.length));
      });

      test('every $family file says its own weight', () {
        families[family]!.forEach((int weight, String asset) {
          final File file = File(asset);
          expect(file.existsSync(), isTrue, reason: '$asset is missing');
          expect(_declaredWeightInside(file), weight,
              reason: '$asset fills the $weight slot but does not say so');
        });
      });
    }

    test('the two restamped files are the drawings they claim to be', () {
      // Same bytes as their source but for the weight class and the two
      // checksums it moves — so the outlines are untouched.
      void sameDrawing(String source, String stamped) {
        final List<int> a = File(source).readAsBytesSync();
        final List<int> b = File(stamped).readAsBytesSync();
        expect(b, hasLength(a.length));
        final int differing = List<int>.generate(a.length, (i) => i)
            .where((i) => a[i] != b[i])
            .length;
        expect(differing, lessThanOrEqualTo(12),
            reason: '$stamped differs from $source by more than metadata');
      }

      sameDrawing('assets/fonts/Tajawal-Medium.ttf',
          'assets/fonts/Tajawal-SemiBold.ttf');
      sameDrawing('assets/fonts/Manrope-ExtraBold.ttf',
          'assets/fonts/Manrope-Black.ttf');
    });
  });

  group('the family follows the content language', () {
    test('Arabic gets Tajawal, everything else Manrope', () {
      expect(AppTheme.familyFor(const Locale('ar')), 'Tajawal');
      expect(AppTheme.familyFor(const Locale('en')), 'Manrope');
    });

    test('the theme carries it into every style, Riyal fallback intact', () {
      final TextTheme text = AppTheme.light(const Locale('ar')).textTheme;
      expect(text.bodyMedium!.fontFamily, 'Tajawal');
      expect(text.displayLarge!.fontFamily, 'Tajawal');
      expect(text.labelSmall!.fontFamilyFallback, contains('SaudiRiyal'));
      expect(
          AppTheme.light(const Locale('en')).textTheme.bodyMedium!.fontFamily,
          'Manrope');
    });
  });
}
