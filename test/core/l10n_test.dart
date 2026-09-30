import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/l10n/app_language.dart';
import 'package:tshk_compass/core/l10n/strings.dart';

const String _sample = '''
{
  "zu":  {"greet": "Sawubona", "only_zu": "Kuphela", "turn": "Phenduka ngo-{n}°"},
  "pt":  {"greet": "Olá", "turn": "Rode {n}° para a {dir}", "blank": "", "dir_r": "direita"},
  "ny":  {"greet": "Moni"},
  "bem": {"greet": "Shani"},
  "en":  {"name": "English"}
}
''';

void main() {
  setUp(() => L10n.install(Translations.parse(_sample)));
  tearDown(() {
    L10n.install(const Translations.empty());
    L10n.setLanguage(AppLanguage.fallback);
  });

  group('one language at a time', () {
    test('English shows the English authored in code', () {
      L10n.setLanguage(AppLanguage.en);
      const Bi bi = Bi('Hello', 'Sawubona (code)', key: 'greet');
      expect(bi.text, 'Hello');
      expect('$bi', 'Hello');
    });

    test('isiZulu shows the isiZulu authored in code', () {
      L10n.setLanguage(AppLanguage.zu);
      const Bi bi = Bi('Hello', 'Sawubona (code)', key: 'greet');
      expect(bi.text, 'Sawubona (code)');
    });

    test('isiZulu falls back to the file, then English', () {
      L10n.setLanguage(AppLanguage.zu);
      expect(const Bi('Only', '', key: 'only_zu').text, 'Kuphela');
      expect(const Bi('Missing', '', key: 'nope').text, 'Missing');
    });

    test('Portuguese, Chichewa and Bemba come from the file', () {
      const Bi bi = Bi('Hello', 'Sawubona', key: 'greet');
      expect(bi.textIn(AppLanguage.pt), 'Olá');
      expect(bi.textIn(AppLanguage.ny), 'Moni');
      expect(bi.textIn(AppLanguage.bem), 'Shani');
    });

    test('a missing translation falls back to English, never isiZulu', () {
      const Bi bi = Bi('Only', 'Kuphela (code)', key: 'only_zu');
      expect(bi.textIn(AppLanguage.bem), 'Only');
      expect(bi.textIn(AppLanguage.pt), 'Only');
    });

    test('blank translations are treated as missing', () {
      const Bi bi = Bi('Blank', 'Akukho', key: 'blank');
      expect(bi.textIn(AppLanguage.pt), 'Blank');
    });

    test('a Bi without a key shows English outside isiZulu', () {
      const Bi bi = Bi('Hello', 'Sawubona');
      expect(bi.textIn(AppLanguage.pt), 'Hello');
      expect(bi.textIn(AppLanguage.zu), 'Sawubona');
    });

    test('text follows the active language', () {
      const Bi bi = Bi('Hello', 'Sawubona', key: 'greet');
      L10n.setLanguage(AppLanguage.pt);
      expect(bi.text, 'Olá');
      L10n.setLanguage(AppLanguage.en);
      expect(bi.text, 'Hello');
    });

    test('placeholders are filled; Bi arguments resolve in the same language',
        () {
      const Bi right = Bi('right', 'kwesokudla', key: 'dir_r');
      const Bi bi = Bi(
        'Turn 30° to your right',
        'Phendukela kwesokudla ngo-30°',
        key: 'turn',
        args: <String, Object>{'n': '30', 'dir': right},
      );
      expect(bi.textIn(AppLanguage.pt), 'Rode 30° para a direita');
      expect(bi.textIn(AppLanguage.en), 'Turn 30° to your right');
    });
  });

  group('AppLanguage', () {
    test('English is the default and the fallback', () {
      expect(AppLanguage.fallback, AppLanguage.en);
      expect(AppLanguage.values.first, AppLanguage.en);
      expect(AppLanguage.en.nativeName, 'English');
    });

    test('suggests from the device locale, English otherwise', () {
      expect(AppLanguage.suggest(languageCode: 'pt', countryCode: 'MZ'),
          AppLanguage.pt);
      expect(AppLanguage.suggest(languageCode: 'zu'), AppLanguage.zu);
      expect(AppLanguage.suggest(languageCode: 'xh'), AppLanguage.zu);
      expect(AppLanguage.suggest(languageCode: 'ny'), AppLanguage.ny);
      expect(AppLanguage.suggest(languageCode: 'bem'), AppLanguage.bem);
      expect(AppLanguage.suggest(languageCode: 'en', countryCode: 'ZA'),
          AppLanguage.en);
      expect(AppLanguage.suggest(languageCode: 'fr'), AppLanguage.en);
      expect(AppLanguage.suggest(languageCode: 'fr', countryCode: 'MZ'),
          AppLanguage.pt);
    });

    test('fromCode is forgiving', () {
      expect(AppLanguage.fromCode('PT'), AppLanguage.pt);
      expect(AppLanguage.fromCode('pt_MZ'), AppLanguage.pt);
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('xx'), AppLanguage.en);
      expect(AppLanguage.fromCode(null), AppLanguage.en);
    });

    test('Material locales exist for every language', () {
      for (final AppLanguage language in AppLanguage.values) {
        expect(AppLanguage.materialLocales, contains(language.materialLocale));
      }
    });

    test('setLanguage notifies listeners', () {
      int calls = 0;
      void listener() => calls++;
      L10n.notifier.addListener(listener);
      L10n.setLanguage(AppLanguage.ny);
      L10n.setLanguage(AppLanguage.ny); // no change → no notification
      L10n.notifier.removeListener(listener);
      expect(calls, 1);
    });
  });

  group('assets/translations.json', () {
    final Translations file =
        Translations.parse(File('assets/translations.json').readAsStringSync());
    final String source =
        File('lib/core/l10n/strings.dart').readAsStringSync();

    test('the four translated languages share the same keys', () {
      final Set<String> zu = file.keysOf('zu').toSet();
      expect(zu, isNotEmpty);
      for (final String lang in <String>['pt', 'ny', 'bem']) {
        expect(file.keysOf(lang).toSet(), zu,
            reason: '$lang keys differ from zu');
      }
      // English lives in code; the file's `en` table only names the language.
      expect(file.lookup('en', 'name'), 'English');
    });

    test('every string in strings.dart has a key', () {
      // Counts `Bi(` constructor calls against `key:` arguments.
      final int constructors = RegExp(r'\bBi\(').allMatches(source).length -
          // The class's own constructor declaration.
          RegExp(r'const Bi\(this\.en').allMatches(source).length;
      final int keys = RegExp(r"key: '[a-z0-9_]+'").allMatches(source).length;
      expect(constructors, greaterThan(100));
      expect(keys, constructors,
          reason: 'every Bi(...) in strings.dart needs a key');
    });

    test('every key used in strings.dart exists in every language', () {
      final Set<String> used = RegExp(r"key: '([a-z0-9_]+)'")
          .allMatches(source)
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();
      expect(used, isNotEmpty);
      for (final String lang in <String>['zu', 'pt', 'ny', 'bem']) {
        final Set<String> missing =
            used.difference(file.keysOf(lang).toSet());
        expect(missing, isEmpty, reason: 'keys missing from $lang');
      }
    });

    test('translations keep the placeholders of their key', () {
      final Set<String> zuKeys = file.keysOf('zu').toSet();
      final RegExp placeholder = RegExp(r'\{(\w+)\}');
      for (final String key in zuKeys) {
        final Set<String> expected = placeholder
            .allMatches(file.lookup('zu', key)!)
            .map((RegExpMatch m) => m.group(1)!)
            .toSet();
        for (final String lang in <String>['pt', 'ny', 'bem']) {
          final Set<String> actual = placeholder
              .allMatches(file.lookup(lang, key)!)
              .map((RegExpMatch m) => m.group(1)!)
              .toSet();
          expect(actual, expected, reason: '$lang/$key placeholders');
        }
      }
    });

    test('real strings translate in every language', () {
      L10n.install(file);
      for (final AppLanguage language in AppLanguage.values) {
        expect(S.tabCompass.textIn(language), isNotEmpty);
      }
      expect(S.tabCompass.textIn(AppLanguage.en), 'Compass');
      expect(S.tabCompass.textIn(AppLanguage.pt), 'Bússola');
      expect(S.save.textIn(AppLanguage.ny), 'Sungani');
      expect(S.sunOffBy(32, toRight: true).textIn(AppLanguage.pt),
          'Não está à frente · 32° à sua direita');
      expect(S.savedNamed('Durban').textIn(AppLanguage.bem),
          'Incende yasungwa · Durban');
    });
  });
}
