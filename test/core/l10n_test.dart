import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/l10n/app_language.dart';
import 'package:tshk_compass/core/l10n/strings.dart';

const String _sample = '''
{
  "zu":  {"greet": "Sawubona", "only_zu": "Kuphela", "turn": "Phenduka ngo-{n}°"},
  "pt":  {"greet": "Olá", "turn": "Vire {n}°", "blank": ""},
  "ny":  {"greet": "Moni"},
  "bem": {"greet": "Shani"},
  "en":  {"greet": "Hello", "only_zu": "Only", "en_only": "English only"}
}
''';

void main() {
  setUp(() => L10n.install(Translations.parse(_sample)));
  tearDown(() {
    L10n.install(const Translations.empty());
    L10n.setLanguage(AppLanguage.zu);
  });

  group('fallback order: chosen → authored zu → file zu → en', () {
    test('chosen language wins when it has the key', () {
      L10n.setLanguage(AppLanguage.pt);
      const Bi bi = Bi('Hello', 'Sawubona (code)', key: 'greet');
      expect(bi.secondary, 'Olá');
      expect(bi.inline, 'Hello · Olá');
    });

    test('isiZulu authored in code when the chosen language lacks the key', () {
      L10n.setLanguage(AppLanguage.bem);
      const Bi bi = Bi('Only', 'Kuphela (code)', key: 'only_zu');
      expect(bi.secondary, 'Kuphela (code)');
    });

    test('file isiZulu when the authored line is empty', () {
      L10n.setLanguage(AppLanguage.ny);
      const Bi bi = Bi('Only', '', key: 'only_zu');
      expect(bi.secondary, 'Kuphela');
    });

    test('English last', () {
      L10n.setLanguage(AppLanguage.pt);
      const Bi bi = Bi('English only', '', key: 'en_only');
      expect(bi.secondary, 'English only');
    });

    test('blank translations are treated as missing', () {
      L10n.setLanguage(AppLanguage.pt);
      const Bi bi = Bi('Blank', 'Akukho', key: 'blank');
      expect(bi.secondary, 'Akukho');
    });

    test('isiZulu selected: authored text, no lookup', () {
      L10n.setLanguage(AppLanguage.zu);
      const Bi bi = Bi('Hello', 'Sawubona (code)', key: 'greet');
      expect(bi.secondary, 'Sawubona (code)');
    });

    test('a Bi without a key always shows its authored isiZulu', () {
      L10n.setLanguage(AppLanguage.pt);
      const Bi bi = Bi('Hello', 'Sawubona');
      expect(bi.secondary, 'Sawubona');
    });

    test('placeholders are filled for translated strings', () {
      L10n.setLanguage(AppLanguage.pt);
      final Bi bi = Bi(
        'Turn 30°',
        'Phenduka ngo-30°',
        key: 'turn',
        args: <String, String>{'n': '30'},
      );
      expect(bi.secondary, 'Vire 30°');
      expect(bi.zu, 'Phenduka ngo-30°');
    });
  });

  group('AppLanguage', () {
    test('suggests from the device locale, isiZulu otherwise', () {
      expect(AppLanguage.suggest(languageCode: 'pt', countryCode: 'MZ'),
          AppLanguage.pt);
      expect(AppLanguage.suggest(languageCode: 'ny'), AppLanguage.ny);
      expect(AppLanguage.suggest(languageCode: 'bem'), AppLanguage.bem);
      expect(AppLanguage.suggest(languageCode: 'en', countryCode: 'ZA'),
          AppLanguage.zu);
      expect(AppLanguage.suggest(languageCode: 'fr'), AppLanguage.zu);
    });

    test('fromCode is forgiving', () {
      expect(AppLanguage.fromCode('PT'), AppLanguage.pt);
      expect(AppLanguage.fromCode('xx'), AppLanguage.zu);
      expect(AppLanguage.fromCode(null), AppLanguage.zu);
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
    test('has the four secondary languages with the same 116 keys', () {
      final File file = File('assets/translations.json');
      expect(file.existsSync(), isTrue);
      final Translations t = Translations.parse(file.readAsStringSync());
      final Set<String> zu = t.keysOf('zu').toSet();
      expect(zu.length, 116);
      for (final String lang in <String>['pt', 'ny', 'bem']) {
        expect(t.keysOf(lang).toSet(), zu, reason: '$lang keys differ from zu');
      }
      // English lives in code; the file's `en` table only names the language.
      expect(t.has('en', 'name'), isTrue);
    });

    test('every key referenced from S.* exists in the file', () {
      final Translations t =
          Translations.parse(File('assets/translations.json').readAsStringSync());
      final Set<String> keys = t.keysOf('zu').toSet();
      final RegExp pattern = RegExp(r"key: '([a-z0-9_]+)'");
      final String source = File('lib/core/l10n/strings.dart').readAsStringSync();
      final Set<String> used = pattern
          .allMatches(source)
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();
      expect(used, isNotEmpty);
      final Set<String> missing = used.difference(keys);
      expect(missing, isEmpty, reason: 'keys used in strings.dart but absent');
    });
  });
}
