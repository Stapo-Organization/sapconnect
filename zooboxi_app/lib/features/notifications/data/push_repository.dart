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

/// One notification the store has already sent — as it sits in the inbox.
///
/// The inbox is the honest half of push: the store caps how many alerts a
/// customer may receive in a day, and everything above that cap is written
/// here **without** a banner. So this list is never a copy of what the phone
/// showed — it is the full record, and [quiet] marks the entries the phone
/// deliberately never rang for.
@immutable
class InboxItem {
  const InboxItem({
    required this.id,
    required this.title,
    this.body = '',
    this.topic = '',
    this.tier = '',
    this.source = '',
    this.route,
    this.image,
    this.quiet = false,
    this.at,
    this.read = false,
  });

  final int id;
  final String title;
  final String body;

  /// Which of the four switches this belongs to — `orders`, `offers`,
  /// `reorder`, `family`. Shown as a chip, so the customer can tell at a
  /// glance which tap in the settings screen would stop it.
  final String topic;

  /// The store's own priority band. Kept because the payload carries it and
  /// dropping a field on parse is how a later feature discovers it was never
  /// there; nothing on this screen reads it yet.
  final String tier;

  /// What produced it — a campaign, the reorder rhythm, an order event.
  final String source;

  /// Where a tap goes. Only in-app paths are followed; anything else is
  /// ignored rather than handed to a browser.
  final String? route;
  final String? image;

  /// Written to the inbox with no push behind it, because the daily cap was
  /// already spent. The screen says so instead of letting the customer think
  /// their phone swallowed it.
  final bool quiet;
  final DateTime? at;
  final bool read;

  /// Whether a tap has anywhere to go.
  bool get hasRoute => (route ?? '').startsWith('/');

  InboxItem copyWith({bool? read}) => InboxItem(
        id: id,
        title: title,
        body: body,
        topic: topic,
        tier: tier,
        source: source,
        route: route,
        image: image,
        quiet: quiet,
        at: at,
        read: read ?? this.read,
      );

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: asInt(json['id']),
        title: asString(json['title']),
        body: asString(json['body']),
        topic: asString(json['topic']),
        tier: asString(json['tier']),
        source: asString(json['source']),
        route: asStringOrNull(json['route']),
        image: asStringOrNull(json['image']),
        quiet: asBool(json['quiet']),
        at: asDate(json['at']),
        read: asBool(json['read']),
      );
}

/// The inbox as one read: the page itself plus the badge number, which the
/// store counts rather than the app inferring it from a truncated page.
typedef InboxPage = ({List<InboxItem> items, int unread});

/// What this customer is waiting to hear about one product. Both flags travel
/// together because the store answers with both after every change.
typedef WaitlistState = ({bool restock, bool price});

WaitlistState _waitlistFrom(Map<String, dynamic> json) =>
    (restock: asBool(json['restock']), price: asBool(json['price']));

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

  /// Everything the store has sent this customer, newest first.
  ///
  /// Works for a guest too: the store keys the inbox by the guest id the app
  /// already carries, so a customer who has not signed in still sees the
  /// order they placed as a guest move along.
  Future<InboxPage> inbox({int limit = 30}) async {
    final data = asMap(await _api.get('/push/inbox', query: {'limit': limit}));
    return (
      items: asMapList(data['items']).map(InboxItem.fromJson).toList(),
      unread: asInt(data['unread']),
    );
  }

  /// Marks entries read. An empty list means *all of them* — that is the
  /// store's contract, and the «قرأت الكل» action relies on it rather than
  /// sending back a page's worth of ids.
  Future<int> markRead(List<int> ids) async {
    final data = asMap(await _api.post('/push/inbox/read', body: {'ids': ids}));
    return asInt(data['read']);
  }

  /// What this customer already asked to be told about [productId].
  Future<WaitlistState> waitlist(int productId) async => _waitlistFrom(
        asMap(await _api.get('/push/waitlist', query: {'product_id': productId})),
      );

  /// «نبّهني عند التوفر» — [kind] is `restock` or `price`.
  Future<WaitlistState> watch({required int productId, required String kind}) async =>
      _waitlistFrom(asMap(await _api.post(
        '/push/waitlist',
        body: {'product_id': productId, 'kind': kind},
      )));

  /// Drops one kind of watch, or every kind when [kind] is empty.
  Future<WaitlistState> unwatch({required int productId, String kind = ''}) async =>
      _waitlistFrom(asMap(await _api.post(
        '/push/waitlist/remove',
        body: {'product_id': productId, 'kind': kind},
      )));
}

final pushRepositoryProvider =
    Provider<PushRepository>((ref) => PushRepository(ref.watch(apiClientProvider)));

/// The inbox, re-read whenever a screen that shows it comes into view.
///
/// autoDispose on purpose: both readers — the inbox screen and the unread
/// count on «حسابي» — want a fresh number when they open, and neither wants
/// to hold a stale one for the life of the app.
final inboxProvider = FutureProvider.autoDispose<InboxPage>(
  (ref) => ref.watch(pushRepositoryProvider).inbox(),
);
