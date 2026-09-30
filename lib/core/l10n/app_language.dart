import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

/// The languages the whole app can be shown in.
///
/// The chosen language replaces *all* text in the app (tabs, buttons, readouts,
/// messages, accessibility labels). English and isiZulu are authored in code
/// (`S.*` in `strings.dart`); Portuguese, Chichewa and Bemba come from
/// `assets/translations.json`. Codes match the top-level keys of that file.
enum AppLanguage {
  en('en', 'English', <String>['en']),
  zu('zu', 'isiZulu', <String>['zu']),
  pt('pt', 'Português', <String>['pt']),
  ny('ny', 'Chichewa', <String>['ny', 'nya']),
  bem('bem', 'iciBemba', <String>['bem']);

  const AppLanguage(this.code, this.nativeName, this.localeCodes);

  /// Key in `translations.json` and the value persisted in preferences.
  final String code;

  /// Name shown in the switcher, in the language itself.
  final String nativeName;

  /// ISO 639 codes (2- and 3-letter) that map to this language.
  final List<String> localeCodes;

  /// The default, and the fallback for any string a language is missing.
  static const AppLanguage fallback = AppLanguage.en;

  /// Languages with Flutter's built-in Material / Cupertino localizations
  /// (text-selection menus, tooltips, …). Chichewa and Bemba have none, so
  /// those fall back to English for the few framework-provided strings.
  static const List<Locale> materialLocales = <Locale>[
    Locale('en'),
    Locale('zu'),
    Locale('pt'),
  ];

  /// The locale handed to `MaterialApp.locale` for this language.
  Locale get materialLocale => switch (this) {
        AppLanguage.zu => const Locale('zu'),
        AppLanguage.pt => const Locale('pt'),
        AppLanguage.en || AppLanguage.ny || AppLanguage.bem =>
          const Locale('en'),
      };

  /// Parses a persisted code; unknown codes give the default.
  static AppLanguage fromCode(String? code) {
    if (code == null) {
      return fallback;
    }
    final String normalized = code.trim().toLowerCase();
    final String primary = normalized.split(RegExp(r'[-_]')).first;
    for (final AppLanguage language in values) {
      if (language.code == normalized ||
          language.localeCodes.contains(normalized) ||
          language.code == primary ||
          language.localeCodes.contains(primary)) {
        return language;
      }
    }
    return fallback;
  }

  /// Nguni languages close enough to isiZulu that it is the better first
  /// guess than English (isiXhosa, siSwati, isiNdebele).
  static const List<String> _nguni = <String>['xh', 'ss', 'nr', 'nd'];

  /// Suggests a language from the device locale, e.g. a phone set to
  /// Portuguese (Mozambique) gets [pt]; isiZulu gets [zu]; Chichewa/Nyanja
  /// gets [ny]; Bemba gets [bem]. English phones stay in English.
  ///
  /// Country hints apply only when the phone's language is neither English
  /// nor one the app has, e.g. a French phone in Mozambique gets [pt].
  static AppLanguage suggest({String? languageCode, String? countryCode}) {
    final String? language = languageCode?.toLowerCase();
    if (language != null) {
      for (final AppLanguage candidate in values) {
        if (candidate.localeCodes.contains(language)) {
          return candidate;
        }
      }
      if (_nguni.contains(language)) {
        return AppLanguage.zu;
      }
    }
    switch (countryCode?.toUpperCase()) {
      case 'MZ':
      case 'AO':
      case 'PT':
      case 'BR':
        return AppLanguage.pt;
      case 'MW':
        return AppLanguage.ny;
      case 'ZM':
        return AppLanguage.bem;
      default:
        return fallback;
    }
  }
}

/// The parsed `translations.json`: one key → string table per language.
///
/// The English table in the file only carries `name`; English (and the
/// authored isiZulu) live in code. Every other language is expected to have
/// the same key set as `zu`.
class Translations {
  const Translations(this._tables);

  /// An empty table: every lookup falls back to the authored English /
  /// isiZulu.
  const Translations.empty() : _tables = const <String, Map<String, String>>{};

  final Map<String, Map<String, String>> _tables;

  /// Parses the JSON text of `assets/translations.json`.
  ///
  /// Throws a [FormatException] on malformed JSON; unknown languages are kept
  /// (they are simply never selected), non-string values are skipped.
  factory Translations.parse(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('translations.json must be a JSON object');
    }
    final Map<String, Map<String, String>> tables =
        <String, Map<String, String>>{};
    decoded.forEach((String language, Object? table) {
      if (table is! Map<String, dynamic>) {
        return;
      }
      final Map<String, String> strings = <String, String>{};
      table.forEach((String key, Object? value) {
        if (value is String) {
          strings[key] = value;
        }
      });
      tables[language] = strings;
    });
    return Translations(tables);
  }

  /// Language codes present in the file.
  Iterable<String> get languages => _tables.keys;

  /// All keys of [language] (empty when the language is missing).
  Iterable<String> keysOf(String language) =>
      _tables[language]?.keys ?? const Iterable<String>.empty();

  /// Raw lookup without fallback.
  String? lookup(String language, String key) => _tables[language]?[key];

  /// Whether [language] has [key].
  bool has(String language, String key) =>
      _tables[language]?.containsKey(key) ?? false;

  /// Replaces `{name}` placeholders.
  static String format(String template, Map<String, String>? args) {
    if (args == null || args.isEmpty) {
      return template;
    }
    String out = template;
    args.forEach((String name, String value) {
      out = out.replaceAll('{$name}', value);
    });
    return out;
  }
}

/// The current app language and the loaded translations.
///
/// A tiny global rather than a provider because string values (`Bi`) are
/// constants used everywhere, including outside the widget tree. The UI
/// listens to [notifier] (see `LanguageScope`) so it rebuilds on change;
/// the persisted choice is owned by `LanguageController`.
abstract final class L10n {
  static Translations _translations = const Translations.empty();

  /// Fires whenever the language changes.
  static final ValueNotifier<AppLanguage> notifier =
      ValueNotifier<AppLanguage>(AppLanguage.fallback);

  /// The active language.
  static AppLanguage get language => notifier.value;

  /// The loaded tables.
  static Translations get translations => _translations;

  /// Installs the translations table (once, at startup or in tests).
  static void install(Translations translations) {
    _translations = translations;
  }

  /// Switches the app language.
  static void setLanguage(AppLanguage language) {
    if (notifier.value != language) {
      notifier.value = language;
    }
  }

  /// Resolves a string in [language] (default: the active language).
  ///
  /// * English → the English authored in code.
  /// * isiZulu → the isiZulu authored in code → isiZulu in the file → English.
  /// * Portuguese / Chichewa / Bemba → the file → English.
  ///
  /// Blank entries count as missing. [args] fill `{name}` placeholders.
  static String resolve({
    required String en,
    required String zu,
    String? key,
    Map<String, String>? args,
    AppLanguage? language,
  }) {
    final AppLanguage active = language ?? L10n.language;
    switch (active) {
      case AppLanguage.en:
        return Translations.format(en, args);
      case AppLanguage.zu:
        if (zu.trim().isNotEmpty) {
          return Translations.format(zu, args);
        }
        final String? fileZulu = _lookup(AppLanguage.zu, key);
        if (fileZulu != null) {
          return Translations.format(fileZulu, args);
        }
        return Translations.format(en, args);
      case AppLanguage.pt:
      case AppLanguage.ny:
      case AppLanguage.bem:
        final String? translated = _lookup(active, key);
        if (translated != null) {
          return Translations.format(translated, args);
        }
        return Translations.format(en, args);
    }
  }

  static String? _lookup(AppLanguage language, String? key) {
    if (key == null) {
      return null;
    }
    final String? value = _translations.lookup(language.code, key);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }
}
