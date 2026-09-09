import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/haptics.dart';

/// One of the four things a customer opens the account tab to do.
@immutable
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;

  /// The icon's own colour. Four quiet tints rather than one — this row is the
  /// only place on the screen that is allowed to be colourful, and it is what
  /// makes the settings under it read as settings.
  final Color tint;
  final VoidCallback onTap;

  /// A small count, when there is something waiting.
  final String? badge;
}

/// The shortcuts row: طلباتي · مشترياتي · المفضّلة · عناويني.
///
/// Four taps that used to be four rows in a list of eleven. A list is for
/// things you read; this is for things you *do*, and putting them above the
/// list is the difference between a settings screen and an account.
class AccountQuickActions extends StatelessWidget {
  const AccountQuickActions({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          for (final action in actions) Expanded(child: _ActionCell(action: action)),
        ],
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return InkWell(
      onTap: () {
        Haptics.selection();
        action.onTap();
      },
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: action.tint.withValues(alpha: context.isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(action.icon, size: 22, color: action.tint),
                ),
                if (action.badge != null)
                  PositionedDirectional(
                    top: -4,
                    end: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: cs.error,
                        borderRadius: BorderRadius.circular(ZbTokens.rPill),
                        border: Border.all(color: cs.surface, width: 1.5),
                      ),
                      child: Text(
                        action.badge!,
                        textAlign: TextAlign.center,
                        style: context.tt.labelSmall?.copyWith(
                          color: cs.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Gap.h8,
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
