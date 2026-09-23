import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// The delivery map's look, in Zooboxi's own colours.
///
/// Google's default map is a reference map — every shop, pin and bus stop in
/// the same shout. On a screen whose only question is «which door is yours»,
/// that noise competes with the one thing that matters, so: cream land, white
/// streets with a warm edge, the highways in the logo's peach, water in teal
/// tint, the points of interest switched off, and the district names in teal —
/// they are what a Riyadh customer reads first. The graphite style is the same
/// map for the dark theme, not an inverted one.
abstract final class ZbMapStyle {
  static String of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static final String light = jsonEncode([
    _s('all', 'labels.text.fill', color: '#5c6b5c'),
    _s('all', 'labels.text.stroke', color: '#ffffff', weight: 3),
    _s('landscape', null, color: '#f6f3ec'),
    _s('landscape.man_made', null, color: '#f1ede4'),
    _s('water', null, color: '#bfe0de'),
    _off('poi'),
    _s('poi.park', null, color: '#dcebdc', visible: true),
    _off('poi.park', 'labels'),
    _off('transit'),
    _s('road', 'geometry', color: '#ffffff'),
    _s('road', 'geometry.stroke', color: '#e2dccf'),
    _s('road.highway', 'geometry', color: '#f7ddc7'),
    _s('road.highway', 'geometry.stroke', color: '#e9c9a0'),
    _off('road', 'labels.icon'),
    _s('administrative.neighborhood', 'labels.text.fill', color: '#2d7a79'),
  ]);

  static final String dark = jsonEncode([
    _s('all', 'labels.text.fill', color: '#a3afaa'),
    _s('all', 'labels.text.stroke', color: '#121615', weight: 3),
    _s('landscape', null, color: '#1a201e'),
    _s('water', null, color: '#19403f'),
    _off('poi'),
    _s('poi.park', null, color: '#1f2a24', visible: true),
    _off('poi.park', 'labels'),
    _off('transit'),
    _s('road', 'geometry', color: '#2c3533'),
    _s('road', 'geometry.stroke', color: '#232a28'),
    _s('road.highway', 'geometry', color: '#3b3226'),
    _off('road', 'labels.icon'),
    _s('administrative.neighborhood', 'labels.text.fill', color: '#5fc0be'),
  ]);

  /// Whether a real map can be drawn here. `flutter test` has no platform
  /// views, so tests get a quiet placeholder instead of a Google map.
  static final bool live = !Platform.environment.containsKey('FLUTTER_TEST');

  static Map<String, Object> _s(String feature, String? element, {String? color, int? weight, bool? visible}) => {
        'featureType': feature,
        'elementType': ?element,
        'stylers': [
          if (visible == true) {'visibility': 'on'},
          if (color != null) {'color': color},
          if (weight != null) {'weight': weight},
        ],
      };

  static Map<String, Object> _off(String feature, [String? element]) => {
        'featureType': feature,
        'elementType': ?element,
        'stylers': [
          {'visibility': 'off'},
        ],
      };
}
