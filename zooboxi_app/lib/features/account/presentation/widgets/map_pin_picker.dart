import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';

/// Riyadh — the fallback centre when there is no fix and no saved pin. Better
/// than dropping the customer in the middle of the ocean at zoom 2.
const LatLng _fallbackCentre = LatLng(24.7136, 46.6753);

/// The delivery pin: an OSM map with a pin fixed to the centre of the frame.
///
/// The pin does not move — the map does. A marker anchored to a coordinate
/// lags a frame behind the drag and reads as broken; a fixed overlay is always
/// exactly where the customer thinks they are pointing, and the coordinate is
/// simply read back off the camera.
///
/// [onMoved] fires while dragging (for a live pin shadow), [onSettled] fires
/// once the map has been still for a beat — that one is where the reverse
/// geocode belongs, so a single pan doesn't spend twenty requests.
class MapPinPicker extends StatefulWidget {
  const MapPinPicker({
    super.key,
    this.initial,
    this.onMoved,
    this.onSettled,
    this.height,
    this.interactive = true,
  });

  final LatLng? initial;
  final ValueChanged<LatLng>? onMoved;
  final ValueChanged<LatLng>? onSettled;
  final double? height;

  /// False renders a still preview of a chosen point.
  final bool interactive;

  @override
  State<MapPinPicker> createState() => MapPinPickerState();
}

class MapPinPickerState extends State<MapPinPicker> {
  final MapController _map = MapController();
  final Debouncer _settle = Debouncer(duration: const Duration(milliseconds: 550));

  late LatLng _centre = widget.initial ?? _fallbackCentre;
  bool _dragging = false;
  bool _locating = false;

  /// The coordinate currently under the pin.
  LatLng get value => _centre;

  @override
  void dispose() {
    _settle.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _centre = camera.center;
    widget.onMoved?.call(_centre);
    if (hasGesture && !_dragging) setState(() => _dragging = true);
    _settle.run(() {
      if (!mounted) return;
      setState(() => _dragging = false);
      widget.onSettled?.call(_centre);
    });
  }

  /// Centres on the device's own fix. Silent on refusal: the customer can
  /// always drag the map, so a permission dialog is a courtesy, not a gate.
  ///
  /// Public because the editor opens straight onto the map for a first-run
  /// customer and centres it for them — the same path as tapping the button.
  Future<void> locate() async {
    if (_locating) return;
    Haptics.light();
    setState(() => _locating = true);
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            ),
          );
          final point = LatLng(position.latitude, position.longitude);
          _map.move(point, 16.5);
          _centre = point;
          widget.onMoved?.call(point);
          widget.onSettled?.call(point);
        }
      }
    } catch (_) {
      // No fix available — the map still works by hand.
    }
    if (mounted) setState(() => _locating = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _centre,
        initialZoom: widget.initial == null ? 11 : 16,
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: cs.surfaceContainerHigh,
        onPositionChanged: widget.interactive ? _onPositionChanged : null,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              // Rotation on a delivery pin only ever confuses; everything else
              // (drag, pinch, double-tap) is how people expect a map to work.
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zooboxi.store',
          maxNativeZoom: 18,
        ),
      ],
    );

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(child: map),
          Positioned.fill(
            child: IgnorePointer(child: Center(child: _Pin(lifted: _dragging))),
          ),
          if (widget.interactive)
            PositionedDirectional(
              end: 12,
              bottom: 12,
              child: _MyLocationButton(busy: _locating, onTap: locate),
            ),
        ],
      ),
    );
  }
}

/// The pin itself, with a shadow that separates from the tip while the map is
/// moving — the small "it's in the air" cue that makes dragging feel physical.
class _Pin extends StatelessWidget {
  const _Pin({required this.lifted});

  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final lift = lifted && !MediaQuery.disableAnimationsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSlide(
          offset: Offset(0, lift ? -0.22 : 0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          // Half the pin's height, so the tip — not the middle — sits on the
          // coordinate the camera reports.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 34),
            child: Icon(
              Icons.location_on_rounded,
              size: 44,
              color: cs.primary,
              shadows: [
                Shadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10),
              ],
            ),
          ),
        ),
        AnimatedScale(
          scale: lift ? 0.7 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 12,
            height: 5,
            margin: const EdgeInsets.only(bottom: 28),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Material(
      color: cs.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Icon(Icons.my_location_rounded, size: 17, color: cs.primary),
              Gap.w8,
              Text(
                L.of(context).addressPinUseGps,
                style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
