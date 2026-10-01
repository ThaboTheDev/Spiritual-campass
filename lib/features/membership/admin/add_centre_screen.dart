import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/constrained_content.dart';
import '../../../widgets/language_scope.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

/// `POST /api/admin/centres`: region, name, address, phone, latitude and
/// longitude. The centres list is refreshed on success so the new place
/// shows up straight away.
class AddCentreScreen extends ConsumerStatefulWidget {
  const AddCentreScreen({super.key});

  static const Key submitKey = Key('admin.addCentre.submit');

  @override
  ConsumerState<AddCentreScreen> createState() => _AddCentreScreenState();
}

class _AddCentreScreenState extends ConsumerState<AddCentreScreen> {
  final TextEditingController _region = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _lat = TextEditingController();
  final TextEditingController _lng = TextEditingController();

  /// Local validation, shown under the offending field.
  final Set<String> _missing = <String>{};

  @override
  void dispose() {
    _region.dispose();
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _submit() {
    final double? lat = double.tryParse(_lat.text.trim());
    final double? lng = double.tryParse(_lng.text.trim());
    final Set<String> missing = <String>{
      if (_region.text.trim().isEmpty) 'region',
      if (_name.text.trim().isEmpty) 'name',
      if (_address.text.trim().isEmpty) 'address',
      if (lat == null || lat < -90 || lat > 90) 'lat',
      if (lng == null || lng < -180 || lng > 180) 'lng',
    };
    setState(() {
      _missing
        ..clear()
        ..addAll(missing);
    });
    if (missing.isNotEmpty || lat == null || lng == null) {
      return;
    }
    ref.read(adminControllerProvider.notifier).addCentre(
          region: _region.text.trim(),
          name: _name.text.trim(),
          address: _address.text.trim(),
          phone: _phone.text.trim(),
          lat: lat,
          lng: lng,
        );
  }

  void _clearForm() {
    _region.clear();
    _name.clear();
    _address.clear();
    _phone.clear();
    _lat.clear();
    _lng.clear();
    setState(_missing.clear);
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final AdminState s = ref.watch(adminControllerProvider);
    final AdminController c = ref.read(adminControllerProvider.notifier);
    final String? added = s.addedCentre;

    // A centre added since the last build: confirm, then empty the form so
    // the next one can be typed.
    ref.listen<AdminState>(adminControllerProvider,
        (AdminState? before, AdminState after) {
      if (after.addedCentre != null && before?.addedCentre == null) {
        _clearForm();
      }
    });

    String? fieldError(String field) {
      final bool bad =
          _missing.contains(field) || s.invalidFields.contains(field);
      if (!bad) {
        return null;
      }
      switch (field) {
        case 'lat':
          return S.invalidLatitude.text;
        case 'lng':
          return S.invalidLongitude.text;
        default:
          return S.adminRequired.text;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(S.adminAddCentre.text)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AdminField(
                        controller: _region,
                        label: S.adminRegion,
                        enabled: !s.busy,
                        errorText: fieldError('region'),
                      ),
                      const SizedBox(height: 12),
                      AdminField(
                        controller: _name,
                        label: S.adminCentreName,
                        enabled: !s.busy,
                        errorText: fieldError('name'),
                      ),
                      const SizedBox(height: 12),
                      AdminField(
                        controller: _address,
                        label: S.adminAddress,
                        enabled: !s.busy,
                        maxLines: 2,
                        errorText: fieldError('address'),
                      ),
                      const SizedBox(height: 12),
                      AdminField(
                        controller: _phone,
                        label: S.adminPhone,
                        enabled: !s.busy,
                        keyboardType: TextInputType.phone,
                        errorText: fieldError('phone'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: AdminField(
                              controller: _lat,
                              label: S.latitude,
                              enabled: !s.busy,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              errorText: fieldError('lat'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminField(
                              controller: _lng,
                              label: S.longitude,
                              enabled: !s.busy,
                              textInputAction: TextInputAction.done,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              errorText: fieldError('lng'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        key: AddCentreScreen.submitKey,
                        label: S.adminAddCentre,
                        icon: Icons.save_outlined,
                        onPressed: s.busy ? null : _submit,
                        expand: true,
                      ),
                      if (s.busy) ...<Widget>[
                        const SizedBox(height: 12),
                        const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ],
                      if (added != null) ...<Widget>[
                        const SizedBox(height: 12),
                        InfoBanner(
                          message: S.adminCentreAdded(added),
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                          actionLabel: S.close,
                          onTap: c.dismiss,
                        ),
                      ],
                      AdminErrorBanner(error: s.error, onDismiss: c.dismiss),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
