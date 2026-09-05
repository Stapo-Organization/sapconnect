import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';
import '../../catalog/data/product_models.dart';
import '../../pets/data/pet_models.dart';

/// A reference to an order, as the loyalty endpoints hand it back: enough to
/// name it on a card and to navigate to it, nothing more.
@immutable
class LoyaltyOrderRef {
  const LoyaltyOrderRef({required this.id, required this.number});

  final int id;
  final String number;

  static LoyaltyOrderRef? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    final id = asInt(map['id']);
    final number = asString(map['number'], fallback: id > 0 ? '$id' : '');
    if (id <= 0 && number.isEmpty) return null;
    return LoyaltyOrderRef(id: id, number: number);
  }
}

/// Membership facts. [holdout] is the one that changes what the app draws:
/// a control-group member keeps paws and tiers but is shown no scratch card
/// and no missions, so the experiment stays clean.
@immutable
class LoyaltyMember {
  const LoyaltyMember({this.joinedAt, this.holdout = false, this.referralCode});

  final DateTime? joinedAt;
  final bool holdout;
  final String? referralCode;

  factory LoyaltyMember.fromJson(Map<String, dynamic> json) => LoyaltyMember(
        joinedAt: asDate(json['joined_at']),
        holdout: asBool(json['holdout']),
        referralCode: asStringOrNull(json['referral_code']),
      );
}

/// The wallet. [pending] is what revealed scratch cards are worth on orders
/// that have not been delivered yet — real, but not yours until it lands.
@immutable
class PawsBalance {
  const PawsBalance({this.balance = 0, this.pending = 0, this.expiresAt});

  final int balance;
  final int pending;
  final DateTime? expiresAt;

  factory PawsBalance.fromJson(Map<String, dynamic> json) => PawsBalance(
        balance: asInt(json['balance']),
        pending: asInt(json['pending']),
        expiresAt: asDate(json['expires_at']),
      );
}

/// One tier benefit, with whether this customer has it yet.
@immutable
class TierPerk {
  const TierPerk({
    required this.key,
    required this.text,
    this.active = false,
    this.fromTier,
    this.fromTierName,
  });

  final String key;
  final String text;
  final bool active;

  /// The tier that unlocks it, for a perk that is still ahead.
  final String? fromTier;

  /// That tier's display name in the request's language, when the server
  /// sends one; the app resolves the key itself otherwise.
  final String? fromTierName;

  factory TierPerk.fromJson(Map<String, dynamic> json) => TierPerk(
        key: asString(json['key']),
        text: asString(json['text']),
        active: asBool(json['active']),
        fromTier: asStringOrNull(json['from_tier']),
        fromTierName: asStringOrNull(json['from_tier_name']),
      );
}

/// The next rung: its name and how many delivered orders are still missing.
@immutable
class NextTier {
  const NextTier({required this.key, required this.name, this.min = 0, this.ordersNeeded = 0});

  final String key;
  final String name;
  final int min;
  final int ordersNeeded;

  static NextTier? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    final key = asString(map['key']);
    if (key.isEmpty) return null;
    return NextTier(
      key: key,
      name: asString(map['name'], fallback: key),
      min: asInt(map['min']),
      ordersNeeded: asInt(map['orders_needed']),
    );
  }
}

/// Standing: which tier, how far into it, and what it buys.
///
/// The tier's own colours arrive from the store (`c1`/`c2`) because the web
/// account page already paints them — the app parses them but always keeps a
/// brand fallback, so one typo'd hex can't produce an off-brand card.
@immutable
class TierInfo {
  const TierInfo({
    this.key = 'new',
    this.name = '',
    this.nameEn = '',
    this.icon,
    this.c1,
    this.c2,
    this.orders12m = 0,
    this.min = 0,
    this.next,
    this.serverProgress,
    this.perks = const [],
    this.atRisk,
  });

  final String key;
  final String name;
  final String nameEn;
  final String? icon;
  final String? c1;
  final String? c2;

  /// Delivered orders in the trailing 12 months — the only tier measure.
  final int orders12m;

  /// The floor of the current tier.
  final int min;
  final NextTier? next;

  /// The server's own 0..100 reading. Kept as a fallback rather than as the
  /// source: the bar is drawn from the order counts, which are exact.
  final int? serverProgress;

  final List<TierPerk> perks;

  /// «طلب واحد يحفظ مستواك» — set when an order is about to leave the
  /// 12-month window and take the tier down with it.
  final TierRisk? atRisk;

  static const TierInfo empty = TierInfo();

  /// 0..1 for the progress bar.
  ///
  /// Computed from the counts whenever they are coherent — `(orders − min) /
  /// (next.min − min)` — because a rounded server percentage and a printed
  /// "3 orders to go" that disagree is the kind of small lie a loyalty screen
  /// cannot afford. The server's value is the fallback, and the top tier is
  /// simply full.
  double get progress {
    final target = next;
    if (target == null) return 1;
    final span = target.min - min;
    if (span > 0) return ((orders12m - min) / span).clamp(0.0, 1.0);
    final fallback = serverProgress;
    return fallback == null ? 0 : (fallback / 100).clamp(0.0, 1.0);
  }

  /// Delivered orders still needed for the next tier, never negative.
  int get ordersToNext {
    final target = next;
    if (target == null) return 0;
    final stated = target.ordersNeeded;
    if (stated > 0) return stated;
    final derived = target.min - orders12m;
    return derived > 0 ? derived : 0;
  }

  bool get isTop => next == null;

  factory TierInfo.fromJson(Map<String, dynamic> json) => TierInfo(
        key: asString(json['key'], fallback: 'new'),
        name: asString(json['name']),
        nameEn: asString(json['name_en']),
        icon: asStringOrNull(json['icon']),
        c1: asStringOrNull(json['c1']),
        c2: asStringOrNull(json['c2']),
        orders12m: asInt(json['orders_12m']),
        min: asInt(json['min']),
        next: NextTier.maybe(json['next']),
        serverProgress: asIntOrNull(json['progress']),
        perks: asMapList(json['perks']).map(TierPerk.fromJson).toList(),
        atRisk: TierRisk.maybe(json['at_risk']),
      );
}

/// The soft drop: how soon, how many orders fall out, and where that lands.
@immutable
class TierRisk {
  const TierRisk({required this.inDays, required this.ordersDropping, required this.wouldDropTo, this.wouldDropToName = ''});

  final int inDays;
  final int ordersDropping;
  final String wouldDropTo;
  final String wouldDropToName;

  static TierRisk? maybe(dynamic value) {
    if (value is! Map) return null;
    final map = asMap(value);
    return TierRisk(
      inDays: asInt(map['in_days']),
      ordersDropping: asInt(map['orders_dropping']),
      wouldDropTo: asString(map['would_drop_to']),
      wouldDropToName: asString(map['would_drop_to_name']),
    );
  }
}

/// A catalog reward — a gift product, free delivery, or a paws top-up.
@immutable
class Reward {
  const Reward({
    required this.id,
    this.kind = 'gift_product',
    this.title = '',
    this.titleEn = '',
    this.description = '',
    this.product,
    this.pawsCost = 0,
    this.valueSar = 0,
    this.validityDays = 0,
    this.minTier = '',
    this.redeemable = false,
    this.reasonAr,
    this.reasonEn,
  });

  final int id;

  /// `gift_product` | `express_free` | `free_delivery` | `paws`. A kind this
  /// build has never heard of is still rendered — as a plain gift — because
  /// the catalog is the owner's to extend without an app release.
  final String kind;

  /// Arrives in the caller's language; [titleEn] is kept for the rare screen
  /// that needs both.
  final String title;
  final String titleEn;
  final String description;

  /// The actual product a gift reward hands over, when the catalog names one.
  final ProductCard? product;

  /// 0 means "granted only" — this reward is never bought with paws.
  final int pawsCost;
  final double valueSar;
  final int validityDays;
  final String minTier;

  /// Whether *this* customer can redeem it right now.
  final bool redeemable;
  final String? reasonAr;
  final String? reasonEn;

  bool get isGift => kind == 'gift_product';

  /// Waives the express fee on the next order — not the whole delivery.
  bool get isExpressFree => kind == 'express_free';

  /// Free delivery at any tier, with no basket minimum.
  bool get isFreeDelivery => kind == 'free_delivery';
  bool get isPaws => kind == 'paws';

  /// A service reward: nothing is added to the basket, a fee is waived.
  bool get isService => isExpressFree || isFreeDelivery;
  bool get isPurchasable => pawsCost > 0;

  /// Why it cannot be redeemed, in the reading language.
  String? reasonFor(String locale) {
    final preferred = locale.startsWith('ar') ? reasonAr : reasonEn;
    final value = preferred ?? reasonAr ?? reasonEn;
    return (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        id: asInt(json['id']),
        kind: asString(json['kind'], fallback: 'gift_product'),
        title: asString(json['title']),
        titleEn: asString(json['title_en']),
        description: asString(json['description']),
        product: asMap(json['product']).isEmpty
            ? null
            : ProductCard.fromJson(asMap(json['product'])),
        pawsCost: asInt(json['paws_cost']),
        valueSar: asDouble(json['value_sar']),
        validityDays: asInt(json['validity_days']),
        minTier: asString(json['min_tier']),
        redeemable: asBool(json['redeemable']),
        reasonAr: asStringOrNull(json['reason_ar']),
        reasonEn: asStringOrNull(json['reason_en']),
      );

  static List<Reward> listFrom(dynamic value) =>
      asMapList(value).map(Reward.fromJson).toList();
}

/// A reward this customer actually holds. `pending` ones are the scratch
/// prizes waiting on a delivery; `active` ones can be carried into the cart.
@immutable
class Grant {
  const Grant({
    required this.id,
    required this.reward,
    this.source = 'admin',
    this.state = 'active',
    this.expiresAt,
    this.activatesOnOrder,
    this.claimed = false,
  });

  final int id;
  final Reward reward;

  /// `scratch` | `mission` | `redeem` | `welcome` | `admin`.
  final String source;

  /// `pending` | `active` | `claimed` | `redeemed` | `expired` | `cancelled`.
  final String state;
  final DateTime? expiresAt;

  /// Set while the grant is still waiting for that order to be delivered.
  final LoyaltyOrderRef? activatesOnOrder;

  /// True once it is sitting in the cart.
  final bool claimed;

  bool get isActive => state == 'active';
  bool get isPending => state == 'pending';
  bool get isClaimed => claimed || state == 'claimed';

  /// Claimable = active, in hand, and not already in the basket.
  bool get isClaimable => isActive && !isClaimed;

  factory Grant.fromJson(Map<String, dynamic> json) => Grant(
        id: asInt(json['id']),
        reward: Reward.fromJson(asMap(json['reward'])),
        source: asString(json['source'], fallback: 'admin'),
        state: asString(json['state'], fallback: 'active'),
        expiresAt: asDate(json['expires_at']),
        activatesOnOrder: LoyaltyOrderRef.maybe(json['activates_on_order']),
        claimed: asBool(json['claimed']),
      );

  static List<Grant> listFrom(dynamic value) =>
      asMapList(value).map(Grant.fromJson).toList();
}

/// `GET /loyalty/rewards` — what can be bought, and what is already owned.
@immutable
class RewardsCatalog {
  const RewardsCatalog({this.catalog = const [], this.grants = const []});

  final List<Reward> catalog;
  final List<Grant> grants;

  static const RewardsCatalog empty = RewardsCatalog();

  List<Grant> get activeGrants =>
      grants.where((grant) => grant.isActive || grant.isClaimed).toList();

  List<Grant> get pendingGrants => grants.where((grant) => grant.isPending).toList();

  bool get isEmpty => catalog.isEmpty && grants.isEmpty;

  factory RewardsCatalog.fromJson(Map<String, dynamic> json) => RewardsCatalog(
        catalog: Reward.listFrom(json['catalog']),
        grants: Grant.listFrom(json['grants']),
      );
}

/// What a mission pays: paws, or a reward from the catalog.
@immutable
class MissionReward {
  const MissionReward({this.kind = 'paws', this.paws = 0, this.reward});

  final String kind;
  final int paws;
  final Reward? reward;

  bool get isPaws => kind == 'paws' || reward == null;

  factory MissionReward.fromJson(Map<String, dynamic> json) => MissionReward(
        kind: asString(json['kind'], fallback: 'paws'),
        paws: asInt(json['paws']),
        reward: asMap(json['reward']).isEmpty
            ? null
            : Reward.fromJson(asMap(json['reward'])),
      );
}

/// One of the month's missions.
@immutable
class Mission {
  const Mission({
    required this.id,
    this.key = '',
    this.kind = '',
    this.title = '',
    this.body = '',
    this.target = 1,
    this.progress = 0,
    this.state = 'active',
    this.reward = const MissionReward(),
    this.suggestedProducts = const [],
    this.completedAt,
  });

  final int id;
  final String key;
  final String kind;
  final String title;
  final String body;
  final int target;
  final int progress;

  /// `active` | `completed` | `rewarded` | `expired`.
  final String state;
  final MissionReward reward;

  /// Up to six cards for a "try something new" mission — the shortest path
  /// from reading the mission to finishing it.
  final List<ProductCard> suggestedProducts;
  final DateTime? completedAt;

  bool get isDone => state == 'completed' || state == 'rewarded';
  bool get isActive => state == 'active';

  /// 0..1, clamped — a server that reports 3/2 still draws a full bar.
  double get ratio {
    if (isDone) return 1;
    if (target <= 0) return 0;
    return (progress / target).clamp(0.0, 1.0);
  }

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
        id: asInt(json['id']),
        key: asString(json['key']),
        kind: asString(json['kind']),
        title: asString(json['title']),
        body: asString(json['body']),
        target: asInt(json['target'], fallback: 1),
        progress: asInt(json['progress']),
        state: asString(json['state'], fallback: 'active'),
        reward: MissionReward.fromJson(asMap(json['reward'])),
        suggestedProducts: ProductCard.listFrom(json['suggested_products']),
        completedAt: asDate(json['completed_at']),
      );

  static List<Mission> listFrom(dynamic value) =>
      asMapList(value).map(Mission.fromJson).toList();
}

/// `GET /loyalty/missions`, and the `missions` block of the summary.
@immutable
class MissionsBlock {
  const MissionsBlock({
    this.period = '',
    this.active = 0,
    this.completed = 0,
    this.items = const [],
  });

  final String period;
  final int active;
  final int completed;
  final List<Mission> items;

  static const MissionsBlock empty = MissionsBlock();

  bool get isEmpty => items.isEmpty;

  /// The one worth putting on the home card: the closest to finishing among
  /// those still open, because that is the nudge with the shortest run-up.
  Mission? get nearest {
    Mission? best;
    for (final mission in items) {
      if (!mission.isActive) continue;
      if (best == null || mission.ratio > best.ratio) best = mission;
    }
    return best;
  }

  factory MissionsBlock.fromJson(Map<String, dynamic> json) => MissionsBlock(
        period: asString(json['period']),
        active: asInt(json['active']),
        completed: asInt(json['completed']),
        items: Mission.listFrom(json['items']),
      );
}

/// A scratch card still sealed, as the summary lists it.
@immutable
class SealedScratch {
  const SealedScratch({required this.id, this.orderNumber = ''});

  final int id;
  final String orderNumber;

  factory SealedScratch.fromJson(Map<String, dynamic> json) => SealedScratch(
        id: asInt(json['id']),
        orderNumber: asString(json['order_number']),
      );
}

/// The `rewards` block of the summary.
@immutable
class SummaryRewards {
  const SummaryRewards({this.activeCount = 0, this.sealedScratch = const []});

  final int activeCount;
  final List<SealedScratch> sealedScratch;

  static const SummaryRewards empty = SummaryRewards();

  factory SummaryRewards.fromJson(Map<String, dynamic> json) => SummaryRewards(
        activeCount: asInt(json['active_count']),
        sealedScratch:
            asMapList(json['sealed_scratch']).map(SealedScratch.fromJson).toList(),
      );
}

@immutable
class LoyaltyCounters {
  const LoyaltyCounters({this.ordersTotal = 0, this.ordersApp = 0});

  final int ordersTotal;
  final int ordersApp;

  factory LoyaltyCounters.fromJson(Map<String, dynamic> json) => LoyaltyCounters(
        ordersTotal: asInt(json['orders_total']),
        ordersApp: asInt(json['orders_app']),
      );
}

/// An order that is placed but not yet delivered — the paws it will pay and
/// whether it came from the app (so a mission may be waiting on it too).
///
/// The whole program settles on delivery, and the customer who just placed
/// their first order needs to be told, in so many words, that nothing is
/// missing: it is on its way.
@immutable
class PendingOrder {
  const PendingOrder({
    required this.id,
    required this.number,
    this.paws = 0,
    this.isApp = false,
    this.createdAt,
  });

  final int id;
  final String number;
  final int paws;
  final bool isApp;
  final DateTime? createdAt;

  factory PendingOrder.fromJson(Map<String, dynamic> json) => PendingOrder(
        id: asInt(json['id']),
        number: asString(json['number'], fallback: asInt(json['id']).toString()),
        paws: asInt(json['paws']),
        isApp: asBool(json['is_app']),
        createdAt: asDate(json['created_at']),
      );

  static List<PendingOrder> listFrom(dynamic value) =>
      asMapList(value).map(PendingOrder.fromJson).where((o) => o.id > 0).toList();
}

/// `GET /loyalty/summary` — one read that answers the whole family hub and
/// both home cards.
@immutable
class LoyaltySummary {
  const LoyaltySummary({
    this.member = const LoyaltyMember(),
    this.paws = const PawsBalance(),
    this.tier = TierInfo.empty,
    this.missions = MissionsBlock.empty,
    this.rewards = SummaryRewards.empty,
    this.pets = const [],
    this.counters = const LoyaltyCounters(),
    this.pendingOrders = const [],
    this.supply = SupplyBlock.empty,
    this.subscriptions = SubscriptionsBlock.empty,
    this.birthday,
    this.referral,
    this.stamps = const [],
    this.nudges = const [],
  });

  final LoyaltyMember member;
  final PawsBalance paws;
  final TierInfo tier;
  final MissionsBlock missions;
  final SummaryRewards rewards;
  final List<Pet> pets;
  final LoyaltyCounters counters;

  /// Orders on their way — paws and missions waiting on a delivery.
  final List<PendingOrder> pendingOrders;

  // ── Phase 2 «العادة» ──

  /// The food gauge: the three soonest run-outs and the counts.
  final SupplyBlock supply;

  /// Soft subscriptions: how many, and the next delivery.
  final SubscriptionsBlock subscriptions;

  /// A pet's birthday inside the window, with what it holds — or null.
  final BirthdayMoment? birthday;

  /// The referral card's light block (code, link, reward).
  final ReferralSummary? referral;

  /// Brand stamp cards; empty until the owner activates a program.
  final List<StampCard> stamps;

  /// Dated things worth saying, soonest first.
  final List<Nudge> nudges;

  static const LoyaltySummary empty = LoyaltySummary();

  /// The soonest supply line that is inside or past its window, if any.
  SupplyItem? get supplyDue {
    for (final item in supply.items) {
      if (item.isDueOrSoon) return item;
    }
    return null;
  }

  /// A subscription delivery due within the reminder window.
  Subscription? get subscriptionDue {
    final next = subscriptions.next;
    if (next == null || !next.isActive) return null;
    final days = next.daysUntil;
    return days != null && days <= 3 ? next : null;
  }

  Pet? get firstPet => pets.isEmpty ? null : pets.first;

  /// Whether an app order is in flight, so an order-driven mission can say
  /// "waiting on your delivery" instead of sitting at zero.
  bool get hasPendingAppOrder => pendingOrders.any((o) => o.isApp);

  /// Paws that exist but haven't landed: revealed prizes plus in-flight orders.
  int get pendingPaws =>
      paws.pending + pendingOrders.fold<int>(0, (sum, o) => sum + o.paws);

  /// Control-group members keep paws and tiers and lose the play layer, so
  /// every gamified section asks this rather than checking `holdout` itself.
  bool get playsGames => !member.holdout;

  bool get hasSealedScratch =>
      playsGames && rewards.sealedScratch.isNotEmpty;

  factory LoyaltySummary.fromJson(Map<String, dynamic> json) => LoyaltySummary(
        member: LoyaltyMember.fromJson(asMap(json['member'])),
        paws: PawsBalance.fromJson(asMap(json['paws'])),
        tier: TierInfo.fromJson(asMap(json['tier'])),
        missions: MissionsBlock.fromJson(asMap(json['missions'])),
        rewards: SummaryRewards.fromJson(asMap(json['rewards'])),
        pets: Pet.listFrom(json['pets']),
        counters: LoyaltyCounters.fromJson(asMap(json['counters'])),
        pendingOrders: PendingOrder.listFrom(json['pending_orders']),
        supply: SupplyBlock.fromJson(asMap(json['supply'])),
        subscriptions: SubscriptionsBlock.fromJson(asMap(json['subscriptions'])),
        birthday: BirthdayMoment.maybe(asMap(json['moments'])['birthday']),
        referral: ReferralSummary.maybe(json['referral']),
        stamps: StampCard.listFrom(json['stamps']),
        nudges: Nudge.listFrom(json['nudges']),
      );
}

/// What a scratch card is hiding.
@immutable
class ScratchPrize {
  const ScratchPrize({this.kind = 'paws', this.paws = 0, this.reward, this.grantId});

  final String kind;
  final int paws;
  final Reward? reward;

  /// The grant the prize created, once there is one.
  final int? grantId;

  bool get isPaws => kind == 'paws' || reward == null;

  factory ScratchPrize.fromJson(Map<String, dynamic> json) => ScratchPrize(
        kind: asString(json['kind'], fallback: 'paws'),
        paws: asInt(json['paws']),
        reward: asMap(json['reward']).isEmpty
            ? null
            : Reward.fromJson(asMap(json['reward'])),
        grantId: asIntOrNull(json['grant_id']),
      );
}

/// One «اخدش واربح» card. The prize is drawn server-side at order time; the
/// reveal is theatre, and [settled] is the only thing that says it is real.
@immutable
class ScratchCard {
  const ScratchCard({
    required this.id,
    this.order,
    this.state = 'sealed',
    this.prize = const ScratchPrize(),
    this.settled = false,
    this.activationHintAr,
    this.activationHintEn,
  });

  final int id;
  final LoyaltyOrderRef? order;

  /// `sealed` | `revealed`.
  final String state;
  final ScratchPrize prize;

  /// True once the order was delivered and the prize actually landed.
  final bool settled;
  final String? activationHintAr;
  final String? activationHintEn;

  bool get isSealed => state == 'sealed';

  String? activationHintFor(String locale) {
    final preferred =
        locale.startsWith('ar') ? activationHintAr : activationHintEn;
    final value = preferred ?? activationHintAr ?? activationHintEn;
    return (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  factory ScratchCard.fromJson(Map<String, dynamic> json) => ScratchCard(
        id: asInt(json['id']),
        order: LoyaltyOrderRef.maybe(json['order']),
        state: asString(json['state'], fallback: 'sealed'),
        prize: ScratchPrize.fromJson(asMap(json['prize'])),
        settled: asBool(json['settled']),
        activationHintAr: asStringOrNull(json['activation_hint_ar']),
        activationHintEn: asStringOrNull(json['activation_hint_en']),
      );

  /// Null for "no card on this order", which is the normal answer for a web
  /// order, a guest, or a control-group member.
  static ScratchCard? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    final card = ScratchCard.fromJson(map);
    return card.id > 0 ? card : null;
  }

  static List<ScratchCard> listFrom(dynamic value) {
    final raw = value is List ? value : asMap(value)['cards'];
    return asMapList(raw).map(ScratchCard.fromJson).toList();
  }
}

/// One append-only line of the paws ledger.
@immutable
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    this.delta = 0,
    this.balanceAfter = 0,
    this.reason = '',
    this.refType = '',
    this.refId = 0,
    this.note = '',
    this.createdAt,
  });

  final int id;
  final int delta;
  final int balanceAfter;

  /// `order_earn` | `profile_complete` | `pet_added` | `mission` | `scratch` |
  /// `redeem` | `reverse` | `expire` | `adjust` | `welcome`.
  final String reason;
  final String refType;
  final int refId;
  final String note;
  final DateTime? createdAt;

  bool get isCredit => delta >= 0;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: asInt(json['id']),
        delta: asInt(json['delta']),
        balanceAfter: asInt(json['balance_after']),
        reason: asString(json['reason']),
        refType: asString(json['ref_type']),
        refId: asInt(json['ref_id']),
        note: asString(json['note']),
        createdAt: asDate(json['created_at']),
      );
}

/// One page of `GET /loyalty/ledger`.
@immutable
class LedgerPage {
  const LedgerPage({this.items = const [], this.page = 1, this.hasMore = false});

  final List<LedgerEntry> items;
  final int page;
  final bool hasMore;

  static const LedgerPage empty = LedgerPage();

  factory LedgerPage.fromJson(Map<String, dynamic> json) => LedgerPage(
        items: asMapList(json['items']).map(LedgerEntry.fromJson).toList(),
        page: asInt(json['page'], fallback: 1),
        hasMore: asBool(json['has_more']),
      );
}

/// `POST /loyalty/rewards/{id}/redeem` — the new grant and the wallet after.
@immutable
class RedeemResult {
  const RedeemResult({required this.grant, this.pawsBalance = 0});

  final Grant grant;
  final int pawsBalance;

  factory RedeemResult.fromJson(Map<String, dynamic> json) => RedeemResult(
        grant: Grant.fromJson(asMap(json['grant'])),
        pawsBalance: asInt(json['paws_balance']),
      );
}

/// The loyalty half of the cart DTO.
@immutable
class CartLoyalty {
  const CartLoyalty({
    this.pawsToEarn = 0,
    this.holdout = false,
    this.claims = const [],
    this.freeDeliveryReason,
    this.expressFreeReason,
    this.subscriptionIds = const [],
  });

  /// What this basket earns once it is delivered.
  final int pawsToEarn;
  final bool holdout;

  /// Grants currently riding in this cart.
  final List<Grant> claims;

  /// `tier` | `reward` | null — why delivery is free, when it is.
  final String? freeDeliveryReason;

  /// `tier` | `reward` | null — why the express fee was waived, when it was.
  /// Distinct from [freeDeliveryReason]: gold gets express for nothing long
  /// before anyone gets every tier for nothing.
  final String? expressFreeReason;

  /// Subscriptions this basket delivers (the one-tap basket flagged them).
  final List<int> subscriptionIds;

  static const CartLoyalty none = CartLoyalty();

  bool get hasClaims => claims.isNotEmpty;

  bool get isSubscriptionBasket => subscriptionIds.isNotEmpty;

  /// Whether any fee at all was waived, and by what.
  bool get hasDeliveryPerk =>
      freeDeliveryReason != null || expressFreeReason != null;

  factory CartLoyalty.fromJson(Map<String, dynamic> json) => CartLoyalty(
        pawsToEarn: asInt(json['paws_to_earn']),
        holdout: asBool(json['holdout']),
        claims: Grant.listFrom(json['claims']),
        freeDeliveryReason: _reason(json['free_delivery_reason']),
        expressFreeReason: _reason(json['express_free_reason']),
        subscriptionIds: (json['subscription_ids'] is List)
            ? (json['subscription_ids'] as List).map(asInt).where((id) => id > 0).toList()
            : const [],
      );

  /// Only the reasons the app knows how to word. Anything else is dropped
  /// rather than printed raw next to a delivery promise.
  static String? _reason(dynamic value) {
    final raw = asStringOrNull(value);
    return raw == 'tier' || raw == 'reward' || raw == 'subscription' ? raw : null;
  }
}

/// Loyalty error codes the UI reacts to structurally rather than by only
/// printing the server's sentence.
abstract final class LoyaltyErrors {
  static const insufficientPaws = 'insufficient_paws';
  static const tierRequired = 'tier_required';
  static const rewardUnavailable = 'reward_unavailable';
  static const grantNotActive = 'grant_not_active';
  static const giftUnavailable = 'gift_unavailable';
  static const alreadyClaimed = 'already_claimed';
  static const petsLimit = 'pets_limit';
  static const petInvalid = 'pet_invalid';
  static const subscriptionLimit = 'subscription_limit';
  static const subscriptionExists = 'subscription_exists';
  static const referralInvalid = 'referral_invalid';
  static const referralUsed = 'referral_used';
  static const referralNotNew = 'referral_not_new';
}

/* ═══════════════════════════════════════════════════════════════════════
   Phase 2 «العادة» — the food gauge, subscriptions, moments, referral,
   brand stamps, nudges. Contract: `14-LOYALTY-PHASE2-SPEC.md` §8.
   ═══════════════════════════════════════════════════════════════════════ */

/// The pet a supply line or subscription feeds — a light reference, not the
/// full profile.
@immutable
class PetRef {
  const PetRef({required this.id, required this.name, required this.species});

  final int id;
  final String name;
  final PetSpecies species;

  static PetRef? maybe(dynamic value) {
    if (value is! Map) return null;
    final map = asMap(value);
    final id = asInt(map['id']);
    if (id <= 0) return null;
    return PetRef(id: id, name: asString(map['name']), species: PetSpecies.fromKey(asStringOrNull(map['species'])));
  }
}

/// One line of the food gauge: a consumable the customer buys, and when it
/// runs out.
///
/// `daysLeft` is the server's — it owns the forecast and the window — and the
/// app never recomputes it; a phone with a wrong clock would otherwise argue
/// with the bonus the store actually pays.
@immutable
class SupplyItem {
  const SupplyItem({
    required this.product,
    this.variationId = 0,
    this.kind = 'other',
    this.pet,
    this.qtyLast = 1,
    this.lastOrderedAt,
    this.cycleDays = 30,
    this.daysLeft = 0,
    this.runsOutAt,
    this.status = 'ok',
    this.confidence = 'low',
    this.onTime = false,
    this.packKg,
    this.buys = 1,
    this.subscriptionId,
  });

  final ProductCard product;
  final int variationId;

  /// `dry` | `wet` | `litter` | `treat` | `other`.
  final String kind;
  final PetRef? pet;
  final int qtyLast;
  final DateTime? lastOrderedAt;

  /// Days one unit lasts, as the server currently believes.
  final double cycleDays;
  final int daysLeft;
  final DateTime? runsOutAt;

  /// `ok` | `soon` | `due` | `overdue`.
  final String status;

  /// `low` | `medium` | `high` — how much history stands behind the number.
  final String confidence;

  /// Ordering right now earns the on-time bonus.
  final bool onTime;
  final double? packKg;
  final int buys;
  final int? subscriptionId;

  bool get isOk => status == 'ok';
  bool get isSoon => status == 'soon';
  bool get isDue => status == 'due';
  bool get isOverdue => status == 'overdue';
  bool get isDueOrSoon => status != 'ok';
  bool get hasSubscription => subscriptionId != null;

  /// The share of the last pack still in the bowl, 0..1, for the ring.
  double get remaining {
    final total = qtyLast * cycleDays;
    if (total <= 0) return 0;
    return (daysLeft / total).clamp(0.0, 1.0);
  }

  factory SupplyItem.fromJson(Map<String, dynamic> json) => SupplyItem(
        product: ProductCard.fromJson(asMap(json['product'])),
        variationId: asInt(json['variation_id']),
        kind: asString(json['kind'], fallback: 'other'),
        pet: PetRef.maybe(json['pet']),
        qtyLast: asInt(json['qty_last'], fallback: 1),
        lastOrderedAt: asDate(json['last_ordered_at']),
        cycleDays: asDouble(json['cycle_days'], fallback: 30),
        daysLeft: asInt(json['days_left']),
        runsOutAt: asDate(json['runs_out_at']),
        status: asString(json['status'], fallback: 'ok'),
        confidence: asString(json['confidence'], fallback: 'low'),
        onTime: asBool(json['on_time']),
        packKg: asDoubleOrNull(json['pack_kg']),
        buys: asInt(json['buys'], fallback: 1),
        subscriptionId: asIntOrNull(json['subscription_id']),
      );

  static List<SupplyItem> listFrom(dynamic value) {
    final raw = value is List ? value : asMap(value)['items'];
    return asMapList(raw)
        .where((m) => m['product'] is Map)
        .map(SupplyItem.fromJson)
        .toList();
  }
}

/// `summary.supply` and `GET /loyalty/supply`.
@immutable
class SupplyBlock {
  const SupplyBlock({
    this.items = const [],
    this.dueCount = 0,
    this.total = 0,
    this.windowBefore = 7,
    this.windowAfter = 3,
    this.onTimePct = 20,
    this.enabled = true,
  });

  final List<SupplyItem> items;
  final int dueCount;
  final int total;
  final int windowBefore;
  final int windowAfter;
  final int onTimePct;
  final bool enabled;

  static const SupplyBlock empty = SupplyBlock();

  bool get isEmpty => items.isEmpty;

  factory SupplyBlock.fromJson(Map<String, dynamic> json) {
    final window = asMap(json['window']);
    final items = SupplyItem.listFrom(json['items']);
    return SupplyBlock(
      items: items,
      dueCount: asInt(json['due_count']),
      total: asInt(json['total'], fallback: items.length),
      windowBefore: asInt(window['before'], fallback: 7),
      windowAfter: asInt(window['after'], fallback: 3),
      onTimePct: asInt(json['on_time_pct'], fallback: 20),
      enabled: json['enabled'] == null ? true : asBool(json['enabled']),
    );
  }
}

/// «وصّل لي كل شهر» — one soft subscription.
@immutable
class Subscription {
  const Subscription({
    required this.id,
    required this.product,
    this.variationId = 0,
    this.variationLabel = '',
    this.qty = 1,
    this.intervalDays = 30,
    this.nextAt,
    this.daysUntil,
    this.state = 'active',
    this.deliveries = 0,
    this.nextGiftIn,
    this.pet,
    this.bonusPct = 10,
    this.giftEvery = 3,
  });

  final int id;
  final ProductCard product;
  final int variationId;
  final String variationLabel;
  final int qty;
  final int intervalDays;
  final DateTime? nextAt;
  final int? daysUntil;

  /// `active` | `paused` | `cancelled`.
  final String state;
  final int deliveries;
  final int? nextGiftIn;
  final PetRef? pet;
  final int bonusPct;
  final int giftEvery;

  bool get isActive => state == 'active';
  bool get isPaused => state == 'paused';

  /// The delivery is due (today or overdue).
  bool get isDue => isActive && (daysUntil ?? 99) <= 0;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final perks = asMap(json['perks']);
    return Subscription(
      id: asInt(json['id']),
      product: ProductCard.fromJson(asMap(json['product'])),
      variationId: asInt(json['variation_id']),
      variationLabel: asString(json['variation_label']),
      qty: asInt(json['qty'], fallback: 1),
      intervalDays: asInt(json['interval_days'], fallback: 30),
      nextAt: asDate(json['next_at']),
      daysUntil: asIntOrNull(json['days_until']),
      state: asString(json['state'], fallback: 'active'),
      deliveries: asInt(json['deliveries']),
      nextGiftIn: asIntOrNull(json['next_gift_in']),
      pet: PetRef.maybe(json['pet']),
      bonusPct: asInt(perks['bonus_pct'], fallback: 10),
      giftEvery: asInt(perks['gift_every'], fallback: 3),
    );
  }

  static Subscription? maybe(dynamic value) {
    if (value is! Map) return null;
    final map = asMap(value);
    if (map['product'] is! Map) return null;
    return Subscription.fromJson(map);
  }

  static List<Subscription> listFrom(dynamic value) {
    final raw = value is List ? value : asMap(value)['items'];
    return asMapList(raw).where((m) => m['product'] is Map).map(Subscription.fromJson).toList();
  }
}

/// `summary.subscriptions`.
@immutable
class SubscriptionsBlock {
  const SubscriptionsBlock({this.active = 0, this.next});

  final int active;
  final Subscription? next;

  static const SubscriptionsBlock empty = SubscriptionsBlock();

  factory SubscriptionsBlock.fromJson(Map<String, dynamic> json) => SubscriptionsBlock(
        active: asInt(json['active']),
        next: Subscription.maybe(json['next']),
      );
}

/// `GET /loyalty/subscriptions`.
@immutable
class SubscriptionsPayload {
  const SubscriptionsPayload({
    this.items = const [],
    this.max = 6,
    this.bonusPct = 10,
    this.giftEvery = 3,
    this.enabled = true,
    this.subscription,
  });

  final List<Subscription> items;
  final int max;
  final int bonusPct;
  final int giftEvery;
  final bool enabled;

  /// The one a write just touched, when the call was a write.
  final Subscription? subscription;

  static const SubscriptionsPayload empty = SubscriptionsPayload();

  int get activeCount => items.where((s) => s.isActive).length;
  bool get canAdd => items.where((s) => s.state != 'cancelled').length < max;

  factory SubscriptionsPayload.fromJson(Map<String, dynamic> json) {
    final perks = asMap(json['perks']);
    return SubscriptionsPayload(
      items: Subscription.listFrom(json['items']),
      max: asInt(json['max'], fallback: 6),
      bonusPct: asInt(perks['bonus_pct'], fallback: 10),
      giftEvery: asInt(perks['gift_every'], fallback: 3),
      enabled: json['enabled'] == null ? true : asBool(json['enabled']),
      subscription: Subscription.maybe(json['subscription']),
    );
  }
}

/// A pet's birthday inside the window, and what the program put in the wallet.
@immutable
class BirthdayMoment {
  const BirthdayMoment({required this.pet, required this.days, this.grant, this.paws, this.eligible = true});

  final Pet pet;

  /// Days until (positive) or since (negative) the birthday.
  final int days;

  /// The gift grant, when the owner attached a product.
  final Grant? grant;

  /// The paws given instead, when there was no gift product.
  final int? paws;
  final bool eligible;

  bool get isToday => days == 0;
  bool get hasGift => grant != null;

  static BirthdayMoment? maybe(dynamic value) {
    if (value is! Map) return null;
    final map = asMap(value);
    if (map['pet'] is! Map) return null;
    return BirthdayMoment(
      pet: Pet.fromJson(asMap(map['pet'])),
      days: asInt(map['days']),
      grant: map['grant'] is Map ? Grant.fromJson(asMap(map['grant'])) : null,
      paws: asIntOrNull(map['paws']),
      eligible: map['eligible'] == null ? true : asBool(map['eligible']),
    );
  }
}

/// `summary.referral` — enough for the hub card.
@immutable
class ReferralSummary {
  const ReferralSummary({required this.code, required this.url, this.rewardPaws = 300, this.rewarded = 0});

  final String code;
  final String url;
  final int rewardPaws;
  final int rewarded;

  static ReferralSummary? maybe(dynamic value) {
    if (value is! Map) return null;
    final map = asMap(value);
    final code = asString(map['code']);
    if (code.isEmpty) return null;
    return ReferralSummary(
      code: code,
      url: asString(map['url']),
      rewardPaws: asInt(map['reward_paws'], fallback: 300),
      rewarded: asInt(map['rewarded']),
    );
  }
}

@immutable
class ReferralItem {
  const ReferralItem({required this.name, required this.state, this.createdAt});

  final String name;

  /// `pending` | `qualified` | `review` | `rewarded` | `rejected`.
  final String state;
  final DateTime? createdAt;

  factory ReferralItem.fromJson(Map<String, dynamic> json) => ReferralItem(
        name: asString(json['name']),
        state: asString(json['state'], fallback: 'pending'),
        createdAt: asDate(json['created_at']),
      );
}

/// `GET /loyalty/referral` — the whole referral screen.
@immutable
class ReferralOverview {
  const ReferralOverview({
    this.code = '',
    this.url = '',
    this.shareText = '',
    this.rewardPaws = 300,
    this.welcome = '',
    this.cap = 10,
    this.thisMonth = 0,
    this.invited = 0,
    this.qualified = 0,
    this.rewarded = 0,
    this.items = const [],
    this.appliedCode,
    this.appliedState,
    this.enabled = true,
  });

  final String code;
  final String url;
  final String shareText;
  final int rewardPaws;

  /// What the invited friend gets, in words.
  final String welcome;
  final int cap;
  final int thisMonth;
  final int invited;
  final int qualified;
  final int rewarded;
  final List<ReferralItem> items;

  /// The code THIS customer used, if they came by invitation.
  final String? appliedCode;
  final String? appliedState;
  final bool enabled;

  static const ReferralOverview empty = ReferralOverview();

  bool get hasApplied => appliedCode != null && appliedCode!.isNotEmpty;
  bool get atCap => cap > 0 && thisMonth >= cap;

  factory ReferralOverview.fromJson(Map<String, dynamic> json) {
    final stats = asMap(json['stats']);
    final applied = json['applied'] is Map ? asMap(json['applied']) : null;
    return ReferralOverview(
      code: asString(json['code']),
      url: asString(json['url']),
      shareText: asString(json['share_text']),
      rewardPaws: asInt(json['reward_paws'], fallback: 300),
      welcome: asString(json['welcome']),
      cap: asInt(json['cap'], fallback: 10),
      thisMonth: asInt(json['this_month']),
      invited: asInt(stats['invited']),
      qualified: asInt(stats['qualified']),
      rewarded: asInt(stats['rewarded']),
      items: asMapList(json['items']).map(ReferralItem.fromJson).toList(),
      appliedCode: applied == null ? null : asStringOrNull(applied['code']),
      appliedState: applied == null ? null : asStringOrNull(applied['state']),
      enabled: json['enabled'] == null ? true : asBool(json['enabled']),
    );
  }
}

/// What applying a code returned.
@immutable
class ReferralApplied {
  const ReferralApplied({this.code = '', this.state = 'pending', this.pawsEarned = 0, this.pawsBalance = 0, this.grant});

  final String code;
  final String state;
  final int pawsEarned;
  final int pawsBalance;
  final Grant? grant;

  factory ReferralApplied.fromJson(Map<String, dynamic> json) {
    final applied = asMap(json['applied']);
    return ReferralApplied(
      code: asString(applied['code']),
      state: asString(applied['state'], fallback: 'pending'),
      pawsEarned: asInt(json['paws_earned']),
      pawsBalance: asInt(json['paws_balance']),
      grant: json['grant'] is Map ? Grant.fromJson(asMap(json['grant'])) : null,
    );
  }
}

/// A brand's stamp program and where this customer stands on it.
@immutable
class StampCard {
  const StampCard({
    required this.programId,
    required this.title,
    this.brandName = '',
    this.brandSlug = '',
    this.unitsRequired = 6,
    this.minPackKg = 0,
    this.reward,
    this.units = 0,
    this.cyclesDone = 0,
    this.remaining = 6,
  });

  final int programId;
  final String title;
  final String brandName;
  final String brandSlug;
  final int unitsRequired;
  final double minPackKg;
  final Reward? reward;
  final int units;
  final int cyclesDone;
  final int remaining;

  double get ratio => unitsRequired <= 0 ? 0 : (units / unitsRequired).clamp(0.0, 1.0);

  factory StampCard.fromJson(Map<String, dynamic> json) {
    final program = asMap(json['program']);
    final brand = asMap(program['brand']);
    return StampCard(
      programId: asInt(program['id']),
      title: asString(program['title']),
      brandName: asString(brand['name']),
      brandSlug: asString(brand['slug']),
      unitsRequired: asInt(program['units_required'], fallback: 6),
      minPackKg: asDouble(program['min_pack_kg']),
      reward: program['reward'] is Map ? Reward.fromJson(asMap(program['reward'])) : null,
      units: asInt(json['units']),
      cyclesDone: asInt(json['cycles_done']),
      remaining: asInt(json['remaining'], fallback: 6),
    );
  }

  static List<StampCard> listFrom(dynamic value) {
    final raw = value is List ? value : asMap(value)['items'];
    return asMapList(raw).where((m) => m['program'] is Map).map(StampCard.fromJson).toList();
  }
}

/// One dated thing worth saying. Past ones are shown; future ones become
/// local notifications on the phone.
@immutable
class Nudge {
  const Nudge({
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.route = '/family',
    this.productId,
    this.subscriptionId,
    this.petId,
  });

  /// `birthday` | `supply` | `subscription` | `winback` | `tier_risk`.
  final String kind;
  final String title;
  final String body;
  final DateTime at;
  final String route;
  final int? productId;
  final int? subscriptionId;
  final int? petId;

  bool get isFuture => at.isAfter(DateTime.now());

  /// A stable id for the OS notification, so re-syncing replaces rather than
  /// duplicates.
  String get notificationId =>
      '$kind-${productId ?? subscriptionId ?? petId ?? 0}-${at.millisecondsSinceEpoch ~/ 60000}';

  factory Nudge.fromJson(Map<String, dynamic> json) => Nudge(
        kind: asString(json['kind']),
        title: asString(json['title']),
        body: asString(json['body']),
        at: asDate(json['at']) ?? DateTime.now(),
        route: asString(json['route'], fallback: '/family'),
        productId: asIntOrNull(json['product_id']),
        subscriptionId: asIntOrNull(json['subscription_id']),
        petId: asIntOrNull(json['pet_id']),
      );

  static List<Nudge> listFrom(dynamic value) {
    final raw = value is List ? value : asMap(value)['nudges'];
    return asMapList(raw).map(Nudge.fromJson).toList();
  }
}
