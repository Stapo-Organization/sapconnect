import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../characters/characters.dart';
import '../characters/companion.dart';
import '../utils/error_text.dart';

/// Full-area failure view. Never a dead end: it always offers the way back.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.error, this.onRetry, this.compact = false});

  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final l = L.of(context);
    final offline = isConnectivityError(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (offline && !compact)
              const _OfflinePeek()
            else
              Container(
                width: compact ? 54 : 68,
                height: compact ? 54 : 68,
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(compact ? 18 : 22),
                ),
                child: Icon(
                  offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                  color: cs.error,
                  size: compact ? 25 : 31,
                ),
              ),
            SizedBox(height: compact ? 12 : 18),
            Text(
              offline && !compact ? l.errOfflineTitle : l.errTitle,
              style: context.tt.titleMedium,
              textAlign: TextAlign.center,
            ),
            Gap.h8,
            Text(
              offline && !compact ? l.errOfflineBody : errorMessage(context, error),
              style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              Gap.h20,
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l.actionRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// No connection: the animal leans out from behind a wall to see where the
/// internet went. The peek's cut edge hides behind the wall, so the drawing is
/// never seen sliced.
class _OfflinePeek extends StatelessWidget {
  const _OfflinePeek();

  @override
  Widget build(BuildContext context) {
    final wall = context.isDark ? context.cs.surfaceContainerHigh : ZbTokens.tealTint;
    return SizedBox(
      width: 190,
      height: 176,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: 34,
            bottom: 0,
            child: Companion(ZbPose.peekSide, height: 168, idle: ZbIdle.peek, delay: Duration(milliseconds: 200)),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(color: wall, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Icon(Icons.wifi_off_rounded, size: 18, color: context.cs.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
