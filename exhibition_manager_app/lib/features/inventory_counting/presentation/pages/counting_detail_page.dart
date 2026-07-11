import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/counting_repository.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/models/counting_session.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/widgets/counting_line_card.dart';
import 'barcode_scanner_page.dart';
import 'variance_report_page.dart';
import 'package:exhibition_manager_app/features/gamification/presentation/widgets/celebration_overlay.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Counting Detail Page — View and manage a single counting session
class CountingDetailPage extends StatefulWidget {
  final int sessionId;

  const CountingDetailPage({super.key, required this.sessionId});

  @override
  State<CountingDetailPage> createState() => _CountingDetailPageState();
}

class _CountingDetailPageState extends State<CountingDetailPage> {
  final CountingRepository _repo = CountingRepository();
  CountingSession? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    final result = await _repo.getSession(widget.sessionId);
    if (mounted) {
      setState(() {
        _session = result.session;
        _isLoading = false;
      });
    }
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerPage(
          countingSessionId: widget.sessionId,
          mode: ScanMode.inventoryCounting,
        ),
      ),
    );
    _loadSession();
  }

  Future<void> _completeCounting() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(context.tr('complete_count')),
          content: Text(context.tr('ic_complete_confirm')
              .replaceAll('{items}', '${_session!.lines.length}')
              .replaceAll('{qty}', '${_session!.totalCountedQty.toInt()}')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: Text(context.tr('complete_count')),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final result = await _repo.completeSession(widget.sessionId);
      if (mounted) {
        if (result.success) {
          if (result.gamification != null) {
            await showCelebration(context, result.gamification!);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('ic_count_completed_snack'))),
            );
          }
        }
        _loadSession();
      }
    }
  }

  Future<void> _cancelCounting() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(context.tr('ic_cancel_count')),
          content: Text(context.tr('ic_cancel_count_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('ic_no'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(context.tr('ic_yes_cancel_count')),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final result = await _repo.cancelSession(widget.sessionId);
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('ic_count_cancelled_snack'))),
          );
        }
        _loadSession();
      }
    }
  }

  Future<void> _editQuantity(CountingLine line) async {
    final controller = TextEditingController(text: line.countedQuantity.toInt().toString());
    final newQty = await showDialog<double>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(line.getLocalizedName(AppLocalizations.isArabic)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge,
            decoration: InputDecoration(
              labelText: context.tr('quantity'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(controller.text);
                Navigator.pop(ctx, qty);
              },
              child: Text(context.tr('update')),
            ),
          ],
        ),
      ),
    );

    if (newQty != null && newQty > 0) {
      await _repo.updateLine(widget.sessionId, line.id, newQty);
      _loadSession();
    }
  }

  Future<void> _deleteLine(CountingLine line) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(context.tr('ic_delete_product')),
          content: Text(context.tr('ic_delete_product_confirm')
              .replaceAll('{name}', line.getLocalizedName(AppLocalizations.isArabic))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(context.tr('delete')),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _repo.deleteLine(widget.sessionId, line.id);
      _loadSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(
          title: _session != null
              ? context.tr('ic_count_number').replaceAll('{n}', '${_session!.id}')
              : context.tr('ic_count_details'),
          actions: [
            if (_session != null && _session!.isInProgress)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 'cancel') _cancelCounting();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: AppColors.error),
                        SizedBox(width: 8),
                        Text(context.tr('ic_cancel_count')),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _session == null
                ? Center(child: Text(context.tr('ic_session_not_found')))
                : RefreshIndicator(
                    onRefresh: _loadSession,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      children: [
                        // ─── Header Info ─────────────────
                        _SessionHeader(session: _session!),
                        const SizedBox(height: AppSpacing.base),

                        // ─── Variance Report Button (completed only) ─────
                        if (_session!.isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.base),
                            child: AppButton(
                              label: context.tr('ic_view_variance_report'),
                              icon: Icons.analytics_outlined,
                              variant: AppButtonVariant.tonal,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VarianceReportPage(sessionId: _session!.id),
                                ),
                              ),
                            ),
                          ),

                        // ─── Scan Button ─────────────────
                        if (_session!.isInProgress)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.base),
                            child: AppButton(
                              label: context.tr('ic_scan_barcode'),
                              icon: Icons.qr_code_scanner_rounded,
                              color: AppColors.accent,
                              gradient: AppColors.goldGradient,
                              onPressed: _openScanner,
                            ),
                          ),

                        // ─── Lines ───────────────────────
                        Text(
                          context.tr('counted_products_n').replaceAll('{n}', '${_session!.lines.length}'),
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_session!.lines.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xl),
                            child: EmptyState(
                              icon: Icons.qr_code_scanner_rounded,
                              title: context.tr('no_records_yet'),
                              subtitle: context.tr('no_records_yet_hint'),
                            ),
                          )
                        else
                          ...withEntryNumbers(_session!.lines).map((r) => CountingLineCard(
                                line: r.line,
                                entryNumber: r.entry,
                                canEdit: _session!.isInProgress,
                                onEdit: () => _editQuantity(r.line),
                                onDelete: () => _deleteLine(r.line),
                              )),

                        const SizedBox(height: AppSpacing.huge),
                      ],
                    ),
                  ),
        bottomNavigationBar: _session != null && _session!.isInProgress
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: AppButton(
                    label: context.tr('complete_count'),
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                    onPressed: _session!.lines.isNotEmpty ? _completeCounting : null,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

// ─── Session Header ───────────────────────────────────────
class _SessionHeader extends StatelessWidget {
  final CountingSession session;
  const _SessionHeader({required this.session});

  Color get _statusColor {
    switch (session.status) {
      case 'in_progress': return AppColors.statusInProgress;
      case 'completed': return AppColors.statusCompleted;
      case 'cancelled': return AppColors.statusCancelled;
      default: return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              StatusBadge(label: session.statusLabel, color: _statusColor),
              if (session.isCycleCount) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text('🔄 ${session.countingTypeLabel}',
                      style: AppTypography.labelMedium.copyWith(color: Colors.tealAccent)),
                ),
              ],
              const Spacer(),
              Text('#${session.id}', style: AppTypography.titleLarge),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          _InfoRow(context.tr('ic_warehouse'), session.warehouseName ?? session.warehouseCode),
          _InfoRow(context.tr('ic_items_count'), '${session.lines.length}'),
          _InfoRow(context.tr('ic_total_quantities'), '${session.totalCountedQty.toInt()}'),
          if (session.notes != null && session.notes!.isNotEmpty)
            _InfoRow(context.tr('ic_notes'), session.notes!),
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
          Flexible(child: Text(value, style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
