import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/core/config/app_version.dart';

void main() {
  test('the version the app reports is the one pubspec.yaml ships', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':').last.trim();
    expect('$kAppVersion+$kAppBuild', version,
        reason: 'bump lib/core/config/app_version.dart with pubspec.yaml');
  });
}
