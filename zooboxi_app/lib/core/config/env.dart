/// Build-time configuration. Nothing secret ever lives here — the app talks
/// only to the public storefront API; payment keys stay on the server.
///
///   flutter run --dart-define=ZB_BASE_URL=https://store.zooboxi.com/wp-json/zooboxi/v2
abstract final class Env {
  static const String _rawBaseUrl = String.fromEnvironment(
    'ZB_BASE_URL',
    defaultValue: 'https://store.zooboxi.com/wp-json/zooboxi/v2',
  );

  static const String _rawStoreUrl = String.fromEnvironment(
    'ZB_STORE_URL',
    defaultValue: 'https://store.zooboxi.com',
  );

  /// API root, guaranteed without a trailing slash — every repository path
  /// starts with `/`, so a configured base ending in `/` would double it.
  static String get baseUrl => normalize(_rawBaseUrl);

  /// Public storefront origin — used for share links and web fallbacks.
  static String get storeUrl => normalize(_rawStoreUrl);

  /// App version reported in `X-ZB-App`. Kept as a define so CI can stamp it
  /// without a source edit.
  static const String appVersion =
      String.fromEnvironment('ZB_APP_VERSION', defaultValue: '1.0.0');

  static String normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
