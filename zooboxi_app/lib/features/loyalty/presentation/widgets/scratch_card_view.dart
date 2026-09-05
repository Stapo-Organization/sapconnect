import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/analytics/events_buffer.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/sparkles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_models.dart';
import '../../data/loyalty_repository.dart';
import 'loyalty_art.dart';
import 'scratch_canvas.dart';

/// The whole «اخدش واربح» moment: the foil, the prize under it, and the one
/// sentence that keeps the promise honest — this is real when the order is
/// delivered, not when the foil comes off.
///
/// The same widget is embedded in the checkout success screen and shown on its
/// own at `/family/scratch/:id`, so a card that was left sealed at checkout is
/// literally the same object when it is opened later.
class ScratchCardView extends ConsumerStatefulWidget {
  const ScratchCardView({
    super.key,
    required this.card,
    this.onDone,
    this.doneLabel,
    this.compact = false,
  });

  final ScratchCard card;

  /// Shown as the closing button once the prize is out.
  final VoidCallback? onDone;
  final String? doneLabel;

  /// Tighter proportions for the embedded case, where the card shares a screen
  /// with the order receipt.
  final bool compact;

  @override
  ConsumerState<ScratchCardView> createState() => _ScratchCardViewState();
}

class _ScratchCardViewState extends ConsumerState<ScratchCardView> {
  late ScratchCard _card = widget.card;
  bool _revealing = false;

  bool get _open => !_card.isSealed;

  Future<void> _reveal() async {
    if (_revealing) return;
    setState(() => _revealing = true);

    ref.read(eventsBufferProvider).track(
          ZbEvent(
            type: ZbEvents.loyaltyScratch,
            zone: 'checkout',
            payload: {'card_id': _card.id, 'prize_kind': _card.prize.kind},
          ),
        );

    try {
      final fresh = await ref.read(loyaltyRepositoryProvider).reveal(_card.id);
      if (!mounted) return;
      setState(() => _card = fresh);
      invalidateLoyalty(ref);
    } catch (_) {
      // The foil is already off and the prize was in the payload — a failed
      // reveal means the *server* hasn't recorded it, so the card simply comes
      // back sealed next time. Never take the moment away over a 500.
      if (!mounted) return;
      setState(() => _card = ScratchCard(
            id: _card.id,
            order: _card.order,
            state: 'revealed',
            prize: _card.prize,
            settled: _card.settled,
            activationHintAr: _card.activationHintAr,
            activationHintEn: _card.activationHintEn,
          ));
    } finally {
      if (mounted) setState(() => _revealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: widget.compact ? 2.05 : 1.55,
          child: ScratchCanvas(
            revealed: _open,
            label: l.scratchTitle,
            hint: l.scratchHint,
            onRevealed: _reveal,
            child: _PrizeFace(card: _card, pending: _revealing),
          ),
        ),
        Gap.h12,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _open
              ? Column(
                  key: const ValueKey('open'),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FamilyMarkIcon(
                          _card.settled ? FamilyMark.check : FamilyMark.clock,
                          size: 16,
                          color: _card.settled ? context.zb.success : null,
                        ),
                        Gap.w6,
                        Flexible(
                          child: Text(
                            _card.settled
                                ? l.scratchSettled
                                : _card.activationHintFor(locale) ?? l.scratchActivation,
                            textAlign: TextAlign.center,
                            style: context.tt.bodySmall?.copyWith(
                              color: _card.settled
                                  ? context.zb.success
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.onDone != null) ...[
                      Gap.h12,
                      FilledButton(
                        onPressed: widget.onDone,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: Text(widget.doneLabel ?? l.scratchDone),
                      ),
                    ],
                  ],
                )
              : Text(
                  _card.order == null
                      ? l.scratchHint
                      : l.scratchOrder(_card.order!.number),
                  key: const ValueKey('sealed'),
                  textAlign: TextAlign.center,
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
        ),
      ],
    );
  }
}

/// What is under the foil. It exists before the first rub — the prize was
/// drawn when the order was placed — so uncovering it is genuinely uncovering
/// something rather than triggering a fetch.
class _PrizeFace extends StatelessWidget {
  const _PrizeFace({required this.card, this.pending = false});

  final ScratchCard card;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final prize = card.prize;
    final unknown = prize.isPaws && prize.paws <= 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.isDark ? cs.surfaceContainerHigh : ZbTokens.creamLogo,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SparkleField(sparkles: _prizeSparkles, twinkle: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unknown && pending)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else ...[
                  RewardSticker(kind: prize.isPaws ? 'paws' : prize.reward!.kind, size: 64),
                  Gap.h8,
                  Text(
                    prize.isPaws
                        ? l.scratchPrizePaws(
                            Fmt.number(prize.paws, locale: locale, decimals: 0),
                          )
                        : prize.reward!.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleMedium?.copyWith(
                      color: ZbTokens.inkWarm,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<SparkleSpec> _prizeSparkles = [
  SparkleSpec(dx: 0.12, dy: 0.20, size: 13, color: ZbTokens.sparkAmber, delay: Duration(milliseconds: 120)),
  SparkleSpec(dx: 0.86, dy: 0.24, size: 16, color: ZbTokens.logoCoral, delay: Duration(milliseconds: 220), rotation: 0.35),
  SparkleSpec(dx: 0.22, dy: 0.82, size: 11, color: ZbTokens.logoTeal, delay: Duration(milliseconds: 320)),
  SparkleSpec(dx: 0.78, dy: 0.84, size: 14, color: ZbTokens.sparkAmber, delay: Duration(milliseconds: 400), rotation: 0.2),
];

/// A one-line entry point to the moment, for the places that only have room
/// for a prompt: a sealed card in the family hub — drawn as the foil itself,
/// so it is unmistakably the thing that gets scratched.
class SealedScratchTile extends StatelessWidget {
  const SealedScratchTile({super.key, required this.orderNumber, required this.onTap});

  final String orderNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE9ECEE), Color(0xFFC3C9CE), Color(0xFFD8DDE0), Color(0xFFB9C0C5)],
              stops: [0.0, 0.42, 0.7, 1.0],
            ),
            borderRadius: BorderRadius.circular(ZbTokens.rXl),
            border: Border.all(color: const Color(0xFF9DA5AB).withValues(alpha: 0.5)),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: PawPattern(color: ZbTokens.tealDeep, opacity: 0.10, scale: 0.8),
              ),
              const Positioned.fill(child: SparkleField(sparkles: _foilSparkles, twinkle: true)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    const RewardSticker(kind: 'gift_product', size: 46),
                    Gap.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.scratchTitle,
                            style: context.tt.titleSmall?.copyWith(
                              color: ZbTokens.tealDeep,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Gap.h4,
                          Text(
                            orderNumber.isEmpty ? l.scratchHint : l.scratchOrder(orderNumber),
                            style: context.tt.bodySmall?.copyWith(color: const Color(0xFF3E4A50)),
                          ),
                        ],
                      ),
                    ),
                    Gap.w12,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: ZbTokens.tealDeep,
                        borderRadius: BorderRadius.circular(ZbTokens.rPill),
                      ),
                      child: Text(
                        l.scratchOpen,
                        style: context.tt.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<SparkleSpec> _foilSparkles = [
  SparkleSpec(dx: 0.36, dy: 0.18, size: 9, color: Colors.white, delay: Duration(milliseconds: 200)),
  SparkleSpec(dx: 0.62, dy: 0.80, size: 7, color: Colors.white, delay: Duration(milliseconds: 700), rotation: 0.4),
];
