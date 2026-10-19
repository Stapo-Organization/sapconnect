import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/zb_colors.dart';
import '../../l10n/app_localizations.dart';
import '../characters/characters.dart';
import '../providers.dart';
import '../widgets/bottom_sheet_scaffold.dart';
import 'analytics_service.dart';

/// The one sentence before iOS asks about the ad identifier.
///
/// The system sheet used to appear on the first home frame, before the
/// customer had seen a product, which is when people say no to everything.
/// Now it waits for the first thing they put in the basket, and Zooboxi says
/// in its own voice what the permission is for. «ليس الآن» is a real answer:
/// the primer never comes back, and the system sheet is not shown behind it.
Future<void> maybeAskTracking(BuildContext context, WidgetRef ref) async {
  final store = ref.read(localStoreProvider);
  if (store.trackingPrimed) return;
  final analytics = ref.read(analyticsProvider);
  if (!await analytics.trackingUndecided()) return;
  // Let the add-to-basket confirmation land first.
  await Future<void>.delayed(const Duration(milliseconds: 1400));
  if (!context.mounted) return;
  await store.setTrackingPrimed();
  if (!context.mounted) return;

  final go = await showZbSheet<bool>(
    context,
    builder: (sheet) => const _TrackingPrimer(),
  );
  if (go == true) {
    await analytics.requestTrackingAuthorization();
  }
}

class _TrackingPrimer extends StatelessWidget {
  const _TrackingPrimer();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    return BottomSheetScaffold(
      title: l.trackingPrimerTitle,
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size(0, 50)),
              child: Text(l.trackingPrimerLater),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              child: Text(l.trackingPrimerContinue),
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ZbSticker.cast(ZbCast.cat, ZbPose.present, height: 92),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l.trackingPrimerBody,
                style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
