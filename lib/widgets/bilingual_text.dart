import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_theme.dart';
import 'language_scope.dart';

/// English text with the secondary-language translation underneath it.
///
/// This is how every label in the app is shown: English as the main text,
/// the chosen second language (isiZulu by default) as a smaller, softer line.
/// It rebuilds when the language changes (see [LanguageScope]).
class BilingualText extends StatelessWidget {
  const BilingualText(
    this.text, {
    super.key,
    this.style,
    this.zuStyle,
    this.spacing = 2,
    this.textAlign,
    this.maxLines,
    this.semanticLabel,
  });

  /// The bilingual value.
  final Bi text;

  /// Style for the English line. Defaults to `bodyMedium` with primary text.
  final TextStyle? style;

  /// Style for the isiZulu line. Defaults to a smaller, muted version of
  /// [style].
  final TextStyle? zuStyle;

  /// Gap between the two lines.
  final double spacing;

  /// Text alignment for both lines.
  final TextAlign? textAlign;

  /// Maximum lines for each of the two texts.
  final int? maxLines;

  /// Overrides the spoken label; defaults to "English. isiZulu".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final String secondary = text.secondary;
    final ThemeData theme = Theme.of(context);
    final TextStyle englishStyle =
        style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final TextStyle zuluStyle = zuStyle ??
        englishStyle.copyWith(
          fontSize: (englishStyle.fontSize ?? 14) * 0.86,
          height: 1.35,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
        );

    return Semantics(
      label: semanticLabel ?? '${text.en}. $secondary',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.en,
              style: englishStyle,
              textAlign: textAlign,
              maxLines: maxLines,
            ),
            SizedBox(height: spacing),
            Text(
              secondary,
              style: zuluStyle,
              textAlign: textAlign,
              maxLines: maxLines,
            ),
          ],
        ),
      ),
    );
  }
}

/// English and isiZulu on one line, separated by a middot, with the isiZulu in
/// a smaller, softer style.
///
/// Used where vertical space is tight: buttons, the bottom navigation bar and
/// compact readouts.
class BilingualInline extends StatelessWidget {
  const BilingualInline(
    this.text, {
    super.key,
    this.style,
    this.zuStyle,
    this.separator = ' · ',
    this.textAlign,
    this.maxLines = 2,
    this.overflow,
  });

  /// The bilingual value.
  final Bi text;

  /// Style for the English part.
  final TextStyle? style;

  /// Style for the isiZulu part.
  final TextStyle? zuStyle;

  /// Separator between the two languages.
  final String separator;

  /// Alignment of the whole line.
  final TextAlign? textAlign;

  /// Maximum number of lines.
  final int maxLines;

  /// Overflow behaviour of the single [Text.rich].
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final String secondary = text.secondary;
    final ThemeData theme = Theme.of(context);
    final TextStyle englishStyle =
        style ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final TextStyle zuluStyle = zuStyle ??
        englishStyle.copyWith(
          fontSize: (englishStyle.fontSize ?? 14) * 0.86,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
        );

    return Semantics(
      label: '${text.en}. $secondary',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: <TextSpan>[
              TextSpan(text: text.en, style: englishStyle),
              TextSpan(text: separator, style: zuluStyle),
              TextSpan(text: secondary, style: zuluStyle),
            ],
          ),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        ),
      ),
    );
  }
}
