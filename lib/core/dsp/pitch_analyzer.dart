import 'dart:math' as math;
import 'dart:typed_data';

/// A top-level entrypoint keeps UI and stream objects out of isolate messages.
PitchResult analyzePluckRequest((List<double>, int) request) =>
    analyzePluck(request.$1, request.$2);

enum PitchKind { fundamental, spectralPeak, rejected }

class PitchResult {
  const PitchResult({
    required this.kind,
    this.frequencyHz,
    required this.message,
    this.spectrum = const [],
    this.rms = 0,
  });
  final PitchKind kind;
  final double? frequencyHz;
  final String message;
  final List<double> spectrum;
  final double rms;
  bool get accepted => kind != PitchKind.rejected && frequencyHz != null;
}

/// Radix-2 FFT. Independently checked against a direct DFT in tests.
List<double> magnitudeSpectrum(List<double> samples) {
  final n = samples.length;
  if (n < 2 || (n & (n - 1)) != 0) {
    throw ArgumentError('FFT length must be a power of two');
  }
  final real = Float64List.fromList(samples), imag = Float64List(n);
  for (int i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    while ((j & bit) != 0) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
    if (i < j) {
      final v = real[i];
      real[i] = real[j];
      real[j] = v;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final angle = -2 * math.pi / len;
    final wr0 = math.cos(angle), wi0 = math.sin(angle);
    for (var offset = 0; offset < n; offset += len) {
      var wr = 1.0, wi = 0.0;
      for (var j = 0; j < len ~/ 2; j++) {
        final a = offset + j, b = a + len ~/ 2;
        final vr = real[b] * wr - imag[b] * wi,
            vi = real[b] * wi + imag[b] * wr;
        real[b] = real[a] - vr;
        imag[b] = imag[a] - vi;
        real[a] += vr;
        imag[a] += vi;
        final next = wr * wr0 - wi * wi0;
        wi = wr * wi0 + wi * wr0;
        wr = next;
      }
    }
  }
  return List.generate(
    n ~/ 2 + 1,
    (i) => math.sqrt(real[i] * real[i] + imag[i] * imag[i]),
  );
}

class PitchAnalyzer {
  static const minHz = 80.0, maxHz = 2500.0;
  PitchResult analyze(List<double> input, int sampleRate) {
    if (input.length != 8192 ||
        sampleRate < 8000 ||
        sampleRate > 96000 ||
        input.any((x) => !x.isFinite)) {
      return const PitchResult(
        kind: PitchKind.rejected,
        message: 'Incomplete audio. Pluck again.',
      );
    }
    final mean = input.reduce((a, b) => a + b) / input.length;
    final x = List<double>.generate(input.length, (i) => input[i] - mean);
    final rms = math.sqrt(x.fold<double>(0, (s, v) => s + v * v) / x.length);
    if (input.where((v) => v.abs() >= 0.985).length > input.length * .001) {
      return const PitchResult(
        kind: PitchKind.rejected,
        message: 'Sound clipped. Pluck more gently or move the phone back.',
      );
    }
    if (rms < .002) {
      return const PitchResult(
        kind: PitchKind.rejected,
        message: 'Sound too quiet. Move the microphone closer.',
      );
    }
    final window = List<double>.generate(
      x.length,
      (i) => x[i] * (.5 - .5 * math.cos(2 * math.pi * i / (x.length - 1))),
    );
    final spectrum = magnitudeSpectrum(window);
    final low = (minHz * x.length / sampleRate).ceil();
    final high = math.min(
      (8000 * x.length / sampleRate).floor(),
      spectrum.length - 2,
    );
    final peaks = <int>[];
    for (var i = low; i < high; i++) {
      if (spectrum[i] > spectrum[i - 1] && spectrum[i] >= spectrum[i + 1]) {
        peaks.add(i);
      }
    }
    peaks.sort((a, b) => spectrum[b].compareTo(spectrum[a]));
    if (peaks.isEmpty) {
      return const PitchResult(
        kind: PitchKind.rejected,
        message: 'No clear resonance. Pluck again.',
      );
    }
    final maxAmplitude = spectrum[peaks.first];
    final bins = List<double>.generate(96, (i) {
      final bin = (i * 4000 / sampleRate * x.length / 95).round().clamp(
        0,
        spectrum.length - 1,
      );
      return (spectrum[bin] / maxAmplitude).clamp(0, 1);
    });
    PitchResult reject(String message) => PitchResult(
      kind: PitchKind.rejected,
      message: message,
      spectrum: bins,
      rms: rms,
    );
    double peakHz(int k) {
      final a = math.log(math.max(spectrum[k - 1], 1e-12));
      final b = math.log(math.max(spectrum[k], 1e-12));
      final c = math.log(math.max(spectrum[k + 1], 1e-12));
      final denominator = a - 2 * b + c;
      final delta = denominator.abs() < 1e-12
          ? 0.0
          : (.5 * (a - c) / denominator).clamp(-.5, .5);
      return (k + delta) * sampleRate / x.length;
    }

    final dominant = peakHz(peaks.first), fYin = _yin(x, sampleRate);
    if (fYin == null) {
      return reject(
        'Unstable or overlapping tones. Pluck one spoke and let it decay.',
      );
    }
    final significant = peaks
        .where((k) => spectrum[k] > maxAmplitude * .12)
        .take(12)
        .toList();
    final matching = <int>{};
    for (final k in significant) {
      final ratio = peakHz(k) / fYin;
      final harmonic = ratio.round();
      if (harmonic >= 1 &&
          harmonic <= 12 &&
          (ratio - harmonic).abs() < .035 * harmonic) {
        matching.add(harmonic);
      } else if (spectrum[k] > maxAmplitude * .3) {
        return reject(
          'More than one resonance family. Check neighbouring spokes.',
        );
      }
    }
    if (fYin <= minHz * 1.015 || fYin >= maxHz * .985) {
      return reject('Frequency at the measurement limit. Result not accepted.');
    }
    if (matching.length < 2) {
      if (dominant < minHz ||
          dominant > maxHz ||
          (dominant / fYin - 1).abs() > .025) {
        return reject('Fundamental and overtone disagree. Pluck again.');
      }
      return PitchResult(
        kind: PitchKind.spectralPeak,
        frequencyHz: dominant,
        message: 'Stable spectral peak; fundamental not confirmed.',
        spectrum: bins,
        rms: rms,
      );
    }
    if (!matching.contains(1) &&
        !(matching.contains(2) && matching.contains(3))) {
      return reject('Missing fundamental is ambiguous. Pluck again.');
    }
    return PitchResult(
      kind: PitchKind.fundamental,
      frequencyHz: fYin,
      message: matching.contains(1)
          ? 'Frequency supported by harmonics.'
          : 'Fundamental inferred from harmonics.',
      spectrum: bins,
      rms: rms,
    );
  }

  double? _yin(List<double> x, int rate) {
    final maxLag = (rate / minHz).ceil();
    final minLag = (rate / maxHz).floor().clamp(2, maxLag);
    final diff = Float64List(maxLag + 1);
    const window = 4096;
    var running = 0.0;
    diff[0] = 1;
    for (var tau = 1; tau <= maxLag; tau++) {
      var sum = 0.0;
      for (var i = 0; i < window; i++) {
        final d = x[i] - x[i + tau];
        sum += d * d;
      }
      running += sum;
      diff[tau] = running > 0 ? sum * tau / running : 1;
    }
    for (var tau = minLag; tau < maxLag - 1; tau++) {
      if (diff[tau] < .12) {
        while (tau + 1 < maxLag && diff[tau + 1] < diff[tau]) {
          tau++;
        }
        if (tau >= maxLag) {
          return null;
        }
        final denominator = diff[tau - 1] - 2 * diff[tau] + diff[tau + 1];
        final delta = denominator.abs() < 1e-12
            ? 0.0
            : (.5 * (diff[tau - 1] - diff[tau + 1]) / denominator).clamp(
                -.5,
                .5,
              );
        return rate / (tau + delta);
      }
    }
    return null;
  }
}

PitchResult analyzePluck(List<double> samples, int rate) {
  if (samples.length < 16384) {
    return const PitchResult(
      kind: PitchKind.rejected,
      message: 'Incomplete pluck.',
    );
  }
  final analyzer = PitchAnalyzer();
  final first = analyzer.analyze(samples.sublist(0, 8192), rate);
  if (!first.accepted) {
    return first;
  }
  final second = analyzer.analyze(samples.sublist(8192, 16384), rate);
  if (!second.accepted ||
      (first.frequencyHz! / second.frequencyHz! - 1).abs() > .015) {
    return PitchResult(
      kind: PitchKind.rejected,
      message: 'Tone changed or decayed too quickly. Try another gentle pluck.',
      spectrum: first.spectrum,
    );
  }
  return first;
}
