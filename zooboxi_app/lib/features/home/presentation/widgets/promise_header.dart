import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/delivery/delivery_eta.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/paw_wallpaper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../location/presentation/location_sheet.dart';
import '../../../search/presentation/express_search_field.dart';
import 'shelf_tabs.dart';

/// «الوعد» — the إكسبريس header where the clock is the hero.
///
/// A store leads with what it sells; a delivery app leads with when it gets
/// there. So the arrival is the largest type on the page, set on a deep teal
/// canvas that runs behind the status bar, with a faint dial behind it, the
/// branch's own countdown to closing on flip tiles, and a route from the
/// branch to the door. The search well rides the panel's curved bottom edge,
/// half on the colour and half on the paper.
///
/// The palette is the express slide palette — the same teal the offer strip
/// wears — so the header and the slides under it read as one shop.
class PromiseHeader extends StatefulWidget {
  const PromiseHeader({super.key, required this.scope, this.now});

  final CatalogScope scope;

  /// Fixed by the sheet tests; the wall clock everywhere else.
  final DateTime? now;

  /// How far the search well hangs below the panel.
  static const double searchOverlap = 27;

  static const Color deep = Color(0xFF07344A);
  static const Color mid = Color(0xFF0B4E64);
  static const Color bloomTop = Color(0xFF0E7C80);
  static const Color bloomBottom = Color(0xFF23DEBB);
  static const Color warm = Color(0xFFF08874);
  static const Color gold = Color(0xFFFBD268);

  @override
  State<PromiseHeader> createState() => _PromiseHeaderState();
}

class _PromiseHeaderState extends State<PromiseHeader> {
  Timer? _tick;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    if (widget.now == null) {
      // The countdown and the arrival both move; half a minute is plenty for
      // a clock that shows minutes.
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final statusTop = MediaQuery.paddingOf(context).top;
    final scope = widget.scope;
    final hours = scope.expressHours;
    final open = isExpressOpen(_now, hours);
    final eta = resolveExpressEta(now: _now, hours: hours);

    // "4:30 م" → the digits and the meridiem, set in two sizes.
    final clock = Fmt.clock(eta.at, locale);
    final cut = clock.lastIndexOf(' ');
    final digits = cut < 0 ? clock : clock.substring(0, cut);
    final suffix = cut < 0 ? '' : clock.substring(cut + 1);

    final lead = open
        ? l.promiseOpenNow
        : l.shelfExpressOpensAt(
            Fmt.clockShort(
              timeOfDayToday(hours!.openMinutes, now: _now),
              locale,
            ),
          );
    // The route starts at إكسبريس, never at a named branch: which shop packs
    // the order is ours to know, not the customer's to read.
    final branch = l.shelfExpressTab;

    // Its own transparent Material: the tabs and the chip splash ink, and a
    // sheet that draws this header alone has no Scaffold to lend them one.
    final panel = ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [PromiseHeader.deep, PromiseHeader.mid],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _Blooms()),
              const Positioned.fill(child: PawWallpaper()),
              Positioned.fill(
                child: CustomPaint(painter: _DialPainter(rtl: context.isRtl)),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  16,
                  statusTop + 4,
                  16,
                  34,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The shelf signs' band — the same band the زوبكسي board
                    // reserves, so the one pair the home screen paints over
                    // both never moves when the shop changes.
                    const SizedBox(height: ShelfBand.reserved),
                    Row(
                      children: [
                        Expanded(
                          child: _Glass(
                            radius: ZbTokens.rPill,
                            child: LocationChip(onCanvas: true, scope: scope),
                          ),
                        ),
                        Gap.w8,
                        _GlassButton(
                          kind: ZbIconKind.bell,
                          tooltip: l.inboxTitle,
                          onTap: () => context.push('/inbox'),
                        ),
                        Gap.w8,
                        _GlassButton(
                          kind: ZbIconKind.heart,
                          tooltip: l.wishlistTitle,
                          onTap: () => context.push('/wishlist'),
                        ),
                      ],
                    ),
                    Gap.h8,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _Promise(
                            lead: lead,
                            digits: digits,
                            suffix: suffix,
                            tomorrow: eta.tomorrow,
                            open: open,
                          ),
                        ),
                        Gap.w12,
                        ClosingCountdown(now: widget.now, hours: hours, open: open),
                      ],
                    ),
                    Gap.h8,
                    _Route(branch: branch),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // The header is a composition with fixed geometry — a clock, two signs,
    // a route, a well — and it has to be the same height on every phone.
    // Android phones commonly run a larger system font, and the clock and
    // the signs grew with it, so the panel stood taller there than on the
    // iPhone it was drawn for. The type in here is fixed; the page below it
    // still scales.
    return MediaQuery.withNoTextScaling(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: PromiseHeader.searchOverlap),
            child: panel,
          ),
        // The well is inside the stack's bounds — a child hanging past the
        // edge would draw but never take a tap.
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              boxShadow: [
                BoxShadow(
                  color: PromiseHeader.deep.withValues(alpha: 0.38),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: PromiseHeader.deep.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: SearchHeroField(branch: 0),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

/// The promise itself: a pulse, the lead line, and the clock in the largest
/// type on the page.
class _Promise extends StatelessWidget {
  const _Promise({
    required this.lead,
    required this.digits,
    required this.suffix,
    required this.tomorrow,
    required this.open,
  });

  final String lead;
  final String digits;
  final String suffix;
  final bool tomorrow;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = context.tt;
    final ink = context.isDark ? ZbTokens.inkDark : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _Pulse(color: open ? ZbTokens.successOnDark : ZbTokens.amberOnDark),
            Gap.w6,
            // Shrinks a step before it ellipsises: a lead line that ends in
            // «الساعة» and then a cut is worse than one a hair smaller.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  lead,
                  maxLines: 1,
                  style: tt.labelMedium?.copyWith(
                    color: ink.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                digits,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.8,
                  color: ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
              if (suffix.isNotEmpty) ...[
                Gap.w8,
                Text(
                  suffix,
                  style: tt.titleLarge?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
              if (tomorrow) ...[
                Gap.w8,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: PromiseHeader.gold,
                    borderRadius: BorderRadius.circular(ZbTokens.rPill),
                  ),
                  child: Text(
                    l.promiseTomorrow,
                    style: tt.labelSmall?.copyWith(
                      color: PromiseHeader.deep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A live dot with two soft rings — the branch is open right now.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.24), spreadRadius: 3),
          BoxShadow(color: color.withValues(alpha: 0.10), spreadRadius: 7),
        ],
      ),
    );
  }
}

/// «إكسبريس يغلق بعد 02:48:15» on flip tiles, the seconds running; «يفتح
/// 09:00» once it has shut.
///
/// Its own clock, one second, in a leaf of its own: the header above it is
/// a big painted panel and must not repaint sixty times a minute for the
/// sake of one digit.
class ClosingCountdown extends StatefulWidget {
  const ClosingCountdown({super.key, required this.now, required this.hours, required this.open});

  /// Fixed by the sheet tests; the wall clock (ticking) when null.
  final DateTime? now;
  final ExpressHours? hours;
  final bool open;

  @override
  State<ClosingCountdown> createState() => _ClosingCountdownState();
}

class _ClosingCountdownState extends State<ClosingCountdown> {
  Timer? _tick;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    if (widget.now == null && widget.open) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tt = context.tt;
    final ink = context.isDark ? ZbTokens.inkDark : Colors.white;
    final hours = widget.hours;
    if (hours == null) return const SizedBox.shrink();

    final left = widget.open ? timeUntilExpressClose(_now, hours) : null;
    final String label;
    final int h;
    final int m;
    final int? s;
    if (left != null) {
      label = l.promiseClosesIn;
      h = left.inHours.clamp(0, 99);
      m = left.inMinutes.remainder(60);
      s = left.inSeconds.remainder(60);
    } else {
      label = l.promiseOpensLabel;
      h = hours.openMinutes ~/ 60;
      m = hours.openMinutes % 60;
      s = null;
    }

    return _Glass(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 12, color: PromiseHeader.gold),
              Gap.w4,
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: ink.withValues(alpha: 0.88), fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FlipClock(hours: h, minutes: m, seconds: s),
        ],
      ),
    );
  }
}

/// Two pairs of split-flap tiles — always drawn left to right, the way a
/// clock reads in either language.
class FlipClock extends StatelessWidget {
  const FlipClock({super.key, required this.hours, required this.minutes, this.seconds, this.small = false});

  final int hours;
  final int minutes;

  /// A third pair, when the clock is close enough to watch.
  final int? seconds;
  final bool small;

  @override
  Widget build(BuildContext context) {
    // Seconds are the pair that moves, so every pair shrinks a step to make
    // room for them without the card growing.
    final tiny = small || seconds != null;
    final colon = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        ':',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: tiny ? 12 : 14,
          height: 1,
          color: (context.isDark ? ZbTokens.inkDark : Colors.white).withValues(alpha: 0.75),
        ),
      ),
    );
    Widget pair(int value) {
      final text = value.toString().padLeft(2, '0');
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [_Tile(text[0], small: tiny), const SizedBox(width: 3), _Tile(text[1], small: tiny)],
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pair(hours),
          colon,
          pair(minutes),
          if (seconds != null) ...[colon, pair(seconds!)],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.digit, {required this.small});

  final String digit;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final w = small ? 18.0 : 22.0;
    final h = small ? 23.0 : 28.0;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(small ? 4 : 5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2F2E), Color(0xFF151918)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              digit,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: small ? 13 : 16,
                height: 1,
                color: Colors.white,
              ),
            ),
          ),
          // The fold line, and the lit upper edge of the top flap.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.16)),
          ),
          Positioned(
            top: h / 2,
            left: 0,
            right: 0,
            height: 1,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

/// Branch → courier → door on one line, with the lit half of the route
/// reaching the courier: the order is on its way the moment it is placed.
///
/// The labels sit beside their nodes rather than under them, so the whole
/// route is one row of type — it used to spend two rows on it.
class _Route extends StatelessWidget {
  const _Route({required this.branch});

  final String branch;

  static const double _progress = 0.46;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ink = context.isDark ? ZbTokens.inkDark : Colors.white;
    final label = context.tt.labelSmall?.copyWith(
      color: ink,
      fontWeight: FontWeight.w800,
      height: 1.2,
    );

    return SizedBox(
      height: 30,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: PromiseHeader.gold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: PromiseHeader.gold.withValues(alpha: 0.25),
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 13,
              color: PromiseHeader.deep,
            ),
          ),
          Gap.w6,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(
              branch,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: label,
            ),
          ),
          Gap.w8,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final track = constraints.maxWidth;
                return Stack(
                  alignment: AlignmentDirectional.centerStart,
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size(track, 2),
                      painter: DashPainter(color: ink.withValues(alpha: 0.45)),
                    ),
                    Container(
                      width: track * _progress,
                      height: 2,
                      decoration: BoxDecoration(
                        color: PromiseHeader.gold,
                        boxShadow: [
                          BoxShadow(
                            color: PromiseHeader.gold.withValues(alpha: 0.8),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    // The courier rides the end of the lit stretch, the
                    // window pinned to its side.
                    PositionedDirectional(
                      start: (track * _progress - 14).clamp(0.0, track),
                      child: _Courier(window: l.heroExpressWindow, label: label),
                    ),
                  ],
                );
              },
            ),
          ),
          Gap.w8,
          Text(l.promiseRouteYou, style: label),
          Gap.w6,
          _Glass(
            radius: 12,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 24,
              height: 24,
              child: Icon(Icons.home_rounded, size: 13, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The moped in its white disc with the delivery window as a pill beside it
/// — one object on the track, not a stack of two.
class _Courier extends StatelessWidget {
  const _Courier({required this.window, required this.label});

  final String window;
  final TextStyle? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Transform.flip(
            flipX: context.isRtl,
            child: const Icon(
              Icons.moped_rounded,
              size: 17,
              color: PromiseHeader.deep,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(ZbTokens.rPill),
          ),
          child: Text(window, style: label, maxLines: 1),
        ),
      ],
    );
  }
}

/// A dashed hairline, horizontal or vertical by the size it is given.
class DashPainter extends CustomPainter {
  const DashPainter({required this.color, this.dash = 5, this.gap = 4});

  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width > size.height ? size.height : size.width
      ..strokeCap = StrokeCap.round;
    final horizontal = size.width > size.height;
    final length = horizontal ? size.width : size.height;
    final mid = horizontal ? size.height / 2 : size.width / 2;
    var at = 0.0;
    while (at < length) {
      final to = math.min(at + dash, length);
      canvas.drawLine(
        horizontal ? Offset(at, mid) : Offset(mid, at),
        horizontal ? Offset(to, mid) : Offset(mid, to),
        paint,
      );
      at += dash + gap;
    }
  }

  @override
  bool shouldRepaint(DashPainter old) =>
      old.color != color || old.dash != dash || old.gap != gap;
}

/// The three soft lights behind everything: a teal bloom at the top start, a
/// bright one at the bottom end, and a small warm one so the panel never
/// reads as cold.
class _Blooms extends StatelessWidget {
  const _Blooms();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const AlignmentDirectional(1, -1),
              radius: 1.1,
              colors: [
                PromiseHeader.bloomTop,
                PromiseHeader.bloomTop.withValues(alpha: 0),
              ],
              stops: const [0, 0.58],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const AlignmentDirectional(-1, 1),
              radius: 0.9,
              colors: [
                PromiseHeader.bloomBottom,
                PromiseHeader.bloomBottom.withValues(alpha: 0),
              ],
              stops: const [0, 0.62],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const AlignmentDirectional(0.75, 0.85),
              radius: 0.42,
              colors: [
                PromiseHeader.warm.withValues(alpha: 0.5),
                PromiseHeader.warm.withValues(alpha: 0),
              ],
              stops: const [0, 0.72],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sixty faint ticks on a ring at the end edge — the header wears a clock.
class _DialPainter extends CustomPainter {
  const _DialPainter({required this.rtl});

  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(rtl ? 30 : size.width - 30, 250);
    const radius = 180.0;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(center, radius, ring);
    final tick = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.30);
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30;
      const inner = radius * 0.62;
      final outer = radius * (i % 5 == 0 ? 0.69 : 0.66);
      canvas.drawLine(
        center + Offset(math.cos(a) * inner, math.sin(a) * inner),
        center + Offset(math.cos(a) * outer, math.sin(a) * outer),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.rtl != rtl;
}

/// Frosted glass on the canvas: a tint, a hairline, a lit top edge.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    required this.radius,
    this.padding = const EdgeInsets.all(2),
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.kind,
    required this.tooltip,
    required this.onTap,
  });

  final ZbIconKind kind;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = context.isDark ? ZbTokens.inkDark : Colors.white;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Haptics.light();
            onTap();
          },
          child: _Glass(
            radius: 18,
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(child: ZbIcon(kind, size: 19, ink: ink)),
            ),
          ),
        ),
      ),
    );
  }
}
