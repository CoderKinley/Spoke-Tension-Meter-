import 'dart:math' as math;
import 'pitch_analyzer.dart';

PitchResult analyzeLiveRequest((List<double>, int) request) =>
    analyzeLiveFrame(request.$1, request.$2);

/// A short, clean decay can still be mapped as frequency-only. It must never
/// inherit the two-window confirmation required for a tension estimate.
PitchResult analyzeMappingPluckRequest((List<double>, int) request) {
  final samples = request.$1, rate = request.$2;
  final strict = analyzePluck(samples, rate);
  if (strict.accepted ||
      samples.length < 16384 ||
      samples.any((v) => !v.isFinite) ||
      samples.where((v) => v.abs() >= .985).length > samples.length * .001) {
    return strict;
  }
  double rms(List<double> values) =>
      math.sqrt(values.fold<double>(0, (s, v) => s + v * v) / values.length);
  final first = samples.sublist(0, 8192), second = samples.sublist(8192, 16384);
  if (rms(second) >= rms(first) * .25) return strict;
  final quick = analyzeLiveFrame(first, rate);
  if (!quick.accepted || quick.frequencyHz! < 80 || quick.frequencyHz! > 2500) {
    return strict;
  }
  return PitchResult(
    kind: PitchKind.spectralPeak,
    frequencyHz: quick.frequencyHz,
    message: 'Short decay · frequency only; repeat to map this spoke.',
    spectrum: quick.spectrum,
    rms: quick.rms,
  );
}

/// One rolling window for immediate feedback. Never counts as a saved pluck.
/// A fallback peak is explicitly not a confirmed fundamental.
PitchResult analyzeLiveFrame(List<double> input, int rate) {
  final checked = PitchAnalyzer().analyze(input, rate);
  if (checked.accepted) return checked;
  if (input.length != 8192 ||
      rate < 8000 ||
      rate > 96000 ||
      input.any((v) => !v.isFinite) ||
      input.where((v) => v.abs() >= .985).length > input.length * .001) {
    return checked;
  }
  final mean = input.reduce((a, b) => a + b) / input.length;
  final centered = input.map((v) => v - mean).toList();
  final rms = math.sqrt(
    centered.fold<double>(0, (s, v) => s + v * v) / input.length,
  );
  if (rms < .00003) return checked;
  final spectrum = magnitudeSpectrum(
    List.generate(
      input.length,
      (i) =>
          centered[i] *
          (.5 - .5 * math.cos(2 * math.pi * i / (input.length - 1))),
    ),
  );
  final low = math.max(2, (50 * input.length / rate).ceil());
  final high = math.min(
    spectrum.length - 2,
    (3000 * input.length / rate).floor(),
  );
  final peaks = <int>[];
  for (var k = low; k <= high; k++) {
    if (spectrum[k] > spectrum[k - 1] && spectrum[k] >= spectrum[k + 1]) {
      peaks.add(k);
    }
  }
  if (peaks.isEmpty) return checked;
  peaks.sort((a, b) => spectrum[b].compareTo(spectrum[a]));
  final peak = peaks.first;
  final ordered = spectrum.sublist(low, high + 1)..sort();
  final floor = ordered[ordered.length ~/ 2];
  final totalPower = spectrum
      .sublist(low, high + 1)
      .fold<double>(0, (s, v) => s + v * v);
  final peakPower = [
    peak - 1,
    peak,
    peak + 1,
  ].fold<double>(0, (s, k) => s + spectrum[k] * spectrum[k]);
  if (spectrum[peak] < math.max(1e-8, floor * 10) ||
      peakPower < totalPower * .2) {
    return checked;
  }
  // Do not turn a rejected mixture of two strong tones into a confident peak.
  for (final k
      in peaks.skip(1).where((k) => spectrum[k] > spectrum[peak] * .4)) {
    final ratio = math.max(k, peak) / math.min(k, peak);
    if ((ratio - ratio.round()).abs() > .035 * ratio) return checked;
  }
  final a = math.log(math.max(spectrum[peak - 1], 1e-12));
  final b = math.log(math.max(spectrum[peak], 1e-12));
  final c = math.log(math.max(spectrum[peak + 1], 1e-12));
  final denominator = a - 2 * b + c;
  final offset = denominator.abs() < 1e-12
      ? 0.0
      : (.5 * (a - c) / denominator).clamp(-.5, .5);
  final hz = (peak + offset) * rate / input.length;
  if (hz < 50 || hz > 3000) return checked;
  return PitchResult(
    kind: PitchKind.spectralPeak,
    frequencyHz: hz,
    message: 'Live spectral peak; fundamental not confirmed.',
    rms: rms,
    spectrum: List.generate(96, (i) {
      final k = (i * 4000 / rate * input.length / 95).round().clamp(
        0,
        spectrum.length - 1,
      );
      return (spectrum[k] / spectrum[peak]).clamp(0, 1);
    }),
  );
}
