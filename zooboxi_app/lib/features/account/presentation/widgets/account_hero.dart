import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../loyalty/data/loyalty_models.dart';

/// The colour at the very top of the canvas. The pinned bar above the hero
/// paints itself with this, so the bar and the canvas are one surface and the
/// seam between them cannot be found.
Color heroTop(BuildContext context) =>
    context.isDark ? const Color(0xFF11312F) : ZbTokens.tealDeep;

/// The identity canvas at the top of «حسابي».
///
/// An account tab is the one screen with no products on it, so it has to earn
/// its place another way: by telling the customer who the shop thinks they
/// are, what they have with it, and how far they are from the next thing.
/// Three facts, one surface, no chrome — the settings underneath stay quiet
/// precisely because this carries the weight.
///
/// A guest gets the same canvas with an invitation in place of the numbers. It
/// is never a blank avatar over an empty name: nobody is a placeholder.
class AccountHero extends StatelessWidget {
  const AccountHero({
    super.key,
    required this.user,
    required this.onSignIn,
    this.tier,
    this.paws,
    this.orders,
    this.pets,
    this.onOpenFamily,
    this.onOpenOrders,
    this.onOpenPets,
  });

  final ZbUser? user;
  final VoidCallback onSignIn;

  /// Standing and wallet, when the loyalty layer answered. All null is the
  /// ordinary state for a guest, a store with the program off, or a summary
  /// still in flight — the canvas simply keeps its shape.
  final TierInfo? tier;
  final int? paws;
  final int? orders;
  final int? pets;

  final VoidCallback? onOpenFamily;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenPets;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final signedIn = user != null;
    final dark = context.isDark;

    // Deep teal, the app's own hero ground. Coral is the brand's accent, not
    // its field: a full screen of it would shout where this should settle.
    final canvas = dark
        ? const [Color(0xFF11312F), Color(0xFF17403E)]
        : const [ZbTokens.tealDeep, ZbTokens.tealDark];
    assert(canvas.first == heroTop(context));

    // Vertical, so the pinned bar above it and this share one colour at the
    // seam and read as a single surface.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: canvas,
        ),
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(28),
          bottomEnd: Radius.circular(28),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // A soft light behind the avatar — the difference between a painted
          // rectangle and a lit surface.
          PositionedDirectional(
            top: -70,
            end: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.06 : 0.13),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Identity(
                  user: user,
                  onSignIn: onSignIn,
                  tier: tier,
                  onOpenFamily: onOpenFamily,
                ),
                if (signedIn) ...[
                  if (_progressLine(context) case final String line) ...[
                    Gap.h16,
                    _TierProgress(tier: tier!, line: line, onTap: onOpenFamily),
                  ],
                  Gap.h16,
                  _Stats(
                    orders: orders,
                    paws: paws,
                    pets: pets,
                    onOpenOrders: onOpenOrders,
                    onOpenFamily: onOpenFamily,
                    onOpenPets: onOpenPets,
                  ),
                ] else ...[
                  Gap.h16,
                  Text(
                    l.accountGuestHint,
                    style: context.tt.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.45,
                    ),
                  ),
                  Gap.h12,
                  FilledButton(
                    onPressed: onSignIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ZbTokens.tealDeep,
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(l.accountLogin),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// «طلبان يفصلانك عن مميّز» — only when the program has a next rung and a
  /// real count to measure it by. Silence beats an invented milestone.
  String? _progressLine(BuildContext context) {
    final standing = tier;
    final next = standing?.next;
    if (standing == null || next == null || next.name.isEmpty) return null;
    final left = standing.ordersToNext;
    if (left <= 0) return null;
    return L.of(context).accountTierProgress(left, next.name);
  }
}

/// Avatar, name, and what the shop calls them.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.user,
    required this.onSignIn,
    required this.tier,
    required this.onOpenFamily,
  });

  final ZbUser? user;
  final VoidCallback onSignIn;
  final TierInfo? tier;
  final VoidCallback? onOpenFamily;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final signedIn = user != null;
    // A customer who never typed a name is still a customer — the screenshot
    // that called a signed-in account «زائر» is how this line got written.
    final name = !signedIn
        ? l.accountGuest
        : (user!.name.trim().isNotEmpty ? user!.name : l.accountMemberFallback);
    final standing = tier;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1.5),
          ),
          alignment: Alignment.center,
          child: signedIn && _initial(user!.name).isNotEmpty
              ? Text(
                  _initial(user!.name),
                  style: context.tt.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : const Icon(Icons.person_outline_rounded, color: Colors.white, size: 30),
        ),
        Gap.w16,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (signedIn) ...[
                Gap.h4,
                Text(
                  Fmt.phone(user!.phone),
                  // A phone number reads left-to-right in both languages.
                  textDirection: TextDirection.ltr,
                  style: context.tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                if (standing != null && standing.name.isNotEmpty) ...[
                  Gap.h8,
                  _CanvasTier(label: standing.name, onTap: onOpenFamily),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '' : trimmed.characters.first;
  }
}

/// The tier's name on the canvas. The program's own colours are mixed for
/// light cards and go muddy on a deep ground, so here it is glass and a star.
class _CanvasTier extends StatelessWidget {
  const _CanvasTier({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(ZbTokens.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_rounded, size: 14, color: ZbTokens.amber),
              Gap.w4,
              Text(
                label,
                style: context.tt.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How far to the next rung, as one sentence and one line.
class _TierProgress extends StatelessWidget {
  const _TierProgress({required this.tier, required this.line, this.onTap});

  final TierInfo tier;
  final String line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            line,
            style: context.tt.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          Gap.h8,
          ClipRRect(
            borderRadius: BorderRadius.circular(ZbTokens.rPill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: tier.progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.20),
                valueColor: const AlwaysStoppedAnimation(ZbTokens.amber),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three numbers the customer owns, on glass: orders, paws, pets.
///
/// Each is a door, not a decoration — tapping the count opens the thing it
/// counts, which is the whole reason a figure belongs on a screen at all.
class _Stats extends StatelessWidget {
  const _Stats({
    required this.orders,
    required this.paws,
    required this.pets,
    this.onOpenOrders,
    this.onOpenFamily,
    this.onOpenPets,
  });

  final int? orders;
  final int? paws;
  final int? pets;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenFamily;
  final VoidCallback? onOpenPets;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              value: Fmt.number(orders ?? 0, locale: locale, decimals: 0),
              label: l.accountStatOrders,
              onTap: onOpenOrders,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _Stat(
              value: Fmt.number(paws ?? 0, locale: locale, decimals: 0),
              label: l.accountStatPaws,
              onTap: onOpenFamily,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _Stat(
              value: Fmt.number(pets ?? 0, locale: locale, decimals: 0),
              label: l.accountStatPets,
              onTap: onOpenPets,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.16));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: context.tt.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                // Tabular, so three counts sit on the same rhythm.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
