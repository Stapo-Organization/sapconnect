import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/checkout/data/checkout_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/family_card.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';

/// The Phase 2 contract («العادة»), parsed.
///
/// Fixtures follow `14-LOYALTY-PHASE2-SPEC.md` §8 rather than the models, so
/// what these prove is that a server shipping the documented shapes lands
/// where the screens expect it — including the two places a wrong read would
/// lie to a customer: the home card's variant order, and a cart that says
/// delivery is free because of a subscription.

Map<String, dynamic> _product(int id) => {
      'id': id,
      'name': 'رويال كانين قطط 2 كجم',
      'image': 'https://x/p$id.jpg',
      'price': 120.0,
      'is_variable': false,
    };

Map<String, dynamic> _supplyItem({int days = 4, String status = 'soon', bool onTime = true, int? sub}) => {
      'product': _product(501),
      'variation_id': 0,
      'kind': 'dry',
      'pet': {'id': 7, 'name': 'مشمش', 'species': 'cat'},
      'qty_last': 1,
      'last_ordered_at': '2026-08-10T09:00:00Z',
      'cycle_days': 41.2,
      'days_left': days,
      'runs_out_at': '2026-09-10T09:00:00Z',
      'status': status,
      'confidence': 'medium',
      'on_time': onTime,
      'pack_kg': 2.0,
      'buys': 3,
      'subscription_id': sub,
    };

Map<String, dynamic> _subscription({int days = 2, String state = 'active'}) => {
      'id': 12,
      'product': _product(501),
      'variation_id': 0,
      'variation_label': '',
      'qty': 2,
      'interval_days': 30,
      'next_at': '2026-09-08',
      'days_until': days,
      'state': state,
      'deliveries': 2,
      'next_gift_in': 1,
      'pet': {'id': 7, 'name': 'مشمش', 'species': 'cat'},
      'perks': {'free_delivery': true, 'bonus_pct': 10, 'gift_every': 3},
    };

Map<String, dynamic> _summaryJson({
  List<Map<String, dynamic>> supply = const [],
  Map<String, dynamic>? nextSub,
  Map<String, dynamic>? birthday,
  Map<String, dynamic>? atRisk,
  List<Map<String, dynamic>> pending = const [],
}) =>
    {
      'member': {'holdout': false, 'referral_code': 'ZBUCNBN'},
      'paws': {'balance': 320, 'pending': 0},
      'tier': {
        'key': 'star',
        'name': 'مميّز',
        'orders_12m': 5,
        'min': 4,
        'next': {'key': 'gold', 'name': 'ذهبي', 'min': 8, 'orders_needed': 3},
        'perks': const [],
        'at_risk': atRisk,
      },
      'missions': {'period': '2026-09', 'items': const []},
      'rewards': {'active_count': 0, 'sealed_scratch': const []},
      'pets': [
        {'id': 7, 'name': 'مشمش', 'species': 'cat', 'birth_date': '2023-09-10', 'is_complete': true, 'birthday_in_days': 4},
      ],
      'counters': {'orders_total': 5, 'orders_app': 2},
      'pending_orders': pending,
      'supply': {'items': supply, 'due_count': supply.where((s) => s['status'] != 'ok').length, 'total': supply.length, 'window': {'before': 7, 'after': 3}},
      'subscriptions': {'active': nextSub == null ? 0 : 1, 'next': nextSub},
      'moments': {'birthday': birthday},
      'referral': {'code': 'ZBUCNBN', 'url': 'https://store.zooboxi.com/?ref=ZBUCNBN', 'reward_paws': 300, 'rewarded': 2},
      'stamps': [
        {
          'program': {
            'id': 3,
            'title': 'بطاقة رويال كانين',
            'brand': {'name': 'Royal Canin', 'slug': 'royal-canin'},
            'units_required': 6,
            'min_pack_kg': 1.5,
            'reward': {'id': 9, 'kind': 'gift_product', 'title': 'كيس مجاني', 'paws_cost': 0},
          },
          'units': 4,
          'cycles_done': 1,
          'remaining': 2,
        },
      ],
      'nudges': [
        {'kind': 'supply', 'title': 'أكل مشمش يكفي 5 أيام', 'body': '…', 'at': '2099-01-01T09:00:00Z', 'route': '/family/supply', 'product_id': 501},
        {'kind': 'tier_risk', 'title': 'طلب واحد يحفظ مستواك', 'body': '…', 'at': '2020-01-01T09:00:00Z', 'route': '/family'},
      ],
    };

void main() {
  group('supply', () {
    test('a supply line parses with its pet, window and forecast', () {
      final item = SupplyItem.fromJson(_supplyItem());
      expect(item.product.id, 501);
      expect(item.pet?.name, 'مشمش');
      expect(item.pet?.species, PetSpecies.cat);
      expect(item.daysLeft, 4);
      expect(item.isSoon, isTrue);
      expect(item.isDueOrSoon, isTrue);
      expect(item.onTime, isTrue);
      expect(item.packKg, 2.0);
      expect(item.hasSubscription, isFalse);
      // 4 of ~41 days left — the ring is nearly empty, never negative.
      expect(item.remaining, closeTo(4 / 41.2, 0.001));
    });

    test('an overdue line clamps the ring at zero', () {
      final item = SupplyItem.fromJson(_supplyItem(days: -6, status: 'overdue'));
      expect(item.isOverdue, isTrue);
      expect(item.remaining, 0);
    });

    test('a line without a product card is dropped rather than crashing the list', () {
      final block = SupplyBlock.fromJson({
        'items': [_supplyItem(), {'kind': 'dry', 'days_left': 3}],
        'due_count': 1,
        'window': {'before': 7, 'after': 3},
        'on_time_pct': 20,
      });
      expect(block.items, hasLength(1));
      expect(block.windowBefore, 7);
      expect(block.onTimePct, 20);
    });
  });

  group('subscriptions', () {
    test('a subscription parses with its perks and the next date', () {
      final sub = Subscription.fromJson(_subscription());
      expect(sub.id, 12);
      expect(sub.qty, 2);
      expect(sub.intervalDays, 30);
      expect(sub.nextAt, DateTime.parse('2026-09-08'));
      expect(sub.daysUntil, 2);
      expect(sub.isActive, isTrue);
      expect(sub.isDue, isFalse);
      expect(sub.bonusPct, 10);
      expect(sub.giftEvery, 3);
      expect(sub.nextGiftIn, 1);
    });

    test('a paused subscription is never due', () {
      final sub = Subscription.fromJson(_subscription(days: 0, state: 'paused'));
      expect(sub.isPaused, isTrue);
      expect(sub.isDue, isFalse);
    });

    test('the payload counts active ones and knows when the ceiling is hit', () {
      final payload = SubscriptionsPayload.fromJson({
        'items': [_subscription(), _subscription(state: 'paused')],
        'max': 2,
        'perks': {'bonus_pct': 10, 'gift_every': 3},
      });
      expect(payload.activeCount, 1);
      expect(payload.canAdd, isFalse);
    });
  });

  group('referral', () {
    test('the overview parses stats, items and the applied code', () {
      final data = ReferralOverview.fromJson({
        'code': 'ZBUCNBN',
        'url': 'https://store.zooboxi.com/?ref=ZBUCNBN',
        'share_text': 'جرّب زوبوكسي…',
        'reward_paws': 300,
        'welcome': 'هدية صديق زوبوكسي',
        'cap': 10,
        'this_month': 10,
        'stats': {'invited': 3, 'qualified': 1, 'rewarded': 2},
        'items': [
          {'name': 'م…', 'state': 'rewarded', 'created_at': '2026-08-01T10:00:00Z'},
        ],
        'applied': {'code': 'ZB7K2QX', 'state': 'pending'},
      });
      expect(data.rewarded, 2);
      expect(data.atCap, isTrue);
      expect(data.hasApplied, isTrue);
      expect(data.appliedCode, 'ZB7K2QX');
      expect(data.items.single.state, 'rewarded');
    });

    test('applying answers with the state and the welcome', () {
      final applied = ReferralApplied.fromJson({
        'applied': {'code': 'ZBUCNBN', 'state': 'pending'},
        'paws_earned': 100,
        'paws_balance': 420,
        'grant': null,
      });
      expect(applied.pawsEarned, 100);
      expect(applied.grant, isNull);
    });
  });

  group('summary', () {
    test('the Phase 2 blocks ride on the summary and the nudges split by time', () {
      final summary = LoyaltySummary.fromJson(_summaryJson(supply: [_supplyItem()], nextSub: _subscription()));
      expect(summary.supply.items, hasLength(1));
      expect(summary.supply.dueCount, 1);
      expect(summary.subscriptions.active, 1);
      expect(summary.subscriptions.next?.id, 12);
      expect(summary.referral?.code, 'ZBUCNBN');
      expect(summary.stamps.single.remaining, 2);
      expect(summary.stamps.single.ratio, closeTo(4 / 6, 0.001));
      expect(summary.nudges, hasLength(2));
      expect(summary.nudges.first.isFuture, isTrue);
      expect(summary.nudges.last.isFuture, isFalse);
      expect(summary.nudges.first.notificationId, startsWith('supply-501-'));
    });

    test('a tier at risk parses onto the tier', () {
      final summary = LoyaltySummary.fromJson(
        _summaryJson(atRisk: {'in_days': 12, 'orders_dropping': 1, 'would_drop_to': 'friend', 'would_drop_to_name': 'صديق'}),
      );
      expect(summary.tier.atRisk?.inDays, 12);
      expect(summary.tier.atRisk?.wouldDropToName, 'صديق');
    });

    test('a birthday moment carries its pet and its gift', () {
      final summary = LoyaltySummary.fromJson(
        _summaryJson(birthday: {
          'pet': {'id': 7, 'name': 'مشمش', 'species': 'cat'},
          'days': 3,
          'grant': {'id': 71, 'state': 'active', 'claimed': false, 'reward': {'id': 5, 'kind': 'gift_product', 'title': 'هدية'}},
          'grant_id': 71,
          'paws': null,
        }),
      );
      expect(summary.birthday?.pet.name, 'مشمش');
      expect(summary.birthday?.hasGift, isTrue);
      expect(summary.birthday?.grant?.isClaimable, isTrue);
    });

    test('an absent Phase 2 payload (an older store) leaves the blocks empty', () {
      final summary = LoyaltySummary.fromJson({
        'member': {'holdout': false},
        'paws': {'balance': 0},
        'tier': {'key': 'new'},
        'missions': {'items': const []},
        'rewards': {},
        'pets': const [],
      });
      expect(summary.supply.isEmpty, isTrue);
      expect(summary.subscriptions.next, isNull);
      expect(summary.birthday, isNull);
      expect(summary.referral, isNull);
      expect(summary.stamps, isEmpty);
      expect(summary.nudges, isEmpty);
    });
  });

  group('home card variant order', () {
    test('birthday beats pending, pending beats supply, supply beats subscription', () {
      final birthday = {
        'pet': {'id': 7, 'name': 'مشمش', 'species': 'cat'},
        'days': 3,
        'grant': null,
        'paws': 100,
      };
      final pending = [
        {'id': 32601, 'number': '32601', 'paws': 118, 'is_app': true},
      ];

      expect(
        FamilyCard.variantOf(LoyaltySummary.fromJson(_summaryJson(birthday: birthday, pending: pending, supply: [_supplyItem()])), null),
        FamilyCardVariant.birthday,
      );
      expect(
        FamilyCard.variantOf(LoyaltySummary.fromJson(_summaryJson(pending: pending, supply: [_supplyItem()])), null),
        FamilyCardVariant.pending,
      );
      expect(
        FamilyCard.variantOf(LoyaltySummary.fromJson(_summaryJson(supply: [_supplyItem()], nextSub: _subscription())), null),
        FamilyCardVariant.supply,
      );
      expect(
        FamilyCard.variantOf(LoyaltySummary.fromJson(_summaryJson(supply: [_supplyItem(days: 20, status: 'ok', onTime: false)], nextSub: _subscription())), null),
        FamilyCardVariant.subscription,
      );
      // A subscription eight days out is not a card yet — the tier line is.
      expect(
        FamilyCard.variantOf(LoyaltySummary.fromJson(_summaryJson(nextSub: _subscription(days: 8))), null),
        FamilyCardVariant.tier,
      );
    });

    test('a passed birthday only stays on the card while its gift is unclaimed', () {
      final claimed = {
        'pet': {'id': 7, 'name': 'مشمش', 'species': 'cat'},
        'days': -3,
        'grant': {'id': 71, 'state': 'claimed', 'claimed': true, 'reward': {'id': 5, 'kind': 'gift_product', 'title': 'هدية'}},
      };
      expect(
        FamilyCard.variantOf(LoyaltySummary.fromJson(_summaryJson(birthday: claimed)), null),
        FamilyCardVariant.tier,
      );
    });
  });

  group('cart and checkout', () {
    test('a subscription basket says why delivery is free', () {
      final loyalty = CartLoyalty.fromJson({
        'paws_to_earn': 240,
        'holdout': false,
        'claims': const [],
        'free_delivery_reason': 'subscription',
        'express_free_reason': null,
        'subscription_ids': [12],
      });
      expect(loyalty.freeDeliveryReason, 'subscription');
      expect(loyalty.isSubscriptionBasket, isTrue);
      expect(loyalty.hasDeliveryPerk, isTrue);
    });

    test('an unknown reason is dropped rather than printed', () {
      final loyalty = CartLoyalty.fromJson({'free_delivery_reason': 'magic'});
      expect(loyalty.freeDeliveryReason, isNull);
    });

    test('the placed order knows it delivered a subscription', () {
      final order = PlacedOrder.fromJson({
        'order_id': 1,
        'order_number': '1',
        'order_key': 'k',
        'status': 'processing',
        'subscription_order': true,
        'paws_to_earn': 120,
      });
      expect(order.subscriptionOrder, isTrue);
      expect(order.withPromise(order.promise).subscriptionOrder, isTrue);
    });
  });
}
