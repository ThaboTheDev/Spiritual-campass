import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens the platform maps app, dials a centre, or opens a web page.
///
/// Apple Maps is used on iOS and Google Maps on Android, with a Google Maps web
/// fallback if the native app is not available.
abstract final class NavigationLauncher {
  /// Opens turn-by-turn directions to [latitude] / [longitude].
  ///
  /// [label] is the name shown at the destination (a centre name, usually).
  static Future<bool> openDirections({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final String destination = '$latitude,$longitude';
    final String encodedLabel =
        label == null ? '' : '&q=${Uri.encodeComponent(label)}';

    final Uri appleMaps = Uri.parse(
      'https://maps.apple.com/?daddr=$destination$encodedLabel',
    );
    final Uri googleMaps = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination'
          '$encodedLabel',
    );

    if (Platform.isIOS) {
      final bool opened = await _launch(appleMaps);
      if (opened) {
        return true;
      }
      return _launch(googleMaps);
    }
    final bool opened = await _launch(googleMaps);
    if (opened) {
      return true;
    }
    return _launch(appleMaps);
  }

  /// Shows [latitude] / [longitude] on the map without starting navigation.
  static Future<bool> openMap({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    final String query =
        label == null ? '' : '&q=${Uri.encodeComponent(label)}';
    return Platform.isIOS
        ? _launch(Uri.parse(
            'https://maps.apple.com/?ll=$latitude,$longitude$query',
          ))
        : _launch(Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$latitude,'
                '$longitude$query',
          ));
  }

  /// Dials [phone], e.g. "+27 67 300 3886".
  static Future<bool> call(String phone) {
    final String digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return _launch(Uri.parse('tel:$digits'));
  }

  /// Opens a normal https URL.
  static Future<bool> openWeb(String url) => _launch(Uri.parse(url));

  static Future<bool> _launch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      // Some schemes are not reported as launchable; try anyway so the platform
      // can offer its own picker.
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
