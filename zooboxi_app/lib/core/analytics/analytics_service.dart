import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'events_buffer.dart';

/// Names of the funnel every ad platform is optimised against.
///
/// These are the *marketing* names — the same spelling the store sends to the
/// Meta / TikTok / Snap conversion APIs and the MMP, so a "first order" on a
/// campaign dashboard is the same fact as a "first order" here. GA4 reserved
/// names (`purchase`, `add_to_cart`, …) are used where one exists so Google
/// App campaigns can bid on them without any mapping.
abstract final class FunnelEvents {
  static const signupComplete = 'signup_complete';
  static const login = 'login';
  static const petAdded = 'pet_added';
  static const expressAvailable = 'express_available';
  static const addToCart = 'add_to_cart';
  static const beginCheckout = 'begin_checkout';
  static const purchase = 'purchase';
  static const firstOrderPaid = 'first_order_paid';
  static const secondOrderPaid = 'second_order_paid';
  static const subscriptionStart = 'subscription_start';
  static const referralSent = 'referral_sent';
  static const share = 'share';
  static const search = 'search';
  static const viewItem = 'view_item';
}

/// Firebase Analytics, folded away when Firebase is not configured.
///
/// Every call is fire-and-forget and swallows its own errors: measurement is
/// never allowed to slow a screen down or fail one. The in-house
/// [EventsBuffer] stays the source of truth for the store; this is the mirror
/// the ad platforms read.
class AnalyticsService {
  AnalyticsService();

  FirebaseAnalytics? _fa;
  bool _attAsked = false;

  bool get available => _fa != null;

  /// Binds to the default Firebase app if one was initialised at launch.
  void start() {
    if (_fa != null) return;
    try {
      if (Firebase.apps.isEmpty) return;
      _fa = FirebaseAnalytics.instance;
      unawaited(_fa!.setAnalyticsCollectionEnabled(true));
    } catch (error) {
      if (kDebugMode) debugPrint('[analytics] not configured: $error');
      _fa = null;
    }
  }

  /// Whether iOS has yet to hear the customer's answer about the ad
  /// identifier — the only time a primer before the system sheet makes sense.
  Future<bool> trackingUndecided() async {
    if (_attAsked || kIsWeb || !Platform.isIOS) return false;
    try {
      return await AppTrackingTransparency.trackingAuthorizationStatus ==
          TrackingStatus.notDetermined;
    } catch (_) {
      return false;
    }
  }

  /// Asks iOS for the ad identifier, once, and only when the OS has not
  /// already recorded an answer. Android and the web have nothing to ask.
  ///
  /// Called from the tracking primer after the customer's first add to the
  /// basket — never cold on the first home frame, where the system sheet
  /// arrived before the customer had seen a single product.
  Future<void> requestTrackingAuthorization() async {
    if (_attAsked || kIsWeb || !Platform.isIOS) return;
    _attAsked = true;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      // A frame of breathing room: iOS refuses the request while a
      // transition is still running.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (error) {
      if (kDebugMode) debugPrint('[analytics] ATT: $error');
    }
  }

  // ── Identity ────────────────────────────────────────────────────────

  /// The store customer id, or null on sign-out. Never a phone or an email.
  void setUser(int? id) {
    _guard(() => _fa!.setUserId(id: id?.toString()));
  }

  void setUserProperty(String name, String? value) {
    _guard(() => _fa!.setUserProperty(name: name, value: value));
  }

  // ── Events ──────────────────────────────────────────────────────────

  void log(String name, [Map<String, Object>? parameters]) {
    _guard(() => _fa!.logEvent(name: name, parameters: parameters));
  }

  void logSignup(int userId, {required bool isNew}) {
    setUser(userId);
    log(isNew ? FunnelEvents.signupComplete : FunnelEvents.login,
        {'method': 'otp'});
  }

  /// The store told us whether إكسبريس serves this address right now. Kept as
  /// a user property too, so the audiences "in zone, no order yet" and
  /// "out of zone" can be built in the ad platforms without a warehouse join.
  void logExpressAvailable({required bool inZone, String? branch}) {
    setUserProperty('in_express_zone', inZone ? 'yes' : 'no');
    log(FunnelEvents.expressAvailable, {
      'in_zone': inZone ? 'true' : 'false',
      'branch': ?branch,
    });
  }

  /// The paid-order ladder. [ordersCount] is the customer's lifetime count
  /// *including* this order, as the store reports it; null means unknown and
  /// only the plain purchase is logged.
  void logPurchase({
    required int orderId,
    required double total,
    int? ordersCount,
    bool express = false,
  }) {
    final params = <String, Object>{
      'transaction_id': orderId.toString(),
      'value': total,
      'currency': 'SAR',
      'shelf': express ? 'express' : 'store',
    };
    log(FunnelEvents.purchase, params);
    if (ordersCount == 1) log(FunnelEvents.firstOrderPaid, params);
    if (ordersCount == 2) log(FunnelEvents.secondOrderPaid, params);
  }

  /// Mirrors an in-house signal under its marketing name. Signals with no
  /// marketing meaning (impressions, card views, weight logs) are skipped so
  /// the GA4 event list stays a funnel, not a firehose.
  void mirror(ZbEvent event) {
    switch (event.type) {
      case ZbEvents.view:
        log(FunnelEvents.viewItem, {
          if (event.itemCode != null) 'item_id': event.itemCode!,
        });
      case ZbEvents.search:
        log(FunnelEvents.search, {
          if (event.query != null) 'search_term': event.query!,
        });
      case ZbEvents.addToCart:
        log(FunnelEvents.addToCart, {
          if (event.itemCode != null) 'item_id': event.itemCode!,
          'currency': 'SAR',
        });
      case ZbEvents.beginCheckout:
        log(FunnelEvents.beginCheckout, {'currency': 'SAR'});
      case ZbEvents.petAdded:
        final species = event.payload?['species'];
        if (species is String) setUserProperty('pet_species', species);
        log(FunnelEvents.petAdded, {
          if (species is String) 'species': species,
        });
      case ZbEvents.referralShare:
        log(FunnelEvents.referralSent);
        log(FunnelEvents.share, {'content_type': 'referral'});
      case ZbEvents.supplyAction:
        if (event.payload?['action'] == 'subscribe') {
          log(FunnelEvents.subscriptionStart, {'source': 'supply'});
        }
      case ZbEvents.subscription:
        final action = event.payload?['action'];
        if (action is String) log('subscription_$action');
      case ZbEvents.loyaltyScratch:
      case ZbEvents.loyaltyRedeem:
      case ZbEvents.loyaltyClaim:
      case ZbEvents.loyaltyMission:
        log(event.type);
      default:
        // purchase is logged with its order ladder from the success screen;
        // everything else is store-only.
        break;
    }
  }

  void _guard(Future<void> Function() call) {
    final fa = _fa;
    if (fa == null) return;
    unawaited(call().catchError((Object error) {
      if (kDebugMode) debugPrint('[analytics] $error');
    }));
  }
}

final analyticsProvider = Provider<AnalyticsService>((ref) {
  final service = AnalyticsService()..start();
  return service;
});

extension AnalyticsRefX on Ref {
  AnalyticsService get analytics => read(analyticsProvider);
}

extension AnalyticsWidgetRefX on WidgetRef {
  AnalyticsService get analytics => read(analyticsProvider);
}
