import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/settings/app_settings.dart';
import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/motion/motion.dart';
import '../../../core/notifications/notify_permission.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/addresses_controller.dart';
import '../../account/presentation/address_editor_screen.dart';
import '../../location/data/location_models.dart';
import '../../location/presentation/widgets/city_picker.dart';

/// رحلة الترحيب — the first-run journey: language, where we deliver, and
/// whether we may tell them their order moved.
///
/// It runs on one brand canvas rather than three screens, because the three
/// questions are one conversation. The language cards switch the app's locale
/// on tap — no confirm step — so the answer to "which language?" is the screen
/// itself changing language under the thumb.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _stepCount = 3;

  /// How long the "وصلناك!" card stays on screen before the flow moves on —
  /// long enough to read the address we resolved, short enough not to stall.
  static const Duration _autoAdvance = Duration(milliseconds: 900);

  final PageController _pager = PageController();
  Timer? _advanceTimer;

  int _step = 0;
  bool _asking = false;
  bool _finishing = false;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    _advanceTimer?.cancel();
    if (_step >= _stepCount - 1) {
      unawaited(_finish());
      return;
    }
    Haptics.light();
    setState(() => _step += 1);
    if (context.reduceMotion) {
      _pager.jumpToPage(_step);
    } else {
      unawaited(_pager.animateToPage(_step, duration: Motion.page, curve: Motion.emphasized));
    }
  }

  void _back() {
    if (_step == 0) return;
    _advanceTimer?.cancel();
    Haptics.light();
    setState(() => _step -= 1);
    if (context.reduceMotion) {
      _pager.jumpToPage(_step);
    } else {
      unawaited(_pager.animateToPage(_step, duration: Motion.enter, curve: Motion.emphasized));
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _advanceTimer?.cancel();
    await ref.read(localStoreProvider).setWelcomeSeen();
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _pickLocale(String code) async {
    if (code == ref.read(appSettingsProvider).effectiveLocale.languageCode) return;
    Haptics.selection();
    await ref.read(appSettingsProvider.notifier).setLocale(code);
  }

  /// The precise answer to "where do we deliver?": a pin the customer placed
  /// themselves, plus the building, floor and flat behind the door.
  ///
  /// Where the address lands depends on who is asking. A signed-in customer
  /// gets it in their book straight away; a guest's waits on the device until
  /// checkout, which is where an account can finally put a name on it.
  Future<void> _pinAddress() async {
    Haptics.light();
    // The step is captured before the await: a customer who taps «لاحقًا»
    // while the editor is open has answered — a late success must not push
    // them off whichever step they moved to.
    final from = _step;
    final loggedIn = ref.read(sessionProvider).isAuthenticated;

    final draft = await showAddressEditor(
      context,
      contactOptional: !loggedIn,
      autoLocate: true,
    );
    if (draft == null || !mounted || _step != from) return;

    final store = ref.read(localStoreProvider);
    var stored = false;
    if (loggedIn) {
      try {
        await ref.read(addressesControllerProvider.notifier).save(draft.address);
        stored = true;
      } catch (_) {
        // A refused request must never cost the customer the address they
        // just typed — it waits on the device and checkout picks it up.
      }
    }
    if (!stored) await store.setPendingAddress(draft.address.toJson());

    final lat = draft.address.lat;
    final lng = draft.address.lng;
    if (lat != null && lng != null) {
      await ref.read(locationProvider.notifier).resolve(lat, lng);
    }

    if (!mounted || _step != from) return;
    _scheduleAdvance();
  }

  Future<void> _openCities() async {
    Haptics.selection();
    final l = L.of(context);
    await showZbSheet<void>(
      context,
      builder: (sheet) => BottomSheetScaffold(
        title: l.citiesTitle,
        bodyPadding: EdgeInsets.zero,
        child: CityPicker(
          onSelected: (city) {
            Haptics.selection();
            // Popped with the sheet's own context, synchronously — popping
            // the screen's navigator after an await would hit whatever is on
            // top by then, which after a hand-dismissed sheet is this screen.
            Navigator.of(sheet).pop();
            unawaited(_applyCity(city));
          },
        ),
      ),
    );
  }

  Future<void> _applyCity(CityEntry city) async {
    final from = _step;
    await ref.read(locationProvider.notifier).setCity(city);
    if (!mounted || _step != from) return;
    _scheduleAdvance();
  }

  /// Moves on by itself once we know where they are — but only from the step
  /// that asked, so a customer who tapped «استمرار» in the meantime isn't
  /// pushed a page further a beat later.
  void _scheduleAdvance() {
    unawaited(Haptics.success());
    final from = _step;
    _advanceTimer?.cancel();
    _advanceTimer = Timer(_autoAdvance, () {
      if (!mounted || _step != from) return;
      _next();
    });
  }

  Future<void> _allowNotifications() async {
    if (_asking) return;
    Haptics.light();
    setState(() => _asking = true);
    // The answer doesn't branch the flow: a refusal is a valid answer, and
    // nagging for it here would cost the first session.
    await NotifyPermission.request();
    if (!mounted) return;
    setState(() => _asking = false);
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;

    final steps = <Widget>[
      _WelcomeStep(
        selected: ref.watch(appSettingsProvider).effectiveLocale.languageCode,
        onPick: (code) => unawaited(_pickLocale(code)),
        onNext: _next,
      ),
      _LocationStep(
        onPinAddress: () => unawaited(_pinAddress()),
        onChooseCity: () => unawaited(_openCities()),
        onNext: _next,
      ),
      _NotificationsStep(
        asking: _asking,
        onAllow: () => unawaited(_allowNotifications()),
        onLater: _next,
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The canvas is deep in both themes, so the clock stays light throughout.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: zb.brandGradient),
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(step: _step, count: _stepCount, onBack: _step == 0 ? null : _back),
                Expanded(
                  child: PageView(
                    controller: _pager,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        AnimatedSwitcher(
                          duration: context.motion(Motion.enter),
                          // Keyed on the locale too: flipping language swaps
                          // every string on the page, and it should read as a
                          // cross-fade rather than as a flicker.
                          child: KeyedSubtree(key: ValueKey('$i-$locale'), child: steps[i]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared canvas vocabulary ───────────────────────────────────────────
//
// Everything here sits on the brand gradient, so the "foreground" is a light
// tone rather than a theme color — the same convention the home hero uses.

Color _canvasFg(BuildContext context) =>
    context.isDark ? ZbTokens.inkDark : Colors.white;

/// Text/icon color on top of a solid [_canvasFg] fill (buttons, cards).
const Color _onSolid = ZbTokens.tealDeep;

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, required this.count, this.onBack});

  final int step;
  final int count;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    color: fg,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    icon: Icon(
                      context.isRtl
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                  ),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) Gap.w6,
                  Expanded(
                    child: AnimatedContainer(
                      duration: context.motion(Motion.select),
                      curve: Motion.decelerate,
                      height: 4,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: i <= step ? 1 : 0.28),
                        borderRadius: BorderRadius.circular(ZbTokens.rPill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Balances the back slot so the segments stay centred on every step.
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// A step's skeleton: content that centres itself and scrolls when it can't,
/// over a footer of actions pinned above the home indicator.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.content, required this.footer});

  final List<Widget> content;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (box.maxHeight - 16).clamp(0.0, double.infinity),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: content,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: footer,
          ),
        ),
      ],
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({required this.child, this.size = 44, this.radius = 14, this.padding});

  final Widget child;
  final double size;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    return Container(
      width: size,
      height: size,
      padding: padding,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _GlassTile(size: 34, radius: 11, child: Icon(icon, size: 17, color: fg)),
          Gap.w12,
          Expanded(
            child: Text(
              text,
              style: context.tt.bodyMedium?.copyWith(
                color: fg.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The canvas CTA. [filled] is the solid light pill; the hollow variant is the
/// same shape in glass, so a step can carry two actions without either of them
/// competing with the brand.
class _CanvasButton extends StatelessWidget {
  const _CanvasButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    final content = filled ? _onSolid : fg;
    final radius = BorderRadius.circular(16);

    return PressScale(
      borderRadius: radius,
      haptic: null,
      onTap: busy ? null : onPressed,
      child: Container(
        height: 52,
        alignment: AlignmentDirectional.center,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: filled ? fg : fg.withValues(alpha: 0.12),
          borderRadius: radius,
          border: filled ? null : Border.all(color: fg.withValues(alpha: 0.40)),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(content),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 19, color: content), Gap.w8],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelLarge?.copyWith(color: content),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The way out of a step. Quiet on purpose — it must be findable without ever
/// looking like the thing to do.
class _CanvasTextAction extends StatelessWidget {
  const _CanvasTextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    return Align(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: fg.withValues(alpha: 0.88),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
        ),
        child: Text(label),
      ),
    );
  }
}

// ── Step 1 · Welcome + language ────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.selected,
    required this.onPick,
    required this.onNext,
  });

  final String selected;
  final ValueChanged<String> onPick;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final fg = _canvasFg(context);
    final still = context.reduceMotion;

    final hero = Column(
      children: [
        _GlassTile(
          size: 96,
          radius: 26,
          padding: const EdgeInsets.all(20),
          child: SvgPicture.asset(
            'assets/brand/submark.svg',
            colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
          ),
        ),
        Gap.h20,
        Text(
          l.appName,
          textAlign: TextAlign.center,
          style: context.tt.displaySmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            fontSize: 34,
          ),
        ),
        Gap.h8,
        Text(
          l.onbWelcomeTitle,
          textAlign: TextAlign.center,
          style: context.tt.titleMedium?.copyWith(color: fg.withValues(alpha: 0.95)),
        ),
        Gap.h8,
        Text(
          l.onbWelcomeBody,
          textAlign: TextAlign.center,
          style: context.tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.80)),
        ),
      ],
    );

    return Stack(
      children: [
        const _WelcomeDecor(),
        _StepBody(
          content: [
            hero
                .animate(target: still ? 1 : null)
                .fadeIn(duration: 420.ms)
                .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1), duration: 520.ms, curve: Motion.spring),
            Gap.h32,
            Text(
              l.onbLanguageTitle,
              textAlign: TextAlign.center,
              style: context.tt.titleMedium?.copyWith(color: fg.withValues(alpha: 0.9)),
            ),
            Gap.h12,
            Row(
              children: [
                // These two labels are never translated: a language is written
                // in its own language, or the person looking for it can't read it.
                Expanded(
                  child: _LanguageCard(
                    label: 'العربية',
                    direction: TextDirection.rtl,
                    selected: selected == 'ar',
                    onTap: () => onPick('ar'),
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: _LanguageCard(
                    label: 'English',
                    direction: TextDirection.ltr,
                    selected: selected == 'en',
                    onTap: () => onPick('en'),
                  ),
                ),
              ],
            ),
          ],
          footer: [_CanvasButton(label: l.onbStart, onPressed: onNext)],
        ),
      ],
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.label,
    required this.direction,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final TextDirection direction;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    final radius = BorderRadius.circular(ZbTokens.rLg);
    final content = selected ? _onSolid : fg;

    return PressScale(
      borderRadius: radius,
      haptic: null,
      onTap: onTap,
      child: AnimatedContainer(
        duration: context.motion(Motion.select),
        curve: Motion.decelerate,
        height: 58,
        alignment: AlignmentDirectional.center,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? fg : fg.withValues(alpha: 0.12),
          borderRadius: radius,
          border: Border.all(
            color: selected ? Colors.transparent : fg.withValues(alpha: 0.40),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_circle_rounded, size: 18, color: content),
              Gap.w6,
            ],
            Flexible(
              child: Text(
                label,
                textDirection: direction,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.titleMedium?.copyWith(
                  color: content,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft brand furniture behind the welcome step — rings, blobs and a paw, all
/// at an alpha that reads as texture rather than as content.
class _WelcomeDecor extends StatelessWidget {
  const _WelcomeDecor();

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    return IgnorePointer(
      child: Stack(
        children: [
          PositionedDirectional(
            top: -78,
            end: -62,
            child: _Ring(size: 236, color: fg.withValues(alpha: 0.10)),
          ),
          PositionedDirectional(
            top: 96,
            start: -96,
            child: _Blob(size: 196, color: fg.withValues(alpha: 0.07)),
          ),
          PositionedDirectional(
            bottom: -54,
            end: 26,
            child: _Blob(size: 168, color: fg.withValues(alpha: 0.06)),
          ),
          PositionedDirectional(
            bottom: 112,
            start: 22,
            child: _Paw(size: 62, color: fg.withValues(alpha: 0.08)),
          ),
          PositionedDirectional(
            top: 44,
            start: 74,
            child: _Paw(size: 34, color: fg.withValues(alpha: 0.07)),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color, this.width = 14});

  final double size;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: width),
        ),
      );
}

/// A paw drawn from primitives: one pad and four toes. Cheaper than an asset
/// and it tints with the canvas.
class _Paw extends StatelessWidget {
  const _Paw({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final toe = size * 0.20;
    Widget dot() => Container(
          width: toe,
          height: toe,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          PositionedDirectional(
            bottom: 0,
            start: size * 0.16,
            child: Container(
              width: size * 0.68,
              height: size * 0.56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.all(
                  Radius.elliptical(size * 0.34, size * 0.28),
                ),
              ),
            ),
          ),
          PositionedDirectional(top: size * 0.12, start: 0, child: dot()),
          PositionedDirectional(top: 0, start: size * 0.27, child: dot()),
          PositionedDirectional(top: 0, start: size * 0.54, child: dot()),
          PositionedDirectional(top: size * 0.12, start: size * 0.80, child: dot()),
        ],
      ),
    );
  }
}

// ── Step 2 · Location ──────────────────────────────────────────────────

class _LocationStep extends ConsumerWidget {
  const _LocationStep({
    required this.onPinAddress,
    required this.onChooseCity,
    required this.onNext,
  });

  final VoidCallback onPinAddress;
  final VoidCallback onChooseCity;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final fg = _canvasFg(context);
    final state = ref.watch(locationProvider);
    final isSet = state.location.isSet;
    final stalled =
        state.phase == LocationPhase.denied || state.phase == LocationPhase.failed;

    final pin = _CanvasButton(
      label: l.onbLocCta,
      icon: Icons.pin_drop_rounded,
      busy: state.isBusy,
      filled: !stalled,
      onPressed: onPinAddress,
    );
    final city = _CanvasButton(
      label: l.onbLocCity,
      icon: Icons.location_city_rounded,
      filled: stalled,
      onPressed: onChooseCity,
    );

    return _StepBody(
      content: [
        Align(child: _PinMotif(fg: fg)),
        Gap.h24,
        Text(
          l.onbLocTitle,
          textAlign: TextAlign.center,
          style: context.tt.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w900),
        ),
        Gap.h8,
        Text(
          l.onbLocBody,
          textAlign: TextAlign.center,
          style: context.tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.82)),
        ),
        Gap.h24,
        // Once we know where they are the generic promises are noise — the
        // resolved address and its delivery window say all three of them.
        if (isSet)
          _LocationSetCard(location: state.location)
        else ...[
          _PerkRow(icon: Icons.bolt_rounded, text: l.onbLocPerk1),
          _PerkRow(icon: Icons.inventory_2_rounded, text: l.onbLocPerk2),
          _PerkRow(icon: Icons.local_offer_rounded, text: l.onbLocPerk3),
        ],
      ],
      footer: [
        if (stalled && !isSet) ...[
          _InlineNote(text: l.onbLocFailed),
          Gap.h12,
        ],
        if (isSet) ...[
          _CanvasButton(label: l.onbContinue, onPressed: onNext),
          Gap.h8,
          city,
        ] else ...[
          if (stalled) ...[city, Gap.h8, pin] else ...[pin, Gap.h8, city],
          _CanvasTextAction(label: l.onbLater, onPressed: onNext),
        ],
      ],
    );
  }
}

/// The place pin, sitting inside two rings that echo a signal spreading out.
class _PinMotif extends StatelessWidget {
  const _PinMotif({required this.fg});

  final Color fg;

  @override
  Widget build(BuildContext context) {
    final motif = SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          _Ring(size: 148, color: fg.withValues(alpha: 0.10), width: 1.4),
          _Ring(size: 112, color: fg.withValues(alpha: 0.18), width: 1.4),
          _GlassTile(
            size: 76,
            radius: 24,
            child: Icon(Icons.place_rounded, size: 34, color: fg),
          ),
        ],
      ),
    );

    return motif
        .animate(target: context.reduceMotion ? 1 : null)
        .fadeIn(duration: 420.ms)
        .scale(
          begin: const Offset(0.86, 0.86),
          end: const Offset(1, 1),
          duration: 560.ms,
          curve: Motion.spring,
        );
  }
}

/// What we resolved, said back to them in their own words — the proof that
/// granting the permission bought them something.
class _LocationSetCard extends StatelessWidget {
  const _LocationSetCard({required this.location});

  final ZbLocation location;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final fg = _canvasFg(context);
    final locale = Localizations.localeOf(context).languageCode;
    final detail = location.detailLabel(locale);
    final promise = location.promiseLabel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fg,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 22, color: ZbTokens.success),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.onbLocSetTitle,
                  style: context.tt.bodySmall?.copyWith(color: ZbTokens.inkSoft),
                ),
                if (detail != null && detail.isNotEmpty)
                  Text(
                    detail,
                    style: context.tt.titleMedium?.copyWith(
                      color: ZbTokens.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (promise != null && promise.isNotEmpty) ...[
                  Gap.h8,
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ZbTokens.tealTint,
                      borderRadius: BorderRadius.circular(ZbTokens.rPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 13, color: ZbTokens.tealDeep),
                        Gap.w4,
                        Text(
                          promise,
                          style: context.tt.labelSmall?.copyWith(
                            color: ZbTokens.tealDeep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: fg.withValues(alpha: 0.9)),
        Gap.w8,
        Expanded(
          child: Text(
            text,
            style: context.tt.bodySmall?.copyWith(color: fg.withValues(alpha: 0.9)),
          ),
        ),
      ],
    );
  }
}

// ── Step 3 · Notifications ─────────────────────────────────────────────

class _NotificationsStep extends StatelessWidget {
  const _NotificationsStep({
    required this.asking,
    required this.onAllow,
    required this.onLater,
  });

  final bool asking;
  final VoidCallback onAllow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final fg = _canvasFg(context);

    return _StepBody(
      content: [
        const _MockNotification(),
        Gap.h32,
        Text(
          l.onbNotifTitle,
          textAlign: TextAlign.center,
          style: context.tt.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w900),
        ),
        Gap.h8,
        Text(
          l.onbNotifBody,
          textAlign: TextAlign.center,
          style: context.tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.82)),
        ),
        Gap.h24,
        _PerkRow(icon: Icons.local_shipping_rounded, text: l.onbNotifPerk1),
        _PerkRow(icon: Icons.local_offer_rounded, text: l.onbNotifPerk2),
        _PerkRow(icon: Icons.notifications_active_rounded, text: l.onbNotifPerk3),
      ],
      footer: [
        _CanvasButton(label: l.onbNotifCta, busy: asking, onPressed: onAllow),
        _CanvasTextAction(label: l.onbLater, onPressed: onLater),
      ],
    );
  }
}

/// The permission being asked for, shown rather than described: the exact
/// notification the customer would get, on a card that looks like the real one.
class _MockNotification extends StatelessWidget {
  const _MockNotification();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final fg = _canvasFg(context);
    final still = context.reduceMotion;

    final ghost = Container(
      height: 46,
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
    );

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: context.zb.brandGradient,
              borderRadius: BorderRadius.circular(ZbTokens.rSm),
            ),
            child: SvgPicture.asset(
              'assets/brand/submark.svg',
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.onbNotifMockTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.titleMedium?.copyWith(
                    color: ZbTokens.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l.onbNotifMockBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodySmall?.copyWith(color: ZbTokens.inkSoft),
                ),
              ],
            ),
          ),
          Gap.w8,
          Text(
            l.onbNotifNow,
            style: context.tt.labelSmall?.copyWith(color: ZbTokens.inkSoft),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        PositionedDirectional(
          top: 0,
          start: 22,
          end: 22,
          child: ghost
              .animate(target: still ? 1 : null)
              .fadeIn(duration: 320.ms)
              .moveY(begin: -14, end: 0, duration: 420.ms, curve: Motion.decelerate),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 22),
          child: card
              .animate(target: still ? 1 : null)
              .fadeIn(delay: 160.ms, duration: 360.ms)
              .moveY(begin: 16, end: 0, delay: 160.ms, duration: 460.ms, curve: Motion.decelerate),
        ),
      ],
    );
  }
}
