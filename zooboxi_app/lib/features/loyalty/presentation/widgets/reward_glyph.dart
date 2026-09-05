import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../../../l10n/app_localizations.dart';

/// The drawn mark for a reward kind.
///
/// Four kinds, four glyphs, one hand: a wrapped box for a gift, a box with
/// speed trails for the express upgrade, a delivery van for free delivery, and
/// the paw for a paws prize. A kind this build has never seen falls back to
/// the gift — the catalog is the owner's to extend, and an unknown reward
/// should look like a present, not like a missing asset.
class RewardGlyph extends StatelessWidget {
  const RewardGlyph({super.key, required this.kind, this.size = 26, this.tint});

  final String kind;
  final double size;

  /// Overrides the glyph's own colours, for a tinted well.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    if (kind == 'paws') {
      return ZbIcon(ZbIconKind.paw, size: size, fill: 1, tint: tint);
    }
    final ink = resolveZbInk(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: switch (kind) {
          'express_free' => _ExpressPainter(ink: ink, size: size, tint: tint),
          'free_delivery' => _VanPainter(ink: ink, size: size, tint: tint),
          _ => _GiftPainter(ink: ink, size: size, tint: tint),
        },
      ),
    );
  }
}

/// The short name of a reward kind, for a chip above the title.
String rewardKindLabel(L l, String kind) => switch (kind) {
      'express_free' => l.rewardKindExpress,
      'free_delivery' => l.rewardKindDelivery,
      'paws' => l.rewardKindPaws,
      _ => l.rewardKindGift,
    };

/// The tinted well a reward glyph sits in — one hue per kind so a list of
/// rewards is scannable before a single word is read.
Color rewardKindTint(BuildContext context, String kind) {
  final zb = context.zb;
  return switch (kind) {
    'express_free' => zb.tierExpress.fg,
    'free_delivery' => zb.tierSameDay.fg,
    'paws' => context.cs.primary,
    _ => zb.sale,
  };
}

abstract class _RewardPainter extends ZbIconPainter {
  const _RewardPainter({required super.ink, required super.size, super.tint})
      : super(fill: 1);

  void solid(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, strokePaint());
  }

  void solidRRect(Canvas canvas, RRect rect, Color color) {
    canvas.drawRRect(rect, Paint()..color = color);
    canvas.drawRRect(rect, strokePaint());
  }
}

/// A wrapped box: body, lid, one ribbon band and a two-loop bow.
class _GiftPainter extends _RewardPainter {
  const _GiftPainter({required super.ink, required super.size, super.tint});

  @override
  void draw(Canvas canvas) {
    final body = tint ?? ZbTokens.cardboard;
    final ribbon = tint == null ? ZbTokens.logoCoral : ZbTokens.creamLogo;

    solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(4.6, 10.6, 19.4, 20.4),
        const Radius.circular(1.6),
      ),
      body,
    );
    solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(3.4, 7.4, 20.6, 11.2),
        const Radius.circular(1.4),
      ),
      body,
    );

    canvas.drawRect(const Rect.fromLTRB(10.6, 7.6, 13.4, 20.2), Paint()..color = ribbon);
    canvas.drawLine(const Offset(10.6, 11.2), const Offset(10.6, 20.3), strokePaint(width: 1.2));
    canvas.drawLine(const Offset(13.4, 11.2), const Offset(13.4, 20.3), strokePaint(width: 1.2));

    final bow = Path()
      ..moveTo(12, 7.4)
      ..quadraticBezierTo(8.2, 6.4, 8.6, 4.0)
      ..quadraticBezierTo(9.2, 2.2, 12, 7.4)
      ..close()
      ..moveTo(12, 7.4)
      ..quadraticBezierTo(15.8, 6.4, 15.4, 4.0)
      ..quadraticBezierTo(14.8, 2.2, 12, 7.4)
      ..close();
    solid(canvas, bow, ribbon);
  }
}

/// A parcel travelling: the box leans forward with three speed trails behind
/// it and a bolt on its face. Mirrors in Arabic so it always moves *forward*.
class _ExpressPainter extends _RewardPainter {
  const _ExpressPainter({required super.ink, required super.size, super.tint});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final body = tint ?? ZbTokens.cardboard;
    final trail = strokePaint(
      width: 1.5,
      color: (tint ?? ZbTokens.teal).withValues(alpha: 0.75),
    );
    canvas.drawLine(const Offset(1.6, 8.8), const Offset(6.4, 8.8), trail);
    canvas.drawLine(const Offset(2.6, 13.0), const Offset(6.0, 13.0), trail);
    canvas.drawLine(const Offset(1.8, 17.2), const Offset(6.6, 17.2), trail);

    solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(8.4, 6.4, 21.2, 18.6),
        const Radius.circular(2.4),
      ),
      body,
    );
    // Tape seam, so the parcel reads as a box and not a card.
    canvas.drawLine(
      const Offset(8.6, 10.2),
      const Offset(21.0, 10.2),
      strokePaint(width: 1.2),
    );

    final bolt = Path()
      ..moveTo(16.0, 11.0)
      ..lineTo(12.6, 15.4)
      ..lineTo(14.8, 15.4)
      ..lineTo(13.8, 18.0)
      ..lineTo(17.4, 13.4)
      ..lineTo(15.1, 13.4)
      ..close();
    canvas.drawPath(bolt, Paint()..color = ZbTokens.amber);
    canvas.drawPath(bolt, strokePaint(width: 1.1));
  }
}

/// A delivery van: cab, body, two wheels, and a paw on the flank.
class _VanPainter extends _RewardPainter {
  const _VanPainter({required super.ink, required super.size, super.tint});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final body = tint ?? ZbTokens.teal;

    solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(9.0, 7.6, 21.4, 16.6),
        const Radius.circular(2.0),
      ),
      body,
    );

    final cab = Path()
      ..moveTo(9.0, 10.6)
      ..lineTo(5.6, 10.6)
      ..quadraticBezierTo(3.0, 10.6, 2.6, 13.2)
      ..lineTo(2.6, 16.6)
      ..lineTo(9.0, 16.6)
      ..close();
    solid(canvas, cab, body);

    // Windscreen — the one cool note on a warm van.
    solidRRect(
      canvas,
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(3.8, 11.6, 8.0, 14.0),
        const Radius.circular(0.8),
      ),
      ZbTokens.creamLogo,
    );

    for (final x in const [6.6, 17.4]) {
      canvas.drawCircle(Offset(x, 17.6), 2.5, Paint()..color = ZbTokens.inkWarm);
      canvas.drawCircle(Offset(x, 17.6), 2.5, strokePaint(width: 1.4));
      canvas.drawCircle(Offset(x, 17.6), 0.9, Paint()..color = ZbTokens.creamLogo);
    }

    if (!detailed) return;
    canvas.drawCircle(
      const Offset(15.2, 12.0),
      1.5,
      Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.85),
    );
  }
}
