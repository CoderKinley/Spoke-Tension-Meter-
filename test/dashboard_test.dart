import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/app/lab_app.dart';
import 'package:spoke_lab/app/lab_controller.dart';
import 'package:spoke_lab/core/dsp/pitch_analyzer.dart';
import 'package:spoke_lab/data/models.dart';
import 'package:spoke_lab/data/repository.dart';
import 'controller_test.dart' show FakeAudio, konaWheel, pluck;

Future<LabController> dashboard(
  WidgetTester tester, {
  AppData? data,
  Size size = const Size(360, 800),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final audio = FakeAudio();
  final c = LabController(audio: audio, repository: MemoryRepository(data));
  await c.initialize();
  await tester.pumpWidget(LabApp(controller: c));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await audio.stream.close();
  });
  return c;
}

Future<void> workshop(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('workshop-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final configuration in [
    (const Size(360, 800), 1.0),
    (const Size(320, 640), 1.5),
    (const Size(412, 915), 2.0),
    (const Size(800, 420), 1.5),
  ]) {
    testWidgets(
      'Measure fits ${configuration.$1} at ${configuration.$2} text scale without scrolling',
      (tester) async {
        await dashboard(
          tester,
          size: configuration.$1,
          scale: configuration.$2,
        );
        expect(find.byKey(const Key('frequency-value')), findsOneWidget);
        expect(find.byKey(const Key('interactive-wheel-map')), findsOneWidget);
        expect(find.byType(ExpansionTile), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('measure-dashboard')),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
        for (final key in [
          'frequency-panel',
          'interactive-wheel-map',
          'capture-button',
          'save-reading',
          'measure-instruction',
        ]) {
          final rect = tester.getRect(find.byKey(Key(key)));
          expect(rect.top, greaterThanOrEqualTo(0), reason: key);
          expect(
            rect.bottom,
            lessThanOrEqualTo(configuration.$1.height),
            reason: key,
          );
        }
        expect(find.byKey(const Key('measure-tension-setup')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'repeated plucks settle, save to the wheel, advance and reopen details',
    (tester) async {
      final c = await dashboard(tester, data: AppData(wheels: [konaWheel()]));
      await c.configureIdealString(272);
      pluck(c, 350);
      pluck(c, 351);
      pluck(c, 350);
      c.livePitch = const PitchResult(
        kind: PitchKind.fundamental,
        frequencyHz: 390,
        message: 'live',
      );
      await tester.pumpAndSettle();
      expect(find.text('SETTLED'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('frequency-value'))).data,
        '350.0',
      );
      await tester.tap(find.byKey(const Key('save-reading')));
      await tester.pumpAndSettle();
      expect(c.spokeIndex, 2);
      expect(c.mappedReadings[1]!.frequencyHz, 350);
      expect(c.pluckCount, 0);
      expect(find.text('1/16 recorded'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wheel-spoke-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('spoke-detail-frequency')), findsOneWidget);
      expect(find.text('350.0 Hz'), findsWidgets);
      expect(find.byKey(const Key('spoke-detail-tension')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('measure-this-spoke')),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('measure-this-spoke')));
      await tester.pumpAndSettle();
      expect(c.spokeIndex, 1);
      expect(c.mappedReadings[1], isNotNull);
      expect(c.pluckCount, 0);
    },
  );
  testWidgets('front rear and left right keep distinct wheel maps', (
    tester,
  ) async {
    final c = await dashboard(
      tester,
      data: AppData(
        wheels: [
          konaWheel(id: 'front', position: 'front'),
          konaWheel(id: 'rear', position: 'rear'),
        ],
      ),
    );
    for (var i = 0; i < 3; i++) {
      pluck(c, 350);
    }
    await c.saveReading(continueListening: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('measure-context-right')));
    await tester.pumpAndSettle();
    expect(c.mappedReadings, isEmpty);
    await tester.tap(find.byKey(const Key('measure-context-left')));
    await tester.pumpAndSettle();
    expect(c.mappedReadings.keys, [1]);
    await tester.tap(find.byKey(const Key('measure-context-rear')));
    await tester.pumpAndSettle();
    expect(c.wheel.id, 'rear');
    expect(c.mappedReadings, isEmpty);
    for (var i = 0; i < 3; i++) {
      pluck(c, 280);
    }
    await c.saveReading(continueListening: true);
    await tester.tap(find.byKey(const Key('measure-context-front')));
    await tester.pumpAndSettle();
    expect(c.mappedReadings[1]!.frequencyHz, 350);
    expect(c.data.readings.length, 2);
  });
  testWidgets(
    'empty spoke details selects a position without inventing a reading',
    (tester) async {
      final c = await dashboard(tester);
      await tester.tap(find.byKey(const Key('wheel-spoke-5')));
      await tester.pumpAndSettle();
      expect(find.text('No saved reading'), findsOneWidget);
      expect(find.byKey(const Key('spoke-detail-tension')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('measure-this-spoke')),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('measure-this-spoke')));
      await tester.pumpAndSettle();
      expect(c.spokeIndex, 5);
      expect(c.data.readings, isEmpty);
    },
  );
  testWidgets(
    'tension is a separate page and its dialog preserves decimal length',
    (tester) async {
      final c = await dashboard(
        tester,
        data: AppData(wheels: [konaWheel()]),
        scale: 1.5,
      );
      await tester.tap(find.text('Tension').last);
      await tester.pumpAndSettle();
      final configure = find.byKey(const Key('measure-tension-setup'));
      await tester.ensureVisible(configure);
      await tester.tap(configure);
      await tester.pumpAndSettle();
      final length = find.byKey(const Key('ideal-model-length'));
      final apply = find.byKey(const Key('apply-ideal-model'));
      expect(tester.widget<TextFormField>(length).controller!.text, '272.0');
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      await tester.ensureVisible(
        find.byKey(const Key('acknowledge-ideal-model')),
      );
      await tester.tap(find.byKey(const Key('acknowledge-ideal-model')));
      await tester.ensureVisible(length);
      await tester.enterText(length, '-1');
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(find.text('Enter a positive length up to 500 mm'), findsOneWidget);
      await tester.ensureVisible(length);
      await tester.enterText(length, '272.5');
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(c.idealSettings!.lengthMm, 272.5);
      await tester.ensureVisible(configure);
      await tester.tap(configure);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(length).controller!.text, '272.5');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Measure').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('measure-tension-setup')), findsNothing);
    },
  );
  testWidgets(
    'references calibration and audio controls live in the tools menu',
    (tester) async {
      final c = await dashboard(tester);
      await workshop(tester, 'Sound references');
      await tester.ensureVisible(find.text('Enter target frequency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter target frequency'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '350');
      await tester.tap(find.text('Save reference'));
      await tester.pumpAndSettle();
      expect(c.data.references.single.frequencyHz, 350);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await workshop(tester, 'Calibration');
      expect(find.text('VALIDATED FORCE UNAVAILABLE'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await workshop(tester, 'Capture settings');
      expect(find.text('Repeat capture sensitivity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
