import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/counting_repository.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/models/counting_session.dart';
import 'counting_detail_page.dart';
import 'cycle_count_detail_page.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';

/// Counting Sessions List Page (Bilingual & Premium Redesign)
class CountingSessionsPage extends StatefulWidget {
  final List<String> warehouseCodes;

  const CountingSessionsPage({super.key, required this.warehouseCodes});

  @override
  State<CountingSessionsPage> createState() => _CountingSessionsPageState();
}

class _CountingSessionsPageState extends State<CountingSessionsPage> {
  final CountingRepository _repo = CountingRepository();
  List<CountingSession> _sessions = [];
  List<CountingSession> _filteredSessions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _selectedStatus; // null = all statuses
  String _typeFilter = 'cycle'; // 'cycle' (دوري) or 'full' (سنوي) — no "all"
  final TextEditingController _searchController = TextEditingController();

  /// Map of warehouse_code → warehouse_name (fetched from API)
  Map<String, String> _warehouseNames = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _loadWarehouseNames();
  }

  Future<void> _loadWarehouseNames() async {
    final result = await ApiClient().get(ApiEndpoints.warehouses);
    if (result.isSuccess && mounted) {
      final List data = result.data['data'] ?? [];
      final Map<String, String> names = {};
      for (final wh in data) {
        final code = wh['warehouse_code']?.toString() ?? '';
        final name = wh['warehouse_name']?.toString() ?? code;
        // Only include warehouses the user has access to
        if (widget.warehouseCodes.contains(code)) {
          names[code] = name;
        }
      }
      // If API didn't return some codes, add them with code as name
      for (final code in widget.warehouseCodes) {
        names.putIfAbsent(code, () => code);
      }
      setState(() => _warehouseNames = names);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _applyFilters();
  }

  /// Apply the type (cycle/full) + search filters over the loaded sessions.
  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredSessions = _sessions.where((s) {
        if (s.countingType != _typeFilter) return false;
        if (q.isEmpty) return true;
        final whName = (s.warehouseName ?? s.warehouseCode).toLowerCase();
        return whName.contains(q) || s.id.toString().contains(q);
      }).toList();
    });
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final result = await _repo.getSessions(status: _selectedStatus);
    if (mounted) {
      setState(() {
        _sessions = result.sessions;
        _isLoading = false;
        _hasError = !result.success;
      });
      _applyFilters();
    }
  }

  Future<void> _createNewSession() async {
    // If user has only 1 warehouse, skip the picker
    if (widget.warehouseCodes.length == 1) {
      await _doCreateSession(widget.warehouseCodes.first);
      return;
    }

    // Show warehouse picker bottom sheet
    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: AppLocalizations.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: _WarehousePickerSheet(
          warehouseNames: _warehouseNames,
          warehouseCodes: widget.warehouseCodes,
        ),
      ),
    );

    if (selectedCode != null) {
      await _doCreateSession(selectedCode);
    }
  }

  Future<void> _doCreateSession(String warehouseCode) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    final result = await _repo.createSession(warehouseCode: warehouseCode);

    if (mounted) {
      Navigator.pop(context); // dismiss loading
    }

    if (result.success && result.session != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CountingDetailPage(sessionId: result.session!.id),
        ),
      ).then((_) => _loadSessions());
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'حدث خطأ في إنشاء سجل الجرد')),
      );
    }
  }

  static String _statusFilterLabel(BuildContext context, String status) {
    switch (status) {
      case 'in_progress':
        return context.tr('counting_in_progress');
      case 'completed':
        return context.tr('status_completed');
      case 'cancelled':
        return context.tr('status_cancelled');
      default:
        return context.tr('all');
    }
  }

  Future<void> _openStatusFilter() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _StatusFilterSheet(current: _selectedStatus),
    );
    if (result == null) return; // dismissed without choosing
    setState(() => _selectedStatus = result == 'all' ? null : result);
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(
          title: context.tr('stock_counting'),
        ),
        // Cycle counts are system-generated — only annual (full) counts are
        // created manually, so the "New Count" button shows on the سنوي tab only.
        floatingActionButton: _typeFilter == 'full'
            ? FloatingActionButton.extended(
                onPressed: _createNewSession,
                icon: const Icon(Icons.add_rounded),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                label: Text(
                  context.tr('new_count_btn'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : null,
        body: Column(
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
                      onChanged: _onSearchChanged,
                      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: context.tr('search_counting'),
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
                  const SizedBox(width: AppSpacing.sm),
                  _FilterButton(
                    active: _selectedStatus != null,
                    onTap: _openStatusFilter,
                  ),
                ],
              ),
            ),

            // ─── Type Segments (دوري / سنوي) ────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.sm),
              child: AppSegmentedControl(
                activeColor: AppDomain.counting.accent,
                items: [
                  SegmentItem(context.tr('cycle_count'), icon: Icons.autorenew_rounded),
                  SegmentItem(context.tr('full_count'), icon: Icons.event_available_outlined),
                ],
                selectedIndex: _typeFilter == 'cycle' ? 0 : 1,
                onChanged: (i) {
                  setState(() => _typeFilter = i == 0 ? 'cycle' : 'full');
                  _applyFilters();
                },
              ),
            ),

            // Active status filter — a removable summary chip.
            if (_selectedStatus != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
                  child: InputChip(
                    label: Text(_statusFilterLabel(context, _selectedStatus!)),
                    onDeleted: () {
                      setState(() => _selectedStatus = null);
                      _loadSessions();
                    },
                    backgroundColor: AppColors.primaryContainer,
                    labelStyle: AppTypography.labelSmall.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                    deleteIconColor: AppColors.primaryDark,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.sm),

            // ─── List Section ───────────────────────────────
            Expanded(
              child: _isLoading
                  ? const SkeletonList(itemCount: 5, cardHeight: 160)
                  : _hasError
                      ? ErrorStateWidget(onRetry: _loadSessions)
                      : _filteredSessions.isEmpty
                          ? EmptyState(
                              icon: _typeFilter == 'cycle'
                                  ? Icons.autorenew_rounded
                                  : Icons.inventory_2_outlined,
                              title: _searchController.text.isEmpty
                                  ? context.tr('no_sessions')
                                  : context.tr('no_results'),
                              subtitle: _typeFilter == 'cycle'
                                  ? context.tr('cycle_auto_generated')
                                  : (_searchController.text.isEmpty ? context.tr('click_to_start') : null),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadSessions,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.base,
                                  vertical: AppSpacing.sm,
                                ),
                                itemCount: _filteredSessions.length,
                                itemBuilder: (context, index) =>
                                    _SessionCard(session: _filteredSessions[index], onRefresh: _loadSessions),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Button (opens status sheet) ───────────────────
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
            Icon(Icons.tune_rounded,
                size: 22, color: active ? Colors.white : AppColors.textSecondary),
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

// ─── Status Filter Bottom Sheet ───────────────────────────
class _StatusFilterSheet extends StatelessWidget {
  final String? current;
  const _StatusFilterSheet({this.current});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final options = <({String value, String label, Color color, IconData icon})>[
      (value: 'all', label: context.tr('all'), color: AppColors.textSecondary, icon: Icons.layers_outlined),
      (value: 'in_progress', label: context.tr('counting_in_progress'), color: AppColors.warning, icon: Icons.timelapse_rounded),
      (value: 'completed', label: context.tr('status_completed'), color: AppColors.success, icon: Icons.check_circle_outline_rounded),
      (value: 'cancelled', label: context.tr('status_cancelled'), color: AppColors.error, icon: Icons.cancel_outlined),
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
                  width: 40, height: 4,
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

// ─── Session Card ─────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final CountingSession session;
  final VoidCallback onRefresh;

  const _SessionCard({required this.session, required this.onRefresh});

  Color get _statusColor {
    switch (session.status) {
      case 'in_progress': return AppColors.statusInProgress;
      case 'completed': return AppColors.statusCompleted;
      case 'cancelled': return AppColors.statusCancelled;
      default: return AppColors.textTertiary;
    }
  }

  String _statusLabel(BuildContext context) {
    switch (session.status) {
      case 'in_progress': return context.tr('counting_in_progress');
      case 'completed': return context.tr('status_completed');
      case 'cancelled': return context.tr('status_cancelled');
      default: return session.statusLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => session.isCycleCount
              ? CycleCountDetailPage(sessionId: session.id)
              : CountingDetailPage(sessionId: session.id),
        ),
      ).then((_) => onRefresh()),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.borderXl,
          border: Border.all(color: AppColors.borderLight),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs + 1,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.09),
                    borderRadius: AppRadius.borderFull,
                    border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
                  ),
                  child: Text(
                    _statusLabel(context),
                    style: AppTypography.labelSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (session.isCycleCount) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(
                    label: context.tr('cycle_count'),
                    color: AppColors.primary,
                    icon: Icons.autorenew_rounded,
                  ),
                ],
                const Spacer(),
                Text(
                  '#${session.id}',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),

            // Warehouse info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: const Icon(Icons.warehouse_outlined, size: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    session.warehouseName ?? session.warehouseCode,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),

            // Stats row
            Row(
              children: [
                _StatPill(
                  icon: Icons.category_outlined,
                  label: '${session.linesCount} ${context.tr('items')}',
                ),
                const SizedBox(width: AppSpacing.md),
                _StatPill(
                  icon: Icons.inventory_outlined,
                  label: '${session.totalCountedQty.toInt()} ${context.tr('pieces')}',
                ),
              ],
            ),

            // Continue button if in_progress
            if (session.isInProgress) ...[
              const SizedBox(height: AppSpacing.base),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => session.isCycleCount
              ? CycleCountDetailPage(sessionId: session.id)
              : CountingDetailPage(sessionId: session.id),
                    ),
                  ).then((_) => onRefresh()),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    context.tr('continue_counting'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderMd,
                    ),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 1),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Warehouse Picker Bottom Sheet ────────────────────────
class _WarehousePickerSheet extends StatelessWidget {
  final Map<String, String> warehouseNames;
  final List<String> warehouseCodes;

  const _WarehousePickerSheet({
    required this.warehouseNames,
    required this.warehouseCodes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.base,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.borderFull,
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('start_new_count'),
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        context.tr('choose_warehouse'),
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          // Warehouse list
          ...warehouseCodes.map((code) {
            final name = warehouseNames[code] ?? code;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context, code),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: AppRadius.borderMd,
                        ),
                        child: const Icon(Icons.warehouse_outlined, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              code,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
