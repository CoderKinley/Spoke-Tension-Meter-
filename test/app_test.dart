import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/app/lab_app.dart';
import 'package:spoke_lab/app/lab_controller.dart';
import 'package:spoke_lab/data/repository.dart';
import 'package:spoke_lab/core/physics/tension.dart';
import 'package:spoke_lab/data/wheel_presets.dart';
import 'package:spoke_lab/data/models.dart';
import 'controller_test.dart' show FakeAudio, konaWheel, pluck;

void main() {
  testWidgets(
    'Kona model requires acknowledgement, preserves decimals and displays gated tension',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final audio = FakeAudio();
      final repo = MemoryRepository(AppData(wheels: [konaWheel()]));
      final c = LabController(audio: audio, repository: repo);
      await c.initialize();
      await tester.pumpWidget(LabApp(controller: c));
      final configure = find.byKey(const Key('configure-ideal-model'));
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
      await tester.pumpAndSettle();
      await tester.ensureVisible(length);
      await tester.enterText(length, '-1');
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(find.text('Enter a positive length up to 500 mm'), findsOneWidget);
      expect(repo.data.idealSettings, isEmpty);
      await tester.ensureVisible(length);
      await tester.enterText(length, '272.5');
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(c.idealSettings!.lengthMm, 272.5);
      expect(find.byKey(const Key('ideal-tension-newtons')), findsNothing);
      for (var i = 0; i < 3; i++) {
        pluck(c, 350);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ideal-tension-newtons')), findsOneWidget);
      expect(find.textContaining('accuracy is unknown'), findsOneWidget);
      await tester.ensureVisible(configure);
      await tester.tap(configure);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(length).controller!.text, '272.5');
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await c.select(selectedSide: WheelSide.right);
      await tester.pumpAndSettle();
      expect(c.idealSettings, isNull);
      expect(find.byKey(const Key('ideal-tension-newtons')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await audio.stream.close();
    },
  );
  testWidgets('empty measurement is honest and all four pages render', (
    tester,
  ) async {
    final audio = FakeAudio();
    final controller = LabController(
      audio: audio,
      repository: MemoryRepository(),
    );
    await controller.initialize();
    await tester.pumpWidget(LabApp(controller: controller));
    expect(find.text('Listen to your wheel.'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('save-reading')))
          .onPressed,
      isNull,
    );
    for (final label in ['Tune', 'Wheels', 'Calibration', 'Measure']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await audio.stream.close();
  });
  testWidgets('manual reference is saved through the dialog', (tester) async {
    final audio = FakeAudio();
    final repo = MemoryRepository();
    final controller = LabController(audio: audio, repository: repo);
    await controller.initialize();
    await tester.pumpWidget(LabApp(controller: controller));
    await tester.tap(find.text('Tune'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enter target frequency'));
    await tester.tap(find.text('Enter target frequency'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '350');
    await tester.tap(find.text('Save reference'));
    await tester.pumpAndSettle();
    expect(repo.data.references.single.frequencyHz, 350);
    expect(repo.data.references.single.origin, 'manual');
    await tester.pumpWidget(const SizedBox());
    await audio.stream.close();
  });
  testWidgets('small screen and larger text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakeAudio();
    final c = LabController(audio: audio, repository: MemoryRepository());
    await c.initialize();
    await tester.pumpWidget(LabApp(controller: c));
    for (final label in ['Measure', 'Tune', 'Wheels', 'Calibration']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await audio.stream.close();
  });
  testWidgets(
    'Kona preset requires a count, saves a rear wheel and survives editing',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final audio = FakeAudio();
      final repository = MemoryRepository();
      final c = LabController(audio: audio, repository: repository);
      await c.initialize();
      await tester.pumpWidget(LabApp(controller: c));
      await tester.tap(find.text('Wheels').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add wheel'));
      await tester.tap(find.text('Add wheel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wheel-preset')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(konaProcess165Ar35.label).last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('spoke-count')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.ensureVisible(
        find.byKey(const Key('preset-wheel-position')),
      );
      await tester.tap(find.byKey(const Key('preset-wheel-position')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rear wheel').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save-profile')));
      await tester.tap(find.byKey(const Key('save-profile')));
      await tester.pumpAndSettle();
      expect(
        repository.data.wheels.length,
        1,
      ); // Unconfirmed count blocks saving.
      await tester.ensureVisible(find.byKey(const Key('spoke-count')));
      await tester.enterText(find.byKey(const Key('spoke-count')), '32');
      await tester.ensureVisible(find.byKey(const Key('save-profile')));
      await tester.tap(find.byKey(const Key('save-profile')));
      await tester.pumpAndSettle();
      expect(repository.data.wheels.length, 2);
      expect(c.wheel.equipment!.position, 'rear');
      expect(c.wheel.equipment!.bikeYear, 2019);
      expect(c.wheel.left.diameterMm, isNull);
      expect(c.wheel.left.lengthMm, isNull);
      expect(c.wheel.right.material, 'Unknown');
      expect(c.reference, isNull);
      expect(TensionMath.forceEstimatesAvailable, isFalse);
      await tester.ensureVisible(find.byTooltip('Edit wheel profile'));
      await tester.tap(find.byTooltip('Edit wheel profile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('wheel-name')));
      await tester.enterText(
        find.byKey(const Key('wheel-name')),
        'My Kona rear',
      );
      await tester.ensureVisible(find.byKey(const Key('save-profile')));
      await tester.tap(find.byKey(const Key('save-profile')));
      await tester.pumpAndSettle();
      expect(c.wheel.name, 'My Kona rear');
      expect(c.wheel.equipment!.replacementYearApprox, 2021);
      expect(c.wheel.equipment!.position, 'rear');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await audio.stream.close();
    },
  );
}
