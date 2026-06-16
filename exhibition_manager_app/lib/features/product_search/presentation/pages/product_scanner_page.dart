import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';

/// Minimal full-screen barcode scanner for product lookup. Unlike the counting
/// scanner, this one does one thing: on a detected code it pops with the raw
/// barcode string, so the search page can look it up.
class ProductScannerPage extends StatefulWidget {
  const ProductScannerPage({super.key});

  @override
  State<ProductScannerPage> createState() => _ProductScannerPageState();
}

class _ProductScannerPageState extends State<ProductScannerPage> {
  static const Color _accent = Color(0xFF4C5FD5);

  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _handled = false;
  bool _flashOn = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            MobileScanner(controller: _camera, onDetect: _onDetect),
            CustomPaint(size: Size.infinite, painter: _FramePainter(_accent)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _circleBtn(Icons.close_rounded, () => Navigator.of(context).pop()),
                    Text(
                      'امسح باركود المنتج',
                      style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    _circleBtn(_flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, () {
                      _camera.toggleTorch();
                      setState(() => _flashOn = !_flashOn);
                    }),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 90,
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              child: Text(
                'وجّه الكاميرا نحو الباركود',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

/// Dimmed backdrop with a rounded scan window and cobalt corner accents.
class _FramePainter extends CustomPainter {
  final Color accent;
  _FramePainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final scan = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 60),
      width: size.width * 0.72,
      height: size.width * 0.72 * 0.62,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scan, const Radius.circular(18))),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final corner = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    // Top-left
    canvas.drawLine(Offset(scan.left, scan.top + 18), Offset(scan.left, scan.top + 18 + len), corner);
    canvas.drawLine(Offset(scan.left + 18, scan.top), Offset(scan.left + 18 + len, scan.top), corner);
    // Top-right
    canvas.drawLine(Offset(scan.right, scan.top + 18), Offset(scan.right, scan.top + 18 + len), corner);
    canvas.drawLine(Offset(scan.right - 18, scan.top), Offset(scan.right - 18 - len, scan.top), corner);
    // Bottom-left
    canvas.drawLine(Offset(scan.left, scan.bottom - 18), Offset(scan.left, scan.bottom - 18 - len), corner);
    canvas.drawLine(Offset(scan.left + 18, scan.bottom), Offset(scan.left + 18 + len, scan.bottom), corner);
    // Bottom-right
    canvas.drawLine(Offset(scan.right, scan.bottom - 18), Offset(scan.right, scan.bottom - 18 - len), corner);
    canvas.drawLine(Offset(scan.right - 18, scan.bottom), Offset(scan.right - 18 - len, scan.bottom), corner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
