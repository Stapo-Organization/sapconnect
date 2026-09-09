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

/// What the map is made of.
///
/// The plain OSM style is a *reference* map — every clinic, mosque and bus
/// stop shouted in the same weight. On a screen whose only question is "which
/// door is yours", that noise competes with the one thing that matters. So:
///
///  * [streets] is CARTO's muted basemap — the same OpenStreetMap data, drawn
///    quiet, in near-greys, with a real dark twin instead of an inverted
///    filter — the teal pin is then the only saturated thing on the screen;
///  * [satellite] is the imagery, because a Riyadh compound is recognised by
///    its roof and its walls long before it is recognised by a street name.
enum MapStyle { streets, satellite }

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
  /// map — the address card at the bottom, a hint capsule at the top.
  final EdgeInsets controlsPadding;

  @override
  State<MapPinPicker> createState() => MapPinPickerState();
}

class MapPinPickerState extends State<MapPinPicker> with TickerProviderStateMixin {
  final MapController _map = MapController();
  final Debouncer _settle = Debouncer(duration: const Duration(milliseconds: 550));

  late LatLng _centre = widget.initial ?? _fallbackCentre;
  late double _zoom = widget.initial == null ? 11 : 16;
  late MapStyle _style = widget.style;
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
    _zoom = camera.zoom;
    widget.onMoved?.call(_centre);
    if (hasGesture && !_dragging) setState(() => _dragging = true);
    _settle.run(() {
      if (!mounted) return;
      setState(() => _dragging = false);
      widget.onSettled?.call(_centre);
    });
  }

  /// A step of zoom from the buttons, animated by hand: a map that jumps a
  /// whole level in one frame loses the customer's place on it.
  void _zoomBy(double delta) {
    final target = (_zoom + delta).clamp(4.0, 18.0);
    if (target == _zoom) return;
    Haptics.selection();
    _animateTo(_centre, target);
  }

  void _animateTo(LatLng point, double zoom) {
    final fromZoom = _zoom;
    final from = _centre;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    curve.addListener(() {
      final t = curve.value;
      _map.move(
        LatLng(
          from.latitude + (point.latitude - from.latitude) * t,
          from.longitude + (point.longitude - from.longitude) * t,
        ),
        fromZoom + (zoom - fromZoom) * t,
      );
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        curve.dispose();
        controller.dispose();
      }
    });
    controller.forward();
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
          if (!mounted) return;
          _animateTo(point, 16.5);
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
    final dark = context.isDark;

    final satellite = _style == MapStyle.satellite;
    // Imagery is imagery in both themes; only the drawn map has a night face.
    final streetsUrl = dark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    final tiles = satellite
        ? TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.zooboxi.app',
            maxNativeZoom: 18,
          )
        : TileLayer(
            urlTemplate: streetsUrl,
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.zooboxi.app',
            maxNativeZoom: 20,
            // The {r} in the URL: a phone screen asks for the @2x tile, so
            // street names are crisp instead of the soft upscale the customer
            // reads as "cheap map".
            retinaMode: RetinaMode.isHighDensity(context),
          );

    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _centre,
        initialZoom: _zoom,
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
      children: [tiles],
    );

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(child: map),
          Positioned.fill(
            child: IgnorePointer(
              // A preview strip can be shorter than the pin is tall; letting it
              // overflow into the clip is right, an overflow error is not.
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
          // Whoever drew the tiles gets named on them — a licence term, and
          // the cheapest kind of trust: this map is a real map.
          PositionedDirectional(
            start: 6,
            bottom: widget.controlsPadding.bottom + 4,
            child: _Attribution(style: _style),
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
                        setState(() => _style = satellite
                            ? MapStyle.streets
                            : MapStyle.satellite);
                      },
                    ),
                    Gap.h12,
                  ],
                  if (widget.showZoom) ...[
                    _ZoomStack(
                      onIn: () => _zoomBy(1),
                      onOut: () => _zoomBy(-1),
                    ),
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

/// The credit line the tiles are used under — OpenStreetMap and CARTO for the
/// drawn map, Esri and its imagery partners for the satellite.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.style});

  final MapStyle style;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final credit = style == MapStyle.satellite
        ? 'Esri · Maxar'
        : '© OpenStreetMap · CARTO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Text(
        credit,
        textDirection: TextDirection.ltr,
        style: context.tt.labelSmall?.copyWith(
          fontSize: 9.5,
          color: cs.onSurfaceVariant,
        ),
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
