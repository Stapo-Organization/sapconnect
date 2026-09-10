import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one-glyph Riyal font, loaded from the actual asset file.
///
/// App Store Connect rejected build 26 (ITMS-90853) because the original
/// CFF file had an incomplete `name` table — it rendered fine everywhere and
/// failed only at Apple's gate. `flutter test` never loads pubspec fonts, so
/// this loads the file by hand and checks that U+E900 shapes to its own
/// advance (766/1000 em) rather than to a fallback.
void main() {
  testWidgets('the Riyal font loads and shapes U+E900', (tester) async {
    final bytes = File('assets/fonts/SaudiRiyal.ttf').readAsBytesSync();
    final loader = FontLoader('SaudiRiyal')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();

    final painter = TextPainter(
      text: const TextSpan(
        text: '',
        style: TextStyle(fontFamily: 'SaudiRiyal', fontSize: 100),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, closeTo(76.6, 0.5));
    expect(painter.height, greaterThan(0));
  });
}
