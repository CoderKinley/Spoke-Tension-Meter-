import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/app/lab_controller.dart';
import 'package:spoke_lab/core/audio/audio_source.dart';
import 'package:spoke_lab/core/dsp/pitch_analyzer.dart';
import 'package:spoke_lab/data/models.dart';
import 'package:spoke_lab/data/repository.dart';
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
