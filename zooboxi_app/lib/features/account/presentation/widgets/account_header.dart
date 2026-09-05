import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../loyalty/data/loyalty_models.dart';
import '../../../loyalty/presentation/widgets/paws_pill.dart';

/// The identity block at the top of the account tab. A guest gets an
/// invitation rather than a blank avatar — the sign-in prompt *is* the header.
class AccountHeader extends StatelessWidget {
  const AccountHeader({
    super.key,
    required this.user,
    required this.onSignIn,
    this.tier,
    this.paws,
    this.onOpenFamily,
  });

  final ZbUser? user;
  final VoidCallback onSignIn;

  /// Standing and wallet, when the loyalty program answered. Both null is the
  /// normal state for a guest, a store with the program off, or a summary that
  /// hasn't landed — the header simply keeps its old shape.
  final TierInfo? tier;
  final int? paws;
  final VoidCallback? onOpenFamily;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final signedIn = user != null;
    final standing = tier;
    final balance = paws;
    final hasLoyalty = signedIn && (standing != null || (balance ?? 0) > 0);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: signedIn ? zb.brandGradient : null,
              color: signedIn ? null : cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            // A signed-in customer who never filled in a name gets the same
            // glyph as a guest rather than a placeholder character.
            child: signedIn && _initial(user!.name).isNotEmpty
                ? Text(
                    _initial(user!.name),
                    style: context.tt.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Icon(
                    Icons.person_outline_rounded,
                    color: signedIn ? Colors.white : cs.onSurfaceVariant,
                  ),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signedIn && user!.name.isNotEmpty ? user!.name : l.accountGuest,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.titleMedium,
                ),
                Gap.h4,
                Text(
                  signedIn ? Fmt.phone(user!.phone) : l.accountGuestHint,
                  maxLines: 2,
                  // A phone number reads left-to-right in both languages.
                  textDirection: signedIn ? TextDirection.ltr : null,
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                // Standing and wallet, one tap from the program itself.
                if (hasLoyalty) ...[
                  Gap.h8,
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (standing != null && standing.name.isNotEmpty)
                        TierChip(
                          label: standing.name,
                          c1: standing.c1,
                          c2: standing.c2,
                          compact: true,
                          onTap: onOpenFamily,
                        ),
                      PawsPill(
                        paws: balance ?? 0,
                        compact: true,
                        onTap: onOpenFamily,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!signedIn) ...[
            Gap.w12,
            FilledButton(onPressed: onSignIn, child: Text(l.accountLogin)),
          ],
        ],
      ),
    );
  }

  /// First grapheme of the display name, or empty when there isn't one.
  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '' : trimmed.characters.first;
  }
}
