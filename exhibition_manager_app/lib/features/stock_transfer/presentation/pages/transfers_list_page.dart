import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/stock_transfer_repository.dart';
import 'package:exhibition_manager_app/features/stock_transfer/data/models/stock_transfer.dart';
import 'transfer_detail_page.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';

/// Stock Transfers List Page (Premium Redesign)
class TransfersListPage extends StatefulWidget {
  const TransfersListPage({super.key});

  @override
  State<TransfersListPage> createState() => _TransfersListPageState();
}

class _TransfersListPageState extends State<TransfersListPage> {
  final StockTransferRepository _repo = StockTransferRepository();
  List<StockTransfer> _transfers = [];
  List<StockTransfer> _filteredTransfers = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _selectedStatus;
  bool _hideCompleted = true;
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

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredTransfers = List.from(_transfers));
      return;
    }
    setState(() {
      _filteredTransfers = _transfers.where((t) {
        final docNum = t.docNum?.toString().toLowerCase() ?? '';
        final fromWh = t.fromWarehouse.toLowerCase();
        final toWh = t.toWarehouse.toLowerCase();
        return docNum.contains(q) || fromWh.contains(q) || toWh.contains(q);
      }).toList();
    });
  }

  Future<void> _loadTransfers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final result = await _repo.getTransfers(
      internalStatus: _selectedStatus,
      hideCompleted: _hideCompleted,
    );
    if (mounted) {
      setState(() {
        _transfers = result.transfers;
        _filteredTransfers = List.from(result.transfers);
        _isLoading = false;
        _hasError = !result.success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(
          title: context.tr('stock_transfers'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Search Bar ─────────────────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: context.tr('search_transfers'),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textTertiary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
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

            // ─── Filter Section ─────────────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    // Hide Completed Toggle Pill
                    _ToggleFilterChip(
                      label: 'إخفاء المكتمل',
                      isActive: _hideCompleted,
                      icon: _hideCompleted ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      onTap: () {
                        setState(() => _hideCompleted = !_hideCompleted);
                        _loadTransfers();
                      },
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      height: 24,
                      width: 1,
                      color: AppColors.border,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Status Filters
                    _FilterChip(
                      label: context.tr('all'),
                      selected: _selectedStatus == null,
                      onTap: () {
                        setState(() => _selectedStatus = null);
                        _loadTransfers();
                      },
                    ),
                    _FilterChip(
                      label: context.tr('status_new'),
                      selected: _selectedStatus == 'New',
                      onTap: () {
                        setState(() => _selectedStatus = 'New');
                        _loadTransfers();
                      },
                    ),
                    _FilterChip(
                      label: context.tr('status_shipped'),
                      selected: _selectedStatus == 'Shipped',
                      onTap: () {
                        setState(() => _selectedStatus = 'Shipped');
                        _loadTransfers();
                      },
                    ),
                    _FilterChip(
                      label: context.tr('status_received'),
                      selected: _selectedStatus == 'Received',
                      onTap: () {
                        setState(() => _selectedStatus = 'Received');
                        _loadTransfers();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ─── List Section ───────────────────────────────
            Expanded(
              child: _isLoading
                  ? const SkeletonList(itemCount: 6, cardHeight: 180)
                  : _hasError
                      ? ErrorStateWidget(onRetry: _loadTransfers)
                      : _filteredTransfers.isEmpty
                          ? EmptyState(
                              icon: Icons.swap_horiz_rounded,
                              title: _searchController.text.isEmpty
                                  ? context.tr('no_transfers')
                                  : context.tr('no_results'),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadTransfers,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.base,
                                  vertical: AppSpacing.md,
                                ),
                                itemCount: _filteredTransfers.length,
                                itemBuilder: (context, index) =>
                                    _TransferCard(transfer: _filteredTransfers[index]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Toggle Filter Chip ────────────────────────────
class _ToggleFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final IconData icon;
  final VoidCallback onTap;

  const _ToggleFilterChip({
    required this.label,
    required this.isActive,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm - 2,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withAlpha(40) : AppColors.surface,
          borderRadius: AppRadius.borderFull,
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm - 2,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: AppRadius.borderFull,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(50),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Transfer Card ────────────────────────────────────────
class _TransferCard extends StatelessWidget {
  final StockTransfer transfer;

  const _TransferCard({required this.transfer});

  Color _statusColor(String status) {
    switch (status) {
      case 'New': return AppColors.statusNew;
      case 'Shipped': return AppColors.statusShipped;
      case 'Received': return AppColors.statusReceived;
      case 'Completed': return AppColors.statusCompleted;
      default: return AppColors.textTertiary;
    }
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'New': return context.tr('status_new');
      case 'Shipped': return context.tr('status_shipped');
      case 'Partially Received': return context.tr('status_partially_received');
      case 'Received': return context.tr('status_received');
      case 'Completed': return context.tr('status_completed');
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final color = _statusColor(transfer.internalStatus);
    
    // Extract unique product images from lines
    final imageUrls = transfer.lines.map((l) => l.imageUrl).take(4).toList(); // Take 4 just in case
    final totalLines = transfer.lines.length;
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransferDetailPage(transferId: transfer.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.borderXl,
          border: Border.all(color: AppColors.borderLight, width: 1.5),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Status Badge on Left (conceptually), ID on Right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Right side conceptually (in RTL, it's drawn on the right)
                Text(
                  '#${transfer.docNum ?? transfer.id}',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                // Left side conceptually
                StatusBadge(
                  label: _statusLabel(context, transfer.internalStatus),
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Row 2: Warehouse Path
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.background.withAlpha(128),
                borderRadius: AppRadius.borderMd,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('from'),
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.store_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                transfer.fromWarehouse,
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textTertiary.withAlpha(50),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Icon(
                        isArabic ? Icons.west_rounded : Icons.east_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('to'),
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.store_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                transfer.toWarehouse,
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // Row 3: Product Images & Items Info
            Row(
              children: [
                _ProductImageStack(imageUrls: imageUrls, totalItems: totalLines),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${transfer.lines.length} ${context.tr('items')}',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${transfer.sendingPercentage.toInt()}% ${context.tr('sent')}',
                      style: AppTypography.labelMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            if (transfer.totalQty > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              // Progress bar
              ClipRRect(
                borderRadius: AppRadius.borderFull,
                child: LinearProgressIndicator(
                  value: transfer.sendingPercentage / 100,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Product Image Stack (Overlapping Circles) ────────────
class _ProductImageStack extends StatelessWidget {
  final List<String> imageUrls;
  final int totalItems; // Total lines in the transfer

  const _ProductImageStack({required this.imageUrls, required this.totalItems});

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0 || imageUrls.isEmpty) return const SizedBox.shrink();

    final int displayCount = imageUrls.length > 3 ? 3 : imageUrls.length;
    final int remainingCount = totalItems > 3 ? totalItems - 3 : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < displayCount; i++)
          Align(
            widthFactor: 0.7, // 30% overlap
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrls[i],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: AppColors.surfaceVariant,
                    highlightColor: AppColors.surface,
                    child: Container(
                      width: 38, height: 38,
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.inventory_2_rounded, size: 20, color: AppColors.textTertiary),
                ),
              ),
            ),
          ),
        if (remainingCount > 0)
          Align(
            widthFactor: 0.7,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
                color: AppColors.primaryLight.withAlpha(40),
              ),
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
