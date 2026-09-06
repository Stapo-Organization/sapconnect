import 'dart:async';

import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/data/zooboxi_orders_repository.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/data/models/mrsool_delivery.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/data/models/zooboxi_order.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/presentation/widgets/mrsool_delivery_card.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/presentation/widgets/zooboxi_order_card.dart' show elapsedLabel;

/// Guided express-order fulfillment — review items, start preparing, tick each
/// line as picked, then confirm prepared (which pushes the status to the store).
class ZooboxiOrderDetailPage extends StatefulWidget {
  final int orderId;
  const ZooboxiOrderDetailPage({super.key, required this.orderId});

  @override
  State<ZooboxiOrderDetailPage> createState() => _ZooboxiOrderDetailPageState();
}

class _ZooboxiOrderDetailPageState extends State<ZooboxiOrderDetailPage>
    with WidgetsBindingObserver {
  final ZooboxiOrdersRepository _repo = ZooboxiOrdersRepository();

  ZooboxiOrder? _order;
  bool _loading = true;
  bool _hasError = false;
  bool _busy = false;
  final Set<int> _picked = {}; // line ids confirmed picked

  // ── Mrsool (مرسول) last-mile ──
  MrsoolDelivery? _mrsool;
  bool _mrsoolEligible = false;
  String? _mrsoolReason;
  bool _mrsoolBusy = false;
  Timer? _mrsoolTimer;

  /// Poll cadence while a courier request is live.
  static const Duration _mrsoolPollInterval = Duration(seconds: 30);

  static final _accent = AppDomain.zooboxi.accent; // crimson — urgency

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _mrsoolTimer?.cancel();
    _mrsoolTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Never poll while the app is backgrounded — resume picks it back up.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncMrsoolTimer();
      if (_shouldShowMrsool) _refreshMrsool();
    } else {
      _mrsoolTimer?.cancel();
      _mrsoolTimer = null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final res = await _repo.getOrder(widget.orderId);
    if (mounted) {
      final order = res.order;
      setState(() {
        _order = order;
        _loading = false;
        _hasError = !res.success || _order == null;
        if (order != null) {
          _mrsoolEligible = order.mrsoolEligible;
          _mrsool = order.mrsoolActive ?? _mrsool;
        }
      });
      if (_shouldShowMrsool) await _refreshMrsool();
      _syncMrsoolTimer();
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    final res = await _repo.startPreparing(widget.orderId);
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _order = res.order ?? _order;
        _busy = false;
      });
    } else {
      setState(() => _busy = false);
      _snack(res.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  Future<void> _prepare() async {
    setState(() => _busy = true);
    final res = await _repo.markPrepared(widget.orderId);
    if (!mounted) return;
    if (res.success) {
      _snack(
        res.wooSynced ? context.tr('order_prepared_done') : context.tr('order_prepared_no_sync'),
        res.wooSynced ? AppColors.success : AppColors.warning,
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      _snack(res.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: bg, content: Text(msg)),
    );
  }

  bool get _allPicked {
    final o = _order;
    if (o == null || o.lines.isEmpty) return false;
    return o.lines.every((l) => _picked.contains(l.id));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final o = _order;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(
          title: o != null ? '${context.tr('order_no')} ${o.reference}' : context.tr('zooboxi_urgent_orders'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _hasError || o == null
                ? ErrorStateWidget(onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _accent,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      children: [
                        _buildHeader(o),
                        if (_shouldShowMrsool) ...[
                          const SizedBox(height: AppSpacing.base),
                          MrsoolDeliveryCard(
                            order: o,
                            delivery: _mrsool,
                            eligible: _mrsoolEligible,
                            reason: _mrsoolReason,
                            busy: _mrsoolBusy,
                            onRequest: _requestMrsool,
                            onCancel: _cancelMrsool,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.base),
                        _buildItems(o),
                        const SizedBox(height: AppSpacing.huge),
                      ],
                    ),
                  ),
        bottomNavigationBar: (o != null && (o.isPending || o.isPreparing)) ? _buildBottom(o) : null,
      ),
    );
  }

  // ─── Mrsool (مرسول) last-mile ───────────────────────────────

  /// The card is additive: it appears only once the branch has finished
  /// picking AND the order is eligible for a courier or one was already asked
  /// for. Everything above (start / prepare) is untouched.
  bool get _shouldShowMrsool {
    final o = _order;
    if (o == null || !o.mrsoolStageReached) return false;
    return _mrsoolEligible || _mrsool != null;
  }

  /// Poll only while a courier request is live and not terminal.
  void _syncMrsoolTimer() {
    final live = _shouldShowMrsool && _mrsool != null && !_mrsool!.isTerminal;
    if (!live) {
      _mrsoolTimer?.cancel();
      _mrsoolTimer = null;
      return;
    }
    _mrsoolTimer ??= Timer.periodic(_mrsoolPollInterval, (_) => _refreshMrsool());
  }

  Future<void> _refreshMrsool() async {
    final res = await _repo.getMrsool(widget.orderId);
    if (!mounted || !res.success) return;
    setState(() {
      _mrsoolEligible = res.eligible;
      _mrsoolReason = res.reason;
      // A terminal row is history the card still shows (failed → retry,
      // delivered → proof photos), so keep it if the endpoint only returns
      // the *active* delivery; a live row that vanished is really gone.
      _mrsool = res.delivery ?? ((_mrsool?.isTerminal ?? false) ? _mrsool : null);
    });
    _syncMrsoolTimer();
  }

  Future<void> _requestMrsool() async {
    final o = _order;
    if (o == null || _mrsoolBusy) return;

    // 1) Indicative price (never blocking — Mrsool may not be configured).
    setState(() => _mrsoolBusy = true);
    final quote = await _repo.getMrsoolQuote(widget.orderId);
    if (!mounted) return;
    setState(() => _mrsoolBusy = false);

    // 2) Owner-facing confirmation with price + both addresses.
    final confirmed = await _confirmMrsoolRequest(o, quote.success ? quote.price : null);
    if (confirmed != true || !mounted) return;

    // 3) Ask for the courier.
    setState(() => _mrsoolBusy = true);
    final res = await _repo.requestMrsool(widget.orderId);
    if (!mounted) return;
    setState(() {
      _mrsoolBusy = false;
      if (res.success) _mrsool = res.delivery ?? _mrsool;
    });
    if (res.success) {
      _snack(context.tr('mrsool_requested'), AppColors.success);
      _syncMrsoolTimer();
      await _refreshMrsool();
    } else {
      _snack(res.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  Future<void> _cancelMrsool() async {
    if (_mrsoolBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocalizations.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(context.tr('mrsool_cancel_confirm_title')),
          content: Text(context.tr('mrsool_cancel_confirm_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(context.tr('mrsool_cancel_confirm_cta')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _mrsoolBusy = true);
    final res = await _repo.cancelMrsool(widget.orderId);
    if (!mounted) return;
    setState(() {
      _mrsoolBusy = false;
      if (res.success) _mrsool = res.delivery ?? _mrsool;
    });
    if (res.success) {
      _snack(context.tr('mrsool_cancel_done'), AppColors.warning);
      _syncMrsoolTimer();
      await _refreshMrsool();
    } else {
      _snack(res.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  /// Bottom-sheet confirmation: price (or "not available"), pickup, dropoff.
  Future<bool?> _confirmMrsoolRequest(ZooboxiOrder o, double? price) {
    final pickup = [o.warehouseName, o.warehouseCode]
        .where((e) => e != null && e.isNotEmpty)
        .join(' · ');
    final dropoff = [o.customer.address, o.customer.city]
        .where((e) => e != null && e.isNotEmpty)
        .join(' — ');

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: AppLocalizations.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: BottomSheetScaffold(
          title: context.tr('mrsool_confirm_title'),
          subtitle: context.tr('mrsool_confirm_hint'),
          icon: Icons.delivery_dining_rounded,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: (price == null ? AppColors.warning : AppColors.success)
                        .withValues(alpha: 0.08),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        price == null ? Icons.info_outline_rounded : Icons.payments_outlined,
                        size: 18,
                        color: price == null ? AppColors.warning : AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(context.tr('mrsool_price'),
                            style: AppTypography.labelMedium
                                .copyWith(color: AppColors.textSecondary)),
                      ),
                      Text(
                        price == null
                            ? context.tr('mrsool_price_unavailable')
                            : '${price.toStringAsFixed(2)} ${context.tr('currency')}',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: price == null ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _sheetRow(Icons.storefront_rounded, context.tr('mrsool_pickup_from'),
                    pickup.isEmpty ? o.warehouseCode : pickup),
                _sheetRow(Icons.person_pin_circle_rounded, context.tr('mrsool_dropoff_to'),
                    dropoff.isEmpty ? (o.customer.name ?? '—') : dropoff),
                const SizedBox(height: AppSpacing.base),
                AppButton(
                  label: context.tr('mrsool_confirm_cta'),
                  icon: Icons.check_rounded,
                  color: _accent,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(context.tr('cancel'),
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: 2),
                Text(value,
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header (order + customer) ──────────────────────────────
  Widget _buildHeader(ZooboxiOrder o) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: AppDomain.zooboxi.accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${context.tr('order_no')} ${o.reference}',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              ),
              StatusBadge(
                label: context.tr('express_delivery'),
                color: _accent,
                icon: Icons.bolt_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatChip(
                icon: Icons.schedule_rounded,
                label: elapsedLabel(context, o.minutesSinceCreated),
                color: _accent,
              ),
              StatChip(icon: Icons.inventory_2_outlined, label: '${o.totalItems.toInt()} ${context.tr('items')}'),
              StatChip(
                icon: Icons.payments_outlined,
                label: '${o.totalAmount.toStringAsFixed(2)} ${context.tr('currency')}',
                color: AppColors.success,
              ),
            ],
          ),
          if (_hasCustomer(o)) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            if (o.customer.name != null && o.customer.name!.isNotEmpty)
              _customerRow(Icons.person_outline_rounded, o.customer.name!),
            if (o.customer.phone != null && o.customer.phone!.isNotEmpty)
              _customerRow(Icons.phone_outlined, o.customer.phone!),
            if (o.customer.address != null && o.customer.address!.isNotEmpty)
              _customerRow(Icons.location_on_outlined,
                  [o.customer.address, o.customer.city].where((e) => e != null && e.isNotEmpty).join(' — ')),
          ],
        ],
      ),
    );
  }

  bool _hasCustomer(ZooboxiOrder o) =>
      (o.customer.name?.isNotEmpty ?? false) ||
      (o.customer.phone?.isNotEmpty ?? false) ||
      (o.customer.address?.isNotEmpty ?? false);

  Widget _customerRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  // ─── Items (with per-line check-off when preparing) ─────────
  Widget _buildItems(ZooboxiOrder o) {
    final pickable = o.isPreparing;
    final pickedCount = o.lines.where((l) => _picked.contains(l.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(context.tr('order_items'),
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (pickable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_allPicked ? AppColors.success : _accent).withValues(alpha: 0.10),
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text('$pickedCount / ${o.lines.length}',
                    style: AppTypography.labelSmall.copyWith(
                        color: _allPicked ? AppColors.success : _accent, fontWeight: FontWeight.w800)),
              )
            else
              Text('${o.lines.length} ${context.tr('items')}',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...o.lines.map((line) => _lineTile(o, line, pickable)),
      ],
    );
  }

  Widget _lineTile(ZooboxiOrder o, ZooboxiOrderLine line, bool pickable) {
    final picked = _picked.contains(line.id);
    final active = pickable && picked;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: active ? AppColors.successLight.withValues(alpha: 0.4) : AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: active ? AppColors.success.withValues(alpha: 0.3) : AppColors.borderLight),
      ),
      child: Row(
        children: [
          if (pickable)
            GestureDetector(
              onTap: () => setState(() {
                if (picked) {
                  _picked.remove(line.id);
                } else {
                  _picked.add(line.id);
                }
              }),
              child: Icon(picked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: picked ? AppColors.success : AppColors.textTertiary, size: 26),
            )
          else
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: AppRadius.borderMd,
              ),
              child: Text('${line.quantity.toInt()}×',
                  style: AppTypography.labelMedium.copyWith(color: _accent, fontWeight: FontWeight.w800)),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.displayName,
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(line.itemCode,
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: AppRadius.borderFull,
            ),
            child: Text('${context.tr('qty_short')} ${line.quantity.toInt()}',
                style: AppTypography.labelSmall.copyWith(
                    color: _accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ─── Bottom action ──────────────────────────────────────────
  Widget _buildBottom(ZooboxiOrder o) {
    final preparing = o.isPreparing;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: AppButton(
          label: preparing ? context.tr('mark_prepared') : context.tr('start_preparing'),
          icon: preparing ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
          color: preparing ? AppColors.success : _accent,
          loading: _busy,
          onPressed: _busy
              ? null
              : preparing
                  ? (_allPicked ? _prepare : null)
                  : _start,
        ),
      ),
    );
  }
}
