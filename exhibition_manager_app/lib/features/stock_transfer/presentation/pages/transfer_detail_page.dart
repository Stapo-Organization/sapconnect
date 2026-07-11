import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/permissions/app_abilities.dart';
import 'package:exhibition_manager_app/core/permissions/app_session.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/stock_transfer_repository.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/models/stock_transfer.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/pages/barcode_scanner_page.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/product_search/presentation/product_detail_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Transfer Detail — hero summary, warehouse path, send/receive progress and
/// a clean per-line breakdown.
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
      final items = result.entries.map((e) => {'item_code': e.key, 'quantity': e.value}).toList();
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
      final items = result.entries.map((e) => {'item_code': e.key, 'quantity': e.value}).toList();
      await _repo.receiveItems(widget.transferId, items);
      _loadTransfer();
    }
  }

  Future<void> _confirmAction({required bool isSend}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(isSend ? context.tr('confirm_send') : context.tr('confirm_receive')),
          content: Text(isSend
              ? context.tr('st_confirm_send_message')
              : context.tr('st_confirm_receive_message')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('confirm_send').split(' ').first)),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    final result = isSend
        ? await _repo.confirmSend(widget.transferId)
        : await _repo.confirmReceive(widget.transferId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.success
            ? (isSend ? context.tr('st_send_confirmed') : context.tr('st_receive_confirmed'))
            : result.error ?? context.tr('unexpected_error'))),
      );
      _loadTransfer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _transfer;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(
          title: t != null
              ? context.tr('st_transfer_number').replaceAll('{n}', '${t.docNum}')
              : context.tr('stock_transfers'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : t == null
                ? Center(child: Text(context.tr('no_transfers')))
                : RefreshIndicator(
                    onRefresh: _loadTransfer,
                    color: AppDomain.transfers.accent,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      children: [
                        _HeroCard(transfer: t),
                        const SizedBox(height: AppSpacing.base),
                        Row(
                          children: [
                            Text(context.tr('items_count_label'),
                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppDomain.transfers.accent.withValues(alpha: 0.10),
                                borderRadius: AppRadius.borderFull,
                              ),
                              child: Text('${t.lines.length}',
                                  style: AppTypography.labelSmall.copyWith(
                                      color: AppDomain.transfers.accent, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (var i = 0; i < t.lines.length; i++)
                          PopIn(
                            delay: Duration(milliseconds: 60 * i.clamp(0, 10)),
                            child: _LineCard(line: t.lines[i]),
                          ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
        bottomNavigationBar: t != null ? _buildBottomActions(t) : null,
      ),
    );
  }

  Widget? _buildBottomActions(StockTransfer t) {
    // Gate by the user's action abilities — the same permissions the backend enforces.
    final canSend = t.canSend && AppSession.can(Ability.stockTransferSend);
    final canReceive = t.canReceive && AppSession.can(Ability.stockTransferConfirmReceive);
    if (!canSend && !canReceive) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canSend) ...[
              AppButton(
                label: context.tr('scan_to_confirm_send'),
                onPressed: _openScannerForSend,
                icon: Icons.qr_code_scanner_rounded,
                variant: AppButtonVariant.outline,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: context.tr('confirm_send'),
                onPressed: () => _confirmAction(isSend: true),
                icon: Icons.local_shipping_rounded,
              ),
            ],
            if (canReceive) ...[
              AppButton(
                label: context.tr('scan_to_confirm_receive'),
                onPressed: _openScannerForReceive,
                icon: Icons.qr_code_scanner_rounded,
                variant: AppButtonVariant.outline,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: context.tr('confirm_receive'),
                onPressed: () => _confirmAction(isSend: false),
                icon: Icons.inventory_2_rounded,
                color: AppColors.success,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Hero summary card ────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final StockTransfer transfer;
  const _HeroCard({required this.transfer});

  Color get _statusColor {
    switch (transfer.internalStatus) {
      case 'New':
        return AppColors.statusNew;
      case 'Shipped':
        return AppColors.statusShipped;
      case 'Received':
        return AppColors.statusReceived;
      case 'Completed':
        return AppColors.statusCompleted;
      default:
        return AppColors.textTertiary;
    }
  }

  String _statusLabel(BuildContext context) {
    switch (transfer.internalStatus) {
      case 'New':
        return context.tr('status_new');
      case 'Shipped':
        return context.tr('status_shipped');
      case 'Partially Received':
        return context.tr('status_partially_received');
      case 'Received':
        return context.tr('status_received');
      case 'Completed':
        return context.tr('status_completed');
      default:
        return transfer.internalStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${transfer.docNum ?? transfer.id}',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
                  if (transfer.docDate != null) ...[
                    const SizedBox(height: 2),
                    Text(transfer.docDate!,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ],
              ),
              StatusBadge(label: _statusLabel(context), color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          _WarehousePath(from: transfer.fromWarehouse, to: transfer.toWarehouse, accent: color),
          const SizedBox(height: AppSpacing.base),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _stat(context, Icons.category_rounded, '${transfer.linesCount}', context.tr('items_count_label'), AppDomain.transfers.accent),
              ),
              _vDivider(),
              Expanded(
                child: _stat(context, Icons.outbound_rounded,
                    '${transfer.sendingPercentage.toInt()}%', context.tr('sent'), AppColors.statusShipped),
              ),
              _vDivider(),
              Expanded(
                child: _stat(context, Icons.move_to_inbox_rounded,
                    '${transfer.receivingPercentage.toInt()}%', context.tr('received_qty'), AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 34, color: AppColors.borderLight);

  Widget _stat(BuildContext context, IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, color: color)),
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
      ],
    );
  }
}

// ─── Warehouse path ───────────────────────────────────────
class _WarehousePath extends StatelessWidget {
  final String from;
  final String to;
  final Color accent;
  const _WarehousePath({required this.from, required this.to, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _node(context, context.tr('from'), from)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: GlowIconChip(
            icon: Icons.west_rounded,
            color: accent,
            size: 28,
            iconSize: 16,
            borderRadius: AppRadius.borderFull,
          ),
        ),
        Expanded(child: _node(context, context.tr('to'), to)),
      ],
    );
  }

  Widget _node(BuildContext context, String label, String code) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.store_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(code,
                    style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Line card with per-line progress ─────────────────────
class _LineCard extends StatelessWidget {
  final StockTransferLine line;
  const _LineCard({required this.line});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final required = line.quantity;
    final sent = line.sentQuantity;
    final received = line.actualReceivedQuantity;
    // Progress relative to the requested quantity.
    final sentPct = required > 0 ? (sent / required).clamp(0.0, 1.0) : 0.0;
    final recvPct = required > 0 ? (received / required).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => openProductDetail(context, line.itemCode,
                name: line.getLocalizedName(isArabic),
                myWarehouses: AppSession.user?.warehouseCodes ?? const []),
            behavior: HitTestBehavior.opaque,
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: AppRadius.borderMd,
                child: CachedNetworkImage(
                  imageUrl: 'https://ppte.sa/imghd/${line.itemCode.length >= 4 ? line.itemCode.substring(0, 4) : line.itemCode}/${line.itemCode}.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: AppColors.surfaceVariant,
                    highlightColor: AppColors.surface,
                    child: Container(width: 52, height: 52, color: Colors.white),
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: 52,
                    height: 52,
                    color: AppColors.surfaceVariant,
                    child: Icon(Icons.image_not_supported_rounded, size: 22, color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.getLocalizedName(isArabic),
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(line.itemCode,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Required / Sent / Received chips
          Row(
            children: [
              _qtyChip(context, context.tr('required_qty'), required, AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              _qtyChip(context, context.tr('sent_qty'), sent, AppColors.statusShipped),
              const SizedBox(width: AppSpacing.xs),
              _qtyChip(context, context.tr('received_qty'), received, AppColors.success),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Dual progress: sent (under) + received (over)
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.borderFull,
                child: LinearProgressIndicator(
                  value: sentPct,
                  minHeight: 6,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation(AppColors.statusShipped.withValues(alpha: 0.45)),
                ),
              ),
              ClipRRect(
                borderRadius: AppRadius.borderFull,
                child: LinearProgressIndicator(
                  value: recvPct,
                  minHeight: 6,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(AppColors.success),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyChip(BuildContext context, String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: AppRadius.borderSm,
        ),
        child: Column(
          children: [
            Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10)),
            const SizedBox(height: 1),
            Text('${value.toInt()}',
                style: AppTypography.labelLarge.copyWith(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
