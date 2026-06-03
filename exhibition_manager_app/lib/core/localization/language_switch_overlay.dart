import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'app_localizations.dart';

/// Switches the app language behind a brief full-screen dissolve.
///
/// The locale flips instantly via [AppLocalizations.toggleLanguage], which is a
/// hard cut that "feels unprogrammed". We mask that cut: a branded scrim fades
/// in, the locale swaps at the peak (hidden), then the scrim fades out — so the
/// change reads as a deliberate transition, with haptic confirmation.
Future<void> animatedLanguageSwitch(BuildContext context) async {
  HapticFeedback.mediumImpact();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _LanguageDissolve(
      onPeak: () => AppLocalizations.toggleLanguage(),
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _LanguageDissolve extends StatefulWidget {
  final VoidCallback onPeak;
  final VoidCallback onDone;
  const _LanguageDissolve({required this.onPeak, required this.onDone});

  @override
  State<_LanguageDissolve> createState() => _LanguageDissolveState();
}

class _LanguageDissolveState extends State<_LanguageDissolve>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _swapped = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 660),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });
    _c.addListener(() {
      // Swap the locale at peak opacity, hidden behind the scrim.
      if (!_swapped && _c.value >= 0.5) {
        _swapped = true;
        widget.onPeak();
      }
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        // Triangular 0→1→0 envelope, eased.
        final raw = v < 0.5 ? v / 0.5 : 1 - (v - 0.5) / 0.5;
        final t = Curves.easeInOut.transform(raw.clamp(0.0, 1.0));
        final isArabic = AppLocalizations.isArabic;
        return IgnorePointer(
          ignoring: v < 0.05 || v > 0.95,
          child: Opacity(
            opacity: t,
            child: Container(
              color: AppColors.background,
              alignment: Alignment.center,
              child: Transform.scale(
                scale: 0.85 + 0.15 * t,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        gradient: AppColors.heroGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.language_rounded,
                          color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? 'العربية' : 'English',
                      style: AppTypography.titleMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
