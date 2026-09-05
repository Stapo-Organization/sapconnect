import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/sparkles.dart';
import '../../../l10n/app_localizations.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';
import 'widgets/loyalty_art.dart';

/// Hand the referral to the OS share sheet. Shared by the hub card and the
/// screen so both send the same words.
Future<void> shareReferral(WidgetRef ref, {required String text, required String url}) async {
  ref.track(const ZbEvent(type: ZbEvents.referralShare, zone: 'referral'));
  final body = text.isNotEmpty ? text : url;
  await SharePlus.instance.share(ShareParams(text: body));
}

/// «ادعُ صديقاً» — the code, the link, the promise, and what came of it.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _codeController = TextEditingController();
  bool _applying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    Haptics.selection();
    AppToast.success(context, L.of(context).referralCopied);
  }

  Future<void> _apply() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _applying) return;
    final l = L.of(context);
    setState(() => _applying = true);
    try {
      final result = await ref.read(loyaltyRepositoryProvider).applyReferral(code);
      if (!mounted) return;
      unawaited(Haptics.success());
      AppToast.success(context, l.referralApplied(result.code));
      _codeController.clear();
      invalidateLoyalty(ref);
    } catch (e) {
      if (!mounted) return;
      Haptics.warning();
      AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final referral = ref.watch(referralProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.referralTitle)),
      body: AsyncView<ReferralOverview>(
        value: referral,
        onRetry: () => ref.invalidate(referralProvider),
        skeleton: const _Skeleton(),
        builder: (data) => ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // The code card.
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [ZbTokens.logoTeal, ZbTokens.tealDeep],
                ),
                borderRadius: BorderRadius.circular(ZbTokens.rXl),
                boxShadow: [
                  BoxShadow(color: ZbTokens.tealDeep.withValues(alpha: 0.25), blurRadius: 22, offset: const Offset(0, 10)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  const Positioned.fill(child: PawPattern(opacity: 0.12, scale: 1.1)),
                  const Positioned.fill(child: SparkleField(sparkles: _sparkles, twinkle: true)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FamilyMarkIcon(FamilyMark.share, size: 40),
                            Gap.w12,
                            Expanded(
                              child: Text(
                                l.referralHubBody(Fmt.number(data.rewardPaws, locale: locale, decimals: 0)),
                                style: context.tt.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                        Gap.h16,
                        Text(
                          l.referralYourCode,
                          style: context.tt.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700),
                        ),
                        Gap.h4,
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(ZbTokens.rLg),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  data.code,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.center,
                                  style: context.tt.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                            ),
                            Gap.w8,
                            IconButton.filledTonal(
                              onPressed: () => _copy(data.code),
                              icon: const Icon(Icons.copy_rounded),
                              tooltip: l.referralCopy,
                              style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.22), foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                        Gap.h12,
                        FilledButton.icon(
                          onPressed: data.code.isEmpty ? null : () => shareReferral(ref, text: data.shareText, url: data.url),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 46),
                            backgroundColor: ZbTokens.logoCoral,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.ios_share_rounded, size: 20),
                          label: Text(l.referralShare),
                        ),
                        Gap.h8,
                        Text(
                          l.referralCap(data.thisMonth, data.cap),
                          style: context.tt.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Gap.h16,

            // Stats.
            Row(
              children: [
                _Stat(label: l.referralStatsInvited, value: data.invited, color: ZbTokens.logoTeal),
                Gap.w8,
                _Stat(label: l.referralStatsQualified, value: data.qualified, color: ZbTokens.amber),
                Gap.w8,
                _Stat(label: l.referralStatsRewarded, value: data.rewarded, color: ZbTokens.logoCoral),
              ],
            ),
            Gap.h20,

            // How it works.
            Text(l.referralHow, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Gap.h8,
            for (final (i, line) in [
              l.referralHow1,
              l.referralHow2(data.welcome),
              l.referralHow3(Fmt.number(data.rewardPaws, locale: locale, decimals: 0)),
            ].indexed) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: ZbTokens.logoTeal.withValues(alpha: 0.14), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${i + 1}', style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: ZbTokens.tealDeep)),
                  ),
                  Gap.w10,
                  Expanded(child: Text(line, style: context.tt.bodyMedium?.copyWith(height: 1.5))),
                ],
              ),
              Gap.h8,
            ],
            Gap.h16,

            // Apply a friend's code (only while it still can be applied).
            if (data.hasApplied)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(ZbTokens.rLg),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    const FamilyMarkIcon(FamilyMark.check, size: 20),
                    Gap.w8,
                    Expanded(child: Text(l.referralAppliedBefore(data.appliedCode!), style: context.tt.bodySmall)),
                  ],
                ),
              )
            else ...[
              Text(l.referralHaveCode, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              Gap.h8,
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      textDirection: TextDirection.ltr,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), LengthLimitingTextInputFormatter(12)],
                      decoration: InputDecoration(hintText: l.referralEnterCode),
                      onSubmitted: (_) => _apply(),
                    ),
                  ),
                  Gap.w8,
                  FilledButton(
                    onPressed: _applying ? null : _apply,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: _applying
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.referralApply),
                  ),
                ],
              ),
            ],
            Gap.h20,

            // The list.
            if (data.items.isEmpty)
              Text(l.referralEmpty, textAlign: TextAlign.center, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
            else
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(ZbTokens.rXl),
                  border: Border.all(color: cs.outlineVariant),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < data.items.length; i++) ...[
                      if (i > 0) Divider(color: cs.outlineVariant.withValues(alpha: 0.7), height: 1),
                      _ReferralRow(item: data.items[i], locale: locale),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const List<SparkleSpec> _sparkles = [
  SparkleSpec(dx: 0.90, dy: 0.14, size: 14, color: Colors.white, delay: Duration(milliseconds: 300)),
  SparkleSpec(dx: 0.96, dy: 0.50, size: 9, color: Colors.white, delay: Duration(milliseconds: 900), rotation: 0.4),
];

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              Fmt.number(value, locale: locale, decimals: 0),
              style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
            Text(label, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ReferralRow extends StatelessWidget {
  const _ReferralRow({required this.item, required this.locale});

  final ReferralItem item;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final (label, color, mark) = switch (item.state) {
      'rewarded' => (l.referralStateRewarded, ZbTokens.success, FamilyMark.check),
      'qualified' => (l.referralStateQualified, ZbTokens.amber, FamilyMark.clock),
      'review' => (l.referralStateReview, ZbTokens.amber, FamilyMark.clock),
      'rejected' => (l.referralStateRejected, cs.onSurfaceVariant, FamilyMark.lock),
      _ => (l.referralStatePending, ZbTokens.logoTeal, FamilyMark.family),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          FamilyMarkIcon(mark, size: 22, color: color),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, style: context.tt.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (item.createdAt != null)
            Text(Fmt.dateShort(item.createdAt!, locale), style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: const [
            SkeletonBox(height: 220, radius: 20),
            Gap.h16,
            SkeletonBox(height: 70, radius: 16),
            Gap.h20,
            SkeletonBox(height: 120, radius: 16),
          ],
        ),
      );
}
