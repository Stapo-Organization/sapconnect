import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// The one place the app says where its map tiles come from.
///
/// CARTO's basemaps — which build 9 through 24 used — began stamping every
/// tile with «API KEY REQUIRED» for unkeyed traffic. A map that shouts that
/// across a customer's street cannot ship, and two screens drew it: the
/// delivery pin and the courier card. So the source lives here, once, and a
/// change of provider is a change of one file.
///
/// Esri's World Street Map is keyless, names Riyadh's streets in Arabic, and
/// is the same host that already serves the satellite layer — one provider,
/// one set of terms, one attribution line to keep honest.
abstract final class ZbTiles {
  static const String _agent = 'com.zooboxi.app';

  static const String _streets =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
  static const String _imagery =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  /// Esri's raster style is painted for daylight; in the app's graphite theme
  /// a white map is the one thing on screen that glares. Inverting luminance
  /// keeps every road and label where it was, in greys, and because the filter
  /// wraps the tiles only, whatever is drawn on top keeps its own colour.
  static const ColorFilter _night = ColorFilter.matrix(<double>[
    -0.2126, -0.7152, -0.0722, 0, 255, //
    -0.2126, -0.7152, -0.0722, 0, 255, //
    -0.2126, -0.7152, -0.0722, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);

  /// The drawn map, dark-aware.
  static Widget streets(BuildContext context) {
    final layer = TileLayer(
      urlTemplate: _streets,
      userAgentPackageName: _agent,
      maxNativeZoom: 19,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? ColorFiltered(colorFilter: _night, child: layer) : layer;
  }

  /// Imagery is imagery in both themes.
  static Widget satellite() => TileLayer(
        urlTemplate: _imagery,
        userAgentPackageName: _agent,
        maxNativeZoom: 19,
      );

  static String creditFor({required bool satellite}) =>
      satellite ? 'Esri · Maxar' : 'Esri · HERE · OpenStreetMap';
}
