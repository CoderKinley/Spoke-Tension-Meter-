import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/core/dsp/pitch_analyzer.dart';
import 'package:spoke_lab/core/dsp/live_pitch.dart';

List<double> signal(
  double hz, {
  int rate = 48000,
  int count = 8192,
  List<double> harmonics = const [.3, .15, .08],
  double decay = 0,
}) => List.generate(count, (i) {
  var v = 0.0;
  for (var h = 0; h < harmonics.length; h++) {
    v += harmonics[h] * math.sin(2 * math.pi * hz * (h + 1) * i / rate);
  }
  return v * math.exp(-decay * i / rate);
});

void main() {
  test('short clean plucks can map frequency without force confirmation', () {
    final samples = signal(
      350,
      count: 16384,
      decay: 30,
      harmonics: [.005, .0025, .0012],
    );
    expect(analyzePluck(samples, 48000).accepted, isFalse);
    final mapped = analyzeMappingPluckRequest((samples, 48000));
    expect(mapped.kind, PitchKind.spectralPeak, reason: mapped.message);
    expect(mapped.frequencyHz, closeTo(350, 3.5));
    expect(
      analyzeMappingPluckRequest((
        [...signal(350), ...signal(440)],
        48000,
      )).accepted,
      isFalse,
    );
  });
  for (final rate in [44100, 48000]) {
    test('quiet PCM16 harmonic pluck has a live frequency at $rate Hz', () {
      final random = math.Random(10);
      final input =
          signal(350, rate: rate, harmonics: [.0006, .0003, .00015], decay: 12)
              .map(
                (v) =>
                    ((v + (random.nextDouble() - .5) * .00004) * 32768)
                        .round() /
                    32768,
              )
              .toList();
      final result = analyzeLiveFrame(input, rate);
      expect(result.accepted, isTrue, reason: result.message);
      expect(result.frequencyHz, closeTo(350, 3.5));
    });
  }
  test('live pitch covers 50–3000 Hz without extending the tension range', () {
    for (final hz in [55.0, 2800.0]) {
      final result = analyzeLiveFrame(signal(hz, harmonics: [.001]), 48000);
      expect(result.kind, PitchKind.spectralPeak, reason: result.message);
      expect(result.frequencyHz, closeTo(hz, 2));
      expect(
        PitchAnalyzer().analyze(signal(hz, harmonics: [.001]), 48000).accepted,
        isFalse,
      );
    }
  });
  test('live analysis rejects quiet noise, clipping and unrelated tones', () {
    final random = math.Random(94);
    final a = signal(350, harmonics: [.001]);
    final b = signal(467, harmonics: [.001]);
    for (final input in [
      List<double>.filled(8192, 0),
      List.generate(8192, (_) => (random.nextDouble() - .5) * .001),
      signal(350, harmonics: [1.5]),
      List.generate(8192, (i) => a[i] + b[i]),
    ]) {
      expect(analyzeLiveFrame(input, 48000).accepted, isFalse);
    }
  });
  test('FFT agrees with independent DFT', () {
    final samples = [.2, .4, -.3, .1, .8, -.6, .2, 0.0];
    final spectrum = magnitudeSpectrum(samples);
    for (var k = 0; k < spectrum.length; k++) {
      var re = 0.0, im = 0.0;
      for (var n = 0; n < samples.length; n++) {
        re += samples[n] * math.cos(-2 * math.pi * k * n / samples.length);
        im += samples[n] * math.sin(-2 * math.pi * k * n / samples.length);
      }
      expect(spectrum[k], closeTo(math.sqrt(re * re + im * im), 1e-10));
    }
  });
  for (final rate in [44100, 48000]) {
    for (final frequency in [100.3, 220.5, 350.0, 700.8, 1400.0, 2200.0]) {
      test('harmonic tone $frequency Hz at $rate Hz', () {
        final result = PitchAnalyzer().analyze(
          signal(frequency, rate: rate),
          rate,
        );
        expect(result.kind, PitchKind.fundamental, reason: result.message);
        expect(result.frequencyHz, closeTo(frequency, frequency * .01));
      });
    }
  }
  test('louder second harmonic does not become the fundamental', () {
    final result = PitchAnalyzer().analyze(
      signal(350, harmonics: [.08, .5, .12]),
      48000,
    );
    expect(result.frequencyHz, closeTo(350, 3.5));
    expect(result.kind, PitchKind.fundamental);
  });
  test('missing fundamental supported by second and third harmonics', () {
    final result = PitchAnalyzer().analyze(
      signal(350, harmonics: [0, .4, .25]),
      48000,
    );
    expect(result.frequencyHz, closeTo(350, 3.5));
  });
  test('single sinusoid is labelled spectral peak only', () {
    final result = PitchAnalyzer().analyze(signal(350, harmonics: [.4]), 48000);
    expect(result.kind, PitchKind.spectralPeak);
    expect(result.frequencyHz, closeTo(350, 1));
  });
  test('silence, clipping, noise and malformed samples are rejected', () {
    final random = math.Random(42);
    for (final samples in [
      List<double>.filled(8192, 0),
      signal(350, harmonics: [1.5]),
      List.generate(8192, (_) => random.nextDouble() * .8 - .4),
      [.1, .2],
      List<double>.filled(8192, double.nan),
    ]) {
      expect(PitchAnalyzer().analyze(samples, 48000).kind, PitchKind.rejected);
    }
  });
  test('unrelated simultaneous tones are rejected', () {
    final a = signal(350, harmonics: [.3]), b = signal(467, harmonics: [.3]);
    expect(
      PitchAnalyzer()
          .analyze(List.generate(a.length, (i) => a[i] + b[i]), 48000)
          .accepted,
      isFalse,
    );
  });
  test('two windows must agree and decay must be sufficient', () {
    expect(
      analyzePluck(signal(350, count: 16384, decay: 3), 48000).accepted,
      isTrue,
    );
    expect(
      analyzePluck([...signal(350), ...signal(440)], 48000).accepted,
      isFalse,
    );
  });
}
