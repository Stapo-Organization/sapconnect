import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pets/data/household.dart';

/// «مين معك في البيت؟» for everyone the welcome never asked — every existing
/// install, and whoever tapped «لاحقًا». The pair from the logo invites; the
/// answer arranges the page. «ليس الآن» rests it for a month.
class HouseholdInvite extends ConsumerStatefulWidget {
  const HouseholdInvite({super.key});

  static const Duration _rest = Duration(days: 30);

  /// Whether to ask: nobody at home that we know of, not «أتسوّق لغيري», and
  /// not declined lately.
  static bool owed(WidgetRef ref) {
    final household = ref.watch(householdProvider);
    if (!household.isEmpty || household.shopsForOthers) return false;
    try {
      final dismissed = ref.read(localStoreProvider).householdInviteDismissed;
      return dismissed == null || DateTime.now().difference(dismissed) >= _rest;
    } catch (_) {
      return false;
    }
  }

  @override
  ConsumerState<HouseholdInvite> createState() => _HouseholdInviteState();
}

class _HouseholdInviteState extends ConsumerState<HouseholdInvite> {
  bool _gone = false;

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    final l = L.of(context);
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 34),
            child: PressScale(
              borderRadius: BorderRadius.circular(ZbTokens.rXl),
              onTap: () => context.push('/household'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 10),
                decoration: BoxDecoration(
                  color: context.isDark ? cs.surfaceContainerHigh : ZbTokens.tealTintSoft,
                  borderRadius: BorderRadius.circular(ZbTokens.rXl),
                  border: Border.all(color: context.isDark ? cs.outlineVariant : ZbTokens.tealTint),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 118),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.onbPetsTitle, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(l.householdInviteBody, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
                            child: Text(
                              l.householdInviteCta,
                              style: context.tt.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Haptics.selection();
                              ref.read(localStoreProvider).dismissHouseholdInvite();
                              setState(() => _gone = true);
                            },
                            child: Text(l.householdInviteDismiss),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The logo's pair, whole.
          PositionedDirectional(
            end: 64,
            bottom: 10,
            child: ZbSticker.cast(ZbCast.dog, ZbPose.sitUp, height: 104, flip: !context.isRtl),
          ),
          PositionedDirectional(
            end: 8,
            bottom: 10,
            child: ZbSticker.cast(ZbCast.cat, ZbPose.wave, height: 96, flip: !context.isRtl, delay: const Duration(milliseconds: 160)),
          ),
        ],
      ),
    );
  }
}
