import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A two column grid of [ReadoutCard]s that collapses to one column on very
/// narrow screens.
class ReadoutGrid extends StatelessWidget {
  const ReadoutGrid({
    super.key,
    required this.children,
    this.spacing = AppLayout.gap,
    this.minColumnWidth = 150,
  });

  /// The cards to lay out.
  final List<Widget> children;

  /// Gap between cards.
  final double spacing;

  /// Below this column width the grid falls back to a single column.
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= minColumnWidth * 2 + spacing ? 2 : 1;
        final double itemWidth =
            columns == 2 ? (width - spacing) / 2 : width;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}
