import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import 'language_scope.dart';

/// A [Bi] string shown in the language chosen on the Guide tab.
///
/// Rebuilds in place when the language changes (see [LanguageScope]), so
/// switching languages updates every label without recreating the screens
/// or the running compass.
class LocalizedText extends StatelessWidget {
  const LocalizedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.semanticLabel,
  });

  /// The localised value.
  final Bi text;

  /// Text style. Defaults to `bodyMedium`.
  final TextStyle? style;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Maximum number of lines.
  final int? maxLines;

  /// Overflow behaviour.
  final TextOverflow? overflow;

  /// Overrides the spoken label; defaults to the text itself.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    return Text(
      text.text,
      style: style ?? Theme.of(context).textTheme.bodyMedium,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: semanticLabel,
    );
  }
}
