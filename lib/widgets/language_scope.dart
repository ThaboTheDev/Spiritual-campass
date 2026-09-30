import 'package:flutter/widgets.dart';

import '../core/l10n/app_language.dart';

/// Rebuilds its dependants when the secondary language changes.
///
/// Placed once at the root of the app (see `TshkApp`). Bilingual widgets call
/// [LanguageScope.watch] in `build` so that switching languages updates every
/// label in place, without recreating the screens or the running compass.
class LanguageScope extends InheritedNotifier<ValueNotifier<AppLanguage>> {
  LanguageScope({super.key, required super.child})
      : super(notifier: L10n.notifier);

  /// Registers a dependency and returns the active secondary language.
  ///
  /// Safe to call without a scope (tests, previews): it then just returns
  /// the current language.
  static AppLanguage watch(BuildContext context) {
    final LanguageScope? scope =
        context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    return scope?.notifier?.value ?? L10n.language;
  }
}
