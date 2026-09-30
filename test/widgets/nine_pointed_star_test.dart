import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/theme/app_theme.dart';
import 'package:tshk_compass/widgets/nine_pointed_star.dart';

void main() {
  group('NinePointedStar widget', () {
    testWidgets('renders CustomPaint with default size and gold color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NinePointedStar(),
            ),
          ),
        ),
      );

      final Finder starFinder = find.byType(NinePointedStar);
      expect(starFinder, findsOneWidget);

      final NinePointedStar starWidget =
          tester.widget<NinePointedStar>(starFinder);
      expect(starWidget.size, 24.0);
      expect(starWidget.color, AppColors.gold);
      expect(starWidget.innerRadiusRatio, 0.46);

      final Finder customPaintFinder = find.descendant(
        of: starFinder,
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);
    });

    testWidgets('respects custom size, color, stroke and shadow parameters',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NinePointedStar(
                size: 40.0,
                color: Colors.amber,
                innerRadiusRatio: 0.5,
                strokeColor: Colors.black,
                strokeWidth: 1.5,
                shadowColor: Colors.black54,
              ),
            ),
          ),
        ),
      );

      final NinePointedStar starWidget =
          tester.widget<NinePointedStar>(find.byType(NinePointedStar));
      expect(starWidget.size, 40.0);
      expect(starWidget.color, Colors.amber);
      expect(starWidget.innerRadiusRatio, 0.5);
      expect(starWidget.strokeColor, Colors.black);
      expect(starWidget.strokeWidth, 1.5);
      expect(starWidget.shadowColor, Colors.black54);
    });
  });
}
