import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/l10n/app_language.dart';

/// Owns the app-language choice (English, isiZulu, Português, Chichewa or
/// iciBemba); the chosen language replaces all text in the app.
///
/// Order of precedence: the persisted choice → a suggestion from the device
/// locale → English. The choice is pushed into [L10n] so every `Bi` resolves
/// against it, and persisted through the preferences store.
class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final String? stored = ref.watch(preferencesStoreProvider).languageCode;
    final AppLanguage language = stored != null
        ? AppLanguage.fromCode(stored)
        : suggestFromDevice();
    L10n.setLanguage(language);
    return language;
  }

  /// Switches the app language and persists it.
  Future<void> set(AppLanguage language) async {
    L10n.setLanguage(language);
    state = language;
    await ref.read(preferencesStoreProvider).saveLanguageCode(language.code);
  }

  /// The language the device locale suggests (never persisted by itself).
  static AppLanguage suggestFromDevice() {
    try {
      final Locale locale = PlatformDispatcher.instance.locale;
      return AppLanguage.suggest(
        languageCode: locale.languageCode,
        countryCode: locale.countryCode,
      );
    } catch (_) {
      return AppLanguage.fallback;
    }
  }
}

/// The active app language.
final NotifierProvider<LanguageController, AppLanguage> languageProvider =
    NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);
