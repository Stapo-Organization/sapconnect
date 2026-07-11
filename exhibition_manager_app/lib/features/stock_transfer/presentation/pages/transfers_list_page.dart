import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/stock_transfer_repository.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/models/stock_transfer.dart';
import 'transfer_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xs),
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
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.borderFull,
                          borderSide: BorderSide.none,
                        ),
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
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.sm),
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
                  ? const SkeletonList(itemCount: 6, cardHeight: 168)
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.background,
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: active ? AppColors.primary : AppColors.borderLight),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.tune_rounded, size: 22, color: active ? Colors.white : AppColors.textSecondary),
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
                    color: selected ? o.color.withValues(alpha: 0.10) : Colors.transparent,
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
                                      color: selected ? o.color : AppColors.textPrimary)),
                            ),
                            if (selected) Icon(Icons.check_rounded, size: 20, color: o.color),
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

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(transfer.internalStatus);
    // Receive tab tracks the receiving %, send tab tracks the sending %.
    final isReceive = tab == 'receive';
    final percent = (isReceive ? transfer.receivingPercentage : transfer.sendingPercentage).clamp(0, 100).toDouble();
    final percentLabel = isReceive ? context.tr('received_qty') : context.tr('sent');

    return Pressable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TransferDetailPage(transferId: transfer.id)),
      ).then((_) => onReturn()),
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.borderXl,
          border: Border.all(color: AppColors.borderLight, width: 1.2),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: doc number + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('#${transfer.docNum ?? transfer.id}',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                StatusBadge(label: _statusLabel(context, transfer.internalStatus), color: color),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Warehouse path: from → to
            _WarehousePath(
              from: transfer.fromWarehouse,
              to: transfer.toWarehouse,
              highlightTo: isReceive,
              accent: color,
            ),
            const SizedBox(height: AppSpacing.base),

            // Images + item count
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProductImageStack(imageUrls: transfer.images, totalItems: transfer.linesCount),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.category_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text('${transfer.linesCount} ${context.tr('items')}',
                          style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primary, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),

            // Progress (only meaningful once something is sent/received)
            if (percent > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.borderFull,
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        backgroundColor: AppColors.borderLight,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${percent.toInt()}% $percentLabel',
                      style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Warehouse path (from → to) ───────────────────────────
class _WarehousePath extends StatelessWidget {
  final String from;
  final String to;
  final bool highlightTo;
  final Color accent;
  const _WarehousePath({required this.from, required this.to, required this.highlightTo, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(child: _node(context, context.tr('from'), from, highlightTo ? false : true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: GlowIconChip(
              icon: isArabic ? Icons.west_rounded : Icons.east_rounded,
              color: accent,
              size: 25,
              iconSize: 15,
              borderRadius: AppRadius.borderFull,
            ),
          ),
          Expanded(child: _node(context, context.tr('to'), to, highlightTo)),
        ],
      ),
    );
  }

  Widget _node(BuildContext context, String label, String code, bool highlight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.store_rounded, size: 15, color: highlight ? accent : AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(code,
                  style: AppTypography.labelLarge.copyWith(
                      color: highlight ? accent : AppColors.textPrimary, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Product Image Stack (overlapping circles) ────────────
class _ProductImageStack extends StatelessWidget {
  final List<String> imageUrls;
  final int totalItems;

  const _ProductImageStack({required this.imageUrls, required this.totalItems});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      // No images yet — show a neutral item indicator.
      return GlowIconChip(
        icon: Icons.inventory_2_rounded,
        color: AppDomain.transfers.accent,
        size: 40,
        iconSize: 18,
        borderRadius: AppRadius.borderFull,
      );
    }

    final displayCount = imageUrls.length > 3 ? 3 : imageUrls.length;
    final remaining = totalItems > displayCount ? totalItems - displayCount : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < displayCount; i++)
          Align(
            widthFactor: 0.68,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.10), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrls[i],
                  fit: BoxFit.cover,
                  // Tinted product chip while loading / on error — never a blank
                  // white circle on the white card.
                  placeholder: (context, url) => Container(
                    color: AppColors.surfaceVariant,
                    alignment: Alignment.center,
                    child: Icon(Icons.image_outlined, size: 16, color: AppColors.textTertiary),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.surfaceVariant,
                    alignment: Alignment.center,
                    child: Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          ),
        if (remaining > 0)
          Align(
            widthFactor: 0.68,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
                color: AppDomain.transfers.soft,
              ),
              child: Text('+$remaining',
                  style: AppTypography.labelMedium.copyWith(color: AppDomain.transfers.accentDark, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}
