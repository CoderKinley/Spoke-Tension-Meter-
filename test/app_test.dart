import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/app/lab_app.dart';
import 'package:spoke_lab/app/lab_controller.dart';
import 'package:spoke_lab/data/repository.dart';
import 'package:spoke_lab/core/physics/tension.dart';
import 'package:spoke_lab/data/wheel_presets.dart';
import 'controller_test.dart' show FakeAudio;

void main() {
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
