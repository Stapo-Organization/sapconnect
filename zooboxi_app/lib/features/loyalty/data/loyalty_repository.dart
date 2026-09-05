import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../cart/data/cart_models.dart';
import 'loyalty_models.dart';

/// What a claim (or an un-claim) returned: the server's fresh cart plus the
/// grant in its new state. The cart is the half that matters — the app never
/// splices a gift line in itself.
typedef ClaimResult = ({CartData cart, Grant grant});

class LoyaltyRepository {
  LoyaltyRepository(this._api);

  final ApiClient _api;

  Future<LoyaltySummary> summary() async =>
      LoyaltySummary.fromJson(asMap(await _api.get('/loyalty/summary')));

  Future<LedgerPage> ledger({int page = 1}) async =>
      LedgerPage.fromJson(asMap(await _api.get('/loyalty/ledger', query: {'page': page})));

  Future<RewardsCatalog> rewards() async =>
      RewardsCatalog.fromJson(asMap(await _api.get('/loyalty/rewards')));

  Future<RedeemResult> redeem(int rewardId) async =>
      RedeemResult.fromJson(asMap(await _api.post('/loyalty/rewards/$rewardId/redeem')));

  Future<ClaimResult> claim(int grantId) async =>
      _claimResult(await _api.post('/loyalty/grants/$grantId/claim'));

  Future<ClaimResult> unclaim(int grantId) async =>
      _claimResult(await _api.delete('/loyalty/grants/$grantId/claim'));

  Future<MissionsBlock> missions() async =>
      MissionsBlock.fromJson(asMap(await _api.get('/loyalty/missions')));

  Future<List<ScratchCard>> scratchCards() async =>
      ScratchCard.listFrom(await _api.get('/loyalty/scratch'));

  Future<ScratchCard> reveal(int cardId) async =>
      ScratchCard.fromJson(asMap(await _api.post('/loyalty/scratch/$cardId/reveal')));

  static ClaimResult _claimResult(dynamic data) {
    final map = asMap(data);
    return (
      cart: CartData.fromJson(asMap(map['cart'])),
      grant: Grant.fromJson(asMap(map['grant'])),
    );
  }
}

final loyaltyRepositoryProvider =
    Provider<LoyaltyRepository>((ref) => LoyaltyRepository(ref.watch(apiClientProvider)));

/// The one read every loyalty surface hangs off.
///
/// It resolves to `null` for a guest instead of firing a call that would 401 —
/// the same contract [buyAgainProvider] keeps — so Home and Account can watch
/// it unconditionally and simply draw nothing. Once it has an answer it is
/// kept alive for the session: the home card, the account header and the
/// family hub are three readers of one payload, not three requests.
final loyaltySummaryProvider = FutureProvider.autoDispose<LoyaltySummary?>((ref) async {
  final session = ref.watch(sessionProvider.select((s) => (s.status, s.user?.id)));
  if (session.$1 != AuthStatus.authenticated) return null;

  final summary = await ref.watch(loyaltyRepositoryProvider).summary();
  ref.keepAlive();
  return summary;
});

/// The wallet as a bare number, for the header chip and the totals line — so a
/// balance change doesn't rebuild everything that watches the whole summary.
final pawsBalanceProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(loyaltySummaryProvider).value?.paws.balance ?? 0,
);

final loyaltyRewardsProvider = FutureProvider.autoDispose<RewardsCatalog>((ref) {
  if (!ref.watch(sessionProvider).isAuthenticated) {
    return Future.value(RewardsCatalog.empty);
  }
  return ref.watch(loyaltyRepositoryProvider).rewards();
});

/// Grants that can be carried into the cart right now. Drives whether the
/// cart shows «استخدم مكافأة» at all — an empty list hides it, and so does a
/// failed read, because a loyalty outage must never block a checkout.
final claimableGrantsProvider = Provider.autoDispose<List<Grant>>((ref) {
  final catalog = ref.watch(loyaltyRewardsProvider).value;
  if (catalog == null) return const [];
  return catalog.grants.where((grant) => grant.isClaimable).toList();
});

final loyaltyMissionsProvider = FutureProvider.autoDispose<MissionsBlock>((ref) {
  if (!ref.watch(sessionProvider).isAuthenticated) {
    return Future.value(MissionsBlock.empty);
  }
  return ref.watch(loyaltyRepositoryProvider).missions();
});

final scratchCardsProvider = FutureProvider.autoDispose<List<ScratchCard>>((ref) {
  if (!ref.watch(sessionProvider).isAuthenticated) {
    return Future.value(const <ScratchCard>[]);
  }
  return ref.watch(loyaltyRepositoryProvider).scratchCards();
});

/// The ledger as the screen reads it: every page fetched so far, appended.
@immutable
class LedgerFeed {
  const LedgerFeed({this.entries = const [], this.page = 1, this.hasMore = false});

  final List<LedgerEntry> entries;
  final int page;
  final bool hasMore;

  static const LedgerFeed empty = LedgerFeed();
}

/// Append-only in the UI too: pages accumulate, nothing is ever re-ordered.
class LedgerController extends AsyncNotifier<LedgerFeed> {
  bool _loadingMore = false;

  @override
  Future<LedgerFeed> build() async {
    if (!ref.watch(sessionProvider).isAuthenticated) return LedgerFeed.empty;
    final page = await ref.read(loyaltyRepositoryProvider).ledger();
    return LedgerFeed(entries: page.items, page: page.page, hasMore: page.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await ref.read(loyaltyRepositoryProvider).ledger(page: current.page + 1);
      state = AsyncValue.data(
        LedgerFeed(
          entries: [...current.entries, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {
      // A failed page must not blank the pages already read.
    } finally {
      _loadingMore = false;
    }
  }
}

final ledgerProvider =
    AsyncNotifierProvider.autoDispose<LedgerController, LedgerFeed>(LedgerController.new);

/// Re-reads everything the loyalty layer caches. Called after any write that
/// moves the wallet: a redeem, a reveal, a saved pet, a claimed gift.
///
/// One function rather than five `ref.invalidate` lines at each call site,
/// because forgetting one of them is how a balance and a ledger end up
/// disagreeing on the same screen.
void invalidateLoyalty(WidgetRef ref) {
  ref.invalidate(loyaltySummaryProvider);
  ref.invalidate(loyaltyRewardsProvider);
  ref.invalidate(loyaltyMissionsProvider);
  ref.invalidate(scratchCardsProvider);
  ref.invalidate(ledgerProvider);
}
