import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/product_models.dart';

/// The product description.
///
/// The store's copy is HTML. Rather than pull a full renderer in for phase
/// one, tags are stripped and entities decoded — readable prose beats a wall
/// of markup, and a real renderer can drop in here later without touching the
/// page around it.
class ProductDescription extends StatelessWidget {
  const ProductDescription({super.key, required this.detail});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = plainText(detail.descriptionHtml ?? detail.shortDescription ?? '');
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.pdpDescription, style: context.tt.titleMedium),
          Gap.h8,
          Text(
            text,
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Block-level tags become newlines so paragraphs survive; everything else
  /// is dropped and the common entities are decoded.
  static String plainText(String html) {
    final withBreaks = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*(p|li|div|h[1-6])\s*>', caseSensitive: false), '\n');
    final stripped = withBreaks.replaceAll(RegExp(r'<[^>]*>'), '');
    return stripped
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
