import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/counting_repository.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/models/counting_session.dart';
import 'barcode_scanner_page.dart';
import 'variance_report_page.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
          title: const Text('إكمال الجرد'),
          content: Text('سيتم إكمال سجل الجرد هذا بإجمالي ${_session!.lines.length} صنف و ${_session!.totalCountedQty.toInt()} قطعة. لا يمكن التراجع بعد الإكمال.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('إكمال الجرد'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final result = await _repo.completeSession(widget.sessionId);
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم إكمال الجرد بنجاح')),
          );
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
          title: const Text('إلغاء الجرد'),
          content: const Text('هل أنت متأكد من إلغاء سجل الجرد هذا؟ لا يمكن التراجع.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('نعم، إلغاء الجرد'),
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
            const SnackBar(content: Text('تم إلغاء سجل الجرد')),
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
            decoration: const InputDecoration(
              labelText: 'الكمية',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(controller.text);
                Navigator.pop(ctx, qty);
              },
              child: const Text('تحديث'),
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
          title: const Text('حذف المنتج'),
          content: Text('هل تريد حذف "${line.getLocalizedName(AppLocalizations.isArabic)}" من سجل الجرد؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('حذف'),
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
        appBar: AppBar(
          title: Text(_session != null ? 'جرد #${_session!.id}' : 'تفاصيل الجرد'),
          actions: [
            if (_session != null && _session!.isInProgress)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'cancel') _cancelCounting();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('إلغاء الجرد'),
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
                ? const Center(child: Text('لم يتم العثور على سجل الجرد'))
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
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.base),
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VarianceReportPage(sessionId: _session!.id),
                                ),
                              ),
                              icon: const Icon(Icons.analytics_outlined, size: 22),
                              label: const Text('📊 عرض تقرير الفروقات'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 52),
                                backgroundColor: const Color(0xFF1E3A5F),
                                foregroundColor: Colors.tealAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),

                        // ─── Scan Button ─────────────────
                        if (_session!.isInProgress)
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.base),
                            child: ElevatedButton.icon(
                              onPressed: _openScanner,
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
                              label: const Text('📸 سكان باركود'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                backgroundColor: AppColors.accent,
                              ),
                            ),
                          ),

                        // ─── Lines ───────────────────────
                        Text(
                          'المنتجات المجرودة (${_session!.lines.length})',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_session!.lines.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.qr_code_scanner, size: 48, color: AppColors.textTertiary),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'لم يتم سكان أي منتج بعد',
                                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'اضغط على "سكان باركود" للبدء',
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._session!.lines.map((line) => _LineCard(
                                line: line,
                                canEdit: _session!.isInProgress,
                                onEdit: () => _editQuantity(line),
                                onDelete: () => _deleteLine(line),
                              )),

                        const SizedBox(height: AppSpacing.huge),
                      ],
                    ),
                  ),
        bottomNavigationBar: _session != null && _session!.isInProgress
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: ElevatedButton(
                    onPressed: _session!.lines.isNotEmpty ? _completeCounting : null,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    child: const Text('✅ إكمال الجرد'),
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
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(session.statusLabel,
                    style: AppTypography.labelMedium.copyWith(color: _statusColor)),
              ),
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
          _InfoRow('المستودع', session.warehouseName ?? session.warehouseCode),
          _InfoRow('عدد الأصناف', '${session.lines.length}'),
          _InfoRow('إجمالي الكميات', '${session.totalCountedQty.toInt()}'),
          if (session.notes != null && session.notes!.isNotEmpty)
            _InfoRow('ملاحظات', session.notes!),
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

// ─── Line Card ────────────────────────────────────────────
class _LineCard extends StatelessWidget {
  final CountingLine line;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LineCard({
    required this.line,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

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
              imageUrl: line.imageUrl ?? '',
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
                const SizedBox(height: 2),
                Text('${line.pieceBarcode ?? ""} • ${line.itemCode}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          // Quantity badge
          GestureDetector(
            onTap: canEdit ? onEdit : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderSm,
              ),
              child: Text(
                '${line.countedQuantity.toInt()}',
                style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
            ),
          ],
        ],
      ),
    );
  }
}
