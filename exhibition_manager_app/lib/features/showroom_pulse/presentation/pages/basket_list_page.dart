import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_button.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

import '../../data/models/pulse_overview.dart';
import '../../data/showroom_pulse_repository.dart';
import '../widgets/lever_item_card.dart';
import '../widgets/pulse_helpers.dart';
import 'package:exhibition_manager_app/features/product_search/presentation/product_detail_launcher.dart';

/// Full list behind كبّر السلة's "إظهار الكل" — every cross-brand
/// frequently-bought-together pair for this branch (same-brand pairs are
/// excluded server-side; they already share a shelf).
class BasketListPage extends StatefulWidget {
  final String warehouse;
  final String warehouseName;

  const BasketListPage({super.key, required this.warehouse, required this.warehouseName});

  @override
  State<BasketListPage> createState() => _BasketListPageState();
}

class _BasketListPageState extends State<BasketListPage> {
  final ShowroomPulseRepository _repo = ShowroomPulseRepository();

  bool _loading = true;
  bool _error = false;
  List<BasketPair> _pairs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final r = await _repo.getBasketAll(warehouse: widget.warehouse);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = !r.success;
      _pairs = r.items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: kBasketColor,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'كبّر السلة',
            style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? _errorState()
                : _pairs.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        color: kBasketColor,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl),
                          itemCount: _pairs.length + 1,
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: Text(
                                  '${_pairs.length} اقتراح عرض · ${widget.warehouseName}',
                                  style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                                ),
                              );
                            }
                            return basketCard(
                              _pairs[i - 1],
                              onOpenItem: (ref) => openProductDetail(
                                context,
                                ref.code,
                                name: ref.name,
                                myWarehouses: [widget.warehouse],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Text(
        'لا توجد اقتراحات عرض بين براندات مختلفة لهذا الفرع.',
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text('تعذّر تحميل القائمة', style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _load),
        ],
      ),
    );
  }
}
