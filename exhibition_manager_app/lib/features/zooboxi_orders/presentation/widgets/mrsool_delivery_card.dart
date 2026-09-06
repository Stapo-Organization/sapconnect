import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/data/models/mrsool_delivery.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/data/models/zooboxi_order.dart';

/// Accent colour for a delivery phase — semantic tokens only.
Color mrsoolPhaseColor(String phase) => switch (phase) {
      MrsoolPhase.delivered => AppColors.success,
      MrsoolPhase.failed => AppColors.error,
      MrsoolPhase.inTransit => AppColors.primary,
      MrsoolPhase.assigned => AppColors.info,
      _ => AppColors.warning,
    };

IconData _phaseIcon(String phase) => switch (phase) {
      MrsoolPhase.delivered => Icons.check_circle_rounded,
      MrsoolPhase.failed => Icons.error_outline_rounded,
      MrsoolPhase.inTransit => Icons.local_shipping_rounded,
      MrsoolPhase.assigned => Icons.person_pin_circle_rounded,
      _ => Icons.pending_actions_rounded,
    };

/// The Mrsool (مرسول) last-mile card on the express-order detail page.
///
/// Additive: it renders only when the order is eligible for a courier or a
/// courier request already exists — the prepare/start flow above it is
/// untouched. All actions are delegated to the page, which owns the polling.
class MrsoolDeliveryCard extends StatelessWidget {
  final ZooboxiOrder order;
  final MrsoolDelivery? delivery;

  /// Server-computed eligibility for a *new* courier request.
  final bool eligible;
  final String? reason;

  /// A request/cancel call is in flight.
  final bool busy;

  final VoidCallback onRequest;
  final VoidCallback onCancel;

  const MrsoolDeliveryCard({
    super.key,
    required this.order,
    required this.delivery,
    required this.eligible,
    required this.reason,
    required this.busy,
    required this.onRequest,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final accent = d == null ? AppDomain.zooboxi.accent : mrsoolPhaseColor(d.phase);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: accent.withValues(alpha: 0.20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, accent, d),
          if (d == null) ...[
            const SizedBox(height: AppSpacing.md),
            _idleBody(context, accent),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            _activeBody(context, accent, d),
          ],
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────
  Widget _header(BuildContext context, Color accent, MrsoolDelivery? d) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: AppRadius.borderMd,
          ),
          child: Icon(
            d == null ? Icons.delivery_dining_rounded : _phaseIcon(d.phase),
            color: accent,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('mrsool_title'),
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                d?.mrsoolOrderId != null
                    ? '${context.tr('mrsool_order_ref')} ${d!.mrsoolOrderId}'
                    : context.tr('mrsool_subtitle'),
                style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (d != null) ...[
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(label: d.displayStatus, color: accent),
        ],
      ],
    );
  }

  // ─── No courier requested yet ──────────────────────────────
  Widget _idleBody(BuildContext context, Color accent) {
    if (!eligible) {
      return _notice(
        context,
        icon: Icons.info_outline_rounded,
        color: AppColors.textTertiary,
        title: context.tr('mrsool_unavailable'),
        body: reason,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('mrsool_idle_hint'),
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: context.tr('mrsool_request'),
          icon: Icons.delivery_dining_rounded,
          color: accent,
          loading: busy,
          onPressed: busy ? null : onRequest,
        ),
      ],
    );
  }

  // ─── A courier request exists ──────────────────────────────
  Widget _activeBody(BuildContext context, Color accent, MrsoolDelivery d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.isFailed)
          _notice(
            context,
            icon: Icons.error_outline_rounded,
            color: AppColors.error,
            title: context.tr('mrsool_failed'),
            body: d.lastError,
          )
        else
          _phaseLine(context, accent, d),
        if (d.isPartial) ...[
          const SizedBox(height: AppSpacing.sm),
          StatusBadge(
            label: context.tr('mrsool_status_partially_delivered'),
            color: AppColors.warning,
            icon: Icons.info_outline_rounded,
          ),
        ],
        if (d.courier != null && !d.isFailed) ...[
          const SizedBox(height: AppSpacing.md),
          _courierRow(context, accent, d.courier!),
        ],
        if (!d.isFailed && _mapPoints(d).length >= 2) ...[
          const SizedBox(height: AppSpacing.md),
          _MrsoolMiniMap(
            branch: _branchPoint,
            customer: _customerPoint,
            courier: _courierPoint(d),
            accent: accent,
          ),
          const SizedBox(height: AppSpacing.sm),
          _mapLegend(context, d),
        ],
        if (d.events.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _timeline(context, accent, d),
        ],
        if (d.pickupImages.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _photoRow(context, context.tr('mrsool_pickup_photos'), d.pickupImages),
        ],
        if (d.dropoffImages.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _photoRow(context, context.tr('mrsool_dropoff_photos'), d.dropoffImages),
        ],
        if (d.priceQuote != null) ...[
          const SizedBox(height: AppSpacing.md),
          _factRow(context, context.tr('mrsool_price'), _price(context, d.priceQuote!)),
        ],
        if (d.lastSyncedAt != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.sync_rounded, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 5),
              Text(
                '${context.tr('mrsool_last_sync')} ${mrsoolTimeLabel(d.lastSyncedAt)}',
                style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
        if (d.canCancel) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: context.tr('mrsool_cancel'),
            icon: Icons.close_rounded,
            variant: AppButtonVariant.outline,
            color: AppColors.error,
            loading: busy,
            onPressed: busy ? null : onCancel,
          ),
        ],
        if (d.isFailed) ...[
          const SizedBox(height: AppSpacing.md),
          if (eligible)
            AppButton(
              label: context.tr('mrsool_request_again'),
              icon: Icons.refresh_rounded,
              color: AppDomain.zooboxi.accent,
              loading: busy,
              onPressed: busy ? null : onRequest,
            )
          else
            _notice(
              context,
              icon: Icons.info_outline_rounded,
              color: AppColors.textTertiary,
              title: context.tr('mrsool_unavailable'),
              body: reason,
            ),
        ],
      ],
    );
  }

  /// The one-line "what is happening now" strip above the courier block.
  Widget _phaseLine(BuildContext context, Color accent, MrsoolDelivery d) {
    final at = d.phaseAt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: AppRadius.borderMd,
      ),
      child: Row(
        children: [
          if (d.isSearching)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          else
            Icon(_phaseIcon(d.phase), size: 16, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              d.isDelivered
                  ? context.tr('mrsool_delivered_at')
                  : d.isSearching
                      ? context.tr('mrsool_searching')
                      : d.displayStatus,
              style: AppTypography.labelMedium
                  .copyWith(color: accent, fontWeight: FontWeight.w800),
            ),
          ),
          if (at != null)
            Text(mrsoolTimeLabel(at),
                style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _courierRow(BuildContext context, Color accent, MrsoolCourier courier) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_rounded, size: 18, color: accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('mrsool_courier'),
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
              const SizedBox(height: 2),
              Text(
                courier.hasName ? courier.name! : context.tr('mrsool_no_courier_yet'),
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (courier.hasPhone)
          Pressable(
            onTap: () => _call(courier.phone!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.10),
                borderRadius: AppRadius.borderFull,
                border: Border.all(color: AppColors.success.withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_rounded, size: 15, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(context.tr('mrsool_call'),
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.success, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _mapLegend(BuildContext context, MrsoolDelivery d) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: 6,
      children: [
        _legendDot(context, AppColors.primary, context.tr('mrsool_map_branch')),
        _legendDot(context, AppDomain.zooboxi.accent, context.tr('mrsool_map_customer')),
        if (_courierPoint(d) != null)
          _legendDot(context, AppColors.success, context.tr('mrsool_map_courier')),
      ],
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _timeline(BuildContext context, Color accent, MrsoolDelivery d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('mrsool_timeline'),
            style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < d.events.length; i++)
          _eventRow(d.events[i], accent, isFirst: i == 0, isLast: i == d.events.length - 1),
      ],
    );
  }

  Widget _eventRow(MrsoolEvent e, Color accent, {required bool isFirst, required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 2, height: 5, color: isFirst ? Colors.transparent : AppColors.borderLight),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isLast ? accent : AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
              ),
              Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : AppColors.borderLight)),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.displayLabel,
                      style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                  if (e.at != null) ...[
                    const SizedBox(height: 2),
                    Text(mrsoolTimeLabel(e.at),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoRow(BuildContext context, String title, List<String> urls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (ctx, i) => Pressable(
              onTap: () => _openPhoto(ctx, urls, i),
              child: ClipRRect(
                borderRadius: AppRadius.borderMd,
                child: CachedNetworkImage(
                  imageUrl: urls[i],
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: AppColors.surfaceVariant),
                  errorWidget: (_, _, _) => Container(
                    width: 72,
                    height: 72,
                    color: AppColors.surfaceVariant,
                    child: Icon(Icons.broken_image_outlined,
                        size: 20, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _notice(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    String? body,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.labelMedium
                        .copyWith(color: color, fontWeight: FontWeight.w800)),
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(body,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _factRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
        const Spacer(),
        Text(value, style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ─── Geometry helpers ──────────────────────────────────────
  LatLng? get _branchPoint => (order.warehouseLat != null && order.warehouseLng != null)
      ? LatLng(order.warehouseLat!, order.warehouseLng!)
      : null;

  LatLng? get _customerPoint => (order.customerLat != null && order.customerLng != null)
      ? LatLng(order.customerLat!, order.customerLng!)
      : null;

  LatLng? _courierPoint(MrsoolDelivery d) =>
      (d.courier?.hasLocation ?? false) ? LatLng(d.courier!.latitude!, d.courier!.longitude!) : null;

  List<LatLng> _mapPoints(MrsoolDelivery d) =>
      [_branchPoint, _customerPoint, _courierPoint(d)].whereType<LatLng>().toList();

  String _price(BuildContext context, double value) =>
      '${value.toStringAsFixed(2)} ${context.tr('currency')}';

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openPhoto(BuildContext context, List<String> urls, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MrsoolPhotoViewer(urls: urls, initialIndex: index),
      ),
    );
  }
}

/// Compact branch ↔ customer ↔ courier map. Re-fits whenever the courier moves.
class _MrsoolMiniMap extends StatefulWidget {
  final LatLng? branch;
  final LatLng? customer;
  final LatLng? courier;
  final Color accent;

  const _MrsoolMiniMap({
    required this.branch,
    required this.customer,
    required this.courier,
    required this.accent,
  });

  @override
  State<_MrsoolMiniMap> createState() => _MrsoolMiniMapState();
}

class _MrsoolMiniMapState extends State<_MrsoolMiniMap> {
  final MapController _map = MapController();
  bool _ready = false;

  List<LatLng> get _points =>
      [widget.branch, widget.customer, widget.courier].whereType<LatLng>().toList();

  @override
  void didUpdateWidget(covariant _MrsoolMiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (oldWidget.courier != widget.courier ||
        oldWidget.branch != widget.branch ||
        oldWidget.customer != widget.customer) {
      _fit();
    }
  }

  void _fit() {
    final points = _points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first, 14);
      return;
    }
    _map.fitCamera(CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.all(38),
      maxZoom: 15,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (points.isEmpty) return const SizedBox.shrink();
    final dark = AppThemeController.isDark;

    return ClipRRect(
      borderRadius: AppRadius.borderLg,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: points.first,
                initialZoom: 13,
                initialCameraFit: points.length > 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(38),
                        maxZoom: 15,
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
                ),
                onMapReady: () => _ready = true,
              ),
              children: [
                TileLayer(
                  urlTemplate: dark
                      ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                      : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                  userAgentPackageName: 'sa.muntajat.exhibitionManagerApp',
                ),
                if (widget.branch != null && widget.customer != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [widget.branch!, widget.customer!],
                        strokeWidth: 2.5,
                        color: widget.accent.withValues(alpha: 0.45),
                        pattern: StrokePattern.dotted(),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (widget.branch != null)
                      _marker(widget.branch!, Icons.storefront_rounded, AppColors.primary),
                    if (widget.customer != null)
                      _marker(widget.customer!, Icons.person_pin_circle_rounded,
                          AppDomain.zooboxi.accent),
                    if (widget.courier != null)
                      _marker(widget.courier!, Icons.delivery_dining_rounded, AppColors.success),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (dark ? Colors.black : Colors.white).withValues(alpha: 0.6),
                  borderRadius: AppRadius.borderSm,
                ),
                child: Text(
                  '© OpenStreetMap · CARTO',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textTertiary, fontSize: 9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color) => Marker(
        point: point,
        width: 34,
        height: 34,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      );
}

/// Full-screen viewer for a pickup/dropoff confirmation photo.
class MrsoolPhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const MrsoolPhotoViewer({super.key, required this.urls, this.initialIndex = 0});

  @override
  State<MrsoolPhotoViewer> createState() => _MrsoolPhotoViewerState();
}

class _MrsoolPhotoViewerState extends State<MrsoolPhotoViewer> {
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    _pages = PageController(
      initialPage: math.max(0, math.min(widget.initialIndex, widget.urls.length - 1)),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(context.tr('mrsool_photo_title'),
            style: AppTypography.titleSmall.copyWith(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: urls[i],
              fit: BoxFit.contain,
              placeholder: (_, _) => const CircularProgressIndicator(color: Colors.white),
              errorWidget: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
