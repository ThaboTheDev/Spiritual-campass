import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/geo_math.dart';
import 'package:tshk_compass/core/l10n/app_language.dart';
import 'package:tshk_compass/core/l10n/strings.dart';
import 'package:tshk_compass/core/theme/app_theme.dart';
import 'package:tshk_compass/features/compass/compass_controller.dart';
import 'package:tshk_compass/features/compass/widgets/compass_dial.dart';
import 'package:tshk_compass/features/compass/widgets/quality_guidance.dart';
import 'package:tshk_compass/features/compass/widgets/source_chip.dart';

class PreviewCompassController extends CompassController {
  @override
  CompassState build() => const CompassState(
    status: CompassStatus.running,
    source: HeadingSourceKind.relativeCalibrated,
    awaitingCalibration: true,
    confidence: HeadingConfidence.uncertain,
    issue: HeadingIssue.calibrationRequired,
  );
  @override
  Future<void> setMode(CompassMode mode) async {
    state = CompassState(
      status: CompassStatus.running,
      mode: mode,
      source: mode == CompassMode.travelDirection
          ? HeadingSourceKind.gpsCourse
          : HeadingSourceKind.relativeCalibrated,
      confidence: HeadingConfidence.uncertain,
      issue: HeadingIssue.waitingForMovement,
    );
  }
}

Widget host(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUp(() {
    L10n.install(const Translations.empty());
    L10n.setLanguage(AppLanguage.en);
  });
  testWidgets(
    'missing, invalid and targetless headings never render a fabricated target needle',
    (WidgetTester tester) async {
      for (final double? heading in <double?>[
        null,
        double.nan,
        double.infinity,
      ]) {
        await tester.pumpWidget(
          host(
            CompassDial(
              headingDeg: heading,
              targetBearingDeg: 0,
              aligned: true,
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey<String>('compass-target-needle')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const CompassDial(headingDeg: 40, targetBearingDeg: null)),
      );
      expect(
        find.byKey(const ValueKey<String>('compass-target-needle')),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(RegExp('Target direction unavailable')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Bearing to Ekuphumuleni 0 degrees')),
        findsNothing,
      );
      semantics.dispose();
    },
  );
  testWidgets('GPS and unavailable values cannot fire alignment haptics', (
    WidgetTester tester,
  ) async {
    int haptics = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics++;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      host(
        const CompassDial(
          headingDeg: 100,
          targetBearingDeg: 100,
          aligned: true,
          travelDirection: true,
        ),
      ),
    );
    await tester.pumpWidget(
      host(
        const CompassDial(
          headingDeg: null,
          targetBearingDeg: 100,
          aligned: true,
        ),
      ),
    );
    expect(haptics, 0);
    await tester.pumpWidget(
      host(
        const CompassDial(
          headingDeg: 100,
          targetBearingDeg: 100,
          aligned: true,
        ),
      ),
    );
    await tester.pump();
    expect(haptics, 1);
    await tester.pumpWidget(
      host(
        const CompassDial(
          headingDeg: 100,
          targetBearingDeg: 100,
          aligned: true,
        ),
      ),
    );
    expect(haptics, 1);
  });
  testWidgets('uncertain sources are warning-coloured, not green', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SourceChip(
          compass: CompassState(
            status: CompassStatus.running,
            source: HeadingSourceKind.rawSensors,
            confidence: HeadingConfidence.uncertain,
          ),
        ),
      ),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).color, AppColors.warning);
  });
  testWidgets('travel mode stays selectable while gyro anchoring is pending', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compassControllerProvider.overrideWith(PreviewCompassController.new),
        ],
        child: host(
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) =>
                QualityGuidance(
                  compass: ref.watch(compassControllerProvider),
                  target: null,
                ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('mode-travel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('mode-travel')));
    await tester.pump();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(QualityGuidance)),
    );
    expect(
      container.read(compassControllerProvider).mode,
      CompassMode.travelDirection,
    );
    expect(find.text(S.travelDirectionNotice.text), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'near-target and GPS msamo guidance explain why alignment is unavailable',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: host(
            const QualityGuidance(
              compass: CompassState(
                status: CompassStatus.running,
                mode: CompassMode.travelDirection,
                source: HeadingSourceKind.gpsCourse,
                confidence: HeadingConfidence.uncertain,
              ),
              requiresPhoneHeading: true,
              target: TargetReading(
                bearingDeg: 0,
                distanceKm: 0,
                isNearTarget: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text(S.phoneHeadingRequired.text), findsOneWidget);
      expect(find.text(S.nearDestination.text), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
