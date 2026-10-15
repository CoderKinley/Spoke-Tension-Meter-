import 'dart:math' as math;
import '../../data/models.dart';

/// Research mathematics. No physically validated force profiles ship in v0.1.
class TensionMath {
  static const newtonsPerKgf = 9.80665;
  static double idealRound({
    required double frequencyHz,
    required double lengthMeters,
    required double diameterMeters,
    required double densityKgM3,
  }) {
    for (final value in [
      frequencyHz,
      lengthMeters,
      diameterMeters,
      densityKgM3,
    ]) {
      if (!value.isFinite || value <= 0) {
        throw ArgumentError('Inputs must be positive and finite');
      }
    }
    final mu = densityKgM3 * math.pi * diameterMeters * diameterMeters / 4;
    return 4 * mu * lengthMeters * lengthMeters * frequencyHz * frequencyHz;
  }

  static double cents(double frequencyHz, double referenceHz) {
    if (!frequencyHz.isFinite ||
        !referenceHz.isFinite ||
        frequencyHz <= 0 ||
        referenceHz <= 0) {
      throw ArgumentError('Invalid frequency');
    }
    return 1200 * math.log(frequencyHz / referenceHz) / math.ln2;
  }

  // User-entered points alone never constitute independent physical validation.
  static bool get forceEstimatesAvailable => false;
}

class CalibrationFit {
  const CalibrationFit(
    this.slope,
    this.intercept,
    this.minHz,
    this.maxHz,
    this.trainingErrorPercent,
  );
  final double slope, intercept, minHz, maxHz, trainingErrorPercent;
  static CalibrationFit fit(List<CalibrationPoint> points) {
    if (points.length < 5 ||
        points.map((p) => p.fingerprint).toSet().length != 1) {
      throw ArgumentError(
        'Use at least five points from the same configuration',
      );
    }
    if (points.any(
      (p) =>
          !p.frequencyHz.isFinite ||
          p.frequencyHz <= 0 ||
          !p.tensionNewtons.isFinite ||
          p.tensionNewtons <= 0 ||
          p.instrument.trim().isEmpty,
    )) {
      throw ArgumentError('Invalid calibration point');
    }
    if (points.map((p) => p.frequencyHz).toSet().length < 5) {
      throw ArgumentError('Five distinct frequencies required');
    }
    final xs = points.map((p) => p.frequencyHz * p.frequencyHz).toList();
    final mx = xs.reduce((a, b) => a + b) / xs.length;
    final my =
        points.map((p) => p.tensionNewtons).reduce((a, b) => a + b) /
        points.length;
    var numerator = 0.0, denominator = 0.0;
    for (var i = 0; i < points.length; i++) {
      numerator += (xs[i] - mx) * (points[i].tensionNewtons - my);
      denominator += (xs[i] - mx) * (xs[i] - mx);
    }
    final slope = numerator / denominator,
        intercept = my - numerator / denominator * mx;
    if (!slope.isFinite || slope <= 0 || !intercept.isFinite) {
      throw ArgumentError('Nonphysical fit');
    }
    final errors = List.generate(
      points.length,
      (i) =>
          ((slope * xs[i] + intercept - points[i].tensionNewtons) /
                  points[i].tensionNewtons)
              .abs() *
          100,
    );
    final frequencies = points.map((p) => p.frequencyHz).toList()..sort();
    return CalibrationFit(
      slope,
      intercept,
      frequencies.first,
      frequencies.last,
      errors.reduce((a, b) => a + b) / errors.length,
    );
  }

  double estimateForResearch(double hz) {
    if (!hz.isFinite || hz < minHz || hz > maxHz) {
      throw RangeError('Extrapolation is disabled');
    }
    final force = slope * hz * hz + intercept;
    if (force <= 0) {
      throw StateError('Nonphysical prediction');
    }
    return force;
  }
}
