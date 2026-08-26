import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// The four answers to "can I trust ordering pet food from an app".
///
/// It closes the page rather than opening it: someone who scrolled this far is
/// deciding, and this is the moment the reassurance is worth the space. Icons,
/// not emoji — emoji render differently on every OS and read as decoration
/// where a drawn icon reads as a statement.
class TrustStrip extends StatelessWidget {
  const TrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrustItem(icon: Icons.bolt_rounded, label: l.homeTrustDelivery),
            _TrustItem(icon: Icons.shield_outlined, label: l.homeTrustPayment),
            _TrustItem(icon: Icons.verified_outlined, label: l.homeTrustGenuine),
            _TrustItem(icon: Icons.keyboard_return_rounded, label: l.homeTrustReturns),
          ],
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          Gap.h8,
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
