import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/maps/map_style.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';

/// Riyadh — the fallback centre when there is no fix and no saved pin. Better
/// than dropping the customer in the middle of the ocean at zoom 2.
const LatLng _fallbackCentre = LatLng(24.7136, 46.6753);

/// What the map is made of.
///
///  * [streets] is Google's map in Zooboxi's own colours (see [ZbMapStyle]):
///    Arabic street and district names, no shop pins shouting over the door —
///    the teal pin is the only saturated thing on the screen;
///  * [satellite] is the imagery with the names on it, because a Riyadh
///    compound is recognised by its roof and its walls long before it is
///    recognised by a street name.
enum MapStyle { streets, satellite }

/// The delivery pin: a map with a pin fixed to the centre of the frame.
///
/// The pin does not move — the map does. A marker anchored to a coordinate
/// lags a frame behind the drag and reads as broken; a fixed overlay is always
/// exactly where the customer thinks they are pointing, and the coordinate is
/// simply read back off the camera.
///
/// [onMoved] fires while dragging (for a live pin shadow), [onSettled] fires
/// once the camera comes to rest — that one is where the reverse geocode
/// belongs, so a single pan doesn't spend twenty requests.
class MapPinPicker extends StatefulWidget {
  const MapPinPicker({
    super.key,
    this.initial,
    this.onMoved,
    this.onSettled,
    this.height,
    this.interactive = true,
    this.showZoom = true,
    this.showStyleSwitch = true,
    this.style = MapStyle.streets,
    this.controlsPadding = EdgeInsets.zero,
  });

  final LatLng? initial;
  final ValueChanged<LatLng>? onMoved;
  final ValueChanged<LatLng>? onSettled;
  final double? height;

  /// False renders a still preview of a chosen point.
  final bool interactive;

  /// The +/− column. Pinching works regardless; the buttons are for the hand
  /// that is holding a phone and a dog lead at the same time.
  final bool showZoom;

  /// The خريطة/قمر-صناعي switch. Off for the still previews, which are a
  /// statement about a point rather than a place to look around in.
  final bool showStyleSwitch;

  /// What the map opens as.
  final MapStyle style;

  /// Keeps the floating controls clear of whatever the screen lays over the
  /// map — the address card at the bottom, the search bar at the top.
  final EdgeInsets controlsPadding;

  @override
  State<MapPinPicker> createState() => MapPinPickerState();
}

class MapPinPickerState extends State<MapPinPicker> {
  gm.GoogleMapController? _map;

  late LatLng _centre = widget.initial ?? _fallbackCentre;
  late double _zoom = widget.initial == null ? 11 : 16.5;
  late MapStyle _style = widget.style;
  bool _dragging = false;
  bool _locating = false;

  /// The coordinate currently under the pin.
  LatLng get value => _centre;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  static gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);

  void _onCameraMove(gm.CameraPosition position) {
    _centre = LatLng(position.target.latitude, position.target.longitude);
    _zoom = position.zoom;
    widget.onMoved?.call(_centre);
    if (!_dragging) setState(() => _dragging = true);
  }

  void _onCameraIdle() {
    if (!mounted) return;
    if (_dragging) setState(() => _dragging = false);
    widget.onSettled?.call(_centre);
  }

  void _zoomBy(double delta) {
    final target = (_zoom + delta).clamp(4.0, 20.0);
    if (target == _zoom) return;
    Haptics.selection();
    _map?.animateCamera(gm.CameraUpdate.zoomTo(target));
  }

  /// Flies the pin to [point] — a search result, the device's own fix. The
  /// settle that follows is what asks the store about it.
  Future<void> moveTo(LatLng point, {double zoom = 17}) async {
    final map = _map;
    if (map == null) {
      setState(() {
        _centre = point;
        _zoom = zoom;
      });
      widget.onSettled?.call(point);
      return;
    }
    await map.animateCamera(gm.CameraUpdate.newLatLngZoom(_g(point), zoom));
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
          if (!mounted) return;
          await moveTo(LatLng(position.latitude, position.longitude), zoom: 17);
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
    final satellite = _style == MapStyle.satellite;

    final Widget map = ZbMapStyle.live
        ? gm.GoogleMap(
            initialCameraPosition: gm.CameraPosition(target: _g(_centre), zoom: _zoom),
            onMapCreated: (controller) => _map = controller,
            onCameraMove: widget.interactive ? _onCameraMove : null,
            onCameraIdle: widget.interactive ? _onCameraIdle : null,
            mapType: satellite ? gm.MapType.hybrid : gm.MapType.normal,
            style: satellite ? null : ZbMapStyle.of(context),
            // The screen draws its own controls; Google's would stack on ours.
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            indoorViewEnabled: false,
            buildingsEnabled: true,
            // Rotation and tilt on a delivery pin only ever confuse.
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            scrollGesturesEnabled: widget.interactive,
            zoomGesturesEnabled: widget.interactive,
            // A still preview is a picture of a point, drawn once.
            liteModeEnabled: !widget.interactive,
            padding: widget.controlsPadding,
          )
        : ColoredBox(color: cs.surfaceContainerHigh);

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(child: map),
          Positioned.fill(
            child: IgnorePointer(
              // The map's padding moves the camera's centre to the middle of the
              // unpadded area — the pin has to stand exactly there, or the
              // coordinate read off the camera is not the one under the pin.
              child: Padding(
                padding: widget.controlsPadding,
                // A preview strip can be shorter than the pin is tall; letting
                // it overflow into the clip is right, an overflow error is not.
                child: Center(
                child: OverflowBox(
                  maxHeight: double.infinity,
                  child: _Pin(
                    lifted: _dragging,
                    compact: (widget.height ?? double.infinity) < 160,
                  ),
                ),
              ),
              ),
            ),
          ),
          if (widget.interactive)
            PositionedDirectional(
              end: 12,
              bottom: widget.controlsPadding.bottom + 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showStyleSwitch) ...[
                    _StyleButton(
                      style: _style,
                      onTap: () {
                        Haptics.selection();
                        setState(() => _style = satellite ? MapStyle.streets : MapStyle.satellite);
                      },
                    ),
                    Gap.h12,
                  ],
                  if (widget.showZoom) ...[
                    _ZoomStack(onIn: () => _zoomBy(1), onOut: () => _zoomBy(-1)),
                    Gap.h12,
                  ],
                  _LocateButton(busy: _locating, onTap: locate),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The pin, drawn so that **its tip is the coordinate**.
///
/// The previous build stacked the pin and its ground mark in a column and
/// centred the column, which put the tip about fifteen points above the point
/// the camera reports and the mark twenty-five below it — the customer aimed
/// at their door and the store was told about the neighbour's.
///
/// So the geometry is stated instead of inferred: the ground mark is centred
/// on the map's exact centre, and the pin is lifted by its own height so that
/// its tip comes down on that mark. Dragging floats it a few points clear —
/// the "it's in the air" cue — and the mark stays put, because the mark *is*
/// the address.
class _Pin extends StatelessWidget {
  const _Pin({required this.lifted, this.compact = false});

  final bool lifted;

  /// Sized for a preview strip rather than a full map, where the full pin
  /// would be taller than the picture it stands on.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final lift = lifted && !MediaQuery.disableAnimationsOf(context);
    final size = compact ? 30.0 : 44.0;

    // Material's location glyph does not fill its box: the tip sits at about
    // 46% below the box centre. Lifting by that much — not by half the icon —
    // is what puts the point of the pin on the point of the map.
    final rest = size * 0.46;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // The ground mark, exactly on the coordinate.
          AnimatedScale(
            scale: lift ? 0.65 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Container(
              width: 12,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            bottom: lift ? rest + 9 : rest,
            child: Icon(
              Icons.location_on_rounded,
              size: size,
              color: cs.primary,
              shadows: [
                Shadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The + / − column, as one card split by a hairline.
class _ZoomStack extends StatelessWidget {
  const _ZoomStack({required this.onIn, required this.onOut});

  final VoidCallback onIn;
  final VoidCallback onOut;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return _MapCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapIconButton(
            icon: Icons.add_rounded,
            tooltip: l.mapZoomIn,
            onTap: onIn,
            radius: const BorderRadius.vertical(top: Radius.circular(ZbTokens.rMd)),
          ),
          Container(width: 24, height: 1, color: cs.outlineVariant),
          _MapIconButton(
            icon: Icons.remove_rounded,
            tooltip: l.mapZoomOut,
            onTap: onOut,
            radius: const BorderRadius.vertical(bottom: Radius.circular(ZbTokens.rMd)),
          ),
        ],
      ),
    );
  }
}

/// خريطة ↔ قمر صناعي.
///
/// Half of Riyadh is addressed by what a place looks like from above — the
/// villa with the two palms, the third gate on the compound wall. A street map
/// cannot say that and imagery cannot say a street name, so the customer keeps
/// the switch rather than the app choosing for them.
class _StyleButton extends StatelessWidget {
  const _StyleButton({required this.style, required this.onTap});

  final MapStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final satellite = style == MapStyle.satellite;
    return _MapCard(
      child: _MapIconButton(
        // The button shows what it switches *to*, the way a mirrored control
        // never does.
        icon: satellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
        tooltip: satellite ? l.mapStyleStreets : l.mapStyleSatellite,
        onTap: onTap,
        radius: BorderRadius.circular(ZbTokens.rMd),
      ),
    );
  }
}

/// "Take me to where I am" — the crosshair every map app has trained people
/// to look for, in the corner they look for it.
class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _MapCard(
      child: _MapIconButton(
        icon: Icons.my_location_rounded,
        tooltip: l.addressPinUseGps,
        onTap: busy ? null : onTap,
        busy: busy,
        tinted: true,
        radius: BorderRadius.circular(ZbTokens.rMd),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.radius,
    this.busy = false,
    this.tinted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final bool busy;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Icon(
                        icon,
                        size: 21,
                        color: tinted ? cs.primary : cs.onSurface,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
