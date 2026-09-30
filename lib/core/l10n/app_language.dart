import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The secondary languages the app can show under the English line.
///
/// English is always the primary line and is authored in code
/// (`S.*`); the secondary line is isiZulu by default and can be switched to
/// any of these. Codes match the top-level keys of `assets/translations.json`.
enum AppLanguage {
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

  /// The default: isiZulu.
  static const AppLanguage fallback = AppLanguage.zu;

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

  /// Suggests a secondary language from the device locale, e.g. a phone set
  /// to Portuguese (Mozambique) gets [pt]; Chichewa/Nyanja gets [ny]; Bemba
  /// gets [bem]. Anything else — including English — gets the default.
  ///
  /// Country hints help where the language is English but the country is
  /// Zambia / Malawi / Mozambique.
  static AppLanguage suggest({String? languageCode, String? countryCode}) {
    final String? language = languageCode?.toLowerCase();
    if (language != null) {
      for (final AppLanguage candidate in values) {
        if (candidate.localeCodes.contains(language)) {
          return candidate;
        }
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
/// The English table in the file only carries `name`; English strings live
/// in code. Every other language is expected to have the same key set.
class Translations {
  const Translations(this._tables);

  /// An empty table: every lookup falls back to isiZulu / English.
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

/// The current secondary language and the loaded translations.
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

  /// The active secondary language.
  static AppLanguage get language => notifier.value;

  /// The loaded tables.
  static Translations get translations => _translations;

  /// Installs the translations table (once, at startup or in tests).
  static void install(Translations translations) {
    _translations = translations;
  }

  /// Switches the secondary language.
  static void setLanguage(AppLanguage language) {
    if (notifier.value != language) {
      notifier.value = language;
    }
  }

  /// Resolves the secondary line for a key with the fallback order
  /// *chosen language → isiZulu (authored) → isiZulu (file) → English*.
  ///
  /// [zu] is the isiZulu authored in code; [en] the English line.
  static String secondary({
    required String en,
    required String zu,
    String? key,
    Map<String, String>? args,
    AppLanguage? language,
  }) {
    final AppLanguage active = language ?? L10n.language;
    if (active != AppLanguage.zu && key != null) {
      final String? translated = _translations.lookup(active.code, key);
      if (translated != null && translated.trim().isNotEmpty) {
        return Translations.format(translated, args);
      }
    }
    if (zu.trim().isNotEmpty) {
      return Translations.format(zu, args);
    }
    if (key != null) {
      final String? fileZulu = _translations.lookup(AppLanguage.zu.code, key);
      if (fileZulu != null && fileZulu.trim().isNotEmpty) {
        return Translations.format(fileZulu, args);
      }
    }
    return Translations.format(en, args);
  }
}
