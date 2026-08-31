import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/icons/zb_icons.dart';
import '../../../core/motion/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_repository.dart';

/// Full-screen barcode scanner.
///
/// The store indexes both retail barcodes and SAP item codes, so scanning the
/// pack in a customer's cupboard is the fastest possible reorder path — faster
/// than remembering a product name in either language.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.qrCode,
    ],
  );

  bool _handling = false;
  String? _lastRejected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .firstOrNull;
    if (code == null || code == _lastRejected) return;

    setState(() => _handling = true);
    Haptics.medium();

    try {
      final product = await ref.read(catalogRepositoryProvider).byBarcode(code);
      if (!mounted) return;

      if (product == null) {
        // Remembered so the same pack still in frame doesn't re-fire the
        // lookup every frame — the customer has to move to a different code.
        _lastRejected = code;
        AppToast.error(context, L.of(context).scanNotFound);
        setState(() => _handling = false);
        return;
      }

      await Haptics.success();
      if (!mounted) return;
      // Replace, so backing out of the product doesn't drop into a live
      // camera the customer has already finished with.
      context.pushReplacement('/product/${product.id}', extra: product);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, L.of(context).errUnknown);
      setState(() => _handling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(l.scanTitle, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_rounded),
            tooltip: l.scanTitle,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _PermissionNotice(message: l.scanPermission),
          ),
          const _ScannerOverlay(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_handling)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: _ScanPulse(),
                  ),
                Text(
                  l.scanHint,
                  textAlign: TextAlign.center,
                  style: context.tt.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's scan glyph with its line travelling top→bottom and back, so the
/// screen reads as *looking* while the camera is up. It sits under the frame,
/// clear of the cut-out, rather than over the barcode.
class _ScanPulse extends StatefulWidget {
  const _ScanPulse();

  @override
  State<_ScanPulse> createState() => _ScanPulseState();
}

class _ScanPulseState extends State<_ScanPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => ZbIcon(
          ZbIconKind.scan,
          size: 44,
          ink: Colors.white.withValues(alpha: 0.92),
          scanY: _c.value,
        ),
      );
}

/// Dimmed surround with a clear cut-out and corner brackets — the standard
/// "aim here" affordance, which also tells the customer how close to get.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final window = size.width * 0.72;

    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.55),
            child: const SizedBox.expand(),
          ),
          Container(
            width: window,
            height: window * 0.68,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 0,
                  spreadRadius: 4000,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 40),
                Gap.h16,
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.tt.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );
}
