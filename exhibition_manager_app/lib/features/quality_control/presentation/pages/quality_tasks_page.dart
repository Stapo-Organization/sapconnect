import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/features/quality_control/data/quality_control_repository.dart';
import 'package:exhibition_manager_app/features/quality_control/data/models/quality_task_models.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/widgets/quality_task_card.dart';
import 'quality_task_detail_page.dart';

/// Quality tasks list — pending / submitted, warehouse-scoped.
class QualityTasksPage extends StatefulWidget {
  const QualityTasksPage({super.key});

  @override
  State<QualityTasksPage> createState() => _QualityTasksPageState();
}

class _QualityTasksPageState extends State<QualityTasksPage> {
  final QualityControlRepository _repo = QualityControlRepository();
  List<QualityTaskInstance> _tasks = [];
  bool _loading = true;
  bool _hasError = false;
  String _status = 'pending'; // pending | submitted

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final res = await _repo.getTasks(status: _status);
    if (mounted) {
      setState(() {
        _tasks = res.tasks;
        _loading = false;
        _hasError = !res.success;
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
        appBar: MuntajatAppBar(title: context.tr('quality_tasks')),
        body: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
              child: AppSegmentedControl(
                activeColor: AppDomain.quality.accent,
                items: [
                  SegmentItem(context.tr('status_pending'), icon: Icons.timelapse_rounded),
                  SegmentItem(context.tr('status_submitted'), icon: Icons.check_circle_outline_rounded),
                ],
                selectedIndex: _status == 'pending' ? 0 : 1,
                onChanged: (i) {
                  setState(() => _status = i == 0 ? 'pending' : 'submitted');
                  _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const SkeletonList(itemCount: 6, cardHeight: 78)
                  : _hasError
                      ? ErrorStateWidget(onRetry: _load)
                      : _tasks.isEmpty
                          ? EmptyState(
                              icon: Icons.verified_outlined,
                              title: context.tr('no_quality_tasks'),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xl),
                                itemCount: _tasks.length,
                                itemBuilder: (context, i) => QualityTaskCard(
                                  task: _tasks[i],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QualityTaskDetailPage(instanceId: _tasks[i].id),
                                    ),
                                  ).then((_) => _load()),
                                )
                                    .animate()
                                    .fadeIn(duration: 280.ms, delay: (i.clamp(0, 8) * 35).ms)
                                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
