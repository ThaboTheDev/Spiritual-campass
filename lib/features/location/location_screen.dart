import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/geo/coordinates.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/centre.dart';
import '../../data/models/town.dart';
import '../../data/repositories/location_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header.dart';
import '../../widgets/localized_text.dart';
import '../../widgets/cards.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/language_scope.dart';
import '../centres/centres_providers.dart';
import '../towns/town_picker_sheet.dart';
import 'location_controller.dart';

/// The Location tab: live GPS, a manual override, and picking a centre.
class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  // Kept as `Bi` values (not resolved text) so a language switch while an
  // error is showing re-renders it in the new language.
  Bi? _latitudeError;
  Bi? _longitudeError;

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final LocationState location = ref.watch(locationControllerProvider);
    final GeoPoint? point = location.effectivePoint;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 16),
              const AppHeader(),
              const SizedBox(height: 16),

              // Current position.
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    LocalizedText(
                      S.currentPosition,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      point == null ? '—' : Formatters.geoPoint(point),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: point == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DetailRow(
                      label: S.accuracy,
                      value: point == null
                          ? '—'
                          : Formatters.accuracyMetres(point.accuracyMetres),
                    ),
                    const SizedBox(height: 4),
                    _DetailRow(
                      label: S.altitude,
                      value: Formatters.altitudeMetres(point?.altitudeMetres),
                    ),
                    const SizedBox(height: 4),
                    _DetailRow(
                      label: S.source,
                      value: location.isManual
                          ? S.sourceManual.text
                          : (point == null ? '—' : S.sourceGps.text),
                    ),
                    if (point?.label != null) ...<Widget>[
                      const SizedBox(height: 4),
                      _DetailRow(
                        label: S.place,
                        value: _placeLabel(point!.label!),
                      ),
                    ],
                    if (location.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        S.locationError.text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_needsHelp(location)) ...<Widget>[
                InfoBanner(
                  message: switch (location.access) {
                    LocationAccess.serviceDisabled => S.locationServicesOff,
                    LocationAccess.deniedForever => S.permissionDeniedForever,
                    LocationAccess.denied => S.permissionDenied,
                    _ => S.permissionNeeded,
                  },
                  icon: Icons.location_off_outlined,
                  color: AppColors.warning,
                  actionLabel: S.openSettings,
                  onTap: () => ref
                      .read(locationControllerProvider.notifier)
                      .openSettings(),
                ),
                const SizedBox(height: 12),
              ],

              if (location.isManual) ...<Widget>[
                const InfoBanner(
                  message: S.manualInUse,
                  icon: Icons.push_pin_outlined,
                  color: AppColors.gold,
                ),
                const SizedBox(height: 12),
              ],

              // Actions.
              AppButton(
                label: location.loading ? S.locate : S.useMyLocation,
                icon: Icons.my_location_rounded,
                onPressed:
                    location.loading ? null : () => _useMyLocation(context),
                expand: true,
              ),
              if (location.isManual) ...<Widget>[
                const SizedBox(height: 10),
                AppButton(
                  label: S.returnToGps,
                  icon: Icons.gps_fixed_rounded,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => _returnToGps(context),
                  expand: true,
                ),
              ],
              const SizedBox(height: 20),

              // Manual entry.
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    LocalizedText(
                      S.enterManually,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    LocalizedText(
                      S.manualNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CoordinateField(
                      controller: _latitudeController,
                      label: S.latitude,
                      hint: '-26.2041',
                      errorText: _latitudeError?.text,
                    ),
                    const SizedBox(height: 10),
                    _CoordinateField(
                      controller: _longitudeController,
                      label: S.longitude,
                      hint: '28.0473',
                      errorText: _longitudeError?.text,
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: S.save,
                      icon: Icons.save_outlined,
                      onPressed: () => _saveManual(context),
                      expand: true,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: S.pickTown,
                      icon: Icons.location_city_outlined,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => _pickTown(context),
                      expand: true,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: S.pickFromCentres,
                      icon: Icons.map_outlined,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => _pickFromCentres(context),
                      expand: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Labels saved by this screen are stored as stable tokens and shown in
  /// the app language; town and centre names are shown as they are.
  String _placeLabel(String label) {
    if (label == _manualLabel || label == _legacyManualLabel) {
      return S.manualEntry.text;
    }
    return label;
  }

  /// Stored with coordinates typed in by hand (a token, not display text).
  static const String _manualLabel = 'Manual entry';

  /// Older builds stored this on the point itself.
  static const String _legacyManualLabel = 'Manual';

  bool _needsHelp(LocationState location) {
    if (location.hasPoint) {
      return false;
    }
    return location.access == LocationAccess.denied ||
        location.access == LocationAccess.deniedForever ||
        location.access == LocationAccess.serviceDisabled;
  }

  Future<void> _useMyLocation(BuildContext context) async {
    final LocationAccess access =
        await ref.read(locationControllerProvider.notifier).startTracking();
    if (!context.mounted) {
      return;
    }
    if (access == LocationAccess.whileInUse || access == LocationAccess.always) {
      _snack(context, S.sourceGps.text);
    }
  }

  Future<void> _returnToGps(BuildContext context) async {
    await ref.read(locationControllerProvider.notifier).useLiveGps();
    if (!context.mounted) {
      return;
    }
    _snack(context, S.useMyLocation.text);
  }

  void _saveManual(BuildContext context) {
    final double? latitude = _parse(_latitudeController.text);
    final double? longitude = _parse(_longitudeController.text);

    setState(() {
      _latitudeError = (latitude == null || latitude.abs() > 90)
          ? S.invalidLatitude
          : null;
      _longitudeError = (longitude == null || longitude.abs() > 180)
          ? S.invalidLongitude
          : null;
    });

    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return;
    }

    final GeoPoint point = GeoPoint(
      latitude: latitude,
      longitude: longitude,
      altitudeMetres: Ekuphumuleni.fallbackAltitudeMetres,
      label: _manualLabel,
    );
    ref
        .read(locationControllerProvider.notifier)
        .useManualLocation(point, label: _manualLabel);
    _snack(context, S.saved.text);
  }

  Future<void> _pickTown(BuildContext context) async {
    final Town? town = await showTownPicker(context);
    if (town == null || !context.mounted) {
      return;
    }
    await ref
        .read(locationControllerProvider.notifier)
        .useManualLocation(town.point, label: town.name);
    if (!context.mounted) {
      return;
    }
    _snack(context, S.savedNamed(town.name).text);
  }

  Future<void> _pickFromCentres(BuildContext context) async {
    List<Centre> centres = <Centre>[];
    try {
      final List<Centre> loaded = await ref.read(centresProvider.future);
      centres =
          loaded.where((Centre centre) => centre.hasCoordinates).toList();
    } catch (_) {
      centres = <Centre>[];
    }

    if (!context.mounted) {
      return;
    }
    if (centres.isEmpty) {
      _snack(context, S.centresFailed.text);
      return;
    }

    final Centre? chosen = await showModalBottomSheet<Centre>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (BuildContext context, ScrollController controller) => Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: LocalizedText(
                S.pickFromCentres,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: centres.length,
                itemBuilder: (BuildContext context, int index) {
                  final Centre centre = centres[index];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined,
                        color: AppColors.accent),
                    title: Text(
                      centre.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      centre.hasAddress ? centre.address : centre.region,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(centre),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen == null || !context.mounted) {
      return;
    }
    await ref
        .read(locationControllerProvider.notifier)
        .useManualLocation(chosen.point!, label: chosen.name);
    if (!context.mounted) {
      return;
    }
    _snack(context, S.savedNamed(chosen.name).text);
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Accepts "26.2", "-26,2" and the unicode minus "−26.2".
  double? _parse(String value) {
    final String normalised =
        value.replaceAll('−', '-').replaceAll(',', '.').trim();
    if (normalised.isEmpty) {
      return null;
    }
    return double.tryParse(normalised);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final Bi label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        SizedBox(
          width: 96,
          child: LocalizedText(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
            maxLines: 1,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoordinateField extends StatelessWidget {
  const _CoordinateField({
    required this.controller,
    required this.label,
    required this.hint,
    this.errorText,
  });

  final TextEditingController controller;
  final Bi label;
  final String hint;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LocalizedText(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            isDense: true,
          ),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
