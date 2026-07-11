import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

import '../controllers/product_search_controller.dart';
import '../widgets/product_widgets.dart';
import 'product_detail_page.dart';
import 'product_scanner_page.dart';

/// بحث المنتجات — type a product name, SAP code, or barcode and get a ranked,
/// thumbnailed result list. Tapping a result opens its full detail (stock across
/// every warehouse & showroom).
class ProductSearchPage extends StatefulWidget {
  /// The signed-in manager's warehouse codes — forwarded to the detail page so
  /// it can offer a "معارضي" stock filter.
  final List<String> myWarehouses;

  const ProductSearchPage({super.key, this.myWarehouses = const []});

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final ProductSearchController _controller = ProductSearchController();
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();

  static const Color _accent = Color(0xFF4C5FD5);

  @override
  void initState() {
    super.initState();
    // Open the keyboard the moment the screen settles.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openDetail(String itemCode, String name) {
    _focus.unfocus();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailPage(
        itemCode: itemCode,
        fallbackName: name,
        myWarehouses: widget.myWarehouses,
      ),
    ));
  }

  /// Open the camera, then look the scanned code up. A unique barcode/SAP-code
  /// hit jumps straight to the product; anything ambiguous just fills the field
  /// and shows the result list.
  Future<void> _onScan() async {
    _focus.unfocus();
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ProductScannerPage()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    _field.text = code;
    _field.selection = TextSelection.collapsed(offset: code.length);
    _controller.onQuery(code);
    final hit = await _controller.findExact(code);
    if (mounted && hit != null) _openDetail(hit.itemCode, hit.name);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
          title: TextField(
            controller: _field,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: AppTypography.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: context.tr('ps_search_hint'),
              hintStyle: AppTypography.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.7)),
            ),
            onChanged: _controller.onQuery,
          ),
          actions: [
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _controller.query.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: context.tr('ps_clear'),
                      onPressed: () {
                        _field.clear();
                        _controller.clear();
                        _focus.requestFocus();
                      },
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: context.tr('scan_to_count'),
              onPressed: _onScan,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _body(),
        ),
      ),
    );
  }

  Widget _body() {
    // Initial state — nothing typed yet.
    if (!_controller.isSearching && _controller.results.isEmpty) {
      if (_controller.loading) return const Center(child: CircularProgressIndicator(color: _accent));
      return _hint(
        icon: Icons.search_rounded,
        title: context.tr('ps_search_prompt_title'),
        subtitle: context.tr('ps_search_prompt_subtitle'),
        action: OutlinedButton.icon(
          onPressed: _onScan,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          label: Text(context.tr('ps_scan_barcode_btn')),
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: const BorderSide(color: _accent, width: 1.4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (_controller.hasError && _controller.results.isEmpty) {
      return _hint(
        icon: Icons.cloud_off_rounded,
        title: context.tr('ps_search_failed'),
        subtitle: _controller.error ?? '',
      );
    }

    if (!_controller.loading && _controller.results.isEmpty) {
      return _hint(
        icon: Icons.inventory_2_outlined,
        title: context.tr('no_results'),
        subtitle: context.tr('ps_try_another_query'),
      );
    }

    final results = _controller.results;
    return Column(
      children: [
        if (_controller.loading)
          const LinearProgressIndicator(minHeight: 2, color: _accent, backgroundColor: Color(0x114C5FD5)),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl),
            itemCount: results.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    context.tr('ps_results_count').replaceAll('{n}', '${results.length}'),
                    style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                  ),
                );
              }
              final hit = results[i - 1];
              return ProductHitTile(hit: hit, onTap: () => _openDetail(hit.itemCode, hit.name));
            },
          ),
        ),
      ],
    );
  }

  Widget _hint({required IconData icon, required String title, required String subtitle, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppDomain.productSearch.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: _accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
