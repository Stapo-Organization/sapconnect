import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
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

  /// True when the page is the «البحث» tab root: large page title, no back
  /// button, and no keyboard on launch (the tab is built with the shell).
  final bool isTab;

  const ProductSearchPage({super.key, this.myWarehouses = const [], this.isTab = false});

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final ProductSearchController _controller = ProductSearchController();
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Pushed from a button → open the keyboard the moment the screen settles.
    if (!widget.isTab) WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
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
    final field = _searchRow();
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: widget.isTab ? null : MuntajatAppBar(title: context.tr('product_search')),
        body: Column(
          children: [
            if (widget.isTab)
              PageHeader(title: context.tr('nav_search'), below: field)
            else
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: field),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Polaris search field (white, grey stroke, blue focus) + a solid scan
  /// button beside it.
  Widget _searchRow() {
    return Row(
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => TextField(
              controller: _field,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: context.tr('ps_search_hint'),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                suffixIcon: _controller.query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.cancel_rounded, size: 18, color: AppColors.textTertiary),
                        tooltip: context.tr('ps_clear'),
                        onPressed: () {
                          _field.clear();
                          _controller.clear();
                          _focus.requestFocus();
                        },
                      ),
              ),
              onChanged: _controller.onQuery,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: context.tr('scan_to_count'),
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _onScan,
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    // Initial state — nothing typed yet.
    if (!_controller.isSearching && _controller.results.isEmpty) {
      if (_controller.loading) return const Center(child: CircularProgressIndicator());
      return _hint(
        icon: Icons.search_rounded,
        title: context.tr('ps_search_prompt_title'),
        subtitle: context.tr('ps_search_prompt_subtitle'),
        action: AppButton(
          label: context.tr('ps_scan_barcode_btn'),
          icon: Icons.qr_code_scanner_rounded,
          onPressed: _onScan,
          expand: false,
          variant: AppButtonVariant.tonal,
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
        if (_controller.loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.xl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                child: Text(
                  context.tr('ps_results_count').replaceAll('{n}', '${results.length}'),
                  style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
              AppSection(
                dividerIndent: 72,
                children: [
                  for (final hit in results)
                    ProductHitTile(hit: hit, onTap: () => _openDetail(hit.itemCode, hit.name)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hint({required IconData icon, required String title, required String subtitle, Widget? action}) {
    return EmptyState(icon: icon, title: title, subtitle: subtitle.isEmpty ? null : subtitle, trailing: action);
  }
}
