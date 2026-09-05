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
  });

  final String key;
  final String text;
  final bool active;

  /// The tier that unlocks it, for a perk that is still ahead.
  final String? fromTier;

  factory TierPerk.fromJson(Map<String, dynamic> json) => TierPerk(
        key: asString(json['key']),
        text: asString(json['text']),
        active: asBool(json['active']),
        fromTier: asStringOrNull(json['from_tier']),
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
      );
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
  });

  final LoyaltyMember member;
  final PawsBalance paws;
  final TierInfo tier;
  final MissionsBlock missions;
  final SummaryRewards rewards;
  final List<Pet> pets;
  final LoyaltyCounters counters;

  static const LoyaltySummary empty = LoyaltySummary();

  Pet? get firstPet => pets.isEmpty ? null : pets.first;

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

  static const CartLoyalty none = CartLoyalty();

  bool get hasClaims => claims.isNotEmpty;

  /// Whether any fee at all was waived, and by what.
  bool get hasDeliveryPerk =>
      freeDeliveryReason != null || expressFreeReason != null;

  factory CartLoyalty.fromJson(Map<String, dynamic> json) => CartLoyalty(
        pawsToEarn: asInt(json['paws_to_earn']),
        holdout: asBool(json['holdout']),
        claims: Grant.listFrom(json['claims']),
        freeDeliveryReason: _reason(json['free_delivery_reason']),
        expressFreeReason: _reason(json['express_free_reason']),
      );

  /// Only the two reasons the app knows how to word. Anything else is dropped
  /// rather than printed raw next to a delivery promise.
  static String? _reason(dynamic value) {
    final raw = asStringOrNull(value);
    return raw == 'tier' || raw == 'reward' ? raw : null;
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
}
