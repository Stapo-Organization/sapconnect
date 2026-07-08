import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// Rounded product thumbnail with a graceful fallback icon and a soft loading
/// state. Theme-aware (light/dark) — the single source for product imagery
/// across the app (branch levers, best-sellers, stock distribution …).
class ProductThumb extends StatelessWidget {
  final String? url;
  final double size;
  final Color? accent;
  final double radius;

  const ProductThumb({
    super.key,
    required this.url,
    this.size = 52,
    this.accent,
    this.radius = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: (accent ?? AppColors.border).withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url!.isEmpty)
          ? _fallback()
          : Image.network(
              url!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _fallback(),
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: SizedBox(
                    width: size * 0.28,
                    height: size * 0.28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: (accent ?? AppColors.primary).withValues(alpha: 0.45),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _fallback() => Icon(
        Icons.inventory_2_outlined,
        size: size * 0.42,
        color: AppColors.textTertiary,
      );
}
