import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// One behavioural signal. Never carries PII — the server already knows who is
/// calling from the bearer token or the guest header.
@immutable
class ZbEvent {
  const ZbEvent({
    required this.type,
    this.itemCode,
    this.query,
    this.zone,
    this.campaignId,
    this.abVariant,
    this.payload,
  });

  final String type;
  final String? itemCode;
  final String? query;
  final String? zone;
  final String? campaignId;
  final String? abVariant;
  final Map<String, dynamic>? payload;

  Map<String, dynamic> toJson() => {
        'event_type': type,
        'item_code': ?itemCode,
        'query': ?query,
        'zone': ?zone,
        'campaign_id': ?campaignId,
        'ab_variant': ?abVariant,
        'payload': ?payload,
      };
}

/// Well-known event names, kept in one place so a typo can't quietly create a
/// second bucket in the warehouse.
abstract final class ZbEvents {
  static const view = 'view';
  static const search = 'search';
  static const addToCart = 'add_to_cart';
  static const beginCheckout = 'begin_checkout';
  static const purchase = 'purchase';
  // The wire value is 'click' — the only spelling the store plugin's
  // EVENT_TYPES allowlist and the warehouse validator accept.
  static const campaignClick = 'click';

  /// A creative that was actually ≥50% on screen. Paired with
  /// [campaignClick] it is what makes a click-through rate mean anything.
  static const impression = 'impression';
}

/// Batches signals and posts them in the background.
///
/// Analytics must never be able to slow a screen down or fail one: sends are
/// fire-and-forget, a failed flush puts the batch back, and the queue is
/// persisted so a cold kill doesn't lose the session's behaviour.
class EventsBuffer {
  EventsBuffer(this._ref) {
    _queue.addAll(_ref.read(localStoreProvider).pendingEvents);
    if (_queue.isNotEmpty) unawaited(flush());
  }

  static const int _batchSize = 20;
  static const Duration _interval = Duration(seconds: 30);

  final Ref _ref;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;
  bool _sending = false;

  void track(ZbEvent event) {
    _queue.add(event.toJson());
    unawaited(_ref.read(localStoreProvider).setPendingEvents(_queue));

    if (_queue.length >= _batchSize) {
      unawaited(flush());
      return;
    }
    _timer ??= Timer(_interval, () => unawaited(flush()));
  }

  /// Sends everything queued. Called on the size/time thresholds and whenever
  /// the app goes to the background.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_sending || _queue.isEmpty) return;

    _sending = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      await _ref.read(apiClientProvider).post('/events', body: {'events': batch});
      await _ref.read(localStoreProvider).setPendingEvents(_queue);
    } catch (_) {
      // Offline or rejected: keep the batch for the next attempt, newest last.
      _queue.insertAll(0, batch);
      await _ref.read(localStoreProvider).setPendingEvents(_queue);
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

final eventsBufferProvider = Provider<EventsBuffer>((ref) {
  final buffer = EventsBuffer(ref);
  ref.onDispose(buffer.dispose);
  return buffer;
});

/// Terse call site: `ref.track(ZbEvent(type: ZbEvents.view, itemCode: …))`.
extension EventsRefX on Ref {
  void track(ZbEvent event) => read(eventsBufferProvider).track(event);
}

extension EventsWidgetRefX on WidgetRef {
  void track(ZbEvent event) => read(eventsBufferProvider).track(event);
}
