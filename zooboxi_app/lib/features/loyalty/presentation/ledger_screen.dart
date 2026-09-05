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
import 'widgets/paws_pill.dart';

/// The paws ledger — append-only, and shown that way.
///
/// Every line says what happened, when, and what the balance was afterwards.
/// A loyalty currency people cannot audit is a currency they stop believing
/// in, so nothing here is summarised away.
class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final feed = ref.watch(ledgerProvider);
    final balance = ref.watch(pawsBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.pawsLedgerTitle),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(child: PawsPill(paws: balance, compact: true)),
          ),
        ],
      ),
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
            if (data.entries.isEmpty) {
              return EmptyState(
                icon: Icons.history_rounded,
                title: l.pawsLedgerEmpty,
                message: l.pawsLedgerEmptyHint,
                mascot: true,
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: data.entries.length + (data.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => Gap.h8,
              itemBuilder: (context, index) {
                if (index == data.entries.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton(
                      onPressed: () =>
                          ref.read(ledgerProvider.notifier).loadMore(),
                      child: Text(l.pawsLedgerMore),
                    ),
                  );
                }
                return _LedgerRow(entry: data.entries[index]);
              },
            );
          },
        ),
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
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: context.isDark ? 0.18 : 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              credit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 17,
              color: accent,
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.pawsReason(entry.reason),
                  style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Gap.h4,
                Text(
                  [
                    if (entry.createdAt != null)
                      Fmt.dateShort(entry.createdAt!, locale),
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
                style: context.tt.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                l.pawsBalanceAfter(
                  Fmt.number(entry.balanceAfter, locale: locale, decimals: 0),
                ),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            SkeletonBox(width: double.infinity, height: 62, radius: ZbTokens.rMd),
            Gap.h8,
            SkeletonBox(width: double.infinity, height: 62, radius: ZbTokens.rMd),
            Gap.h8,
            SkeletonBox(width: double.infinity, height: 62, radius: ZbTokens.rMd),
            Gap.h8,
            SkeletonBox(width: double.infinity, height: 62, radius: ZbTokens.rMd),
          ],
        ),
      );
}
