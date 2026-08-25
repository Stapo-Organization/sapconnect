import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../location/presentation/location_sheet.dart';

/// The launch screen.
///
/// It does exactly two things — restore the session from the keychain and,
/// on a first run, offer the location primer — then gets out of the way. It
/// deliberately does not wait on the catalog: the home screen has skeletons
/// for that, and a splash that lingers for a network call is a splash the
/// customer resents.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    // A floor on the splash so the logo animation reads as intentional
    // rather than as a flash, but the work runs in parallel with it.
    final minimumSplash = Future<void>.delayed(const Duration(milliseconds: 1100));

    await ref.read(sessionProvider.notifier).restore();
    await minimumSplash;
    if (!mounted) return;

    final store = ref.read(localStoreProvider);
    final location = ref.read(currentLocationProvider);
    final needsPrimer = !store.hasOnboarded && !location.isSet;

    context.go('/home');
    if (!needsPrimer) return;

    await store.setOnboarded();
    if (!mounted) return;
    // Offered *after* landing on home, so the customer can dismiss it and
    // still be looking at a store rather than at a blocking wall.
    await showLocationSheet(context, primer: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final mark = Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        gradient: zb.brandGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.30),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: SvgPicture.asset(
        'assets/brand/submark.svg',
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reduceMotion)
              mark
            else
              mark
                  .animate()
                  .scale(
                    begin: const Offset(0.72, 0.72),
                    end: const Offset(1, 1),
                    duration: 620.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 400.ms),
            Gap.h24,
            Text(
              l.appName,
              style: context.tt.headlineMedium?.copyWith(letterSpacing: -0.4),
            )
                .animate(target: reduceMotion ? 1 : null)
                .fadeIn(delay: 240.ms, duration: 420.ms)
                .moveY(begin: 8, end: 0, delay: 240.ms, duration: 420.ms),
          ],
        ),
      ),
    );
  }
}
