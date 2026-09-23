import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../core/maps/map_style.dart';
import '../../data/live_tracking.dart';

/// Every point worth framing: the courier, the door, and the branch when we
/// know it.
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

/// The ride, on the same Google map (and in the same Zooboxi style) as the
/// delivery pin: the branch, the door, the courier gliding between fixes, and
/// the leg he is actually riding, dotted. One widget for the card's still
/// preview and the full-screen map, so the two can never drift apart.
class CourierMap extends StatefulWidget {
  const CourierMap({
    super.key,
    required this.tracking,
    required this.tone,
    this.interactive = false,
    this.framePadding = 46,
    this.maxZoom = 15.5,
  });

  final LiveTracking tracking;

  /// The phase's colour — the courier's dot and his leg wear it.
  final Color tone;
  final bool interactive;
  final double framePadding;
  final double maxZoom;

  @override
  State<CourierMap> createState() => _CourierMapState();
}

class _CourierMapState extends State<CourierMap> with SingleTickerProviderStateMixin {
  gm.GoogleMapController? _map;
  gm.BitmapDescriptor? _branch;
  gm.BitmapDescriptor? _door;
  gm.BitmapDescriptor? _courier;
  Color? _iconsFor;

  /// The glide between the last fix drawn and the new one. Held in state: a
  /// tween from a value read during build would restart on every rebuild.
  late final AnimationController _glide =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..value = 1;
  LatLng? _from;
  LatLng? _to;

  static gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);

  LatLng? get _courierNow {
    final t = widget.tracking;
    return t.courierIsWhereWeSay ? LatLng(t.courier.lat!, t.courier.lng!) : null;
  }

  @override
  void initState() {
    super.initState();
    _to = _courierNow;
    _from = _to;
    _glide.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paintIcons();
  }

  @override
  void didUpdateWidget(covariant CourierMap old) {
    super.didUpdateWidget(old);
    final next = _courierNow;
    if (next != _to) {
      _from = _position ?? next;
      _to = next;
      _glide.forward(from: 0);
    }
    if (old.tone != widget.tone) _paintIcons();
    // On the still preview a courier riding out of the frame would slide off
    // and never come back. The full map is the customer's to pan.
    if (!widget.interactive) _frame(animate: true);
  }

  @override
  void dispose() {
    _glide.dispose();
    _map?.dispose();
    super.dispose();
  }

  LatLng? get _position {
    final from = _from;
    final to = _to;
    if (to == null) return null;
    if (from == null) return to;
    final t = Curves.easeInOut.transform(_glide.value);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  Future<void> _paintIcons() async {
    if (!ZbMapStyle.live) return;
    final tone = widget.tone;
    if (_iconsFor == tone && _courier != null) return;
    _iconsFor = tone;
    final cs = context.cs;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final branch = await _markerIcon(Icons.storefront_rounded, ring: cs.onSurfaceVariant, fill: cs.surface, size: 34, dpr: dpr);
    final door = await _markerIcon(Icons.home_rounded, ring: cs.primary, fill: cs.surface, size: 34, dpr: dpr);
    final courier = await _markerIcon(Icons.two_wheeler_rounded, ring: tone, fill: tone, glyph: Colors.white, halo: tone, size: 44, dpr: dpr);
    if (!mounted) return;
    setState(() {
      _branch = branch;
      _door = door;
      _courier = courier;
    });
  }

  void _frame({bool animate = false}) {
    final map = _map;
    if (map == null) return;
    final points = mapPoints(widget.tracking);
    if (points.isEmpty) return;
    final gm.CameraUpdate update;
    if (points.length == 1) {
      update = gm.CameraUpdate.newLatLngZoom(_g(points.first), widget.maxZoom);
    } else {
      final lats = points.map((p) => p.latitude);
      final lngs = points.map((p) => p.longitude);
      update = gm.CameraUpdate.newLatLngBounds(
        gm.LatLngBounds(
          southwest: gm.LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
          northeast: gm.LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
        ),
        widget.framePadding,
      );
    }
    animate ? map.animateCamera(update) : map.moveCamera(update);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracking;
    final courier = _position;
    final dropoff = t.dropoff == null ? null : LatLng(t.dropoff!.lat, t.dropoff!.lng);
    final pickup = t.pickup == null ? null : LatLng(t.pickup!.lat, t.pickup!.lng);

    // Draw the leg the courier is actually riding. Before pickup he is heading
    // for the branch, and a line to the customer's door would be a lie drawn
    // to scale. With no dot to draw from, the line runs branch to door — he is
    // somewhere along it.
    final target = t.headingTo == 'pickup' ? pickup : dropoff;
    final from = courier ?? (t.headingTo == 'dropoff' ? pickup : null);
    final to = courier != null ? target : dropoff;

    if (!ZbMapStyle.live) {
      // `flutter test` has no platform views; the dot's presence is still the
      // fact under test.
      return ColoredBox(
        color: context.cs.surfaceContainerHigh,
        child: courier == null ? const SizedBox.expand() : const SizedBox.expand(key: courierDotKey),
      );
    }

    final points = mapPoints(t);
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: points.isEmpty ? const gm.LatLng(24.7136, 46.6753) : _g(points.first),
        zoom: 14,
      ),
      onMapCreated: (controller) {
        _map = controller;
        _frame();
      },
      style: ZbMapStyle.of(context),
      markers: {
        if (pickup != null && _branch != null)
          gm.Marker(markerId: const gm.MarkerId('branch'), position: _g(pickup), icon: _branch!, anchor: const Offset(0.5, 0.5)),
        if (dropoff != null && _door != null)
          gm.Marker(markerId: const gm.MarkerId('door'), position: _g(dropoff), icon: _door!, anchor: const Offset(0.5, 0.5)),
        if (courier != null && _courier != null)
          gm.Marker(
            markerId: const gm.MarkerId('courier'),
            position: _g(courier),
            icon: _courier!,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 2,
          ),
      },
      polylines: {
        if (from != null && to != null)
          gm.Polyline(
            polylineId: const gm.PolylineId('leg'),
            points: [_g(from), _g(to)],
            color: widget.tone.withValues(alpha: 0.6),
            width: 4,
            patterns: [gm.PatternItem.dot, gm.PatternItem.gap(10)],
          ),
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
    );
  }
}

/// A map mark drawn in the app's own hand — a disc with a ring and a glyph —
/// rendered once to an image the native map can place.
Future<gm.BitmapDescriptor> _markerIcon(
  IconData icon, {
  required Color ring,
  required Color fill,
  required double size,
  required double dpr,
  Color? glyph,
  Color? halo,
}) async {
  final px = size * dpr;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final c = Offset(px / 2, px / 2);
  var r = px / 2;
  if (halo != null) {
    canvas.drawCircle(c, r, Paint()..color = halo.withValues(alpha: 0.22));
    r *= 0.72;
  }
  canvas.drawCircle(c.translate(0, 1.5 * dpr), r, Paint()..color = Colors.black.withValues(alpha: 0.16));
  canvas.drawCircle(c, r, Paint()..color = fill);
  canvas.drawCircle(
    c,
    r - 1 * dpr,
    Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * dpr,
  );
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: r * 1.05, color: glyph ?? ring),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  final image = await recorder.endRecording().toImage(px.round(), px.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return gm.BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: dpr);
}
