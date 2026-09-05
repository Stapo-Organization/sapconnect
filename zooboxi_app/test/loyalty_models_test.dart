import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';

/// The loyalty contract, parsed.
///
/// These fixtures are copied from `13-LOYALTY-PHASE1-SPEC.md` §4 rather than
/// written to fit the models, so a server that ships exactly what the spec
/// promises is what the tests prove works — including the two shapes that are
/// easy to get wrong: a control-group member, and a tier with no rung above it.

Map<String, dynamic> _summaryJson({bool holdout = false}) => {
      'member': {
        'joined_at': '2026-03-01T09:00:00Z',
        'holdout': holdout,
        'referral_code': 'ZB7K2QX',
      },
      'paws': {
        'balance': 1240,
        'pending': 120,
        'expires_at': '2027-09-01T00:00:00Z',
      },
      'tier': {
        'key': 'star',
        'name': 'مميّز',
        'name_en': 'Star',
        'icon': '⭐',
        'c1': '#e8a765',
        'c2': '#d48644',
        'orders_12m': 5,
        'min': 4,
        'next': {'key': 'gold', 'name': 'ذهبي', 'min': 8, 'orders_needed': 3},
        'progress': 25,
        'perks': [
          {'key': 'free_min_150', 'text': 'الشحن المجاني من 150 ﷼', 'active': true},
          {
            'key': 'express_free_always',
            'text': 'توصيل سريع مجاني دائمًا',
            'active': false,
            'from_tier': 'gold',
          },
          {
            'key': 'free_delivery_always',
            'text': 'توصيل مجاني بلا حد أدنى',
            'active': false,
            'from_tier': 'amb',
          },
        ],
      },
      'missions': {
        'period': '2026-09',
        'active': holdout ? 0 : 3,
        'completed': holdout ? 0 : 1,
        'items': holdout
            ? const []
            : [
                {
                  'id': 11,
                  'key': 'profile',
                  'kind': 'profile',
                  'title': 'أكمل ملف مشمش',
                  'body': 'الوزن وتاريخ الميلاد',
                  'target': 1,
                  'progress': 0,
                  'state': 'active',
                  'reward': {'kind': 'paws', 'paws': 100},
                },
                {
                  'id': 12,
                  'key': 'frequency',
                  'kind': 'frequency',
                  'title': '3 طلبات هذا الشهر',
                  'target': 3,
                  'progress': 2,
                  'state': 'active',
                  'reward': {'kind': 'paws', 'paws': 300},
                },
                {
                  'id': 13,
                  'key': 'try_new_brand',
                  'kind': 'trial',
                  'title': 'جرّب ماركة جديدة',
                  'target': 1,
                  'progress': 1,
                  'state': 'rewarded',
                  'reward': {
                    'kind': 'reward',
                    'reward': {
                      'id': 4,
                      'kind': 'gift_product',
                      'title': 'هدية صغيرة',
                      'paws_cost': 600,
                    },
                  },
                  'suggested_products': [
                    {'id': 900, 'name': 'رويال كانين', 'price': 89},
                  ],
                },
              ],
      },
      'rewards': {
        'active_count': holdout ? 0 : 2,
        'sealed_scratch':
            holdout ? const [] : [{'id': 88, 'order_number': '32579'}],
      },
      'pets': [
        {
          'id': 7,
          'name': 'مشمش',
          'species': 'cat',
          'breed': 'شيرازي',
          'sex': 'm',
          'weight_kg': '4.20',
          'birth_date': '2024-06-14',
          'age_label': 'سنتان و3 أشهر',
          'neutered': 1,
          'avatar': '',
          'is_complete': true,
          'birthday_in_days': 5,
        },
      ],
      'counters': {'orders_total': 17, 'orders_app': 3},
    };

void main() {
  group('LoyaltySummary', () {
    test('parses the full summary from the spec', () {
      final summary = LoyaltySummary.fromJson(_summaryJson());

      expect(summary.member.holdout, isFalse);
      expect(summary.member.referralCode, 'ZB7K2QX');
      expect(summary.member.joinedAt?.year, 2026);

      expect(summary.paws.balance, 1240);
      expect(summary.paws.pending, 120);
      expect(summary.paws.expiresAt, isNotNull);

      expect(summary.tier.key, 'star');
      expect(summary.tier.name, 'مميّز');
      expect(summary.tier.nameEn, 'Star');
      expect(summary.tier.orders12m, 5);
      expect(summary.tier.next?.key, 'gold');
      expect(summary.tier.perks, hasLength(3));
      expect(summary.tier.perks.first.active, isTrue);
      expect(summary.tier.perks[1].fromTier, 'gold');
      expect(summary.tier.perks[2].key, 'free_delivery_always');

      expect(summary.missions.period, '2026-09');
      expect(summary.missions.items, hasLength(3));
      expect(summary.rewards.activeCount, 2);
      expect(summary.rewards.sealedScratch.single.orderNumber, '32579');
      expect(summary.counters.ordersTotal, 17);
      expect(summary.playsGames, isTrue);
      expect(summary.hasSealedScratch, isTrue);
    });

    test('the nearest mission is the closest one still open', () {
      final summary = LoyaltySummary.fromJson(_summaryJson());
      // 2/3 beats 0/1, and the rewarded one is not a nudge any more.
      expect(summary.missions.nearest?.id, 12);
      expect(summary.missions.items.last.isDone, isTrue);
      expect(summary.missions.items.last.ratio, 1);
      expect(summary.missions.items[1].ratio, closeTo(2 / 3, 0.0001));
    });

    test('a mission reward can be paws or a catalog reward', () {
      final summary = LoyaltySummary.fromJson(_summaryJson());
      expect(summary.missions.items.first.reward.isPaws, isTrue);
      expect(summary.missions.items.first.reward.paws, 100);

      final gift = summary.missions.items.last.reward;
      expect(gift.isPaws, isFalse);
      expect(gift.reward?.title, 'هدية صغيرة');
      expect(summary.missions.items.last.suggestedProducts, hasLength(1));
    });

    test('a holdout member keeps paws and tier but loses the play layer', () {
      final summary = LoyaltySummary.fromJson(_summaryJson(holdout: true));

      expect(summary.member.holdout, isTrue);
      expect(summary.playsGames, isFalse);
      expect(summary.missions.items, isEmpty);
      expect(summary.rewards.sealedScratch, isEmpty);
      expect(summary.hasSealedScratch, isFalse);

      // The half of the program everyone gets is untouched.
      expect(summary.paws.balance, 1240);
      expect(summary.tier.key, 'star');
      expect(summary.tier.perks, hasLength(3));
    });

    test('an empty payload resolves rather than throws', () {
      final summary = LoyaltySummary.fromJson(const {});
      expect(summary.paws.balance, 0);
      expect(summary.tier.key, 'new');
      expect(summary.pets, isEmpty);
      expect(summary.missions.nearest, isNull);
    });
  });

  group('tier progress', () {
    TierInfo tier({
      required int orders,
      required int min,
      Map<String, dynamic>? next,
      int? serverProgress,
    }) =>
        TierInfo.fromJson({
          'key': 'star',
          'orders_12m': orders,
          'min': min,
          'next': next,
          'progress': serverProgress,
        });

    test('is the fraction of the way from this tier floor to the next', () {
      final star = tier(orders: 5, min: 4, next: {'key': 'gold', 'min': 8});
      expect(star.progress, closeTo(0.25, 0.0001));
      expect(star.isTop, isFalse);
    });

    test('the top tier is simply full', () {
      final top = tier(orders: 20, min: 14);
      expect(top.isTop, isTrue);
      expect(top.progress, 1);
      expect(top.ordersToNext, 0);
    });

    test('clamps below the floor and above the ceiling', () {
      expect(tier(orders: 2, min: 4, next: {'key': 'gold', 'min': 8}).progress, 0);
      expect(tier(orders: 99, min: 4, next: {'key': 'gold', 'min': 8}).progress, 1);
    });

    test('falls back to the server percentage when the bounds are useless', () {
      final odd = tier(
        orders: 5,
        min: 8,
        next: {'key': 'gold', 'min': 8},
        serverProgress: 40,
      );
      expect(odd.progress, closeTo(0.4, 0.0001));
    });

    test('orders-to-next prefers the server count and derives it otherwise', () {
      final stated = TierInfo.fromJson({
        'orders_12m': 5,
        'min': 4,
        'next': {'key': 'gold', 'min': 8, 'orders_needed': 3},
      });
      expect(stated.ordersToNext, 3);

      final derived = TierInfo.fromJson({
        'orders_12m': 5,
        'min': 4,
        'next': {'key': 'gold', 'min': 8},
      });
      expect(derived.ordersToNext, 3);

      // Already past the threshold but not yet recomputed server-side.
      final past = TierInfo.fromJson({
        'orders_12m': 9,
        'min': 4,
        'next': {'key': 'gold', 'min': 8},
      });
      expect(past.ordersToNext, 0);
    });
  });

  group('Pet', () {
    test('carries the server age label and the birthday countdown', () {
      final pet = LoyaltySummary.fromJson(_summaryJson()).pets.single;

      expect(pet.name, 'مشمش');
      expect(pet.species, PetSpecies.cat);
      expect(pet.ageLabel, 'سنتان و3 أشهر');
      expect(pet.weightKg, 4.2);
      expect(pet.birthDate, DateTime(2024, 6, 14));
      expect(pet.neutered, isTrue);
      expect(pet.isComplete, isTrue);
      expect(pet.birthdayInDays, 5);
      expect(pet.isBirthdaySoon, isTrue);
    });

    test('an absent age label is null, not an empty line on the card', () {
      final pet = Pet.fromJson(const {
        'id': 3,
        'name': 'بسبس',
        'species': 'small',
        'age_label': '',
      });
      expect(pet.ageLabel, isNull);
      expect(pet.birthdayInDays, isNull);
      expect(pet.isBirthdaySoon, isFalse);
      expect(pet.neutered, isNull);
      expect(pet.isComplete, isFalse);
    });

    test('an unknown species lands on `other` instead of breaking the list', () {
      expect(Pet.fromJson(const {'species': 'axolotl'}).species, PetSpecies.other);
      expect(Pet.fromJson(const {'species': 'REPTILE'}).species, PetSpecies.reptile);
    });

    test('the write shape omits what was never filled in', () {
      const bare0 = Pet(id: 0, name: 'ريم', species: PetSpecies.dog);
      final bare = bare0.toJson();
      expect(bare, {'name': 'ريم', 'species': 'dog'});

      final full = Pet(
        id: 1,
        name: 'ريم',
        species: PetSpecies.dog,
        breed: 'هاسكي',
        sex: 'f',
        weightKg: 12.5,
        birthDate: DateTime(2023, 1, 9),
        neutered: false,
      ).toJson();
      expect(full['birth_date'], '2023-01-09');
      expect(full['weight_kg'], 12.5);
      expect(full['neutered'], isFalse);
    });
  });

  group('Reward kinds', () {
    Reward of(String kind) => Reward.fromJson({'id': 1, 'kind': kind});

    test('separates the express upgrade from full free delivery', () {
      expect(of('express_free').isExpressFree, isTrue);
      expect(of('express_free').isFreeDelivery, isFalse);
      expect(of('express_free').isService, isTrue);

      expect(of('free_delivery').isFreeDelivery, isTrue);
      expect(of('free_delivery').isExpressFree, isFalse);
      expect(of('free_delivery').isService, isTrue);

      expect(of('gift_product').isGift, isTrue);
      expect(of('gift_product').isService, isFalse);
      expect(of('paws').isPaws, isTrue);
    });

    test('a kind this build has never seen is inert, not fatal', () {
      final unknown = of('mystery_box_v2');
      expect(unknown.isGift, isFalse);
      expect(unknown.isService, isFalse);
      expect(unknown.isPaws, isFalse);
      expect(unknown.kind, 'mystery_box_v2');
    });

    test('the refusal reason is read in the reading language', () {
      final reward = Reward.fromJson(const {
        'id': 2,
        'kind': 'gift_product',
        'redeemable': false,
        'reason_ar': 'بصماتك لا تكفي',
        'reason_en': 'Not enough paws',
      });
      expect(reward.reasonFor('ar'), 'بصماتك لا تكفي');
      expect(reward.reasonFor('en'), 'Not enough paws');
      expect(Reward.fromJson(const {'id': 3}).reasonFor('ar'), isNull);
    });
  });

  group('Grant and ScratchCard', () {
    test('a pending grant is not claimable and names its order', () {
      final grant = Grant.fromJson(const {
        'id': 5,
        'reward': {'id': 9, 'kind': 'express_free', 'title': 'ترقية سريع'},
        'source': 'scratch',
        'state': 'pending',
        'activates_on_order': {'id': 4001, 'number': '32579'},
        'claimed': false,
      });
      expect(grant.isPending, isTrue);
      expect(grant.isClaimable, isFalse);
      expect(grant.activatesOnOrder?.number, '32579');
      expect(grant.reward.isExpressFree, isTrue);
    });

    test('a claimed grant is active but no longer offerable', () {
      final grant = Grant.fromJson(const {
        'id': 6,
        'reward': {'id': 9, 'kind': 'gift_product'},
        'state': 'claimed',
        'claimed': true,
      });
      expect(grant.isClaimed, isTrue);
      expect(grant.isClaimable, isFalse);
    });

    test('a sealed card carries its prize and its activation wording', () {
      final card = ScratchCard.fromJson(const {
        'id': 88,
        'order': {'id': 4001, 'number': '32579'},
        'state': 'sealed',
        'prize': {'kind': 'paws', 'paws': 50},
        'settled': false,
        'activation_hint_ar': 'تُفعَّل عند تسليم الطلب',
        'activation_hint_en': 'Activates when your order is delivered',
      });
      expect(card.isSealed, isTrue);
      expect(card.prize.isPaws, isTrue);
      expect(card.prize.paws, 50);
      expect(card.settled, isFalse);
      expect(card.activationHintFor('ar'), 'تُفعَّل عند تسليم الطلب');
      expect(card.activationHintFor('en'), startsWith('Activates'));
    });

    test('no card on an order is null, not an empty card', () {
      expect(ScratchCard.maybe(null), isNull);
      expect(ScratchCard.maybe(const <String, dynamic>{}), isNull);
      expect(ScratchCard.maybe(const {'id': 0}), isNull);
      expect(ScratchCard.maybe(const {'id': 7})?.id, 7);
    });
  });

  group('CartLoyalty', () {
    test('reads both waived-fee reasons independently', () {
      final loyalty = CartLoyalty.fromJson(const {
        'paws_to_earn': 240,
        'holdout': false,
        'claims': [
          {
            'id': 5,
            'reward': {'id': 9, 'kind': 'gift_product'},
            'state': 'claimed',
            'claimed': true,
          },
        ],
        'free_delivery_reason': null,
        'express_free_reason': 'tier',
      });

      expect(loyalty.pawsToEarn, 240);
      expect(loyalty.freeDeliveryReason, isNull);
      expect(loyalty.expressFreeReason, 'tier');
      expect(loyalty.hasDeliveryPerk, isTrue);
      expect(loyalty.claims.single.isClaimed, isTrue);
    });

    test('drops a reason the app has no wording for', () {
      final loyalty = CartLoyalty.fromJson(const {
        'free_delivery_reason': 'promo_week',
        'express_free_reason': '',
      });
      expect(loyalty.freeDeliveryReason, isNull);
      expect(loyalty.expressFreeReason, isNull);
      expect(loyalty.hasDeliveryPerk, isFalse);
    });

    test('a cart with no loyalty block still parses', () {
      final cart = CartData.fromJson(const {
        'items': [
          {'key': 'a', 'product_id': 1, 'name': 'طعام', 'qty': 2, 'unit_price': 10},
        ],
        'count': 2,
      });
      expect(cart.loyalty.pawsToEarn, 0);
      expect(cart.loyalty.hasDeliveryPerk, isFalse);
      expect(cart.giftItems, isEmpty);
      expect(cart.items.single.isGift, isFalse);
    });

    test('a gift line is flagged, locked and grant-linked', () {
      final cart = CartData.fromJson(const {
        'items': [
          {
            'key': 'gift-1',
            'product_id': 55,
            'name': '🎁 هدية · لعبة قطط',
            'qty': 1,
            'unit_price': 0,
            'line_total': 0,
            'is_gift': true,
            'grant_id': 123,
            'locked_qty': true,
          },
        ],
        'count': 1,
        'loyalty': {'paws_to_earn': 0},
      });

      final gift = cart.giftItems.single;
      expect(gift.isGift, isTrue);
      expect(gift.grantId, 123);
      expect(gift.lockedQty, isTrue);
      expect(gift.lineTotal, 0);

      // Optimistic copies must not quietly launder a gift into a normal line.
      expect(cart.withItemQty('gift-1', 3).items.single.isGift, isTrue);
      expect(cart.withItemQty('gift-1', 3).items.single.grantId, 123);
      expect(cart.withoutItem('gift-1').giftItems, isEmpty);
    });
  });

  group('LedgerPage', () {
    test('parses entries and the has-more flag', () {
      final page = LedgerPage.fromJson(const {
        'items': [
          {
            'id': 1,
            'delta': 240,
            'balance_after': 1240,
            'reason': 'order_earn',
            'ref_type': 'order',
            'ref_id': 4001,
            'created_at': '2026-09-01T10:00:00Z',
          },
          {
            'id': 2,
            'delta': -400,
            'balance_after': 840,
            'reason': 'redeem',
            'note': 'توصيل مجاني',
          },
        ],
        'page': 1,
        'has_more': true,
      });

      expect(page.items, hasLength(2));
      expect(page.items.first.isCredit, isTrue);
      expect(page.items.last.isCredit, isFalse);
      expect(page.items.last.note, 'توصيل مجاني');
      expect(page.hasMore, isTrue);
    });
  });
}
