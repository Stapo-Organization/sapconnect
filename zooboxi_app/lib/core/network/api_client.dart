import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/local_store.dart';
import 'api_exception.dart';
import 'envelope.dart';

/// Callbacks the client pulls per request. They are function refs rather than
/// values so the client never holds a stale token, language or location.
typedef ValueReader<T> = T Function();

/// The single HTTP door to `zooboxi/v2`.
///
/// It carries the whole request pipeline the server expects:
/// bearer token, guest id, location headers (the app is the cookie jar the
/// store's 44 location-aware classes read), `?lang=`, `X-ZB-App`, plus a
/// conditional-GET cache so repeat catalog reads cost a 304.
class ApiClient {
  ApiClient({
    required LocalStore store,
    required this.readToken,
    required this.readGuestId,
    required this.readLocationHeaders,
    required this.readLanguageCode,
    required this.readShelf,
    required this.readEffectiveShelf,
    this.onAuthRequired,
  }) : _store = store {
    dio = Dio(
      BaseOptions(
        baseUrl: Env.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
        // 304 is a success for us: the interceptor swaps in the cached body.
        validateStatus: (s) => s != null && (s < 400 || s == 304),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    if (kDebugMode) {
      // Method, path and status only. Bodies and headers carry the bearer
      // token, the customer's coordinates and their basket — never log them.
      dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (r, h) {
            debugPrint('[api] ${r.requestOptions.method} ${r.requestOptions.path} → ${r.statusCode}');
            h.next(r);
          },
          onError: (e, h) {
            debugPrint('[api] ${e.requestOptions.method} ${e.requestOptions.path} ✗ ${e.response?.statusCode ?? e.type.name}');
            h.next(e);
          },
        ),
      );
    }
  }

  late final Dio dio;
  final LocalStore _store;

  final ValueReader<String?> readToken;
  final ValueReader<String?> readGuestId;
  final ValueReader<Map<String, String>> readLocationHeaders;
  final ValueReader<String> readLanguageCode;

  /// Which storefront tab is browsing ('express' | 'all') — every catalogue
  /// read is scoped to it server-side.
  final ValueReader<String> readShelf;

  /// Which storefront the server said it actually served. Part of the cache
  /// key only: after closing time an إكسبريس request comes back as the زوبكسي
  /// shelf, and without this both answers would share one entry — so the
  /// full-store body could later be replayed under the إكسبريس tab.
  final ValueReader<String> readEffectiveShelf;

  /// Fired when the server rejects a *bearer* call. It does **not** log a
  /// guest out — guests are expected to hit account routes and be refused;
  /// that is a prompt to sign in, not a session teardown.
  final VoidCallback? onAuthRequired;

  /// In-memory mirror of the persisted ETag cache — avoids a prefs read on
  /// every request. Key → (etag, raw json body).
  final Map<String, (String etag, String body)> _memCache = {};

  /// Only immutable-ish catalog reads are cached. Cart, checkout, orders and
  /// account are per-customer and must never be served from a 304 store.
  static bool _isCacheable(String path) {
    const prefixes = ['/home', '/catalog', '/brands', '/clearance', '/meta', '/location/cities'];
    return prefixes.any(path.startsWith);
  }

  /// The same question, for a request that may have opted out. The idle
  /// prefetch of the other shelf reads a body this device is not currently
  /// browsing; storing its ETag would let a later request for the shelf we
  /// *are* on be answered 304 with the wrong storefront.
  static bool _cacheableRequest(RequestOptions options) =>
      options.method == 'GET' &&
      options.extra[_noCache] != true &&
      _isCacheable(options.path);

  /// Request-scoped flags a caller can set through `get(extra: …)`.
  static const String _noCache = 'zb_no_cache';
  static const String _shelfOverride = 'zb_shelf';
  static const String _cacheKeyStash = 'zb_cache_key';

  // ── Interceptors ─────────────────────────────────────────────────────

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    final guest = readGuestId();
    if (guest != null && guest.isNotEmpty) {
      options.headers['X-ZB-Guest'] = guest;
    }

    options.headers.addAll(readLocationHeaders());
    // A caller may ask for a specific shelf — the idle prefetch of the other
    // storefront does. Without this the interceptor would stamp the current
    // shelf over it and the prefetch would fetch what we already have.
    options.headers['X-ZB-Shelf'] =
        (options.extra[_shelfOverride] as String?) ?? readShelf();
    options.headers['X-ZB-App'] = '${_platformName()}/${Env.appVersion}';
    options.headers['X-ZB-Slots'] = '${Env.layoutSlots}';

    // The server maps ids through Polylang from this parameter.
    options.queryParameters = {
      ...options.queryParameters,
      'lang': readLanguageCode(),
    };

    if (_cacheableRequest(options)) {
      // Computed once, here, and carried on the request. It used to be
      // recomputed when the response landed — and the readers it is built
      // from move while a request is in flight, so a body fetched on one
      // shelf could be filed under the key of whichever shelf the customer
      // had tapped by the time it arrived, then replayed as that storefront.
      final key = _cacheKey(options);
      options.extra[_cacheKeyStash] = key;
      final entry = _cacheEntry(key);
      if (entry != null) options.headers['If-None-Match'] = entry.$1;
    }

    handler.next(options);
  }

  void _onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    final key = options.extra[_cacheKeyStash] as String?;
    if (key == null) {
      handler.next(response);
      return;
    }

    if (response.statusCode == 304) {
      final entry = _cacheEntry(key);
      if (entry != null) {
        try {
          handler.next(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: jsonDecode(entry.$2),
            ),
          );
          return;
        } catch (_) {
          // Cache corrupted — fall through and let the caller retry warm.
        }
      }
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const ApiException(type: ApiErrorType.network),
        ),
        true,
      );
      return;
    }

    final etag = response.headers.value('etag');
    if (etag != null && etag.isNotEmpty && response.data != null) {
      try {
        final body = jsonEncode(response.data);
        _memCache[key] = (etag, body);
        // Fire-and-forget: a slow disk write must not delay the UI.
        unawaited(_store.putCached(key, etag, body));
      } catch (_) {}
    }

    handler.next(response);
  }

  void _onError(DioException e, ErrorInterceptorHandler handler) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      final hadToken = (readToken() ?? '').isNotEmpty;
      if (hadToken) onAuthRequired?.call();
    }
    handler.next(e);
  }

  (String, String)? _cacheEntry(String key) {
    final mem = _memCache[key];
    if (mem != null) return mem;
    final etag = _store.cachedEtag(key);
    final body = _store.cachedBody(key);
    if (etag == null || body == null) return null;
    final entry = (etag, body);
    _memCache[key] = entry;
    return entry;
  }

  /// The cache key includes the query (which already carries `lang`) *and*
  /// the delivery location, because stock, badges and promises are all
  /// location-scoped: the same URL means different things in two cities.
  String _cacheKey(RequestOptions options) {
    final query = options.queryParameters.entries
        .map((e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    final loc = readLocationHeaders();
    // The branch matters, not just the city: two express branches serve
    // different shelves inside one city, and their payloads must not share a
    // cache entry.
    // Both shelves: the one asked for and the one served. They differ after
    // closing time, and two different bodies must never share one entry.
    final asked = (options.extra[_shelfOverride] as String?) ?? readShelf();
    final scope = '${loc['X-ZB-City'] ?? ''}|${loc['X-ZB-Delivery-Type'] ?? ''}'
        '|${loc['X-ZB-Branch'] ?? ''}|$asked|${readEffectiveShelf()}';
    return '${options.path}?${query.join('&')}#$scope';
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  // ── Verbs (envelope-unwrapped) ───────────────────────────────────────

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Map<String, dynamic>? extra,
  }) =>
      _run(() => dio.get<dynamic>(
            path,
            queryParameters: query,
            cancelToken: cancelToken,
            options: extra == null ? null : Options(extra: extra),
          ));

  /// Reads a path as if the app were browsing [shelf], without letting the
  /// answer into the ETag store. Used to warm the other storefront so the tab
  /// paints from memory instead of a shimmer.
  Future<dynamic> getAsShelf(String path, String shelf) => get(
        path,
        extra: {_shelfOverride: shelf, _noCache: true},
      );

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _run(() => dio.post<dynamic>(path, data: body, queryParameters: query));

  Future<dynamic> patch(String path, {Object? body}) =>
      _run(() => dio.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path, {Object? body, Map<String, dynamic>? query}) =>
      _run(() => dio.delete<dynamic>(path, data: body, queryParameters: query));

  Future<dynamic> _run(Future<Response<dynamic>> Function() send) async {
    try {
      final res = await send();
      return Envelope.unwrap(res.data);
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Drops every cached catalog payload. Called when the delivery location
  /// changes — cached bodies describe another city's availability.
  Future<void> clearCache() async {
    _memCache.clear();
    await _store.clearHttpCache();
  }

  // ── Error mapping ────────────────────────────────────────────────────

  static ApiException mapError(Object e) {
    if (e is ApiException) return e;
    if (e is! DioException) return const ApiException(type: ApiErrorType.unknown);
    if (e.error is ApiException) return e.error! as ApiException;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(type: ApiErrorType.timeout);
      case DioExceptionType.connectionError:
        return const ApiException(type: ApiErrorType.network);
      case DioExceptionType.cancel:
        return const ApiException(type: ApiErrorType.cancelled);
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final data = e.response?.data;
        if (data is Map) {
          return Envelope.errorFrom(Map<String, dynamic>.from(data), status);
        }
        return ApiException(type: Envelope.typeForStatus(status, null), statusCode: status);
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        // Dio buckets socket failures under `unknown` on some platforms.
        return const ApiException(type: ApiErrorType.network);
    }
  }
}
