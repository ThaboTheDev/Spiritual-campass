import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tshk_compass/app_providers.dart';
import 'package:tshk_compass/core/l10n/app_language.dart';
import 'package:tshk_compass/core/l10n/strings.dart';
import 'package:tshk_compass/data/local/preferences_store.dart';
import 'package:tshk_compass/features/settings/widgets/language_button.dart';
import 'package:tshk_compass/widgets/app_header.dart';
import 'package:tshk_compass/widgets/language_scope.dart';
import 'package:tshk_compass/widgets/localized_text.dart';

/// The language choice has to be reachable before the gate lets anyone in, so
/// the header button is pinned here: it is visible, it opens the sheet, and a
/// tap applies and persists the language.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() => L10n.setLanguage(AppLanguage.fallback));

  /// `showLogo: false` keeps the crest's asset image out of the widget tree.
  Widget host(Widget child) => ProviderScope(
        overrides: <Override>[
          preferencesStoreProvider
              .overrideWithValue(PreferencesStore(preferences)),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: child),
        ),
      );

  testWidgets('the header carries the language button and the active code',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(const AppHeader(showLogo: false)));
    await tester.pumpAndSettle();

    expect(find.byKey(LanguageButton.buttonKey), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('a screen can ask for the header without the button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      host(const AppHeader(showLogo: false, showLanguageButton: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(LanguageButton.buttonKey), findsNothing);
  });

  testWidgets('choosing a language in the sheet applies and persists it',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(const AppHeader(showLogo: false)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(LanguageButton.buttonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(LanguageSheet.sheetKey), findsOneWidget);
    for (final AppLanguage option in AppLanguage.values) {
      expect(find.byKey(LanguageSheet.optionKey(option)), findsOneWidget);
    }
    // Every row is named in its own language.
    expect(find.text('isiZulu'), findsOneWidget);
    expect(find.text('iciBemba'), findsOneWidget);

    await tester.tap(find.byKey(LanguageSheet.optionKey(AppLanguage.zu)));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // The sheet closed, the header now says ZU, and the choice was stored.
    expect(find.byKey(LanguageSheet.sheetKey), findsNothing);
    expect(L10n.language, AppLanguage.zu);
    expect(find.text('ZU'), findsOneWidget);
    expect(preferences.getString('l10n.secondaryLanguage'), 'zu');
  });

  testWidgets('every label follows the language chosen from the header',
      (WidgetTester tester) async {
    L10n.install(
      Translations.parse(File('assets/translations.json').readAsStringSync()),
    );
    addTearDown(() => L10n.install(const Translations.empty()));

    await tester.pumpWidget(
      host(
        LanguageScope(
          child: Column(
            children: <Widget>[
              const AppHeader(showLogo: false),
              const LocalizedText(S.tabGuide),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guide'), findsOneWidget);

    await tester.tap(find.byKey(LanguageButton.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LanguageSheet.optionKey(AppLanguage.pt)));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // The header pill and the rest of the app changed in place.
    expect(find.text('PT'), findsOneWidget);
    expect(find.text('Guia'), findsOneWidget);
    expect(find.text('Guide'), findsNothing);
  });
}
