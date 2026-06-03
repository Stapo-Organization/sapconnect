import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/stock_transfer_repository.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/models/stock_transfer.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/pages/barcode_scanner_page.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Transfer Detail Page — View items, scan for send/receive
class TransferDetailPage extends StatefulWidget {
  final int transferId;

  const TransferDetailPage({super.key, required this.transferId});

  @override
  State<TransferDetailPage> createState() => _TransferDetailPageState();
}

class _TransferDetailPageState extends State<TransferDetailPage> {
  final StockTransferRepository _repo = StockTransferRepository();
  StockTransfer? _transfer;
  bool _isLoading = true;
  final Map<String, double> _scannedQuantities = {};

  @override
  void initState() {
    super.initState();
    _loadTransfer();
  }

  Future<void> _loadTransfer() async {
    setState(() => _isLoading = true);
    final result = await _repo.getTransfer(widget.transferId);
    if (mounted) {
      setState(() {
        _transfer = result.transfer;
        _isLoading = false;
      });
    }
  }

  Future<void> _openScannerForSend() async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerPage(
          mode: ScanMode.stockTransferSend,
          expectedItems: _transfer!.lines
              .map((l) => {'item_code': l.itemCode, 'quantity': l.quantity})
              .toList(),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _scannedQuantities.addAll(result));
      // Save scanned quantities
      final items = result.entries
          .map((e) => {'item_code': e.key, 'quantity': e.value})
          .toList();
      await _repo.sendItems(widget.transferId, items);
      _loadTransfer();
    }
  }

  Future<void> _openScannerForReceive() async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerPage(
          mode: ScanMode.stockTransferReceive,
          expectedItems: _transfer!.lines
              .map((l) => {'item_code': l.itemCode, 'quantity': l.sentQuantity})
              .toList(),
        ),
      ),
    );

    if (result != null && mounted) {
      final items = result.entries
          .map((e) => {'item_code': e.key, 'quantity': e.value})
          .toList();
      await _repo.receiveItems(widget.transferId, items);
      _loadTransfer();
    }
  }

  Future<void> _confirmSend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الإرسال'),
          content: const Text('هل أنت متأكد من تأكيد إرسال هذا التحويل؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final result = await _repo.confirmSend(widget.transferId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.success ? 'تم تأكيد الإرسال بنجاح' : result.error ?? 'حدث خطأ')),
        );
        _loadTransfer();
      }
    }
  }

  Future<void> _confirmReceive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الاستلام'),
          content: const Text('هل أنت متأكد من تأكيد استلام هذا التحويل؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final result = await _repo.confirmReceive(widget.transferId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.success ? 'تم تأكيد الاستلام بنجاح' : result.error ?? 'حدث خطأ')),
        );
        _loadTransfer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_transfer != null ? 'تحويل #${_transfer!.docNum}' : 'تفاصيل التحويل'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _transfer == null
                ? const Center(child: Text('لم يتم العثور على التحويل'))
                : RefreshIndicator(
                    onRefresh: _loadTransfer,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      children: [
                        // ─── Info Card ──────────────────────
                        _InfoSection(transfer: _transfer!),
                        const SizedBox(height: AppSpacing.base),

                        // ─── Lines ──────────────────────────
                        Text('المنتجات (${_transfer!.lines.length})',
                            style: AppTypography.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        ..._transfer!.lines.map((line) => _LineCard(line: line)),

                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
        bottomNavigationBar: _transfer != null ? _buildBottomActions() : null,
      ),
    );
  }

  Widget? _buildBottomActions() {
    if (_transfer == null) return null;
    final t = _transfer!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.canSend) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openScannerForSend,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('📸 سكان لتأكيد الإرسال'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmSend,
                  child: const Text('تأكيد الإرسال'),
                ),
              ),
            ],
            if (t.canReceive) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openScannerForReceive,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('📸 سكان لتأكيد الاستلام'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmReceive,
                  child: const Text('تأكيد الاستلام'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final StockTransfer transfer;
  const _InfoSection({required this.transfer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _InfoRow('من مستودع', transfer.fromWarehouse),
          _InfoRow('إلى مستودع', transfer.toWarehouse),
          _InfoRow('التاريخ', transfer.docDate ?? '—'),
          _InfoRow('الحالة', transfer.internalStatus),
          _InfoRow('إجمالي الأصناف', '${transfer.totalQty.toInt()}'),
          _InfoRow('المرسل', '${transfer.totalSentQty.toInt()} (${transfer.sendingPercentage.toInt()}%)'),
          _InfoRow('المستلم', '${transfer.totalReceivedQty.toInt()} (${transfer.receivingPercentage.toInt()}%)'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  final StockTransferLine line;
  const _LineCard({required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: AppRadius.borderSm,
            child: CachedNetworkImage(
              imageUrl: line.imageUrl,
              width: 48, height: 48, fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: AppColors.surfaceVariant,
                highlightColor: AppColors.surface,
                child: Container(
                  width: 48, height: 48,
                  color: Colors.white,
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 48, height: 48,
                color: AppColors.surfaceVariant,
                child: const Icon(Icons.image_not_supported, size: 24, color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.getLocalizedName(AppLocalizations.isArabic),
                    style: AppTypography.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(line.itemCode, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('مطلوب: ${line.quantity.toInt()}', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
              Text('مرسل: ${line.sentQuantity.toInt()}', style: AppTypography.labelSmall.copyWith(color: AppColors.info)),
              Text('مستلم: ${line.actualReceivedQuantity.toInt()}', style: AppTypography.labelSmall.copyWith(color: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }
}
