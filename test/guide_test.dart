import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/app/theme.dart';
import 'package:spoke_lab/features/wheel_guide.dart';
import 'dashboard_test.dart' show dashboard, workshop;

Future<void> selectTopic(WidgetTester tester, String topic) async {
  final chip = find.byKey(Key('guide-topic-$topic'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> guide(WidgetTester tester, Size size, double scale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: labTheme(),
      home: const Scaffold(body: SafeArea(child: WheelGuide())),
    ),
  );
}

String direction(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  testWidgets(
    'nipple direction reverses with viewpoint for tightening and loosening',
    (tester) async {
      await guide(tester, const Size(412, 915), 1);
      final semantics = tester.ensureSemantics();
      try {
        await selectTopic(tester, 'turns');
        expect(direction(tester, 'guide-turn-direction'), 'CLOCKWISE');
        await tester.tap(find.byKey(const Key('guide-from-hub')));
        await tester.pumpAndSettle();
        expect(direction(tester, 'guide-turn-direction'), 'COUNTERCLOCKWISE');
        await tester.tap(find.byKey(const Key('guide-loosen')));
        await tester.pumpAndSettle();
        expect(direction(tester, 'guide-turn-direction'), 'CLOCKWISE');
        await tester.tap(find.byKey(const Key('guide-from-hub')));
        await tester.pumpAndSettle();
        expect(direction(tester, 'guide-turn-direction'), 'COUNTERCLOCKWISE');
        await tester.ensureVisible(find.byKey(const Key('guide-diagram-turn')));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel(
            'Loosen: turn counterclockwise when looking from the tire bed toward the hub.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'lateral and radial choices explain the appropriate correction direction',
    (tester) async {
      await guide(tester, const Size(412, 915), 1);
      await selectTopic(tester, 'lateral');
      expect(direction(tester, 'guide-lateral-direction'), 'Move the rim LEFT');
      await tester.tap(find.byKey(const Key('guide-rim-left')));
      await tester.pumpAndSettle();
      expect(
        direction(tester, 'guide-lateral-direction'),
        'Move the rim RIGHT',
      );
      await selectTopic(tester, 'radial');
      expect(
        direction(tester, 'guide-radial-direction'),
        'High spot → toward the hub',
      );
      await tester.tap(find.byKey(const Key('guide-low-spot')));
      await tester.pumpAndSettle();
      expect(
        direction(tester, 'guide-radial-direction'),
        'Low spot → away from the hub',
      );
      expect(find.textContaining('never leave spokes slack'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final config in [
    (const Size(320, 640), 2.0),
    (const Size(800, 420), 1.5),
  ]) {
    testWidgets(
      'all guide topics scroll without overflow at ${config.$1} and ${config.$2} scale',
      (tester) async {
        await guide(tester, config.$1, config.$2);
        for (final topic in ['inspect', 'turns', 'lateral', 'radial']) {
          await selectTopic(tester, topic);
          final sources = find.byKey(const PageStorageKey('guide-sources'));
          await tester.ensureVisible(sources);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byKey(const PageStorageKey('guide-sources')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Park Tool · Truing mechanics'));
        expect(find.byType(SelectableText), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Guide is reachable from navigation, help and tools without changing the wheel',
    (tester) async {
      final c = await dashboard(tester);
      final wheelId = c.wheel.id;
      c.listening = true;
      await tester.tap(find.text('Guide').last);
      await tester.pumpAndSettle();
      expect(c.listening, isFalse);
      expect(find.byType(WheelGuide), findsOneWidget);
      await tester.tap(find.text('Measure').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('interactive-wheel-map')), findsOneWidget);
      await tester.tap(find.byTooltip('Wheel guide'));
      await tester.pumpAndSettle();
      expect(find.byType(WheelGuide), findsOneWidget);
      await tester.tap(find.text('Measure').last);
      await tester.pumpAndSettle();
      await workshop(tester, 'Wheel guide');
      expect(find.byType(WheelGuide), findsOneWidget);
      expect(c.wheel.id, wheelId);
      expect(c.data.readings, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
