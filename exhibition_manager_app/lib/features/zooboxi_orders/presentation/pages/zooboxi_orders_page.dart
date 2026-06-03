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

/// Express Zooboxi orders for the manager's branch — new / preparing.
class ZooboxiOrdersPage extends StatefulWidget {
  const ZooboxiOrdersPage({super.key});

  @override
  State<ZooboxiOrdersPage> createState() => _ZooboxiOrdersPageState();
}

class _ZooboxiOrdersPageState extends State<ZooboxiOrdersPage> {
  final ZooboxiOrdersRepository _repo = ZooboxiOrdersRepository();
  List<ZooboxiOrder> _orders = [];
  bool _loading = true;
  bool _hasError = false;
  String _status = 'pending'; // pending | preparing

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
    final res = await _repo.getOrders(status: _status);
    if (mounted) {
      setState(() {
        _orders = res.orders;
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
        appBar: MuntajatAppBar(title: context.tr('zooboxi_urgent_orders')),
        body: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
              child: AppSegmentedControl(
                activeColor: AppDomain.zooboxi.accent,
                items: [
                  SegmentItem(context.tr('orders_new'), icon: Icons.bolt_rounded),
                  SegmentItem(context.tr('status_preparing'), icon: Icons.timelapse_rounded),
                ],
                selectedIndex: _status == 'pending' ? 0 : 1,
                onChanged: (i) {
                  setState(() => _status = i == 0 ? 'pending' : 'preparing');
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
                              icon: Icons.local_shipping_outlined,
                              color: AppDomain.zooboxi.accent,
                              title: context.tr('no_urgent_orders'),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xl),
                                itemCount: _orders.length,
                                itemBuilder: (context, i) => ZooboxiOrderCard(
                                  order: _orders[i],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ZooboxiOrderDetailPage(orderId: _orders[i].id),
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
