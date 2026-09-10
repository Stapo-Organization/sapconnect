import 'dart:math' as math;
import 'package:clock/clock.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/live_tracking.dart';
import 'courier_search_glyph.dart';
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
    final tone = livePhaseColor(context, tracking.phase);

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
          // While we are still looking there is no courier to put on a map, so
          // the slot the map will occupy carries the search itself rather than
          // collapsing and leaving the card looking like it has stalled.
          if (!tracking.hasMap && tracking.phase == LivePhase.searching)
            _SearchingPanel(tone: tone, deadline: tracking.assignmentDeadline),
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
      // The searching panel below carries the hint and the clock; saying it
      // twice on one card is worse than saying it once.
      LivePhase.searching => null,
      LivePhase.failed => l.liveTrackFailedHint,
      LivePhase.delivered => tracking.deliveredAt == null
          ? null
          : l.liveTrackDeliveredAt(
              Fmt.clock(tracking.deliveredAt!, Localizations.localeOf(context).languageCode)),
      _ => _distanceLine(context, tracking) ?? _lastSeenLine(context, tracking),
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
                  liveStatusLine(context, tracking),
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
    // Searching gets its own drawing: it is the phase with nothing to report,
    // and the one people watch hardest.
    if (widget.phase == LivePhase.searching) {
      return CourierSearchGlyph(tone: widget.tone, size: 38);
    }

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

/// The wait, given the room the map will take once there is a courier to draw.
///
/// Deliberately calm: someone reading "we are looking for a courier" does not
/// need to be alarmed, only reassured that somebody is looking.
class _SearchingPanel extends StatelessWidget {
  const _SearchingPanel({required this.tone, this.deadline});

  final Color tone;
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tone.withValues(alpha: 0.10), tone.withValues(alpha: 0.02)],
        ),
      ),
      child: Column(
        children: [
          CourierSearchGlyph(tone: tone, size: 84),
          Gap.h12,
          if (deadline != null)
            CourierCountdown(
              deadline: deadline!,
              // The clock is the loudest thing here on purpose: it is the only
              // number a customer can act on while nothing else is happening.
              style: context.tt.headlineSmall?.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              expiredStyle: context.tt.titleSmall?.copyWith(color: tone),
            ),
          Gap.h4,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              L.of(context).liveTrackAssignHint,
              textAlign: TextAlign.center,
              style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
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
/// What the camera has to keep in frame.
///
/// A stale courier point is deliberately NOT one of them: framing the map
/// around a place he left half an hour ago drags the view back to the branch
/// and squeezes the part of the journey that is still ahead.
List<LatLng> mapPoints(LiveTracking t) => [
      if (t.courierIsWhereWeSay) LatLng(t.courier.lat!, t.courier.lng!),
      if (t.dropoff != null) LatLng(t.dropoff!.lat, t.dropoff!.lng),
      if (t.pickup != null) LatLng(t.pickup!.lat, t.pickup!.lng),
    ];

/// The courier's dot, keyed so a test can assert on it: it is the one mark on
/// this screen that must never be drawn from a position we no longer believe.
const Key courierDotKey = Key('zb-courier-dot');

/// The tiles, the leg being ridden, and the three markers — shared by the
/// preview and the full-screen map so they can never drift apart.
List<Widget> courierMapLayers(BuildContext context, LiveTracking t) {
  final l = L.of(context);
  final tone = livePhaseColor(context, t.phase);
  final dark = Theme.of(context).brightness == Brightness.dark;

  // Only a position we still believe becomes a dot. For most of a ride Mrsool
  // has not moved the courier since he confirmed pickup, and drawing him there
  // parks a marker on the branch while he is halfway across Riyadh — which is
  // what «ليش باين المندوب عند المعرض» was looking at.
  final courier = t.courierIsWhereWeSay ? LatLng(t.courier.lat!, t.courier.lng!) : null;
  final dropoff = t.dropoff == null ? null : LatLng(t.dropoff!.lat, t.dropoff!.lng);
  final pickup = t.pickup == null ? null : LatLng(t.pickup!.lat, t.pickup!.lng);

  // Draw the leg the courier is actually riding. Before pickup he is heading
  // for the branch, and a line to the customer's door would be a lie drawn to
  // scale.
  final target = t.headingTo == 'pickup' ? pickup : dropoff;

  // With no dot to draw from, the line runs the whole journey instead: branch
  // to door is what is actually true — he is somewhere along it.
  final from = courier ?? (t.headingTo == 'dropoff' ? pickup : null);
  final to = courier != null ? target : dropoff;

  return [
    TileLayer(
      urlTemplate: dark
          ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
          : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.zooboxi.app',
      maxNativeZoom: 18,
    ),
    if (from != null && to != null)
      PolylineLayer(
        polylines: [
          Polyline(
            points: [from, to],
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
    if (courier != null)
      _CourierMarkerLayer(key: courierDotKey, to: courier, tone: tone),
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
  const _CourierMarkerLayer({super.key, required this.to, required this.tone});

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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        // On top of a map, a translucent chip with a hairline border reads as
        // part of the tiles. Nearly opaque, with a soft lift under it, and it
        // reads as a control.
        color: context.cs.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        border: Border.all(color: context.cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_full_rounded, size: 13, color: context.cs.onSurfaceVariant),
          Gap.w6,
          Text(label, style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
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
    final phone = courier.phone ?? '';
    final wa = whatsappNumber(phone);

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
        if (phone.isNotEmpty) ...[
          Gap.w8,
          _ContactAction(
            label: l.liveTrackCall,
            fill: tone.withValues(alpha: 0.12),
            border: tone.withValues(alpha: 0.32),
            icon: Icon(Icons.phone_rounded, size: 19, color: tone),
            onTap: () {
              Haptics.light();
              launchUrl(Uri(scheme: 'tel', path: phone));
            },
          ),
        ],
        if (wa != null) ...[
          Gap.w8,
          _ContactAction(
            label: l.liveTrackWhatsapp,
            fill: _whatsapp,
            glow: true,
            icon: const _WhatsappGlyph(size: 20, color: Colors.white),
            onTap: () {
              Haptics.light();
              launchUrl(
                Uri.https('wa.me', '/$wa', {'text': l.liveTrackWhatsappHello}),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
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

/// WhatsApp's own green. Left as the brand colour rather than pulled into the
/// palette: this button is recognised before it is read, and a teal WhatsApp
/// would cost exactly the recognition it exists for.
const Color _whatsapp = Color(0xFF25D366);

/// The courier's number the way `wa.me` wants it — digits only, in
/// international form.
///
/// Mrsool hands the number back in whatever shape the rider typed it: `05xx…`,
/// `+9665xx…`, `009665xx…`, sometimes with spaces. `tel:` forgives all of that;
/// WhatsApp does not — a local `05…` opens on «the phone number is invalid».
/// Anything that still does not look dialable returns null, and the button is
/// simply not offered rather than offered broken.
String? whatsappNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  if (digits.startsWith('00')) digits = digits.substring(2);
  // «+966 055…» — the country code and the trunk zero, both written out. Left
  // alone it is 13 digits, passes every length check, and dies on wa.me.
  if (digits.startsWith('9660')) digits = '966${digits.substring(4)}';
  if (digits.startsWith('0')) {
    digits = '966${digits.substring(1)}';
  } else if (digits.length == 9 && digits.startsWith('5')) {
    digits = '966$digits';
  }

  return digits.length < 11 || digits.length > 15 ? null : digits;
}

/// One round contact button.
///
/// The call used to be a wide labelled button that took a third of the row and
/// clipped the courier's own name to «هيثم أحمد حسن م…». Two circles give the
/// name its width back and let WhatsApp — how most people here actually message
/// a rider — stand BESIDE the phone instead of replacing it.
class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.label,
    required this.icon,
    required this.fill,
    required this.onTap,
    this.border,
    this.glow = false,
  });

  final String label;
  final Widget icon;
  final Color fill;
  final Color? border;

  /// A soft halo in the button's own colour — used on the WhatsApp circle so
  /// the pair reads as accent + quiet action rather than as two grey discs.
  final bool glow;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // `button` only — the Tooltip already carries the label, and iOS
      // concatenates the two into «اتصل بالمندوب، اتصل بالمندوب، زر».
      button: true,
      child: Tooltip(
        message: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: fill.withValues(alpha: 0.34),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: fill,
            shape: CircleBorder(
              side: border == null ? BorderSide.none : BorderSide(color: border!),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              // 44: the smallest square a thumb hits reliably, and the reason
              // the two of them still fit next to a long Arabic name.
              child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The WhatsApp mark itself, from the official outline.
///
/// A chat bubble from the Material set would have been half a sentence — the
/// glyph is what makes the button legible at a glance, in a country where the
/// customer will reach for WhatsApp before the dialler.
class _WhatsappGlyph extends StatelessWidget {
  const _WhatsappGlyph({required this.size, required this.color});

  final double size;
  final Color color;

  static const String _d =
      'M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="$_d"/></svg>',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
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
    final tone = livePhaseColor(context, tracking.phase);
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
          Text(liveStatusLine(context, tracking), style: context.tt.titleSmall),
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
/// Shared with the live bar above the tab bar: the sentence a customer reads in
/// two different places must be the same sentence.
///
/// The server already ships an Arabic sentence, but an English reader must get
/// English — so the app owns the wording and keeps the server's string only as
/// the fallback for a status this build has not heard of yet.
String liveStatusLine(BuildContext context, LiveTracking t) {
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

/// «آخر موقع للمندوب قبل ٧ دقائق».
///
/// Mrsool stamps the courier's position at the last status event, not from a
/// live GPS feed, so for most of the ride the dot on the map is where he WAS.
/// Drawing it without saying so is what makes the screen look broken: the
/// customer watches a marker that never moves and concludes the tracking is
/// dead. This is the sentence that turns a frozen dot into an honest one.
///
/// Only while he is actually riding, and only once the fix is old enough that
/// its stillness is worth explaining.
String? _lastSeenLine(BuildContext context, LiveTracking t) {
  if (t.phase != LivePhase.inTransit || !t.courier.hasPosition) return null;

  final seen = t.courierSeenAt;
  if (seen == null) return null;

  final minutes = clock.now().difference(seen).inMinutes;
  if (minutes < courierFixStaleMinutes) return null;

  return L.of(context).liveTrackLastSeen(minutes);
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

Color livePhaseColor(BuildContext context, LivePhase phase) {
  final zb = context.zb;

  return switch (phase) {
    LivePhase.searching => zb.warning,
    LivePhase.assigned => zb.tierExpress.fg,
    LivePhase.inTransit => context.cs.primary,
    LivePhase.delivered => zb.success,
    LivePhase.failed => context.cs.error,
  };
}
