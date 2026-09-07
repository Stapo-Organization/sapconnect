import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import 'campaign_chips.dart';
import 'hero_auto_slide.dart';
import 'hero_live_copy.dart';

/// One composition per slide — not one template in eight colours.
///
/// The first version of this carousel drew every slide the same way: kicker,
/// headline, subtitle, chip, artwork in the corner. Recoloured eight times it
/// still read as one slide shown eight times, which is the thing a customer
/// swipes past without looking.
///
/// So each subject is laid out as what it *is*. A clock slide is a clock: a
/// time set enormous with its label whispered above it. A best-seller slide is
/// a shelf: three numbered tiles in a row. A discount is a number the size of
/// a fist. A bundle is a stack of boxes. A brand is a signature on a quiet
/// stage. They share only the field they sit on and the type ramp — everything
/// else, including where the eye lands first, is different on purpose.
///
/// Every one of them is built for a band 1/3.2 of the screen tall — about
/// 123pt on a phone — so the compositions run WIDE: what changes between them
/// is which side carries the weight, not how many rows they stack.
class HeroSlideBody extends StatelessWidget {
  const HeroSlideBody({
    super.key,
    required this.slide,
    required this.skin,
    required this.live,
    required this.title,
    required this.badge,
    required this.height,
    required this.compact,
    this.now,
  });

  final HeroSlide slide;
  final AutoSlideSkin skin;
  final HeroLive live;

  /// Already resolved: the device's own sentence where it has one.
  final String? title;
  final String? badge;

  final double height;

  /// The band cannot carry a full copy stack — see [HeroAutoCard].
  final bool compact;

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final images = slide.productImages;

    return switch (slide.theme) {
      'express_clock' => _ClockBody(
          skin: skin,
          live: live,
          title: title,
          badge: badge,
          subtitle: slide.subtitle,
          height: height,
          now: now,
        ),
      'express_top' => _ShelfBody(
          skin: skin,
          title: title,
          subtitle: slide.subtitle,
          images: images,
          height: height,
        ),
      'express_new' => _PolaroidBody(
          skin: skin,
          title: title,
          subtitle: slide.subtitle,
          images: images,
          height: height,
          tag: L.of(context).heroTagNew,
        ),
      'cutoff' => _CountdownBody(
          skin: skin,
          live: live,
          title: title,
          subtitle: slide.subtitle,
          images: images,
          height: height,
          now: now,
        ),
      'bundles' => _StackBody(
          skin: skin,
          title: title,
          subtitle: slide.subtitle,
          badge: badge,
          images: images,
          height: height,
        ),
      'clearance' => _PercentBody(
          skin: skin,
          title: title,
          subtitle: slide.subtitle,
          value: slide.value,
          badge: badge,
          images: images,
          height: height,
        ),
      'brand' => _SignatureBody(
          skin: skin,
          title: title,
          subtitle: slide.subtitle,
          logo: slide.brand?.logo,
        ),
      // Legacy themes (`express`, `bestsellers`) and anything a newer server
      // invents keep the original anatomy — an unknown slide must still draw.
      _ => ClassicSlideBody(
          slide: slide,
          skin: skin,
          live: live,
          title: title,
          badge: badge,
          height: height,
          compact: compact,
          now: now,
        ),
    };
  }
}

/* ── shared pieces ──────────────────────────────────────────────────── */

const EdgeInsetsDirectional _pad =
    EdgeInsetsDirectional.fromSTEB(20, 12, 16, 12);

/// The small line above a big one. Whispered, so the number can shout.
class _Kicker extends StatelessWidget {
  const _Kicker(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.tt.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );

}

/// A line of copy that must never be the reason a slide overflows.
class _Line extends StatelessWidget {
  const _Line(this.text, {required this.color, this.lines = 1, this.style});

  final String text;
  final Color color;
  final int lines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        style: (style ?? context.tt.bodyMedium)?.copyWith(color: color, height: 1.3),
      );
}

/// A square photo tile, white-bordered so it reads as an object on the colour.
class _Tile extends StatelessWidget {
  const _Tile({required this.url, required this.size, this.rank, this.tilt = 0});

  final String url;
  final double size;
  final int? rank;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.20),
        child: ZbImage(url: url, fit: BoxFit.cover, backgroundColor: Colors.white),
      ),
    );

    final art = tilt == 0 ? tile : Transform.rotate(angle: tilt, child: tile);
    if (rank == null) return art;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        art,
        PositionedDirectional(
          top: -6,
          start: -6,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: ZbTokens.amber,
              boxShadow: [
                BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              '$rank',
              style: context.tt.labelSmall?.copyWith(
                color: ZbTokens.ink,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ── 1. the clock: a time, set enormous ─────────────────────────────── */

/// إكسبريس's promise is an hour, so the hour is the artwork. The label is a
/// whisper above it, the branch a whisper below, and the only other thing on
/// the panel is a dial cropped by the edge — no product photos, because a
/// photograph would compete with the one number that matters.
///
/// The last line is whichever is true right now: «خلال ساعتين» most of the
/// day, and inside the final four hours the branch's own countdown, «يغلق بعد
/// 02:48». The shutter had a slide of its own for a while; it was this poster
/// twice with a different number on it.
class _ClockBody extends StatelessWidget {
  const _ClockBody({
    required this.skin,
    required this.live,
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.height,
    this.now,
  });

  final AutoSlideSkin skin;
  final HeroLive live;
  final String? title;

  /// «خلال ساعتين» — and null once the branch has shut, which is precisely
  /// when this slide must NOT promise two hours.
  final String? badge;
  final String? subtitle;
  final double height;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final whole = title ?? '';
    final split = _splitClock(whole);
    final closing = live.deadlineAt != null;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        PositionedDirectional(
          start: -height * 0.34,
          top: -height * 0.18,
          child: _Dial(color: skin.fg, size: height * 1.28),
        ),
        Padding(
          padding: _pad,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (split.$1.isNotEmpty) _Kicker(split.$1, color: skin.muted),
              Text(
                split.$2.isEmpty ? whole : split.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.displaySmall?.copyWith(
                  color: skin.fg,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -0.5,
                ),
              ),
              if ((subtitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Flexible(child: _Line(subtitle!, color: skin.muted)),
              ],
              if (closing) ...[
                const SizedBox(height: 6),
                HeroLivePill(live: live, fg: skin.fg, accent: skin.accent, now: now),
              ] else if ((badge ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                _Kicker(badge!, color: skin.fg.withValues(alpha: 0.9)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Splits «يوصلك الساعة 10:45 م» into its words and its number. The number
  /// is whatever begins at the first digit — Western digits are the app's
  /// rule everywhere, so this holds in both languages.
  static (String, String) _splitClock(String text) {
    final at = text.indexOf(RegExp(r'[0-9]'));
    if (at <= 0) return ('', text);
    return (text.substring(0, at).trim(), text.substring(at).trim());
  }
}

/// A face cropped by the slide's edge: two quiet rings, nothing else. The
/// hands are the type.
class _Dial extends StatelessWidget {
  const _Dial({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(size: Size.square(size), painter: _DialPainter(color)),
      );
}

class _DialPainter extends CustomPainter {
  const _DialPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    for (final (factor, alpha, width) in const [(1.0, 0.16, 2.0), (0.74, 0.10, 1.4)]) {
      canvas.drawCircle(
        c,
        r * factor,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.color != color;
}

/* ── 2. the shelf: three numbered tiles ─────────────────────────────── */

/// «الأكثر طلباً في فرعك» is a shelf, so it is drawn as one: the products in a
/// row, numbered, taking most of the panel. The words are a caption above
/// them, not a headline they orbit.
class _ShelfBody extends StatelessWidget {
  const _ShelfBody({
    required this.skin,
    required this.title,
    required this.subtitle,
    required this.images,
    required this.height,
  });

  final AutoSlideSkin skin;
  final String? title;
  final String? subtitle;
  final List<String> images;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tiles = images.take(4).toList();

    return Padding(
      padding: _pad,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((title ?? '').isNotEmpty)
            _Line(
              title!,
              color: skin.fg,
              style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          if ((subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            _Line(subtitle!, color: skin.muted, style: context.tt.bodySmall),
          ],
          const SizedBox(height: 8),
          // The tiles take whatever height the caption left them, and stay
          // SQUARE: sized from the band alone they came out landscape, which
          // reads as a bug rather than a shelf.
          Flexible(
            child: LayoutBuilder(builder: (context, box) {
              // Both axes, or the fourth tile pushes the first one off the
              // start edge — and the first is the one wearing the 1.
              const gap = 10.0;
              final byWidth =
                  (box.maxWidth - gap * (tiles.length - 1)) / tiles.length;
              final byHeight = box.maxHeight.isFinite ? box.maxHeight : 64.0;
              final size = (byHeight < byWidth ? byHeight : byWidth).clamp(36.0, 88.0);
              return Row(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    _Tile(url: tiles[i], size: size, rank: i + 1),
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

/* ── 3. the polaroid: what just landed ──────────────────────────────── */

/// A new arrival is ONE thing, so it is shown as one thing: the newest
/// product large on the far side, cropped by the frame like a photo laid on a
/// desk, with «جديد» stuck to its corner. The shelf slide next to it shows
/// three; this one shows one. That difference is legible at a swipe, which is
/// the whole job of a slide in a carousel.
class _PolaroidBody extends StatelessWidget {
  const _PolaroidBody({
    required this.skin,
    required this.title,
    required this.subtitle,
    required this.images,
    required this.height,
    required this.tag,
  });

  final AutoSlideSkin skin;
  final String? title;
  final String? subtitle;
  final List<String> images;
  final double height;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final size = (height * 0.86).clamp(64.0, 132.0);

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: _pad,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((title ?? '').isNotEmpty)
                  _Line(
                    title!,
                    color: skin.fg,
                    style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Flexible(
                    child: _Line(subtitle!, color: skin.muted, lines: 2, style: context.tt.bodySmall),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (images.isNotEmpty)
          // Cropped by the end edge on purpose: a photograph that runs off the
          // frame reads as a scene, one floating inside it reads as clip-art.
          SizedBox(
              width: size * 0.82,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Flush to the bottom edge: the photo sinks onto the panel
                  // like one laid on a desk, rather than floating in it.
                  PositionedDirectional(
                    end: -size * 0.16,
                    bottom: 0,
                    child: _Tile(url: images.first, size: size, tilt: -0.05),
                  ),
                  PositionedDirectional(
                    end: size * 0.42,
                    bottom: size * 0.74,
                    child: Transform.rotate(
                      angle: -0.10,
                      alignment: AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ZbTokens.rXs),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.20),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          tag,
                          style: context.tt.labelMedium?.copyWith(
                            color: skin.accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ),
      ],
    );
  }
}

/* ── 4. the countdown: centred, like a departure board ──────────────── */

/// The cut-off is a deadline, and a deadline is read in the middle of the
/// board: the sentence on top, the clock under it, centred — the only centred
/// composition in the carousel, which is what makes it stop the thumb.
class _CountdownBody extends StatelessWidget {
  const _CountdownBody({
    required this.skin,
    required this.live,
    required this.title,
    required this.subtitle,
    required this.images,
    required this.height,
    this.now,
  });

  final AutoSlideSkin skin;
  final HeroLive live;
  final String? title;
  final String? subtitle;
  final List<String> images;
  final double height;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final size = (height * 0.42).clamp(40.0, 64.0);
    final packs = images.take(2).toList();

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if ((title ?? '').isNotEmpty)
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.titleLarge?.copyWith(
                    color: skin.fg,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              if (live.deadlineAt != null) ...[
                const SizedBox(height: 6),
                HeroLivePill(live: live, fg: skin.fg, accent: skin.accent, now: now),
              ] else if ((subtitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                _Line(subtitle!, color: skin.muted),
              ],
            ],
            ),
          ),
        ),
        // A little of the goods, at the far side and wholly inside the frame —
        // enough to say "a shop", never enough to crowd the board.
        if (packs.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: SizedBox(
              width: size * 1.25,
              height: size * 1.1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = packs.length - 1; i >= 0; i--)
                    PositionedDirectional(
                      end: i * size * 0.32,
                      top: i * 6,
                      child: _Tile(url: packs[i], size: size - i * 8, tilt: (i - 0.5) * 0.10),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/* ── 5. the stack: bundles as boxes ─────────────────────────────────── */

/// A bundle is several things bought as one, so it is drawn as a stack: the
/// packs overlapping and tilted, with the saving stuck on them like a price
/// sticker slapped at an angle.
class _StackBody extends StatelessWidget {
  const _StackBody({
    required this.skin,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.images,
    required this.height,
  });

  final AutoSlideSkin skin;
  final String? title;
  final String? subtitle;
  final String? badge;
  final List<String> images;
  final double height;

  @override
  Widget build(BuildContext context) {
    final size = (height * 0.62).clamp(56.0, 96.0);
    final packs = images.take(3).toList();

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: _pad,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((title ?? '').isNotEmpty)
                      _Line(
                        title!,
                        color: skin.fg,
                        style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    if ((subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _Line(subtitle!, color: skin.muted, lines: 2, style: context.tt.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            // The packs, overlapping and tilted the way boxes actually land on
            // a counter — one object made of three, which is what a bundle is.
            if (packs.isNotEmpty)
              SizedBox(
                width: size * 1.30,
                height: size * 1.06,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = packs.length - 1; i >= 0; i--)
                      PositionedDirectional(
                        end: i * size * 0.24,
                        top: i * 5.0,
                        child: _Tile(
                          url: packs[i],
                          size: size - i * 9,
                          tilt: (i - 1) * 0.10,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        // The saving, stuck on the STACK at an angle — a price sticker goes on
        // the box, not on the headline it was covering.
        if ((badge ?? '').isNotEmpty)
          PositionedDirectional(
            end: 10,
            top: 10,
            child: Transform.rotate(
              angle: 0.10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: skin.accent,
                  borderRadius: BorderRadius.circular(ZbTokens.rXs),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  badge!,
                  style: context.tt.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/* ── 6. the number: a discount the size of a fist ───────────────────── */

/// «خصم حتى 45%» sets the 45 in the largest type in the app. Nothing else on
/// the slide competes: the words shrink to a caption beside it and the goods
/// line up small along the bottom, the way a sale sign is actually built.
class _PercentBody extends StatelessWidget {
  const _PercentBody({
    required this.skin,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.badge,
    required this.images,
    required this.height,
  });

  final AutoSlideSkin skin;
  final String? title;
  final String? subtitle;
  final int? value;
  final String? badge;
  final List<String> images;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final size = (height * 0.38).clamp(36.0, 58.0);
    final thumbs = images.take(3).toList();

    return Row(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 18, top: 10, bottom: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (value != null) ...[
                _Kicker(l.heroUpTo, color: skin.muted),
                Text(
                  Fmt.percent(value!, locale: locale),
                  maxLines: 1,
                  style: context.tt.displayMedium?.copyWith(
                    color: skin.fg,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    letterSpacing: -1,
                  ),
                ),
              ] else if ((badge ?? '').isNotEmpty)
                CampaignChip(
                  label: badge!,
                  foreground: skin.accent,
                  background: Colors.white,
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((title ?? '').isNotEmpty)
                _Line(
                  title!,
                  color: skin.fg,
                  style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              if ((subtitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                _Line(subtitle!, color: skin.muted, lines: 2, style: context.tt.bodySmall),
              ],
            ],
          ),
        ),
        // The goods themselves, small and in a line — a sale sign, not a
        // gallery: the number is what sells this slide.
        if (thumbs.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < thumbs.take(2).length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _Tile(url: thumbs[i], size: size, tilt: (i - 0.5) * 0.08),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/* ── 7. the signature: a brand on a quiet stage ─────────────────────── */

/// A brand slide's job is to hand the panel over. The mark sits on its own
/// white card in the middle of a deep, empty stage — no products, no badge,
/// no gradient tricks — and the name is set beneath it like a caption in a
/// gallery.
class _SignatureBody extends StatelessWidget {
  const _SignatureBody({
    required this.skin,
    required this.title,
    required this.subtitle,
    required this.logo,
  });

  final AutoSlideSkin skin;
  final String? title;
  final String? subtitle;
  final String? logo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logo != null) ...[
              Container(
                width: 92,
                height: 62,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ZbTokens.rMd),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ZbImage(url: logo!, fit: BoxFit.contain, backgroundColor: Colors.white),
              ),
              const SizedBox(width: 16),
            ],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((title ?? '').isNotEmpty)
                    _Line(
                      title!,
                      color: skin.fg,
                      style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  if ((subtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _Line(subtitle!, color: skin.muted, style: context.tt.bodySmall),
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
