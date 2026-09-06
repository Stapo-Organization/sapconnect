import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/delivery/delivery_eta.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/location/location_controller.dart';
import '../../../../core/shelf/shelf_controller.dart';
import '../../../../core/shelf/shelf_identity.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/sparkles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';

/// The two storefronts, as signage above everything else.
///
/// Not a segmented control: two shop signs. Each carries its own glyph, name
/// and promise line, and the active one is filled with that store's own
/// gradient — ember for إكسبريس, the brand teal for زوبكسي — so the choice
/// reads as *which shop am I standing in*, not *which filter is on*. The
/// thumb slides with a spring and the incoming sign throws two sparkles, the
/// logo's own gesture.
///
/// Outside an express zone the إكسبريس sign stays up but dims and its promise
/// line changes to «غير متاح هنا»; tapping it explains instead of ignoring.
///
/// The إكسبريس line carries the branch's **opening hours** («9 ص – 11 م»), not
/// its speed. A shop sign says when the door is open; how fast the shop is
/// belongs to the order, and the header already answers that with an arrival
/// time. Out of hours the same line turns into «يفتح 9 ص».
class ShelfTabs extends ConsumerStatefulWidget {
  const ShelfTabs({
    super.key,
    this.onCanvas = false,
    this.hours,
    this.expressAvailable,
  });

  /// True when the tabs sit on the hero's deep-coloured canvas.
  final bool onCanvas;

  /// Today's express opening hours, from the shelf payload.
  final ExpressHours? hours;

  /// The server's live answer to "would express serve this address now?".
  /// The saved delivery type was decided when the address was chosen and does
  /// not know the branch has since closed, so this wins when it is present.
  final bool? expressAvailable;

  @override
  ConsumerState<ShelfTabs> createState() => _ShelfTabsState();
}

class _ShelfTabsState extends ConsumerState<ShelfTabs> {
  /// The side whose sparkles are currently flying, or null when at rest.
  Shelf? _celebrating;

  void _pick(
    Shelf target, {
    required Shelf current,
    required bool expressOpen,
  }) {
    final l = L.of(context);
    if (target == Shelf.express && !expressOpen) {
      Haptics.warning();
      AppToast.info(context, l.shelfExpressClosed);
      return;
    }
    if (target == current) return;
    Haptics.selection();
    ref.read(shelfProvider.notifier).select(target);
    if (!context.reduceMotion) {
      setState(() => _celebrating = target);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _celebrating = null);
      });
    }
  }

  /// What the إكسبريس sign says underneath its name: the branch's hours while
  /// they mean something, the reopening time once the shutter is down, and
  /// «غير متاح هنا» where there is no branch at all.
  String _expressLine(BuildContext context, L l, bool open) {
    final hours = widget.hours;
    final locale = Localizations.localeOf(context).languageCode;
    if (hours == null) {
      return open ? l.shelfExpressOpenNow : l.shelfExpressOffSub;
    }
    // A branch that keeps a schedule with today off is closed, not absent.
    if (hours.closedToday) return l.shelfExpressClosedToday;
    if (open) {
      return l.shelfExpressHours(
        Fmt.clockShort(timeOfDayToday(hours.openMinutes), locale),
        Fmt.clockShort(timeOfDayToday(hours.closeMinutes), locale),
      );
    }
    return l.shelfExpressOpensAt(
      Fmt.clockShort(timeOfDayToday(hours.openMinutes), locale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final shelf = ref.watch(shelfProvider);
    final bool expressOpen =
        widget.expressAvailable ?? ref.watch(expressAvailableProvider);
    // زوبكسي promises tomorrow inside a served city; out of town it ships.
    final shipping = ref.watch(
          locationProvider.select((s) => s.location.deliveryType),
        ) ==
        'shipping';
    final still = context.reduceMotion;
    final cs = context.cs;

    final identity = ShelfIdentity.of(context, shelf);
    final track = widget.onCanvas
        ? Colors.black.withValues(alpha: 0.20)
        : cs.surfaceContainerHigh;

    // A lit sign over a shut shop is a lie. When the server says express is
    // not serving this address right now it is already returning the زوبكسي
    // shelf, so the زوبكسي sign is the one that is lit — without rewriting
    // the customer's remembered preference, which is still express for
    // tomorrow morning.
    final expressSelected = shelf == Shelf.express && expressOpen;
    // In RTL the first child sits on the right — إكسبريس leads the reading.
    final align = expressSelected
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd;

    return Semantics(
      container: true,
      label: l.shelfTabsLabel,
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: align,
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 340),
              curve: Motion.emphasized,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: AnimatedContainer(
                  duration: still ? Duration.zero : Motion.select,
                  decoration: BoxDecoration(
                    gradient: identity.thumb,
                    borderRadius: BorderRadius.circular(ZbTokens.rMd + 2),
                    boxShadow: [
                      BoxShadow(
                        color: identity.accent.withValues(alpha: 0.38),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _Sign(
                    identity: ShelfIdentity.of(context, Shelf.express),
                    name: l.shelfExpressTab,
                    promise: _expressLine(context, l, expressOpen),
                    selected: expressSelected,
                    enabled: expressOpen,
                    onCanvas: widget.onCanvas,
                    celebrating: _celebrating == Shelf.express,
                    onTap: () => _pick(
                      Shelf.express,
                      current: shelf,
                      expressOpen: expressOpen,
                    ),
                  ),
                ),
                Expanded(
                  child: _Sign(
                    identity: ShelfIdentity.of(context, Shelf.all),
                    name: l.shelfAllTab,
                    promise: shipping ? l.shelfAllSubShipping : l.shelfAllSub,
                    selected: !expressSelected,
                    enabled: true,
                    onCanvas: widget.onCanvas,
                    celebrating: _celebrating == Shelf.all,
                    onTap: () => _pick(
                      Shelf.all,
                      current: shelf,
                      expressOpen: expressOpen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Sign extends StatelessWidget {
  const _Sign({
    required this.identity,
    required this.name,
    required this.promise,
    required this.selected,
    required this.enabled,
    required this.onCanvas,
    required this.celebrating,
    required this.onTap,
  });

  final ShelfIdentity identity;
  final String name;
  final String promise;
  final bool selected;

  /// False = this storefront does not exist here; the sign dims but stays
  /// tappable so it can explain itself.
  final bool enabled;
  final bool onCanvas;

  /// One-shot sparkles while this sign is being arrived at.
  final bool celebrating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final resting = onCanvas
        ? Colors.white.withValues(alpha: 0.82)
        : cs.onSurfaceVariant;
    final fg = selected ? identity.onAccent : resting;
    final duration = context.motion(Motion.select);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$name — $promise',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZbTokens.rMd + 2),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      duration: duration,
                      curve: Motion.spring,
                      scale: selected ? 1.0 : 0.9,
                      child: Icon(
                        identity.icon,
                        size: 20,
                        // On the deep canvas an identity-coloured resting icon
                        // can melt into it (teal on teal); rest in the same
                        // quiet white as the text and let selection bring the
                        // colour.
                        color: selected
                            ? fg
                            : (onCanvas
                                ? resting
                                : identity.accent.withValues(alpha: 0.8)),
                      ),
                    ),
                    Gap.w6,
                    // Flexible, or a long promise line overflows the sign's
                    // half-width instead of ellipsizing inside it.
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: duration,
                            style: (context.tt.titleSmall ?? const TextStyle())
                                .copyWith(
                                  color: fg,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AnimatedDefaultTextStyle(
                            duration: duration,
                            style: (context.tt.labelSmall ?? const TextStyle())
                                .copyWith(
                                  fontSize: 10,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: fg.withValues(
                                    alpha: selected ? 0.85 : 0.65,
                                  ),
                                ),
                            child: Text(
                              promise,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (celebrating)
                Positioned.fill(
                  child: SparkleField(
                    sparkles: [
                      SparkleSpec(
                        dx: 0.14,
                        dy: 0.16,
                        size: 9,
                        color: identity.spark,
                      ),
                      const SparkleSpec(
                        dx: 0.88,
                        dy: 0.72,
                        size: 7,
                        color: Colors.white,
                        delay: Duration(milliseconds: 90),
                        rotation: 0.4,
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
