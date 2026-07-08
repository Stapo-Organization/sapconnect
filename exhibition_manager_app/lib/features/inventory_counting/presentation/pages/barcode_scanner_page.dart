import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/counting_repository.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/models/counting_session.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Scan modes — determines the context of scanning
enum ScanMode {
  inventoryCounting,     // Scan for inventory counting
  stockTransferSend,     // Scan for stock transfer send verification
  stockTransferReceive,  // Scan for stock transfer receive verification
}

/// Barcode Scanner Page — Full screen camera with overlay
class BarcodeScannerPage extends StatefulWidget {
  final int? countingSessionId;
  final ScanMode mode;
  final List<Map<String, dynamic>>? expectedItems;

  /// Cycle-count gating: when true, items scanned that are NOT in the target
  /// list are blocked (a warning sheet is shown instead of the add sheet).
  /// Only used for inventory-counting cycle sessions.
  final bool isCycle;

  /// Fast client-side fallback set of target item codes (the server flag
  /// `in_target_list` is authoritative; this avoids a round-trip miss).
  final Set<String>? cycleTargetCodes;

  const BarcodeScannerPage({
    super.key,
    this.countingSessionId,
    this.mode = ScanMode.inventoryCounting,
    this.expectedItems,
    this.isCycle = false,
    this.cycleTargetCodes,
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final CountingRepository _repo = CountingRepository();

  bool _isProcessing = false;
  ScannedProduct? _lastScanned;
  String? _errorMessage;
  Map<String, dynamic>? _notInTransferProduct;
  ScannedProduct? _offListProduct; // cycle: scanned item not in target list
  final TextEditingController _quantityController = TextEditingController();
  bool _flashOn = false;

  // For stock transfer mode: track scanned quantities
  final Map<String, double> _scannedItems = {};

  @override
  void dispose() {
    _cameraController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    if (widget.mode == ScanMode.inventoryCounting && widget.countingSessionId != null) {
      final result = await _repo.scanBarcode(widget.countingSessionId!, barcode);

      if (mounted) {
        if (result.success && result.product != null) {
          final p = result.product!;

          // Cycle gating: block items that are not in the target list.
          // Server flag `in_target_list` is authoritative; fall back to the
          // client-side target set if the flag is absent.
          if (widget.isCycle) {
            final inTarget = p.inTargetList ??
                (widget.cycleTargetCodes?.contains(p.itemCode) ?? true);
            if (!inTarget) {
              HapticFeedback.heavyImpact();
              setState(() {
                _offListProduct = p;
                _lastScanned = null;
                _errorMessage = null;
              });
              return;
            }
          }

          HapticFeedback.lightImpact();
          setState(() {
            _offListProduct = null;
            _lastScanned = p;
            _quantityController.text =
                p.existingLine?.countedQuantity.toInt().toString() ?? '1';
          });
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _errorMessage = result.error ?? context.tr('unknown_product');
            _lastScanned = null;
          });
          // Auto-dismiss error
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isProcessing = false);
          });
          return;
        }
      }
    } else {
      // Stock transfer mode — look up product and check if it's in the transfer
      final result = await _repo.lookupBarcode(barcode);
      if (mounted) {
        if (result.success && result.product != null) {
          final p = result.product!;
          final itemCode = p['item_code'] ?? '';

          // Check if this product is in the expected transfer items
          Map<String, dynamic>? matchedItem;
          if (widget.expectedItems != null) {
            for (final item in widget.expectedItems!) {
              if (item['item_code'] == itemCode) {
                matchedItem = item;
                break;
              }
            }
          }

          if (matchedItem == null && widget.expectedItems != null && widget.expectedItems!.isNotEmpty) {
            // Product exists but NOT in this transfer
            HapticFeedback.heavyImpact();
            setState(() {
              _errorMessage = null;
              _notInTransferProduct = p;
              _lastScanned = null;
            });
            return;
          }

          HapticFeedback.lightImpact();
          setState(() {
            _notInTransferProduct = null;
            _lastScanned = ScannedProduct(
              itemCode: itemCode,
              itemName: p['item_name'] ?? '',
              pieceBarcode: p['piece_barcode'],
              imageUrl: p['image_url'] ?? '',
            );
            _quantityController.text = (matchedItem?['quantity'] ?? 1).toInt().toString();
          });
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _errorMessage = context.tr('unknown_product');
            _lastScanned = null;
            _notInTransferProduct = null;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isProcessing = false);
          });
          return;
        }
      }
    }
  }

  Future<void> _saveQuantity() async {
    final qty = double.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) return;

    final product = _lastScanned!;

    if (widget.mode == ScanMode.inventoryCounting && widget.countingSessionId != null) {
      final res = await _repo.addLine(
        widget.countingSessionId!,
        product.itemCode,
        qty,
      );
      if (!mounted) return;
      // Surface server rejections (e.g. off-list cycle item → 422) instead of
      // silently pretending the add succeeded.
      if (!res.success) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(res.error ?? context.tr('off_list_cannot_count')),
          ),
        );
        setState(() {
          _lastScanned = null;
          _isProcessing = false;
        });
        return;
      }
    } else {
      // Stock transfer mode — store locally
      _scannedItems[product.itemCode] = qty;
    }

    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('product_saved')
              .replaceAll('{name}', product.getLocalizedName(AppLocalizations.isArabic))
              .replaceAll('{qty}', '${qty.toInt()}'),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      setState(() {
        _lastScanned = null;
        _isProcessing = false;
      });
    }
  }

  void _dismissProduct() {
    setState(() {
      _lastScanned = null;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ─── Camera ──────────────────────────────────
            MobileScanner(
              controller: _cameraController,
              onDetect: _onBarcodeDetected,
            ),

            // ─── Overlay ─────────────────────────────────
            _ScannerOverlay(flashOn: _flashOn),

            // ─── Top Bar ─────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
                    _CircleButton(
                      icon: Icons.close,
                      onTap: () {
                        if (widget.mode != ScanMode.inventoryCounting && _scannedItems.isNotEmpty) {
                          Navigator.pop(context, _scannedItems);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    Text(
                      widget.mode == ScanMode.inventoryCounting
                          ? context.tr('barcode_scanner')
                          : widget.mode == ScanMode.stockTransferSend
                              ? context.tr('barcode_scanner_send')
                              : context.tr('barcode_scanner_receive'),
                      style: AppTypography.titleMedium.copyWith(color: Colors.white),
                    ),
                    Row(
                      children: [
                        // Flash toggle
                        _CircleButton(
                          icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                          onTap: () {
                            _cameraController.toggleTorch();
                            setState(() => _flashOn = !_flashOn);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ─── Scanned count (stock transfer) ─────────
            if (widget.mode != ScanMode.inventoryCounting)
              Positioned(
                bottom: _lastScanned != null ? 340 : 100,
                right: 0,
                left: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Text(
                      context.tr('scanned_count').replaceAll('{count}', '${_scannedItems.length}').replaceAll('{total}', '${widget.expectedItems?.length ?? 0}'),
                      style: AppTypography.labelMedium.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),

            // ─── Error Message ───────────────────────────
            if (_errorMessage != null)
              Positioned(
                bottom: 100,
                right: AppSpacing.xl,
                left: AppSpacing.xl,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: AppRadius.borderLg,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Not In Transfer Warning ─────────────────
            if (_notInTransferProduct != null)
              Positioned(
                bottom: 0,
                right: 0,
                left: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: AppSpacing.lg,
                    left: AppSpacing.xl,
                    right: AppSpacing.xl,
                    bottom: MediaQuery.of(context).padding.bottom + AppSpacing.base,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: AppRadius.borderFull,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      // Warning icon
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 36),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        context.tr('product_not_in_transfer'),
                        style: AppTypography.titleMedium.copyWith(color: AppColors.warning),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _notInTransferProduct!['item_name'] ?? '',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'SAP: ${_notInTransferProduct!['item_code'] ?? ''}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _notInTransferProduct = null;
                              _isProcessing = false;
                            });
                          },
                          icon: const Icon(Icons.skip_next_rounded),
                          label: Text(context.tr('skip_and_scan_next')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Off-list Warning (cycle) ────────────────
            if (_offListProduct != null)
              Positioned(
                bottom: 0,
                right: 0,
                left: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: AppSpacing.lg,
                    left: AppSpacing.xl,
                    right: AppSpacing.xl,
                    bottom: MediaQuery.of(context).padding.bottom + AppSpacing.base,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: AppRadius.borderFull,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.block_rounded, color: AppColors.error, size: 36),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        context.tr('product_off_cycle_list'),
                        style: AppTypography.titleMedium.copyWith(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _offListProduct!.getLocalizedName(AppLocalizations.isArabic),
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'SAP: ${_offListProduct!.itemCode}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _offListProduct = null;
                              _isProcessing = false;
                            });
                          },
                          icon: const Icon(Icons.skip_next_rounded),
                          label: Text(context.tr('skip_and_scan_next')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Product Bottom Sheet ────────────────────
            if (_lastScanned != null)
              Positioned(
                bottom: 0,
                right: 0,
                left: 0,
                child: _ProductSheet(
                  product: _lastScanned!,
                  quantityController: _quantityController,
                  onSave: _saveQuantity,
                  onDismiss: _dismissProduct,
                  isUpdate: _lastScanned!.existingLine != null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Scanner Overlay ──────────────────────────────────────
class _ScannerOverlay extends StatelessWidget {
  final bool flashOn;
  const _ScannerOverlay({required this.flashOn});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _OverlayPainter(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final borderPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 60),
      width: size.width * 0.7,
      height: size.width * 0.7 * 0.6,
    );

    // Draw overlay
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(16))),
      ),
      bgPaint,
    );

    // Draw border
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanArea, const Radius.circular(16)),
      borderPaint,
    );

    // Draw corner accents
    final cornerLength = 24.0;
    final accentPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(scanArea.left, scanArea.top + 16), Offset(scanArea.left, scanArea.top + 16 + cornerLength), accentPaint);
    canvas.drawLine(Offset(scanArea.left + 16, scanArea.top), Offset(scanArea.left + 16 + cornerLength, scanArea.top), accentPaint);

    // Top-right
    canvas.drawLine(Offset(scanArea.right, scanArea.top + 16), Offset(scanArea.right, scanArea.top + 16 + cornerLength), accentPaint);
    canvas.drawLine(Offset(scanArea.right - 16, scanArea.top), Offset(scanArea.right - 16 - cornerLength, scanArea.top), accentPaint);

    // Bottom-left
    canvas.drawLine(Offset(scanArea.left, scanArea.bottom - 16), Offset(scanArea.left, scanArea.bottom - 16 - cornerLength), accentPaint);
    canvas.drawLine(Offset(scanArea.left + 16, scanArea.bottom), Offset(scanArea.left + 16 + cornerLength, scanArea.bottom), accentPaint);

    // Bottom-right
    canvas.drawLine(Offset(scanArea.right, scanArea.bottom - 16), Offset(scanArea.right, scanArea.bottom - 16 - cornerLength), accentPaint);
    canvas.drawLine(Offset(scanArea.right - 16, scanArea.bottom), Offset(scanArea.right - 16 - cornerLength, scanArea.bottom), accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Circle Button ────────────────────────────────────────
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─── Product Sheet ────────────────────────────────────────
class _ProductSheet extends StatelessWidget {
  final ScannedProduct product;
  final TextEditingController quantityController;
  final VoidCallback onSave;
  final VoidCallback onDismiss;
  final bool isUpdate;

  const _ProductSheet({
    required this.product,
    required this.quantityController,
    required this.onSave,
    required this.onDismiss,
    required this.isUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.borderFull,
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: AppRadius.borderMd,
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  width: 72, height: 72, fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: AppColors.surfaceVariant,
                    highlightColor: AppColors.surface,
                    child: Container(
                      width: 72, height: 72,
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: Icon(Icons.image_not_supported, color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.getLocalizedName(AppLocalizations.isArabic), style: AppTypography.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Text('الباركود: ${product.pieceBarcode ?? "—"}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                    Text('SAP: ${product.itemCode}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              // Dismiss
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textTertiary),
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          // Quantity input
          Row(
            children: [
              Text('الكمية:', style: AppTypography.labelLarge),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: isUpdate ? AppColors.warning : AppColors.primary,
              ),
              child: Text(isUpdate ? 'تحديث الكمية' : 'إضافة'),
            ),
          ),
        ],
      ),
    );
  }
}
