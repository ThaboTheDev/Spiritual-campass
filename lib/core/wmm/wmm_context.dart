import '../geo/coordinates.dart';
import '../geo/geo_math.dart';
import 'wmm.dart';

class MagneticContext {
  const MagneticContext({required this.modelValid, this.field});
  final bool modelValid;
  final MagneticField? field;
  double? get declinationDeg =>
      modelValid && field != null && !field!.inBlackoutZone
      ? field!.declinationDeg
      : null;
}

/// Keep spherical harmonics out of the per-sample / per-GPS-fix path. A 100 m
/// move, 100 m altitude change or UTC date change refreshes the field. This
/// cache is shared by the controller, readouts and source diagnostics.
class WmmContextCache {
  GeoPoint? _point;
  DateTime? _day;
  MagneticField? _field;

  MagneticContext evaluate(GeoPoint? point, DateTime when) {
    final bool valid = Wmm2025.isValidAt(when);
    if (point == null || !point.isValid || !valid) {
      return MagneticContext(modelValid: valid);
    }
    final DateTime utc = when.toUtc();
    final DateTime day = DateTime.utc(utc.year, utc.month, utc.day);
    if (_point == null ||
        _day != day ||
        GeoMath.distanceBetweenKm(_point!, point) >= 0.1 ||
        (_point!.altitudeKm - point.altitudeKm).abs() >= 0.1) {
      _point = point;
      _day = day;
      _field = Wmm2025.field(
        latitudeDeg: point.latitude,
        longitudeDeg: point.longitude,
        altitudeKm: point.altitudeKm,
        when: when,
      );
    }
    return MagneticContext(modelValid: valid, field: _field);
  }
}
