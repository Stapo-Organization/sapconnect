import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';

/// What the customer has agreed to hear about.
///
/// Four switches, because four is what the store can honestly distinguish. A
/// longer list is a list nobody reads, and one «كل شيء» switch is the one
/// people turn off in iOS Settings — where the delivery notifications go with
/// it, and those are the ones they actually wanted.
@immutable
class PushPreferences {
  const PushPreferences({
    this.orders = true,
    this.offers = true,
    this.reorder = true,
    this.family = true,
  });

  /// Where my order is. Transactional, and the reason the permission was
  /// granted in the first place.
  final bool orders;

  /// Price drops, clearance, the bundles the store put together.
  final bool offers;

  /// «قارب طعام لونا على الانتهاء» — the reorder rhythm.
  final bool reorder;

  /// عائلة زوبوكسي: a gift unlocked, a stamp card completed, a birthday.
  final bool family;

  static const PushPreferences all = PushPreferences();

  PushPreferences copyWith({bool? orders, bool? offers, bool? reorder, bool? family}) =>
      PushPreferences(
        orders: orders ?? this.orders,
        offers: offers ?? this.offers,
        reorder: reorder ?? this.reorder,
        family: family ?? this.family,
      );

  factory PushPreferences.fromJson(Map<String, dynamic> json) => PushPreferences(
        orders: asBool(json['orders'], fallback: true),
        offers: asBool(json['offers'], fallback: true),
        reorder: asBool(json['reorder'], fallback: true),
        family: asBool(json['family'], fallback: true),
      );

  Map<String, dynamic> toJson() => {
        'orders': orders,
        'offers': offers,
        'reorder': reorder,
        'family': family,
      };

  /// True when nothing is left on — the screen says so plainly rather than
  /// leaving four dead switches looking like a setting that failed to save.
  bool get isSilent => !orders && !offers && !reorder && !family;
}

class PushRepository {
  PushRepository(this._api);

  final ApiClient _api;

  /// The order is on the lock screen. The store keeps the activity's push
  /// token beside the device's own, so it can move the courier along after
  /// the app has been closed.
  Future<void> registerLiveActivity({
    required int orderId,
    required String activityToken,
    required String deviceToken,
  }) async {
    await _api.post('/push/live-activity', body: {
      'order_id': orderId,
      'activity_token': activityToken,
      'device_token': deviceToken,
    });
  }

  Future<void> endLiveActivity({required int orderId}) async {
    await _api.post('/push/live-activity/end', body: {'order_id': orderId});
  }

  /// Tells the store which device is holding this token, and gets back what
  /// this customer already asked to hear about.
  Future<PushPreferences> register({
    required String token,
    required String platform,
    required String appVersion,
    required String locale,
  }) async {
    final data = asMap(await _api.post('/push/register', body: {
      'token': token,
      'platform': platform,
      'app_version': appVersion,
      'locale': locale,
    }));
    return PushPreferences.fromJson(asMap(data['preferences']));
  }

  Future<void> unregister(String token) async {
    await _api.post('/push/unregister', body: {'token': token});
  }

  /// A notification was tapped. [msg] is the store's id for it, carried in
  /// the payload; the store marks it opened and counts it.
  Future<void> opened(int msg) async {
    await _api.post('/push/opened', body: {'msg': msg});
  }

  Future<PushPreferences> preferences({String? token}) async {
    final data = asMap(await _api.get(
      '/push/preferences',
      query: token == null ? null : {'token': token},
    ));
    return PushPreferences.fromJson(asMap(data['preferences']));
  }

  Future<PushPreferences> save(PushPreferences preferences) async {
    final data = asMap(await _api.post(
      '/push/preferences',
      body: {'preferences': preferences.toJson()},
    ));
    return PushPreferences.fromJson(asMap(data['preferences']));
  }
}

final pushRepositoryProvider =
    Provider<PushRepository>((ref) => PushRepository(ref.watch(apiClientProvider)));
