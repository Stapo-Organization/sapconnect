import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../features/notifications/data/push_repository.dart';
import '../config/env.dart';
import '../providers.dart';
import '../session/session_controller.dart';
import 'notify_permission.dart';

/// Push, and the one rule it lives by: **the app must be perfect without it.**
///
/// Firebase is configured by a file that ships with the build
/// (`GoogleService-Info.plist`). A build made before that file exists — every
/// build until the project is created — must still launch, sell, and deliver.
/// So every entry point here is wrapped: no configuration means [available]
/// stays false, the settings screen says why in one line, and nothing throws.
///
/// The permission itself is never asked for here. Onboarding asks once, at the
/// moment it can explain what the notifications are for; this class only ever
/// works with an answer that already exists.
class PushService {
  PushService(this._ref);

  final Ref _ref;

  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _opened;
  String? _token;

  /// Whether Firebase answered at all. False on a build with no plist, on a
  /// simulator with no APNs, and anywhere the initialisation failed — all of
  /// which mean the same thing to a caller: there is no push here.
  bool get available => _messaging != null;

  String? get token => _token;

  /// Where a tapped notification wants to go, once the app is alive enough to
  /// route. Held rather than acted on: a cold start from a notification
  /// arrives long before the router exists.
  String? pendingRoute;

  /// Brings push up if the build carries a Firebase configuration.
  ///
  /// Safe to call more than once and safe to call before sign-in: a token
  /// registered as a guest is re-registered against the account the moment
  /// [refreshRegistration] is told the session changed.
  Future<void> start() async {
    if (_messaging != null) return;
    try {
      await Firebase.initializeApp();
    } catch (error) {
      // No plist, or a malformed one. This is the ordinary state before the
      // Firebase project exists, not a fault worth surfacing.
      if (kDebugMode) debugPrint('[push] Firebase not configured: $error');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      // iOS shows nothing in the foreground unless asked. An order that just
      // went out for delivery deserves the banner even while the customer is
      // looking at the app.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // A notification that opened the app, and one tapped while it was warm.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _onTapped(initial, cold: true);
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _onTapped(message, cold: false),
      );

      _tokenRefresh = messaging.onTokenRefresh.listen((token) {
        _token = token;
        unawaited(_sendToStore(token));
      });

      await refreshRegistration();
    } catch (error) {
      if (kDebugMode) debugPrint('[push] start failed: $error');
      _messaging = null;
    }
  }

  /// Re-registers the current token — after sign-in, after sign-out, and after
  /// the customer grants the permission from the settings screen.
  ///
  /// Silent when the OS permission is not granted: a token minted without it
  /// is a device the store would count and never reach.
  Future<void> refreshRegistration() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      if (await NotifyPermission.status() != 'granted') return;

      // On iOS the FCM token only exists once APNs has handed over its own.
      if (Platform.isIOS && await messaging.getAPNSToken() == null) return;

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      _token = token;
      await _sendToStore(token);
    } catch (error) {
      if (kDebugMode) debugPrint('[push] registration failed: $error');
    }
  }

  /// Drops this device from the store's registry — sign-out, or the customer
  /// switching everything off. The token itself is kept: the same install will
  /// re-register the moment they change their mind.
  Future<void> unregister() async {
    final token = _token;
    if (token == null) return;
    try {
      await _ref.read(pushRepositoryProvider).unregister(token);
    } catch (_) {
      // A device the store failed to forget is not the customer's problem;
      // the next send will prune it.
    }
  }

  Future<void> _sendToStore(String token) async {
    try {
      await _ref.read(pushRepositoryProvider).register(
            token: token,
            platform: Platform.isIOS ? 'ios' : 'android',
            appVersion: Env.appVersion,
            locale: _ref.read(localStoreProvider).localeCode ?? 'ar',
          );
    } catch (error) {
      if (kDebugMode) debugPrint('[push] store registration failed: $error');
    }
  }

  /// A notification was tapped.
  ///
  /// Two things happen, in this order: the store is told (so the tap counts
  /// in the notification's own numbers — the only measure of whether it was
  /// worth sending), and the app goes where the notification pointed. On a
  /// cold start the router does not exist yet, so the route waits for the
  /// splash; while the app is warm it is pushed right away — a tap that
  /// merely brought the app forward, onto whatever screen it was on, was the
  /// bug this replaces.
  void _onTapped(RemoteMessage message, {required bool cold}) {
    final msg = int.tryParse('${message.data['msg'] ?? ''}');
    if (msg != null && msg > 0) {
      unawaited(_reportOpened(msg));
    }
    final route = _routeOf(message);
    if (route == null) return;

    if (cold) {
      pendingRoute = route;
      return;
    }
    try {
      final router = _ref.read(routerProvider);
      final here = router.routerDelegate.currentConfiguration.uri.path;
      // Still booting, or inside the welcome journey: the screen that ends
      // those reads pendingRoute and pushes it.
      if (here == '/splash' || here == '/' || here.startsWith('/onboarding')) {
        pendingRoute = route;
      } else {
        router.push(route);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[push] route failed: $error');
      pendingRoute = route;
    }
  }

  Future<void> _reportOpened(int msg) async {
    try {
      await _ref.read(pushRepositoryProvider).opened(msg);
    } catch (_) {
      // A tap the store did not hear about is a number, not a broken screen.
    }
  }

  /// The deep link the store put in the payload — «/orders/32579».
  static String? _routeOf(RemoteMessage message) {
    final route = message.data['route'];
    return route is String && route.startsWith('/') ? route : null;
  }

  void dispose() {
    unawaited(_tokenRefresh?.cancel());
    unawaited(_opened?.cancel());
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(service.dispose);

  // The token belongs to whoever is signed in. Crossing that line — in either
  // direction — has to reach the store, or a customer keeps getting the last
  // customer's order updates on a shared phone.
  ref.listen<bool>(
    sessionProvider.select((s) => s.isAuthenticated),
    (_, _) => unawaited(service.refreshRegistration()),
  );

  return service;
});
