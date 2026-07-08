import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';

/// A brand logo in a soft white card, with a graceful fallback to the brand's
/// initials when the (CDN-hosted) logo image is missing or fails to load.
///
/// Pass [heroTag] to enable a shared-element flight of the logo between the
/// landing brands row and the brand page.
class BrandLogo extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final double size;
  final bool light;
  final Object? heroTag;

  const BrandLogo({
    super.key,
    required this.name,
    required this.logoUrl,
    this.size = 72,
    this.light = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      alignment: Alignment.center,
      color: AppColors.surfaceVariant,
      child: Text(
        _initials(name),
        style: AppTypography.titleLarge.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: light ? 0.25 : 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: (logoUrl == null || logoUrl!.isEmpty)
              ? fallback
              : CachedNetworkImage(
                  imageUrl: logoUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );

    if (heroTag == null) return logo;
    return Hero(
      tag: heroTag!,
      // Keep rounded corners crisp during the flight.
      flightShuttleBuilder: (_, _, _, _, toHero) => toHero.widget,
      child: logo,
    );
  }

  static String _initials(String n) {
    final t = n.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0].characters.take(1).toString() +
              parts[1].characters.take(1).toString())
          .toUpperCase();
    }
    return t.characters.take(2).toString().toUpperCase();
  }
}
