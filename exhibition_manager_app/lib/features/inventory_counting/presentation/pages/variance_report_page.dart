import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/animated_icons.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/counting_repository.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Variance Report Page — shows variance analysis after completing a counting session
class VarianceReportPage extends StatefulWidget {
  final int sessionId;
  const VarianceReportPage({super.key, required this.sessionId});

  @override
  State<VarianceReportPage> createState() => _VarianceReportPageState();
}

class _VarianceReportPageState extends State<VarianceReportPage> {
  final CountingRepository _repo = CountingRepository();
  Map<String, dynamic>? _reportData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.getVarianceReport(widget.sessionId);
    if (mounted) {
      setState(() {
        _loading = false;
        if (result.success) {
          _reportData = result.report;
        } else {
          _error =
              result.error ??
              AppLocalizations.translate('ic_report_load_failed');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(context.tr('ic_variance_report_title')),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.textPrimary),
              )
            : _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: TextStyle(color: AppColors.error, fontSize: 16),
                ),
              )
            : _buildReport(),
      ),
    );
  }

  Widget _buildReport() {
    final report = _reportData?['report'];
    if (report == null) {
      return Center(
        child: Text(
          context.tr('ic_no_data'),
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final summary = report['summary'] as Map<String, dynamic>? ?? {};
    final discrepancies = report['discrepancies'] as List? ?? [];
    final uncountedCount = _reportData?['uncounted_count'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadReport,
      color: AppColors.textPrimary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          _buildHeaderCard(report, summary),
          const SizedBox(height: 16),

          // Summary Stats
          _buildSummaryGrid(summary),
          const SizedBox(height: 16),

          // Accuracy Card
          _buildAccuracyCard(summary),
          const SizedBox(height: 16),

          // Uncounted Items Warning
          if (uncountedCount > 0) ...[
            _buildUncountedCard(uncountedCount),
            const SizedBox(height: 16),
          ],

          // Discrepancies
          if (discrepancies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context
                    .tr('ic_discrepancies_n')
                    .replaceAll('{n}', '${discrepancies.length}'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...discrepancies.map((d) => _buildDiscrepancyCard(d)),
          ] else
            _buildNoDiscrepanciesCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    Map<String, dynamic> report,
    Map<String, dynamic> summary,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report['warehouse_name'] ?? report['warehouse_code'] ?? '',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context
                .tr('ic_count_type_label')
                .replaceAll(
                  '{type}',
                  report['counting_type'] == 'cycle'
                      ? context.tr('cycle_count')
                      : context.tr('ic_full_count_type'),
                ),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                context
                    .tr('ic_products_counted_n')
                    .replaceAll('{n}', '${summary['total_lines'] ?? 0}'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(Map<String, dynamic> summary) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            '✅ ${context.tr('ic_variance_match')}',
            '${summary['match'] ?? 0}',
            AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            '⚡ ${context.tr('ic_variance_within_tolerance')}',
            '${summary['within_tolerance'] ?? 0}',
            AppColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            '📈 ${context.tr('ic_variance_over')}',
            '${summary['over'] ?? 0}',
            AppColors.info,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            '📉 ${context.tr('ic_variance_short')}',
            '${summary['short'] ?? 0}',
            AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyCard(Map<String, dynamic> summary) {
    final accuracy = (summary['accuracy_percentage'] ?? 100).toDouble();
    final color = accuracy >= 98
        ? AppColors.success
        : accuracy >= 95
        ? AppColors.warning
        : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            accuracy >= 98
                ? Icons.check_circle_rounded
                : accuracy >= 95
                ? Icons.warning_rounded
                : Icons.error_rounded,
            color: color,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('ic_stock_accuracy'),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${accuracy.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context
                    .tr('ic_counted_qty_label')
                    .replaceAll('{n}', '${summary['total_counted_qty'] ?? 0}'),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
              Text(
                context
                    .tr('ic_system_qty_label')
                    .replaceAll('{n}', '${summary['total_system_qty'] ?? 0}'),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUncountedCard(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('ic_uncounted_products'),
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context
                      .tr('ic_uncounted_products_note')
                      .replaceAll('{n}', '$count'),
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscrepancyCard(Map<String, dynamic> d) {
    final status = d['variance_status'] ?? '';
    final variance = (d['variance'] ?? 0).toDouble();
    final variancePct = (d['variance_percentage'] ?? 0).toDouble();
    final color = status == 'short'
        ? AppColors.error
        : status == 'over'
        ? AppColors.info
        : AppColors.warning;
    final icon = status == 'short'
        ? Icons.trending_down_rounded
        : Icons.trending_up_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: d['image_url'] ?? '',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: AppColors.shimmerBase,
                highlightColor: AppColors.shimmerHighlight,
                child: Container(width: 50, height: 50, color: Colors.white),
              ),
              errorWidget: (_, _, _) => Container(
                width: 50,
                height: 50,
                color: AppColors.surfaceVariant,
                child: Icon(
                  Icons.image_not_supported_rounded,
                  color: AppColors.textTertiary,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d['item_name'] ?? d['item_code'] ?? '',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  d['item_code'] ?? '',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
                if (d['investigation_note'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📝 ${d['investigation_note']}',
                    style: TextStyle(color: AppColors.warning, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Variance
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${variance > 0 ? '+' : ''}${variance.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                '${variancePct.toStringAsFixed(1)}%',
                style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                context
                    .tr('ic_system_vs_counted')
                    .replaceAll(
                      '{sys}',
                      (d['system_quantity'] ?? 0).toDouble().toStringAsFixed(0),
                    )
                    .replaceAll(
                      '{counted}',
                      (d['counted_quantity'] ?? 0).toDouble().toStringAsFixed(
                        0,
                      ),
                    ),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoDiscrepanciesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // بطل حالة النجاح — يطفو بهدوء (الحلقة المستمرة الوحيدة في الشاشة).
          FloatingIcon(
            child: Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 48,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('ic_no_discrepancies'),
            style: TextStyle(
              color: AppColors.success,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('ic_no_discrepancies_sub'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
