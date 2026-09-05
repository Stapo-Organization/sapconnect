import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';
import 'widgets/loyalty_art.dart';

/// The paws ledger — append-only, and shown that way.
///
/// The wallet sits at the top as an object (the coin, the balance, what is
/// still in the air and when it would lapse), and every line under it says
/// what happened, when, and what the balance was afterwards. A loyalty
/// currency people cannot audit is a currency they stop believing in, so
/// nothing here is summarised away.
class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final feed = ref.watch(ledgerProvider);
    final summary = ref.watch(loyaltySummaryProvider).value;
    final balance = ref.watch(pawsBalanceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.pawsLedgerTitle)),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(ledgerProvider);
          await ref.read(ledgerProvider.future);
        },
        child: AsyncView<LedgerFeed>(
          value: feed,
          onRetry: () => ref.invalidate(ledgerProvider),
          skeleton: const _LedgerSkeleton(),
          builder: (data) {
            final bottom = 28 + MediaQuery.paddingOf(context).bottom;
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _WalletCard(
                  balance: balance,
                  pending: summary?.pendingPaws ?? 0,
                  expiresAt: summary?.paws.expiresAt,
                ),
                Gap.h16,
                if (data.entries.isEmpty)
                  EmptyState(
                    icon: Icons.history_rounded,
                    title: l.pawsLedgerEmpty,
                    message: l.pawsLedgerEmptyHint,
                    mascot: true,
                  )
                else ...[
                  for (var i = 0; i < data.entries.length; i++) ...[
                    _LedgerRow(entry: data.entries[i]),
                    if (i < data.entries.length - 1) Gap.h8,
                  ],
                  if (data.hasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: OutlinedButton(
                        onPressed: () => ref.read(ledgerProvider.notifier).loadMore(),
                        child: Text(l.pawsLedgerMore),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The wallet as an object: coin, balance counted up, and the two facts that
/// matter about it — what is still landing, and when it would lapse.
class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.balance, required this.pending, this.expiresAt});

  final int balance;
  final int pending;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final dark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: dark
              ? [ZbTokens.amberContainerDark, ZbTokens.amberContainerDarkEnd]
              : [const Color(0xFFFDEBC2), const Color(0xFFFCF3DC)],
        ),
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: ZbTokens.amber.withValues(alpha: dark ? 0.3 : 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: PawPattern(color: Color(0xFF8A5F08), opacity: 0.07, scale: 0.9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                const PawCoin(size: 56),
                Gap.w16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.pawsWalletTitle,
                        style: context.tt.labelMedium?.copyWith(
                          color: dark ? ZbTokens.amberOnDark : const Color(0xFF8A5F08),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          CountUp(
                            value: balance,
                            format: (v) => Fmt.number(v, locale: locale, decimals: 0),
                            style: context.tt.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              height: 1.1,
                            ),
                          ),
                          Gap.w6,
                          Text(l.pawsUnit, style: context.tt.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                      if (pending > 0 || expiresAt != null)
                        Text(
                          [
                            if (pending > 0) l.pawsPending(Fmt.number(pending, locale: locale, decimals: 0)),
                            if (expiresAt != null) l.pawsExpires(Fmt.dateShort(expiresAt!, locale)),
                          ].join(' · '),
                          style: context.tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;
    final credit = entry.isCredit;
    final accent = credit ? zb.success : cs.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          PawCoin(size: 30, muted: !credit),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.pawsReason(entry.reason),
                  style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Gap.h4,
                Text(
                  [
                    if (entry.createdAt != null) Fmt.dateShort(entry.createdAt!, locale),
                    if (entry.note.isNotEmpty) entry.note,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Gap.w8,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${credit ? '+' : '−'}${Fmt.number(entry.delta.abs(), locale: locale, decimals: 0)}',
                style: context.tt.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                l.pawsBalanceAfter(Fmt.number(entry.balanceAfter, locale: locale, decimals: 0)),
                style: context.tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerSkeleton extends StatelessWidget {
  const _LedgerSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: const [
            SkeletonBox(width: double.infinity, height: 104, radius: ZbTokens.rXl),
            Gap.h16,
            SkeletonBox(width: double.infinity, height: 66, radius: ZbTokens.rLg),
            Gap.h8,
            SkeletonBox(width: double.infinity, height: 66, radius: ZbTokens.rLg),
            Gap.h8,
            SkeletonBox(width: double.infinity, height: 66, radius: ZbTokens.rLg),
          ],
        ),
      );
}
