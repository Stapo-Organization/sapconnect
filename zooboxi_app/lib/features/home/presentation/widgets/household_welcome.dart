import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/characters/companion.dart';
import '../../../../core/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pets/data/household.dart';
import '../../../pets/presentation/widgets/pet_card.dart' show speciesLabel;

final _owedThisLaunch = Provider<bool>((ref) {
  try {
    return !ref.read(localStoreProvider).householdWelcomed;
  } catch (_) {
    return false;
  }
});

/// The first home after «مين معك في البيت؟»: the page says what the answer
/// changed — once. The promise it makes is kept by the rail under it
/// («مختار لـ…») and by the animal drawn everywhere after.
class HouseholdWelcome extends ConsumerStatefulWidget {
  const HouseholdWelcome({super.key});

  /// Whether there is a welcome still owed: a household to greet, and a card
  /// not yet seen before this launch — it stays for the whole visit, however
  /// often the page rebuilds, and is gone next time.
  static bool owed(WidgetRef ref) => !ref.watch(householdProvider).isEmpty && ref.watch(_owedThisLaunch);

  @override
  ConsumerState<HouseholdWelcome> createState() => _HouseholdWelcomeState();
}

class _HouseholdWelcomeState extends ConsumerState<HouseholdWelcome> {
  @override
  void initState() {
    super.initState();
    // Seen is seen: the card stays for this visit and never comes back.
    ref.read(localStoreProvider).setHouseholdWelcomed();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final household = ref.watch(householdProvider);
    if (household.isEmpty) return const SizedBox.shrink();
    String name(HouseholdMember m) => m.name.isNotEmpty ? m.name : speciesLabel(l, m.species);
    final names = household.members.map(name).toList();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final joined = names.length == 1
        ? names.first
        : ar
            ? names.join(' و')
            : '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
    final focus = household.focus!;
    const sitter = 128.0;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 34),
            width: double.infinity,
            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: context.isDark ? cs.surfaceContainerHigh : ZbTokens.tealTintSoft,
              borderRadius: BorderRadius.circular(ZbTokens.rXl),
              border: Border.all(color: context.isDark ? cs.outlineVariant : ZbTokens.tealTint),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: sitter * 0.78),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.isDark ? cs.primaryContainer : ZbTokens.tealTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l.homeWelcomeKicker(joined),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.homeWelcomeTitle(name(focus)),
                    style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    household.members.length > 1 ? l.homeWelcomeSwitch : l.homeWelcomeSingle,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            end: 10,
            bottom: 8,
            child: Companion(ZbPose.wave, height: sitter, flip: !context.isRtl, delay: const Duration(milliseconds: 200)),
          ),
        ],
      ),
    );
  }
}
