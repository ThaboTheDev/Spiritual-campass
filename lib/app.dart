import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/strings.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/language_controller.dart';
import 'features/shell/app_shell.dart';
import 'widgets/language_scope.dart';

/// The root widget: a single dark Material 3 app.
class TshkApp extends ConsumerWidget {
  const TshkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the persisted / suggested secondary language before the first
    // frame so every Bilingual widget renders the right second line.
    ref.watch(languageProvider);

    return LanguageScope(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemOverlayStyle,
        child: MaterialApp(
          title: S.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const AppShell(),
          builder: (BuildContext context, Widget? child) {
            // Never let the OS font scale make the readouts unreadable, and
            // keep 320 dp phones from overflowing at large system scales.
            final MediaQueryData media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: media.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.3,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
