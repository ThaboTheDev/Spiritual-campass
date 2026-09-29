import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';

/// The msamo screen's own state: the direction the user has frozen, if any.
class MsamoState {
  const MsamoState({this.lockedBearingDeg, this.lockedAt});

  /// Frozen true bearing in degrees, or `null` when following live readings.
  final double? lockedBearingDeg;

  /// When the direction was frozen.
  final DateTime? lockedAt;

  /// Whether a direction is frozen.
  bool get isLocked => lockedBearingDeg != null;

  MsamoState copyWith({
    double? lockedBearingDeg,
    DateTime? lockedAt,
    bool clear = false,
  }) {
    return MsamoState(
      lockedBearingDeg: clear ? null : (lockedBearingDeg ?? this.lockedBearingDeg),
      lockedAt: clear ? null : (lockedAt ?? this.lockedAt),
    );
  }
}

/// Freezes the required direction so the user can walk to the spot and mark it.
///
/// The locked bearing survives a restart (it is stored through
/// [PreferencesStore]) and is cleared by tapping "Unlock".
class MsamoController extends Notifier<MsamoState> {
  @override
  MsamoState build() {
    final double? stored = ref.watch(preferencesStoreProvider).lockedBearing;
    return MsamoState(lockedBearingDeg: stored);
  }

  /// Freezes [bearingDeg] (a true bearing).
  Future<void> lock(double bearingDeg) async {
    await ref.read(preferencesStoreProvider).saveLockedBearing(bearingDeg);
    state = MsamoState(lockedBearingDeg: bearingDeg, lockedAt: DateTime.now());
  }

  /// Goes back to live readings.
  Future<void> unlock() async {
    await ref.read(preferencesStoreProvider).saveLockedBearing(null);
    state = const MsamoState();
  }
}

/// The msamo state.
final NotifierProvider<MsamoController, MsamoState> msamoControllerProvider =
    NotifierProvider<MsamoController, MsamoState>(MsamoController.new);
