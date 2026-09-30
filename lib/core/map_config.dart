import 'package:flutter/material.dart';

/// Centralised configuration for map tile providers and styling.
///
/// Easily switch between OpenStreetMap and keyed providers (MapTiler, Stadia Maps, etc.).
final class MapConfig {
  const MapConfig._();

  /// Primary tile URL template (OpenStreetMap standard raster tiles).
  ///
  /// No API key required.
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Optional API key for keyed tile services.
  ///
  /// Read from this constant rather than hard-coded inline.
  static const String apiKey = '';

  // ---------------------------------------------------------------------------
  // Commented examples of keyed tile providers:
  //
  // MapTiler dark tiles example (replace MapConfig.apiKey with your key):
  // static const String tileUrlTemplate =
  //     'https://api.maptiler.com/maps/basic-v2-dark/{z}/{x}/{y}.png?key=$apiKey';
  //
  // Stadia Maps Alidade Smooth Dark example:
  // static const String tileUrlTemplate =
  //     'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png?api_key=$apiKey';
  // ---------------------------------------------------------------------------

  /// The application package name required by OpenStreetMap's Tile Usage Policy
  /// in the HTTP User-Agent header to avoid request blocking.
  ///
  /// Matches Android applicationId (`com.tshk.tshk_compass`) and iOS bundle ID (`com.tshk.tshkCompass`).
  static const String userAgentPackageName = 'com.tshk.tshk_compass';

  /// Maximum native zoom level supported by the tile layer.
  static const int maxNativeZoom = 19;

  /// OpenStreetMap copyright and attribution text (English; the map shows
  /// the localised `S.attribution`).
  static const String osmAttributionText = '© OpenStreetMap contributors';

  /// OpenStreetMap copyright information URL.
  static const String osmAttributionUrl =
      'https://www.openstreetmap.org/copyright';

  /// Invert-and-darken colour matrix to style standard light OSM raster tiles
  /// into a dark theme that matches the app's `#0f131c` palette.
  ///
  /// Matrix transformation:
  /// 1. Inverts RGB colors: `R' = 255 - R`, `G' = 255 - G`, `B' = 255 - B`
  /// 2. Scales luminance down (~0.75-0.78x) and shifts base black towards `#0f131c` (~15, 19, 28)
  static const ColorFilter darkMapFilter = ColorFilter.matrix(<double>[
    -0.78,  0.00,  0.00, 0.00, 210.0,
     0.00, -0.78,  0.00, 0.00, 210.0,
     0.00,  0.00, -0.75, 0.00, 215.0,
     0.00,  0.00,  0.00, 1.00,   0.0,
  ]);
}
