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

/// Transfer Detail — hero summary, warehouse path, send/receive progress and
/// a clean per-line breakdown.
class TransferDetailPage extends StatefulWidget {
  final int transferId;
  /// Opened from the «send» or «receive» tab: only that side's actions show.
  final String? side;

  const TransferDetailPage({super.key, required this.transferId, this.side});

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
              // Shipped in SAP only: expect what SAP delivered.
              .map((l) => {'item_code': l.itemCode, 'quantity': l.sentQuantity > 0 ? l.sentQuantity : l.sapReceivedQuantity})
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
                                      color: AppDomain.transfers.accent, fontWeight: FontWeight.w700)),
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
    // The receiving branch never sees «send», the sending one never «receive».
    final canSend = t.canSend && t.isOutgoing && widget.side != 'receive' && AppSession.can(Ability.stockTransferSend);
    final canReceive =
        t.canReceive && t.isIncoming && widget.side != 'send' && AppSession.can(Ability.stockTransferConfirmReceive);
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

  /// «23/07/2026 · 87 days ago» from the SAP document date.
  String _when(BuildContext context) {
    final d = DateTime.tryParse(transfer.docDate ?? '');
    if (d == null) return '';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return '$date · ${days <= 0 ? context.tr('st_today') : context.tr('st_days_ago').replaceAll('{n}', '$days')}';
  }

  /// One compact block: number, date and status; from → to on one line; the
  /// counts; and what SAP says — the details are the lines below, not this.
  @override
  Widget build(BuildContext context) {
    final t = transfer;
    final arabic = AppLocalizations.isArabic;
    final color = _statusColor;
    final meta = AppTypography.labelSmall.copyWith(color: AppColors.textSecondary);
    final place = AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600);
    final sapPending = t.sapReceivedQty > 0 && t.internalStatus != 'Received' && t.internalStatus != 'Completed';
    final sapLeft = (t.totalQty - t.sapReceivedQty).clamp(0, double.infinity);

    Widget kv(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 3),
          Text(text, style: meta.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ]);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(_when(context), style: meta)),
            StatusBadge(label: _statusLabel(context), color: color),
          ]),
          const SizedBox(height: AppSpacing.sm),
          // From → to, one line.
          Row(children: [
            Icon(Icons.storefront_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Flexible(child: Text(t.fromName(arabic), maxLines: 1, overflow: TextOverflow.ellipsis, style: place)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(arabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 16, color: color),
            ),
            Flexible(child: Text(t.toName(arabic), maxLines: 1, overflow: TextOverflow.ellipsis, style: place)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.md, runSpacing: 4, children: [
            kv(Icons.category_outlined, '${t.lines.length} ${context.tr('items')}'),
            kv(Icons.inventory_2_outlined, context.tr('st_pcs').replaceAll('{n}', '${t.totalQty.toInt()}')),
            if (t.sendingPercentage > 0) kv(Icons.outbound_rounded, context.tr('st_sent_pct').replaceAll('{n}', '${t.sendingPercentage.toInt()}')),
            if (t.receivingPercentage > 0)
              kv(Icons.move_to_inbox_rounded, context.tr('st_received_pct').replaceAll('{n}', '${t.receivingPercentage.toInt()}')),
          ]),
          if (t.isDirect || t.sapReceivedQty > 0 || t.documentStatus == 'bost_Close') ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
              decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: AppRadius.borderMd),
              child: Row(children: [
                Icon(Icons.sync_alt_rounded, size: 16, color: AppColors.info),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      if (t.isDirect) ...[
                        context.tr('st_direct_note'),
                        if (sapPending) context.tr('st_sap_not_confirmed'),
                      ] else ...[
                      context.tr('st_sap_delivered').replaceAll('{d}', '${t.sapReceivedQty.toInt()}').replaceAll('{q}', '${t.totalQty.toInt()}'),
                      if (t.documentStatus == 'bost_Close')
                        context.tr('st_sap_closed')
                      else if (sapLeft > 0)
                        context.tr('st_sap_left').replaceAll('{n}', '${sapLeft.toInt()}'),
                      if (sapPending) context.tr('st_sap_not_confirmed'),
                      ],
                    ].join(' · '),
                    style: AppTypography.bodySmall.copyWith(color: AppColors.info, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],
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
              // Plain Image.network (via ProductThumb): cached_network_image never painted on iOS here.
              ProductThumb(
                url: 'https://ppte.sa/img/${line.itemCode.length >= 4 ? line.itemCode.substring(0, 4) : line.itemCode}/${line.itemCode}.png',
                size: 52,
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
              if (line.sapReceivedQuantity > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                _qtyChip(context, context.tr('st_sap_qty'), line.sapReceivedQuantity, AppColors.info),
              ],
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
                style: AppTypography.labelLarge.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
