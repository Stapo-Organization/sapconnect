import 'dart:async';
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
import 'package:exhibition_manager_app/features/zooboxi_orders/data/zooboxi_orders_repository.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/data/models/zooboxi_order.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/presentation/widgets/zooboxi_order_card.dart';
import 'zooboxi_order_detail_page.dart';

/// Express Zooboxi orders for the manager's branch — waiting / done.
class ZooboxiOrdersPage extends StatefulWidget {
  const ZooboxiOrdersPage({super.key, this.initialScope = 'waiting'});

  final String initialScope; // 'waiting' | 'done'

  @override
  State<ZooboxiOrdersPage> createState() => _ZooboxiOrdersPageState();
}

class _ZooboxiOrdersPageState extends State<ZooboxiOrdersPage> {
  final ZooboxiOrdersRepository _repo = ZooboxiOrdersRepository();
  List<ZooboxiOrder> _orders = [];
  bool _loading = true;
  bool _hasError = false;
  late String _scope = widget.initialScope; // waiting | done
  DateTime _fetchedAt = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // Keep the "waiting for X" counters live.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _scope == 'waiting' && _orders.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final res = await _repo.getOrders(scope: _scope);
    if (mounted) {
      setState(() {
        _orders = res.orders;
        _fetchedAt = DateTime.now();
        _loading = false;
        _hasError = !res.success;
      });
    }
  }

  /// Live minutes-waiting = server value + minutes elapsed since we fetched.
  int _liveMinutes(ZooboxiOrder o) =>
      o.minutesSinceCreated + DateTime.now().difference(_fetchedAt).inMinutes;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final waiting = _scope == 'waiting';
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('zooboxi_urgent_orders')),
        body: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
              child: AppSegmentedControl(
                activeColor: AppDomain.zooboxi.accent,
                items: [
                  SegmentItem(context.tr('orders_waiting'), icon: Icons.bolt_rounded),
                  SegmentItem(context.tr('orders_done'), icon: Icons.check_circle_outline_rounded),
                ],
                selectedIndex: waiting ? 0 : 1,
                onChanged: (i) {
                  setState(() => _scope = i == 0 ? 'waiting' : 'done');
                  _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const SkeletonList(itemCount: 6, cardHeight: 78)
                  : _hasError
                      ? ErrorStateWidget(onRetry: _load)
                      : _orders.isEmpty
                          ? EmptyState(
                              icon: waiting ? Icons.inbox_outlined : Icons.check_circle_outline_rounded,
                              color: AppDomain.zooboxi.accent,
                              title: context.tr(waiting ? 'no_urgent_orders' : 'no_done_orders'),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppDomain.zooboxi.accent,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xl),
                                itemCount: _orders.length,
                                itemBuilder: (context, i) => ZooboxiOrderCard(
                                  order: _orders[i],
                                  minutesOverride: waiting ? _liveMinutes(_orders[i]) : null,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ZooboxiOrderDetailPage(orderId: _orders[i].id),
                                    ),
                                  ).then((_) => _load()),
                                )
                                    .animate()
                                    .fadeIn(duration: 280.ms, delay: (i.clamp(0, 8) * 35).ms)
                                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOut)
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
