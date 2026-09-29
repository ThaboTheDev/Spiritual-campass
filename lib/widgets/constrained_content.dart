import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Centres content and caps its width, so the app still looks right on a tablet
/// in landscape.
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: AppLayout.gutter),
    this.maxWidth = AppLayout.maxContentWidth,
  });

  /// The content to lay out.
  final Widget child;

  /// Padding applied inside the width constraint.
  final EdgeInsetsGeometry padding;

  /// Maximum content width in logical pixels.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
