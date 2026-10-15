import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/app/lab_app.dart';
import 'package:spoke_lab/app/lab_controller.dart';
import 'package:spoke_lab/data/repository.dart';
import 'controller_test.dart' show FakeAudio;

void main() {
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
}
