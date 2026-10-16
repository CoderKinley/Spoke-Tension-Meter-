import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/data/models.dart';
import 'package:spoke_lab/data/repository.dart';
import 'package:spoke_lab/data/wheel_presets.dart';
import 'package:spoke_lab/core/physics/tension.dart';

void main() {
  test('custom wheel positions round-trip and scope their saved context', () {
    const front = WheelProfile(id: 'custom', name: 'Custom', position: 'front');
    const rear = WheelProfile(id: 'custom', name: 'Custom', position: 'rear');
    expect(WheelProfile.fromJson(front.toJson()).wheelPosition, 'front');
    expect(
      front.fingerprint(WheelSide.left),
      isNot(rear.fingerprint(WheelSide.left)),
    );
    expect(
      () => WheelProfile.fromJson(front.toJson()..['position'] = 'other'),
      throwsFormatException,
    );
  });
  test('legacy archives load without theoretical assumptions', () {
    final legacy = AppData.empty().toJson()..remove('idealStringSettings');
    expect(AppData.fromJson(legacy).idealSettings, isEmpty);
  });
  test('theoretical snapshots reject damaged arithmetic and provenance', () {
    const settings = IdealStringSettings(fingerprint: 'context', lengthMm: 272);
    final estimate = IdealStringEstimate(
      frequencyHz: 350,
      newtons: TensionMath.idealRound(
        frequencyHz: 350,
        lengthMeters: .272,
        diameterMeters: .002,
        densityKgM3: 7850,
      ),
      settings: settings,
    );
    expect(
      IdealStringEstimate.fromJson(estimate.toJson()).newtons,
      estimate.newtons,
    );
    for (final change in <String, dynamic>{
      'newtons': 100,
      'validation': 'validated',
      'frequencyHz': 351,
    }.entries) {
      expect(
        () => IdealStringEstimate.fromJson(
          estimate.toJson()..[change.key] = change.value,
        ),
        throwsFormatException,
      );
    }
    expect(
      () => IdealStringSettings.fromJson(settings.toJson()..['lengthMm'] = 0),
      throwsFormatException,
    );
    final reading = SpokeReading(
      id: 'r',
      wheelId: 'first-wheel',
      side: WheelSide.left,
      spokeIndex: 1,
      frequencyHz: 350,
      spreadPercent: 0,
      plucks: 3,
      createdAt: DateTime(2026),
      fingerprint: 'context',
      mode: 'individual/fundamental',
      captureSource: 'test',
      sessionId: 's',
      idealEstimate: estimate,
    );
    final data = AppData.empty().copyWith(
      readings: [reading],
      idealSettings: [settings],
    );
    expect(AppData.fromJson(data.toJson()).idealSettings.single.lengthMm, 272);
    for (final change in <String, dynamic>{
      'frequencyHz': 351,
      'fingerprint': 'other',
      'mode': 'coupled/fundamental',
      'plucks': 2,
    }.entries) {
      final json = data.toJson();
      (json['readings'] as List).single[change.key] = change.value;
      expect(() => AppData.fromJson(json), throwsFormatException);
    }
  });
  test(
    'local storage survives restart and maintains a previous snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp('spokelab-test-');
      try {
        final repo = LocalRepository(directory);
        await repo.save(AppData.empty());
        final updated = AppData(
          wheels: [
            const WheelProfile(
              id: 'wheel-2',
              name: 'Road wheel',
              tireState: '40 psi',
            ),
          ],
        );
        await repo.save(updated);
        expect(
          (await LocalRepository(directory).load()).wheels.single.name,
          'Road wheel',
        );
        final backup = jsonDecode(
          await File('${directory.path}/spoke_lab.backup.json').readAsString(),
        );
        expect(backup['wheels'][0]['id'], 'first-wheel');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
  test('corrupt data is surfaced and remains untouched', () async {
    final directory = await Directory.systemTemp.createTemp(
      'spokelab-corrupt-',
    );
    try {
      final file = File('${directory.path}/spoke_lab.json');
      await file.writeAsString('{broken');
      await expectLater(
        LocalRepository(directory).load(),
        throwsFormatException,
      );
      expect(await file.readAsString(), '{broken');
    } finally {
      await directory.delete(recursive: true);
    }
  });
  test('unsupported version cannot silently reset data', () {
    expect(
      () => AppData.fromJson({'schemaVersion': 99}),
      throwsFormatException,
    );
  });
  test(
    'equipment preset survives storage without inventing spoke geometry',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'spokelab-preset-',
      );
      try {
        final wheel = WheelProfile(
          id: 'kona-front',
          name: konaProcess165Ar35.wheelName('front'),
          spokeCount: 32, // Explicitly supplied by the wheel owner.
          equipment: konaProcess165Ar35.equipmentFor('front'),
        );
        final repository = LocalRepository(directory);
        await repository.save(AppData(wheels: [wheel]));
        final restored = (await repository.load()).wheels.single;
        expect(restored.equipment!.bikeYear, 2019);
        expect(restored.equipment!.replacementYearApprox, 2021);
        expect(restored.equipment!.rimModel, 'Race Face AR35');
        expect(restored.equipment!.diameterInches, 27.5);
        expect(restored.left.lengthMm, isNull);
        expect(restored.left.diameterMm, isNull);
        expect(restored.right.material, 'Unknown');
        expect(
          restored.fingerprint(WheelSide.left),
          wheel.fingerprint(WheelSide.left),
        );
        expect((await repository.load()).references, isEmpty);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'legacy profiles keep their fingerprints and front/rear stay distinct',
    () {
      final legacy = AppData.empty().wheels.single;
      final oldJson = legacy.toJson()..remove('equipment');
      final restored = WheelProfile.fromJson(oldJson);
      expect(restored.equipment, isNull);
      expect(
        restored.fingerprint(WheelSide.left),
        legacy.fingerprint(WheelSide.left),
      );
      expect(
        jsonDecode(restored.fingerprint(WheelSide.left)),
        isNot(contains('equipment')),
      );
      final front = WheelProfile(
        id: 'same-id',
        name: 'Wheel',
        equipment: konaProcess165Ar35.equipmentFor('front'),
      );
      final rear = WheelProfile(
        id: 'same-id',
        name: 'Wheel',
        equipment: konaProcess165Ar35.equipmentFor('rear'),
      );
      expect(
        front.fingerprint(WheelSide.left),
        isNot(rear.fingerprint(WheelSide.left)),
      );
    },
  );
}
