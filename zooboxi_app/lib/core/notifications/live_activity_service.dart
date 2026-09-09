import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/activity_update.dart';
import 'package:live_activities/models/url_scheme_data.dart';

import '../../app/router.dart';
import '../../features/notifications/data/push_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../features/orders/data/live_tracking.dart';
import '../../features/orders/data/orders_repository.dart';
import 'push_service.dart';

/// The order on the lock screen and in the Dynamic Island.
///
/// A customer who has ordered puts the phone down. From that moment the app is
/// closed and the courier is invisible — unless the order lives where the eye
/// falls without unlocking anything. iOS Live Activities are exactly that
/// surface, and delivery apps report two to three times the engagement of a
/// push notification for it.
///
/// This service watches the same feed the live bar does and mirrors it: start
/// an activity when an express order is being prepared, update it on every
/// tick while the app is open, and hand the store the activity's push token so
/// it can keep the lock screen moving after the app is gone. The activity ends
/// with the order — delivered or not.
///
/// Everything is guarded: no Live Activity support (Android, old iOS, the
/// setting switched off) means this class does nothing and says nothing.
class LiveActivityService {
  LiveActivityService(this._ref);

  final Ref _ref;
  final LiveActivities _plugin = LiveActivities();

  static const String appGroupId = 'group.com.zooboxi.app';
  static const String urlScheme = 'zooboxi';

  bool _ready = false;
  bool _supported = false;

  /// The one activity we keep — for the one order the bar is about.
  String? _activityId;
  int? _orderId;
  String? _lastSignature;

  /// An activity token that arrived before the device had its FCM token; it
  /// is handed to the store on the next tick that has both.
  String? _pendingActivityToken;

  /// Every mirror runs after the previous one has finished. Two feed events
  /// in flight would otherwise race `createActivity` and leave an orphan card
  /// on the lock screen that nothing can end.
  Future<void> _chain = Future<void>.value();

  StreamSubscription<ActivityUpdate>? _updates;
  StreamSubscription<UrlSchemeData>? _taps;
  ProviderSubscription<AsyncValue<ActiveOrder?>>? _feed;

  Future<void> start() async {
    if (_ready || !Platform.isIOS) return;
    try {
      await _plugin.init(appGroupId: appGroupId, urlScheme: urlScheme);
      _supported = await _plugin.areActivitiesSupported() && await _plugin.areActivitiesEnabled();
      _ready = true;
    } catch (error) {
      if (kDebugMode) debugPrint('[live-activity] unavailable: $error');
      return;
    }
    if (!_supported) return;

    // The activity's push token arrives here — once at start and again when
    // iOS rotates it. The store needs the latest, always.
    _updates = _plugin.activityUpdateStream.listen((update) {
      update.mapOrNull(
        active: (a) => unawaited(_register(a.activityToken)),
        ended: (_) => _forget(),
        stale: (_) {},
        unknown: (_) {},
      );
    });

    // A tap on the lock screen or the Island lands on the order it is about.
    // Cold start: the router is not up yet, so the route waits where the push
    // service parks its own (splash reads it once home is on screen).
    _taps = _plugin.urlSchemeStream().listen((data) {
      final path = data.path;
      if (path == null || !path.startsWith('/')) return;
      final router = _ref.read(routerProvider);
      final here = router.routerDelegate.currentConfiguration.uri.path;
      if (here == '/splash' || here == '/') {
        _ref.read(pushServiceProvider).pendingRoute = path;
      } else {
        router.push(path);
      }
    });

    // Follow the feed the bar already polls: no second poller.
    _feed = _ref.listen<AsyncValue<ActiveOrder?>>(activeOrderProvider, (_, next) {
      final active = next.value;
      _chain = _chain.then((_) => active == null ? _endIfAny() : _mirror(active));
    }, fireImmediately: true);
  }

  /// Start or update the activity so it says what the feed says.
  Future<void> _mirror(ActiveOrder active) async {
    if (!_supported) return;

    // A token that could not be registered earlier (no FCM token yet) goes
    // out as soon as the device has one.
    final pending = _pendingActivityToken;
    if (pending != null && _ref.read(pushServiceProvider).token != null) {
      await _register(pending);
    }

    // Nothing to put on a lock screen for an order that is already over.
    if (_activityId == null && !active.isLive) return;

    final state = _stateFor(active);
    final signature = state.values.join('|');

    try {
      if (_activityId == null || _orderId != active.order.id) {
        // A different order than the one on the lock screen: end the old one
        // first, so two cards never fight for the Island.
        await _endIfAny();
        _orderId = active.order.id;
        _activityId = await _plugin.createActivity(
          'order-${active.order.id}',
          state,
          removeWhenAppIsKilled: false,
        );
        _lastSignature = signature;
        return;
      }
      if (signature == _lastSignature) return;
      await _plugin.updateActivity(_activityId!, state);
      _lastSignature = signature;
    } catch (error) {
      if (kDebugMode) debugPrint('[live-activity] mirror failed: $error');
    }

    // Once the order is over the lock screen keeps its final frame briefly,
    // then lets go.
    if (!active.isLive) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await _endIfAny();
    }
  }

  Future<void> _endIfAny() async {
    final id = _activityId;
    if (id == null) return;
    try {
      await _plugin.endActivity(id);
    } catch (_) {
      // Already gone is fine.
    }
    final orderId = _orderId;
    _forget();
    if (orderId != null) {
      try {
        await _ref.read(pushRepositoryProvider).endLiveActivity(orderId: orderId);
      } catch (_) {
        // The store prunes the token on its own when the order completes.
      }
    }
  }

  void _forget() {
    _activityId = null;
    _orderId = null;
    _lastSignature = null;
    _pendingActivityToken = null;
  }

  /// Hand the store the two tokens it needs to keep this moving from afar:
  /// the activity's own, and the device's FCM token to address it through.
  Future<void> _register(String activityToken) async {
    final orderId = _orderId;
    if (orderId == null || activityToken.isEmpty) return;
    final device = _ref.read(pushServiceProvider).token;
    if (device == null) {
      // The activity token usually arrives at splash time, before FCM has
      // answered. Keep it; the next mirror tick with a device token sends it.
      _pendingActivityToken = activityToken;
      return;
    }
    try {
      await _ref.read(pushRepositoryProvider).registerLiveActivity(
            orderId: orderId,
            activityToken: activityToken,
            deviceToken: device,
          );
      _pendingActivityToken = null;
    } catch (error) {
      _pendingActivityToken = activityToken;
      if (kDebugMode) debugPrint('[live-activity] register failed: $error');
    }
  }

  /// The keys the widget extension reads. They mirror the Swift `ContentState`
  /// AND the store's push payload field for field — three places, one shape.
  Map<String, dynamic> _stateFor(ActiveOrder active) {
    final t = active.tracking;
    final phase = t?.phase.name ?? (active.order.status == 'zb-ready' ? 'ready' : 'preparing');

    return {
      'phase': switch (t?.phase) {
        LivePhase.inTransit => 'in_transit',
        LivePhase.searching => 'searching',
        LivePhase.assigned => 'assigned',
        LivePhase.delivered => 'delivered',
        LivePhase.failed => 'failed',
        null => phase,
      },
      'headline': t?.statusLabel ?? _fallbackHeadline(active, ar: true),
      'headlineEn': _fallbackHeadline(active, ar: false),
      'courier': t?.courier.name ?? '',
      'progress': _progress(active),
      'etaMinutes': t?.etaMinutes ?? 0,
      'updatedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'orderNumber': active.order.number,
      'route': '/orders/${active.order.id}',
    };
  }

  /// No BuildContext out here, so the sentence is looked up by locale — the
  /// same keys the live bar uses, never a literal in Dart.
  static String _fallbackHeadline(ActiveOrder active, {required bool ar}) {
    final l = lookupL(Locale(ar ? 'ar' : 'en'));
    return active.order.status == 'zb-ready' ? l.liveBarReady : l.liveBarPreparing;
  }

  static double _progress(ActiveOrder active) => switch (active.tracking?.phase) {
        LivePhase.searching => 0.4,
        LivePhase.assigned => 0.6,
        LivePhase.inTransit => 0.85,
        LivePhase.delivered => 1,
        LivePhase.failed => 1,
        null => active.order.status == 'zb-ready' ? 0.3 : 0.15,
      };

  void dispose() {
    unawaited(_updates?.cancel());
    unawaited(_taps?.cancel());
    _feed?.close();
  }
}

final liveActivityServiceProvider = Provider<LiveActivityService>((ref) {
  final service = LiveActivityService(ref);
  ref.onDispose(service.dispose);
  return service;
});
