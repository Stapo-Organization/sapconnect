import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/stock_transfer_repository.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/models/stock_transfer.dart';
import 'transfer_detail_page.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';

/// Stock Transfers — Send / Receive tabs, status filter, modern cards.
class TransfersListPage extends StatefulWidget {
  const TransfersListPage({super.key});

  @override
  State<TransfersListPage> createState() => _TransfersListPageState();
}

class _TransfersListPageState extends State<TransfersListPage> {
  final StockTransferRepository _repo = StockTransferRepository();
  List<StockTransfer> _transfers = [];
  bool _isLoading = true;
  bool _hasError = false;

  /// 'send' (outgoing) or 'receive' (incoming).
  String _tab = 'send';

  /// null = all statuses, else 'New' | 'Shipped' | 'Received' | 'Completed'.
  /// Defaults to New (the actionable scope).
  String? _status = 'New';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransfers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    // Load a wide page once; tab/status/search filtering happens client-side
    // so switching is instant.
    final result = await _repo.getTransfers(hideCompleted: false, perPage: 100);
    if (mounted) {
      setState(() {
        _transfers = result.transfers;
        _isLoading = false;
        _hasError = !result.success;
      });
    }
  }

  // ─── Filtering ──────────────────────────────────────────────
  bool _directionOk(StockTransfer t, String tab) =>
      tab == 'send' ? t.isOutgoing : t.isIncoming;

  bool _statusOk(StockTransfer t, String tab) {
    // Receive default (New) means "not yet received" → New OR Shipped.
    if (tab == 'receive' && _status == 'New') {
      return t.internalStatus == 'New' || t.internalStatus == 'Shipped';
    }
    if (_status == null) return true; // all
    return t.internalStatus == _status;
  }

  bool _searchOk(StockTransfer t) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (t.docNum ?? '').toLowerCase().contains(q) ||
        t.fromWarehouse.toLowerCase().contains(q) ||
        t.toWarehouse.toLowerCase().contains(q);
  }

  List<StockTransfer> get _visible => _transfers
      .where((t) => _directionOk(t, _tab) && _statusOk(t, _tab) && _searchOk(t))
      .toList();

  int _tabCount(String tab) =>
      _transfers.where((t) => _directionOk(t, tab) && _statusOk(t, tab)).length;

  Future<void> _openStatusFilter() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _StatusFilterSheet(current: _status),
    );
    if (result == null) return;
    setState(() => _status = result == 'all' ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final visible = _visible;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('stock_transfers')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Search + Filter button ─────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: context.tr('search_transfers'),
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: AppColors.textTertiary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterButton(active: _status != 'New', onTap: _openStatusFilter),
                ],
              ),
            ),

            // ─── Send / Receive tabs ────────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.md),
              child: AppSegmentedControl(
                activeColor: AppDomain.transfers.accent,
                items: [
                  SegmentItem(context.tr('tab_send'), icon: Icons.outbound_rounded, badge: _tabCount('send')),
                  SegmentItem(context.tr('tab_receive'), icon: Icons.move_to_inbox_rounded, badge: _tabCount('receive')),
                ],
                selectedIndex: _tab == 'send' ? 0 : 1,
                onChanged: (i) => setState(() => _tab = i == 0 ? 'send' : 'receive'),
              ),
            ),

            // Active status filter summary chip (when not the default).
            if (_status != 'New')
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
                  child: InputChip(
                    label: Text(_status == null ? context.tr('all') : _statusLabel(context, _status!)),
                    onDeleted: () => setState(() => _status = 'New'),
                    backgroundColor: AppColors.primaryContainer,
                    labelStyle: AppTypography.labelSmall.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                    deleteIconColor: AppColors.primaryDark,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.sm),

            // ─── List ───────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const SkeletonList(itemCount: 8, cardHeight: 84)
                  : _hasError
                      ? ErrorStateWidget(onRetry: _loadTransfers)
                      : visible.isEmpty
                          ? EmptyState(
                              icon: _tab == 'send' ? Icons.outbound_rounded : Icons.move_to_inbox_rounded,
                              title: _searchController.text.isNotEmpty
                                  ? context.tr('no_results')
                                  : (_tab == 'send'
                                      ? context.tr('transfers_send_empty')
                                      : context.tr('transfers_receive_empty')),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadTransfers,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.md),
                                itemCount: visible.length,
                                itemBuilder: (context, index) => _TransferCard(
                                  transfer: visible[index],
                                  tab: _tab,
                                  onReturn: _loadTransfers,
                                )
                                    .animate()
                                    .fadeIn(duration: 280.ms, delay: (index.clamp(0, 8) * 35).ms)
                                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'New':
        return context.tr('status_new');
      case 'Shipped':
        return context.tr('status_shipped');
      case 'Received':
        return context.tr('status_received');
      case 'Completed':
        return context.tr('status_completed');
      default:
        return status;
    }
  }
}

// ─── Filter Button ────────────────────────────────────────
class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primary : AppColors.inputBorder),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.tune_rounded, size: 21, color: active ? Colors.white : AppColors.textPrimary),
            if (active)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Filter Sheet ──────────────────────────────────
class _StatusFilterSheet extends StatelessWidget {
  final String? current;
  const _StatusFilterSheet({this.current});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final options = <({String value, String label, Color color, IconData icon})>[
      (value: 'all', label: context.tr('all'), color: AppColors.textSecondary, icon: Icons.layers_outlined),
      (value: 'New', label: context.tr('status_new'), color: AppColors.statusNew, icon: Icons.fiber_new_rounded),
      (value: 'Shipped', label: context.tr('status_shipped'), color: AppColors.statusShipped, icon: Icons.local_shipping_outlined),
      (value: 'Received', label: context.tr('status_received'), color: AppColors.statusReceived, icon: Icons.inventory_2_outlined),
      (value: 'Completed', label: context.tr('status_completed'), color: AppColors.statusCompleted, icon: Icons.check_circle_outline_rounded),
    ];
    final currentValue = current ?? 'all';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: AppRadius.borderFull),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(context.tr('status_filter_title'),
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              ...options.map((o) {
                final selected = o.value == currentValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Material(
                    color: selected ? AppColors.secondary : Colors.transparent,
                    borderRadius: AppRadius.borderMd,
                    child: InkWell(
                      borderRadius: AppRadius.borderMd,
                      onTap: () => Navigator.pop(context, o.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(o.icon, size: 20, color: o.color),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(o.label,
                                  style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                      color: AppColors.textPrimary)),
                            ),
                            if (selected) Icon(Icons.check_rounded, size: 20, color: AppColors.textPrimary),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Transfer Card ────────────────────────────────────────
/// One transfer as a compact row: who it is with, when, what is in it (real
/// product pictures), how much, and what SAP says — no empty space.
class _TransferCard extends StatelessWidget {
  final StockTransfer transfer;
  final String tab; // 'send' | 'receive'
  final VoidCallback onReturn;

  const _TransferCard({required this.transfer, required this.tab, required this.onReturn});

  Color _statusColor(String status) {
    switch (status) {
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

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
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
        return status;
    }
  }

  /// «23/07/2026 · 86 days ago» from the SAP document date.
  String _when(BuildContext context) {
    final d = DateTime.tryParse(transfer.docDate ?? '');
    if (d == null) return '';
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final today = DateTime.now();
    final days = DateTime(today.year, today.month, today.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    final ago = days <= 0 ? context.tr('st_today') : context.tr('st_days_ago').replaceAll('{n}', '$days');
    return '$date · $ago';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final t = transfer;
    final color = _statusColor(t.internalStatus);
    final isReceive = tab == 'receive';
    final other = isReceive ? t.fromName(isArabic) : t.toName(isArabic);
    final percent = (isReceive ? t.receivingPercentage : t.sendingPercentage).clamp(0, 100).toDouble();
    final sapPending = t.sapReceivedQty > 0 && t.internalStatus != 'Received' && t.internalStatus != 'Completed';
    final meta = AppTypography.labelSmall.copyWith(color: AppColors.textSecondary);

    return Pressable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TransferDetailPage(transferId: t.id, side: tab)),
      ).then((_) => onReturn()),
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.xs + 2),
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Collage(imageUrls: t.images, totalItems: t.linesCount),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        context.tr(isReceive ? 'st_from_branch' : 'st_to_branch').replaceAll('{name}', other),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    StatusBadge(label: _statusLabel(context, t.internalStatus), color: color),
                  ]),
                  const SizedBox(height: 2),
                  Text('#${t.docNum ?? t.id}  ·  ${_when(context)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${t.linesCount} ${context.tr('items')} · ${context.tr('st_pcs').replaceAll('{n}', '${t.totalQty.toInt()}')}',
                        style: meta.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const Spacer(),
                    if (t.isDirect)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: AppRadius.borderFull),
                        child: Text(
                          context.tr('st_direct_chip'),
                          style: AppTypography.labelSmall.copyWith(color: AppColors.info, fontWeight: FontWeight.w700),
                        ),
                      )
                    else if (sapPending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: AppRadius.borderFull),
                        child: Text(
                          context.tr('st_sap_chip')
                              .replaceAll('{d}', '${t.sapReceivedQty.toInt()}')
                              .replaceAll('{q}', '${t.totalQty.toInt()}'),
                          style: AppTypography.labelSmall.copyWith(color: AppColors.info, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ]),
                  if (percent > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: AppRadius.borderFull,
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        backgroundColor: AppColors.borderLight,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Product collage ──────────────────────────────────────
/// The transfer's first products in one small square: 1 picture, or a 2×2
/// grid with «+N» on the last cell. Plain Image.network — cached_network_image
/// never painted on the owner's iPhone.
class _Collage extends StatelessWidget {
  final List<String> imageUrls;
  final int totalItems;
  const _Collage({required this.imageUrls, required this.totalItems});

  static const double _size = 62;

  Widget _img(String url, double side) => Container(
        width: side,
        height: side,
        color: Colors.white,
        padding: const EdgeInsets.all(2),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          cacheWidth: (side * 3).round(),
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => Icon(Icons.inventory_2_outlined, size: side * 0.45, color: AppColors.textTertiary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final urls = imageUrls.take(4).toList();
    Widget child;
    if (urls.isEmpty) {
      child = Icon(Icons.inventory_2_outlined, size: 26, color: AppColors.textTertiary);
    } else if (urls.length == 1) {
      child = _img(urls.first, _size - 2);
    } else {
      const cell = (_size - 4) / 2; // 1 px border each side + 2 px gap
      final more = totalItems - 3;
      child = Wrap(spacing: 2, runSpacing: 2, children: [
        for (var i = 0; i < 4; i++)
          if (i == 3 && more > 1)
            Container(
              width: cell,
              height: cell,
              alignment: Alignment.center,
              color: AppColors.surfaceVariant,
              child: Text('+$more',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            )
          else if (i < urls.length)
            _img(urls[i], cell)
          else
            Container(width: cell, height: cell, color: AppColors.surfaceVariant),
      ]);
    }
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
