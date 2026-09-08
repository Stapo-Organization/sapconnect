import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/live_tracking.dart';
import '../../data/orders_repository.dart';

/// «تتبّع مندوبك» — the live courier panel on the order screen.
///
/// The order of the card is the order of the customer's questions: *how long*,
/// then *where*, then *who*, then *what happened so far*. The map is not the
/// headline — a number of minutes is what people actually read — so the line
/// of text comes first and the map sits under it as the evidence.
class LiveTrackingCard extends StatelessWidget {
  const LiveTrackingCard({super.key, required this.tracking, this.orderId});

  final LiveTracking tracking;

  /// Set on the order screen so tapping the map opens one that keeps moving.
  /// Left null in tests and previews, where the card stands alone.
  final int? orderId;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tone = _phaseTone(context, tracking.phase);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Headline(tracking: tracking, tone: tone),
          if (tracking.hasMap)
            _CourierMap(
              tracking: tracking,
              onOpen: orderId == null
                  ? null
                  : () {
                      Haptics.light();
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => LiveTrackingMapPage(
                          orderId: orderId!,
                          initial: tracking,
                        ),
                      ));
                    },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tracking.courier.isKnown) ...[
                  _CourierRow(courier: tracking.courier, tone: tone),
                  Gap.h12,
                ],
                _Steps(steps: tracking.steps, tone: tone),
                if (tracking.proofImages.isNotEmpty) ...[
                  Gap.h12,
                  _Proof(images: tracking.proofImages),
                ],
                if (tracking.updatedAt != null && tracking.isLive) ...[
                  Gap.h8,
                  _UpdatedAt(at: tracking.updatedAt!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ── The sentence that answers "how long?" ──────────────────────── */

class _Headline extends StatelessWidget {
  const _Headline({required this.tracking, required this.tone});

  final LiveTracking tracking;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final eta = tracking.etaMinutes;

    final String? sub = switch (tracking.phase) {
      LivePhase.searching => l.liveTrackSearchingHint,
      LivePhase.failed => l.liveTrackFailedHint,
      LivePhase.delivered => tracking.deliveredAt == null
          ? null
          : l.liveTrackDeliveredAt(
              Fmt.clock(tracking.deliveredAt!, Localizations.localeOf(context).languageCode)),
      _ => _distanceLine(context, tracking),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      color: tone.withValues(alpha: 0.10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhaseGlyph(phase: tracking.phase, tone: tone),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLine(context, tracking),
                  style: context.tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                if (sub != null) ...[
                  Gap.h4,
                  Text(
                    sub,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          // An arrival estimate over two hours is not an estimate, it is a
          // symptom — a courier without a GPS fix, or a stale position. Better
          // to say nothing than to promise a number nobody believes.
          if (eta != null && eta <= 120) ...[
            Gap.w12,
            _EtaPill(minutes: eta, tone: tone),
          ],
        ],
      ),
    );
  }
}

/// The whole point of the panel, in one word-sized box.
class _EtaPill extends StatelessWidget {
  const _EtaPill({required this.minutes, required this.tone});

  final int minutes;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Text(
        minutes <= 0 ? l.liveTrackEtaNow : l.liveTrackEta(minutes),
        style: context.tt.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A pulsing dot while the courier is live, a settled icon once he is not.
/// The motion is the honest signal that the screen is actually watching.
class _PhaseGlyph extends StatefulWidget {
  const _PhaseGlyph({required this.phase, required this.tone});

  final LivePhase phase;
  final Color tone;

  @override
  State<_PhaseGlyph> createState() => _PhaseGlyphState();
}

class _PhaseGlyphState extends State<_PhaseGlyph> with SingleTickerProviderStateMixin {
  // Built eagerly, never lazily: a delivered order never starts the pulse, and
  // a `late` controller would then be constructed for the first time inside
  // dispose() — which looks up TickerMode on an element that is already gone.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    if (!widget.phase.isTerminal) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _PhaseGlyph old) {
    super.didUpdateWidget(old);
    if (widget.phase.isTerminal && _c.isAnimating) {
      _c.stop();
    } else if (!widget.phase.isTerminal && !_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (widget.phase) {
      LivePhase.searching => Icons.radar_rounded,
      LivePhase.assigned => Icons.storefront_rounded,
      LivePhase.inTransit => Icons.two_wheeler_rounded,
      LivePhase.delivered => Icons.check_rounded,
      LivePhase.failed => Icons.error_outline_rounded,
    };

    final core = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: widget.tone, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: Colors.white),
    );

    if (widget.phase.isTerminal) return core;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_c.value);
        return SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 38 + 22 * t,
                height: 38 + 22 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.tone.withValues(alpha: 0.22 * (1 - t)),
                ),
              ),
              ?child,
            ],
          ),
        );
      },
      child: core,
    );
  }
}

/* ── The map ────────────────────────────────────────────────────── */

/// Branch, courier and door on one canvas, framed so all three fit.
///
/// The courier's marker is tweened between polls rather than teleporting every
/// ten seconds: the position is ten seconds old either way, and a dot that
/// glides reads as "live" while a dot that jumps reads as broken.
class _CourierMap extends StatefulWidget {
  const _CourierMap({required this.tracking, this.onOpen});

  final LiveTracking tracking;
  final VoidCallback? onOpen;

  @override
  State<_CourierMap> createState() => _CourierMapState();
}

class _CourierMapState extends State<_CourierMap> {
  final MapController _map = MapController();
  bool _ready = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CourierMap old) {
    super.didUpdateWidget(old);

    // A courier riding out of the initial frame would otherwise slide off the
    // preview and never come back.
    final points = mapPoints(widget.tracking);
    if (_ready && points.length > 1) {
      _map.fitCamera(CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(46),
        maxZoom: 15.5,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracking;
    final points = mapPoints(t);

    return GestureDetector(
      onTap: widget.onOpen,
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(46),
                    maxZoom: 15.5,
                  ),
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  onMapReady: () => _ready = true,
                ),
                children: courierMapLayers(context, t),
              ),
            ),
            // The map is a preview, so it says so rather than inviting a drag
            // that the disabled interaction would swallow.
            if (widget.onOpen != null)
              PositionedDirectional(
                end: 10,
                bottom: 10,
                child: _MapChip(label: L.of(context).liveTrackOpenMap),
              ),
          ],
        ),
      ),
    );
  }
}

/// Every point worth framing: the courier, the door, and the branch when we
/// know it.
List<LatLng> mapPoints(LiveTracking t) => [
      if (t.courier.hasPosition) LatLng(t.courier.lat!, t.courier.lng!),
      if (t.dropoff != null) LatLng(t.dropoff!.lat, t.dropoff!.lng),
      if (t.pickup != null) LatLng(t.pickup!.lat, t.pickup!.lng),
    ];

/// The tiles, the leg being ridden, and the three markers — shared by the
/// preview and the full-screen map so they can never drift apart.
List<Widget> courierMapLayers(BuildContext context, LiveTracking t) {
  final l = L.of(context);
  final tone = _phaseTone(context, t.phase);
  final dark = Theme.of(context).brightness == Brightness.dark;

  final courier = t.courier.hasPosition ? LatLng(t.courier.lat!, t.courier.lng!) : null;
  final dropoff = t.dropoff == null ? null : LatLng(t.dropoff!.lat, t.dropoff!.lng);
  final pickup = t.pickup == null ? null : LatLng(t.pickup!.lat, t.pickup!.lng);

  // Draw the leg the courier is actually riding. Before pickup he is heading
  // for the branch, and a line to the customer's door would be a lie drawn to
  // scale.
  final target = t.headingTo == 'pickup' ? pickup : dropoff;

  return [
    TileLayer(
      urlTemplate: dark
          ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
          : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.zooboxi.store',
      maxNativeZoom: 18,
    ),
    if (courier != null && target != null)
      PolylineLayer(
        polylines: [
          Polyline(
            points: [courier, target],
            strokeWidth: 3,
            color: tone.withValues(alpha: 0.55),
            pattern: const StrokePattern.dotted(),
          ),
        ],
      ),
    MarkerLayer(
      markers: [
        if (pickup != null)
          Marker(
            point: pickup,
            width: 34,
            height: 34,
            child: _MapDot(
              icon: Icons.storefront_rounded,
              color: context.cs.onSurfaceVariant,
              tooltip: l.liveTrackBranch,
            ),
          ),
        if (dropoff != null)
          Marker(
            point: dropoff,
            width: 34,
            height: 34,
            child: _MapDot(
              icon: Icons.home_rounded,
              color: context.cs.primary,
              tooltip: l.liveTrackYou,
            ),
          ),
      ],
    ),
    if (courier != null) _CourierMarkerLayer(to: courier, tone: tone),
    RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      showFlutterMapAttribution: false,
      attributions: [
        TextSourceAttribution('OpenStreetMap', onTap: () {
          launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          );
        }),
        const TextSourceAttribution('CARTO', prependCopyright: false),
      ],
    ),
  ];
}

/// The courier's own layer, so his marker can be moved smoothly without
/// re-laying the static markers on every animation frame.
///
/// The lerp is between the LAST point we drew and the new one, held in state:
/// tweening from a value read during build would restart the glide on every
/// unrelated rebuild.
class _CourierMarkerLayer extends StatefulWidget {
  const _CourierMarkerLayer({required this.to, required this.tone});

  final LatLng to;
  final Color tone;

  @override
  State<_CourierMarkerLayer> createState() => _CourierMarkerLayerState();
}

class _CourierMarkerLayerState extends State<_CourierMarkerLayer> {
  late LatLng _from = widget.to;

  @override
  void didUpdateWidget(covariant _CourierMarkerLayer old) {
    super.didUpdateWidget(old);
    if (old.to != widget.to) _from = old.to;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${widget.to.latitude},${widget.to.longitude}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, t, _) {
        final point = LatLng(
          _from.latitude + (widget.to.latitude - _from.latitude) * t,
          _from.longitude + (widget.to.longitude - _from.longitude) * t,
        );

        return MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 44,
              height: 44,
              child: _CourierDot(tone: widget.tone),
            ),
          ],
        );
      },
    );
  }
}

/// The courier's dot: a soft halo so it stays findable against a busy tile.
class _CourierDot extends StatelessWidget {
  const _CourierDot({required this.tone});

  final Color tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone.withValues(alpha: 0.22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tone,
            boxShadow: [
              BoxShadow(color: tone.withValues(alpha: 0.45), blurRadius: 10, spreadRadius: 1),
            ],
          ),
          child: const Icon(Icons.two_wheeler_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _MapDot extends StatelessWidget {
  const _MapDot({required this.icon, required this.color, this.tooltip});

  final IconData icon;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final dot = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.cs.surface,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 17, color: color),
    );

    final label = tooltip;
    return label == null ? dot : Tooltip(message: label, child: dot);
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_full_rounded, size: 13, color: context.cs.onSurfaceVariant),
          Gap.w6,
          Text(label, style: context.tt.labelSmall),
        ],
      ),
    );
  }
}

/* ── Who is carrying it ─────────────────────────────────────────── */

class _CourierRow extends StatelessWidget {
  const _CourierRow({required this.courier, required this.tone});

  final LiveCourier courier;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final phone = courier.phone;

    return Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: tone.withValues(alpha: 0.15),
          child: Text(
            _initials(courier.name!),
            style: context.tt.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w700),
          ),
        ),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(courier.name!, style: context.tt.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(l.liveTrackCourier, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        if (phone != null && phone.isNotEmpty)
          FilledButton.tonalIcon(
            onPressed: () {
              Haptics.light();
              launchUrl(Uri(scheme: 'tel', path: phone));
            },
            icon: const Icon(Icons.phone_rounded, size: 17),
            label: Text(l.liveTrackCall),
          ),
      ],
    );
  }

  /// One or two letters — enough to make the avatar feel like a person rather
  /// than a placeholder, in either script.
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first;
    return parts.first.characters.first + parts[1].characters.first;
  }
}

/* ── What has happened so far ───────────────────────────────────── */

class _Steps extends StatelessWidget {
  const _Steps({required this.steps, required this.tone});

  final List<LiveStep> steps;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final lastDone = steps.lastIndexWhere((s) => s.done);

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            label: _stepLabel(context, steps[i]),
            time: steps[i].at == null ? null : Fmt.clock(steps[i].at!, locale),
            done: steps[i].done,
            current: i == lastDone,
            last: i == steps.length - 1,
            tone: tone,
            muted: cs.outlineVariant,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.current,
    required this.last,
    required this.tone,
    required this.muted,
    this.time,
  });

  final String label;
  final String? time;
  final bool done;
  final bool current;
  final bool last;
  final Color tone;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final color = done ? tone : muted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: current ? 12 : 9,
                height: current ? 12 : 9,
                margin: EdgeInsets.only(top: current ? 4 : 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : cs.surface,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: color.withValues(alpha: done ? 0.5 : 1)),
                ),
            ],
          ),
          Gap.w12,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: context.tt.bodySmall?.copyWith(
                        color: done ? cs.onSurface : cs.onSurfaceVariant,
                        fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (time != null)
                    Text(
                      time!,
                      style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Proof of delivery ──────────────────────────────────────────── */

class _Proof extends StatelessWidget {
  const _Proof({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.liveTrackProof, style: context.tt.labelMedium),
        Gap.h8,
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => Gap.w8,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () {
                Haptics.light();
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => _PhotoPage(url: images[i], title: l.liveTrackProof),
                ));
              },
              child: SizedBox(
                width: 92,
                height: 92,
                child: ZbImage(
                  url: images[i],
                  fit: BoxFit.cover,
                  radius: BorderRadius.circular(ZbTokens.rSm),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: ZbImage(url: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _UpdatedAt extends StatelessWidget {
  const _UpdatedAt({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(Icons.sync_rounded, size: 12, color: context.cs.onSurfaceVariant),
        Gap.w4,
        Text(
          L.of(context).liveTrackUpdatedAt(Fmt.clock(at, locale)),
          style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/* ── The full-screen map ────────────────────────────────────────── */

/// The same three points, given the whole screen.
///
/// It watches the provider rather than the snapshot it was opened with: this is
/// the screen a customer stares at while the courier rides, and a frozen dot
/// here would be worse than no map at all. The provider is already alive under
/// the order screen beneath, so watching it costs nothing extra.
class LiveTrackingMapPage extends ConsumerWidget {
  const LiveTrackingMapPage({super.key, required this.orderId, required this.initial});

  final int orderId;

  /// What the card was showing when the customer tapped — drawn immediately, so
  /// the map never opens empty while the first poll lands.
  final LiveTracking initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final tracking = ref.watch(liveTrackingProvider(orderId)).value ?? initial;
    final tone = _phaseTone(context, tracking.phase);
    final points = mapPoints(tracking);

    return Scaffold(
      appBar: AppBar(title: Text(l.liveTrackTitle)),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: points.length > 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(70),
                        maxZoom: 16,
                      )
                    : null,
                initialCenter: points.isEmpty ? const LatLng(24.7136, 46.6753) : points.first,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: courierMapLayers(context, tracking),
            ),
          ),
          PositionedDirectional(
            start: 12,
            end: 12,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: _MapFooter(tracking: tracking, tone: tone),
          ),
        ],
      ),
    );
  }
}

class _MapFooter extends StatelessWidget {
  const _MapFooter({required this.tracking, required this.tone});

  final LiveTracking tracking;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final url = tracking.trackingUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statusLine(context, tracking), style: context.tt.titleSmall),
          if (_distanceLine(context, tracking) case final line?) ...[
            Gap.h4,
            Text(line, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
          if (tracking.courier.isKnown) ...[
            Gap.h12,
            _CourierRow(courier: tracking.courier, tone: tone),
          ],
          if (url != null && url.isNotEmpty) ...[
            Gap.h8,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(L.of(context).liveTrackOpenMrsool),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ── Shared wording and colour ──────────────────────────────────── */

/// Mrsool's raw status, said in the reader's language.
///
/// The server already ships an Arabic sentence, but an English reader must get
/// English — so the app owns the wording and keeps the server's string only as
/// the fallback for a status this build has not heard of yet.
String _statusLine(BuildContext context, LiveTracking t) {
  final l = L.of(context);

  return switch (t.status) {
    'COURIER_PENDING' => l.liveTrackSearching,
    'COURIER_ASSIGNED' => l.liveTrackAssigned,
    'COURIER_REASSIGNED' => l.liveTrackReassigned,
    'PICKUP_ARRIVED' => l.liveTrackAtBranch,
    'COLLECTING' => l.liveTrackCollecting,
    'CONFIRMED_PICKUP' || 'WAITING_FOR_DELIVERY' => l.liveTrackPickedUp,
    'DELIVERING' => l.liveTrackOnTheWay,
    'DROPOFF_ARRIVED' => l.liveTrackAtDoor,
    'PARTIALLY_DELIVERED' => l.liveTrackPartial,
    'DELIVERED' => l.liveTrackDelivered,
    'RETURN' => l.liveTrackReturned,
    'CANCELED' => l.liveTrackCanceled,
    'EXPIRED' => l.liveTrackExpired,
    // Prefer our own phase wording over the server's Arabic sentence: the
    // phase is always known, and an English reader must not be handed Arabic
    // just because Mrsool invented a status since this build shipped.
    _ => _phaseLine(l, t.phase),
  };
}

String _phaseLine(L l, LivePhase phase) => switch (phase) {
      LivePhase.searching => l.liveTrackSearching,
      LivePhase.assigned => l.liveTrackAssigned,
      LivePhase.inTransit => l.liveTrackOnTheWay,
      LivePhase.delivered => l.liveTrackDelivered,
      LivePhase.failed => l.liveTrackCanceled,
    };

String _stepLabel(BuildContext context, LiveStep step) {
  final l = L.of(context);

  return switch (step.key) {
    'requested' => l.liveTrackStepRequested,
    'assigned' => l.liveTrackStepAssigned,
    'picked_up' => l.liveTrackStepPickedUp,
    'delivered' => l.liveTrackStepDelivered,
    'failed' => l.liveTrackStepFailed,
    // A key this build does not know is rare enough that the server's own
    // wording is a better answer than a blank row.
    _ => step.label,
  };
}

String? _distanceLine(BuildContext context, LiveTracking t) {
  final km = t.distanceKm;
  if (km == null || !t.isLive) return null;

  final locale = Localizations.localeOf(context).languageCode;
  final rounded = km < 1 ? (math.max(km, 0.1)) : km;

  return L.of(context).liveTrackDistance(
        Fmt.number(rounded, locale: locale, decimals: 1),
      );
}

Color _phaseTone(BuildContext context, LivePhase phase) {
  final zb = context.zb;

  return switch (phase) {
    LivePhase.searching => zb.warning,
    LivePhase.assigned => zb.tierExpress.fg,
    LivePhase.inTransit => context.cs.primary,
    LivePhase.delivered => zb.success,
    LivePhase.failed => context.cs.error,
  };
}
