/// This build's version, as `pubspec.yaml` names it.
///
/// Flutter gives Dart no way to read the pubspec version without a native
/// plugin, and the old `ZB_APP_VERSION` define was never passed by the release
/// scripts — so every shipped build said «الإصدار 1.0.0» and told the store it
/// was 1.0.0. `test/app_version_test.dart` fails the moment this and the
/// pubspec disagree, which makes bumping both one step of the release.
const String kAppVersion = '1.0.4';
const int kAppBuild = 43;
