import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/app/lab_controller.dart';
import 'package:spoke_lab/core/audio/audio_source.dart';
import 'package:spoke_lab/core/dsp/pitch_analyzer.dart';
import 'package:spoke_lab/data/models.dart';
import 'package:spoke_lab/data/repository.dart';
import 'package:spoke_lab/data/wheel_presets.dart';
import 'package:spoke_lab/core/physics/tension.dart';
import 'dsp_test.dart' show signal;

class FakeAudio implements AudioSource {
  final stream = StreamController<AudioPacket>.broadcast();
  int stops = 0;
  @override
  Stream<AudioPacket> get packets => stream.stream;
  @override
  Future<String> start() async => 'test-device';
  @override
  Future<void> stop() async {
    stops++;
  }
}

void pluck(LabController c, double hz) => c.acceptAnalysis(
  PitchResult(kind: PitchKind.fundamental, frequencyHz: hz, message: 'test'),
);

WheelProfile konaWheel({
  String id = 'kona',
  String position = 'rear',
  SpokeSpec spec = const SpokeSpec(contact: ContactMode.individual),
}) => WheelProfile(
  id: id,
  name: 'My Kona',
  equipment: konaProcess165Ar35.equipmentFor(position),
  left: spec,
  right: spec,
);

void main() {
  late LabController c;
  late MemoryRepository repo;
  late FakeAudio audio;
  setUp(() async {
    repo = MemoryRepository();
    audio = FakeAudio();
    c = LabController(audio: audio, repository: repo);
    await c.initialize();
  });
  tearDown(() async {
    c.dispose();
    await audio.stream.close();
  });
  test(
    'Kona model starts fresh and saves an unvalidated assumption snapshot',
    () async {
      await c.saveWheel(konaWheel());
      for (var i = 0; i < 3; i++) {
        pluck(c, 350);
      }
      expect(c.idealEstimate, isNull);
      expect(await c.configureIdealString(272), isTrue);
      expect(c.pluckCount, 0);
      for (var i = 0; i < 2; i++) {
        pluck(c, 350);
      }
      expect(c.idealEstimate, isNull);
      pluck(c, 350);
      expect(c.idealEstimate!.newtons, closeTo(894.03272833218, 1e-9));
      expect(TensionMath.forceEstimatesAvailable, isFalse);
      expect(await c.saveReading(), isTrue);
      final restored = AppData.fromJson(repo.data.toJson());
      final estimate = restored.readings.single.idealEstimate!;
      expect(estimate.settings.lengthMm, 272);
      expect(estimate.frequencyHz, restored.readings.single.frequencyHz);
      expect(
        estimate.settings.fingerprint,
        restored.readings.single.fingerprint,
      );
      final csv = readingsCsv(restored);
      expect(csv, contains('theoretical_newtons'));
      expect(csv, contains('unvalidated-ideal-string'));
      expect(csv, contains(IdealStringSettings.basis));
      await c.disableIdealString();
      expect(c.idealSettings, isNull);
      expect(repo.data.readings.single.idealEstimate, isNotNull);
    },
  );
  test(
    'model assumptions stay scoped to wheel, side and configuration',
    () async {
      await c.saveWheel(konaWheel());
      await c.configureIdealString(272.5);
      await c.select(selectedSide: WheelSide.right);
      expect(c.idealSettings, isNull);
      await c.select(selectedSide: WheelSide.left);
      expect(c.idealSettings!.lengthMm, 272.5);
      await c.saveWheel(konaWheel(position: 'front'));
      expect(c.idealSettings, isNull);
      await c.saveWheel(konaWheel(id: 'other-wheel'));
      expect(c.idealSettings, isNull);
      await c.saveWheel(
        konaWheel(
          spec: const SpokeSpec(diameterMm: 2, contact: ContactMode.individual),
        ),
      );
      expect(c.idealSettings, isNull);
    },
  );
  test(
    'unsupported contacts and section data cannot produce tension',
    () async {
      for (final spec in [
        const SpokeSpec(contact: ContactMode.coupled),
        const SpokeSpec(),
        const SpokeSpec(material: 'Aluminum', contact: ContactMode.individual),
        const SpokeSpec(shape: 'Butted', contact: ContactMode.individual),
        const SpokeSpec(shape: 'Bladed', contact: ContactMode.individual),
        const SpokeSpec(diameterMm: 1.8, contact: ContactMode.individual),
        const SpokeSpec(
          buttProfile: '2/1.8/2',
          contact: ContactMode.individual,
        ),
      ]) {
        await c.saveWheel(konaWheel(spec: spec));
        await c.configureIdealString(272);
        for (var i = 0; i < 3; i++) {
          pluck(c, 350);
        }
        expect(c.canSave, isTrue);
        expect(c.idealEstimate, isNull, reason: spec.toJson().toString());
        expect(await c.saveReading(), isTrue);
        expect(repo.data.readings.last.idealEstimate, isNull);
      }
    },
  );
  test(
    'spectral peaks, rejection and inconsistent repeats retain frequency-only behavior',
    () async {
      await c.saveWheel(konaWheel());
      await c.configureIdealString(272);
      for (var i = 0; i < 3; i++) {
        c.acceptAnalysis(
          const PitchResult(
            kind: PitchKind.spectralPeak,
            frequencyHz: 350,
            message: 'peak',
          ),
        );
      }
      expect(c.canSave, isTrue);
      expect(c.idealEstimate, isNull);
      pluck(c, 350); // A mode change restarts the set.
      expect(c.pluckCount, 1);
      pluck(c, 350);
      pluck(c, 350);
      expect(c.idealEstimate, isNotNull);
      c.acceptAnalysis(
        const PitchResult(kind: PitchKind.rejected, message: 'ambiguous'),
      );
      expect(c.idealEstimate, isNull);
      pluck(c, 350);
      pluck(c, 450);
      pluck(c, 350);
      expect(c.idealEstimate, isNull);
    },
  );
  test(
    'invalid lengths and non-Kona profiles cannot enable the model',
    () async {
      expect(await c.configureIdealString(272), isFalse);
      await c.saveWheel(konaWheel());
      for (final length in [0.0, -1.0, 501.0, double.nan, double.infinity]) {
        expect(await c.configureIdealString(length), isFalse);
      }
      expect(repo.data.idealSettings, isEmpty);
      expect(
        await c.saveWheel(
          konaWheel(spec: const SpokeSpec(diameterMm: double.nan)),
        ),
        isFalse,
      );
    },
  );
  test('three repeats save a reading, five save a reference', () async {
    pluck(c, 350);
    pluck(c, 351);
    expect(c.canSave, isFalse);
    pluck(c, 350);
    expect(c.canSave, isTrue);
    expect(c.canReference, isFalse);
    pluck(c, 349);
    pluck(c, 350);
    expect(await c.saveReference('Baseline'), isTrue);
    expect(c.reference!.plucks, 5);
    expect(await c.saveReading(), isTrue);
    expect(repo.data.readings.single.frequencyHz, 350);
    expect(c.spokeIndex, 2);
  });
  test('rejected audio clears a previously accepted frequency', () {
    pluck(c, 350);
    pluck(c, 350);
    pluck(c, 350);
    expect(c.canSave, isTrue);
    c.acceptAnalysis(
      const PitchResult(kind: PitchKind.rejected, message: 'ambiguous'),
    );
    expect(c.frequencyHz, isNull);
    expect(c.canSave, isFalse);
  });
  test('inconsistent repeat set cannot be saved', () {
    pluck(c, 350);
    pluck(c, 400);
    pluck(c, 350);
    expect(c.canSave, isFalse);
  });
  test('reference cannot cross side or changed geometry', () async {
    await c.saveReference('Manual', manualHz: 350);
    expect(c.reference, isNotNull);
    await c.select(selectedSide: WheelSide.right);
    expect(c.reference, isNull);
    await c.select(selectedSide: WheelSide.left);
    expect(c.reference, isNotNull);
    await c.saveWheel(
      WheelProfile(
        id: c.wheel.id,
        name: 'Changed',
        left: const SpokeSpec(diameterMm: 2),
      ),
    );
    expect(c.reference, isNull);
    expect(c.data.references.length, 1);
  });
  test('audio interruption discards the display', () async {
    await c.start();
    pluck(c, 350);
    audio.stream.addError(StateError('disconnected'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.listening, isFalse);
    expect(c.frequencyHz, isNull);
    expect(c.error, contains('disconnected'));
  });
  test('manual invalid frequencies are not persisted', () async {
    expect(await c.saveReference('bad', manualHz: double.nan), isFalse);
    expect(repo.data.references, isEmpty);
  });
  test('PCM16 decoding preserves sign and scale', () {
    final bytes = Uint8List.fromList([0, 128, 255, 127, 0, 0]);
    final packet = AudioPacket.fromEvent({
      'pcm': bytes,
      'sampleRate': 48000,
      'sequence': 0,
    });
    expect(packet.samples, [-1, 32767 / 32768, 0]);
    expect(
      () => AudioPacket.fromEvent({'pcm': Uint8List(1)}),
      throwsFormatException,
    );
  });
  test('packet gaps invalidate measurements', () async {
    await c.start();
    pluck(c, 350);
    audio.stream.add(AudioPacket(List.filled(2048, 0), 48000, 0));
    audio.stream.add(AudioPacket(List.filled(2048, 0), 48000, 2));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.listening, isFalse);
    expect(c.frequencyHz, isNull);
    expect(c.error, contains('buffers were lost'));
  });
  test('stream closure discards the previous frequency', () async {
    await c.start();
    pluck(c, 350);
    await audio.stream.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.frequencyHz, isNull);
    expect(c.listening, isFalse);
  });
  test(
    'streamed plucks pass onset, isolate analysis and repeat gating',
    () async {
      await c.start();
      var sequence = 0;
      Future<void> send(List<double> samples) async {
        for (var offset = 0; offset < samples.length; offset += 2048) {
          audio.stream.add(
            AudioPacket(
              samples.sublist(offset, (offset + 2048).clamp(0, samples.length)),
              48000,
              sequence++,
            ),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      await send(List.filled(16384, 0));
      for (var repeat = 1; repeat <= 3; repeat++) {
        await send(signal(350, count: 18432, decay: 3));
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (c.pluckCount < repeat &&
            c.error == null &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(c.error, isNull);
        expect(c.pluckCount, repeat, reason: c.status);
        await send(List.filled(8192, 0));
      }
      expect(c.frequencyHz, closeTo(350, 3.5));
      expect(c.canSave, isTrue);
      expect(await c.saveReading(), isTrue);
      expect(repo.data.readings.single.captureSource, 'test-device');
    },
  );
}
