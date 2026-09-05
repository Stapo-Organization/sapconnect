import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves every `binding.takeScreenshot(name)` to `SCREENSHOT_DIR` (or
/// `build/screenshots`). Run with `flutter drive --driver=test_driver/...`.
Future<void> main() async {
  final dir = Directory(Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots')
    ..createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
      return true;
    },
  );
}
