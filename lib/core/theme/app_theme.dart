import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark-only design tokens for TSHK Compass.
///
/// Background #0f131c, cards a slightly lighter navy, cornflower blue accent,
/// gold for the Ekuphumuleni marker, white/soft-grey text.
abstract final class AppColors {
  /// App background (#0f131c).
  static const Color background = Color(0xFF0F131C);

  /// Card / surface background (slightly lighter navy).
  static const Color surface = Color(0xFF151B27);

  /// Raised surface, e.g. chips and pressed states.
  static const Color surfaceAlt = Color(0xFF1C2534);

  /// 1px card borders.
  static const Color border = Color(0xFF27313F);

  /// Cornflower blue accent (#6b9be8).
  static const Color accent = Color(0xFF6B9BE8);

  /// Dimmed accent, for tinted highlights.
  static const Color accentDim = Color(0x266B9BE8);

  /// Ekuphumuleni gold (#d4a53c).
  static const Color gold = Color(0xFFD4A53C);

  /// Dimmed gold, for tinted highlights.
  static const Color goldDim = Color(0x26D4A53C);

  /// Primary text.
  static const Color textPrimary = Color(0xFFEEF2F8);

  /// Secondary text (isiZulu lines, captions).
  static const Color textSecondary = Color(0xFF9AA7BD);

  /// Muted text (units, hints).
  static const Color textMuted = Color(0xFF6C7A91);

  /// Positive / confirmed state.
  static const Color success = Color(0xFF5FC98A);

  /// Warning state (calibration, permission problems).
  static const Color warning = Color(0xFFE8B15C);

  /// Error state.
  static const Color danger = Color(0xFFE47B72);
}

/// Layout constants shared by every screen.
abstract final class AppLayout {
  /// Content is centred and capped at this width on tablets.
  static const double maxContentWidth = 610;

  /// Card corner radius.
  static const double cardRadius = 16;

  /// Standard horizontal screen padding.
  static const double gutter = 16;

  /// Vertical space between cards.
  static const double gap = 12;

  /// Minimum tap target size (accessibility).
  static const double minTapTarget = 48;
}

/// Builds the single dark Material 3 theme used by the whole app.
abstract final class AppTheme {
  /// The dark theme.
  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      primary: AppColors.accent,
      secondary: AppColors.gold,
    ).copyWith(
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
    );

    final TextTheme bodyText =
        GoogleFonts.ibmPlexSansTextTheme(_baseTextTheme(scheme));

    // Titles use a serif (Source Serif 4); the body uses IBM Plex Sans.
    final TextTheme serif =
        GoogleFonts.sourceSerif4TextTheme(_baseTextTheme(scheme));

    final TextTheme textTheme = bodyText.copyWith(
      displayLarge: serif.displayLarge,
      displayMedium: serif.displayMedium,
      displaySmall: serif.displaySmall,
      headlineLarge: serif.headlineLarge,
      headlineMedium: serif.headlineMedium,
      headlineSmall: serif.headlineSmall,
      titleLarge: serif.titleLarge,
      titleMedium: serif.titleMedium,
      titleSmall: bodyText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: textTheme,
      dividerColor: AppColors.border,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemOverlayStyle,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.cardRadius),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(0, AppLayout.minTapTarget),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: const Color(0xFF08101F),
          elevation: 0,
          minimumSize: const Size(0, AppLayout.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, AppLayout.minTapTarget),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        helperStyle: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.danger),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.textMuted,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceAlt,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
      ),
    );
  }

  /// Light status bar / navigation bar icons, transparent-ish background.
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static TextTheme _baseTextTheme(ColorScheme scheme) {
    return TextTheme(
      displayLarge: const TextStyle(
        fontSize: 34,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      displayMedium: const TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      displaySmall: const TextStyle(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineLarge: const TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineMedium: const TextStyle(
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: const TextStyle(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: const TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodySmall: const TextStyle(
        fontSize: 12.5,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      labelMedium: const TextStyle(
        fontSize: 12.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      labelSmall: const TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Text helpers that need a font the base theme does not expose.
abstract final class AppText {
  /// Monospace text, used for the coordinates card on the Guide screen.
  static TextStyle mono({
    double fontSize = 14,
    Color color = AppColors.textPrimary,
    FontWeight fontWeight = FontWeight.w500,
    double height = 1.5,
    double letterSpacing = 0.2,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// The small uppercase letter-spaced eyebrow used above titles.
  static const TextStyle eyebrow = TextStyle(
    fontSize: 10.5,
    height: 1.2,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w700,
    color: AppColors.accent,
  );

  /// Section header (uppercase, letter-spaced), e.g. "GAUTENG · 20".
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 11.5,
    height: 1.2,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );
}
