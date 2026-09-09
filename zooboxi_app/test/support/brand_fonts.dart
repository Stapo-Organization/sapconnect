import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, FontLoader;

/// Puts the app's real type into the test engine.
///
/// `flutter test` answers every family with Ahem — it never reads the `fonts:`
/// block of `pubspec.yaml`, not even for a font the app already bundles — so a
/// golden of a screen is a golden of grey boxes unless the faces are pushed in
/// by hand. These are the very files the phone ships, registered under the
/// family names the theme asks for, each one carrying its own weight class. A
/// sheet drawn after this is drawn the way the customer sees it, and there is
/// no environment variable to remember.
const Map<String, List<String>> _families = {
  'Tajawal': [
    'Tajawal-Regular',
    'Tajawal-Medium',
    'Tajawal-SemiBold',
    'Tajawal-Bold',
    'Tajawal-ExtraBold',
    'Tajawal-Black',
  ],
  'Manrope': [
    'Manrope-Regular',
    'Manrope-Medium',
    'Manrope-SemiBold',
    'Manrope-Bold',
    'Manrope-ExtraBold',
    'Manrope-Black',
  ],
};

bool _loaded = false;

Future<void> loadBrandFonts() async {
  if (_loaded) return;
  _loaded = true;

  Future<ByteData> read(String path) async =>
      ByteData.view(Uint8List.fromList(await File(path).readAsBytes()).buffer);

  for (final MapEntry<String, List<String>> family in _families.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final String name in family.value) {
      loader.addFont(read('assets/fonts/$name.ttf'));
    }
    await loader.load();
  }

  // The one-glyph Riyal face, so ﷼ draws in a sheet exactly as it does in the
  // app instead of falling through to a blank.
  await (FontLoader('SaudiRiyal')
        ..addFont(read('assets/fonts/SaudiRiyal.otf')))
      .load();
}
