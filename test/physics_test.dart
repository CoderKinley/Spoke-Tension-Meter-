import 'package:flutter_test/flutter_test.dart';
import 'package:spoke_lab/core/physics/tension.dart';
import 'package:spoke_lab/data/models.dart';

void main() {
  test('SI calculation matches independently computed example', () {
    final force = TensionMath.idealRound(
      frequencyHz: 350,
      lengthMeters: .290,
      diameterMeters: .002,
      densityKgM3: 7850,
    );
    expect(force, closeTo(1016.27585, .00001));
    expect(force / TensionMath.newtonsPerKgf, closeTo(103.631296, .000001));
    expect(
      TensionMath.idealRound(
        frequencyHz: 700,
        lengthMeters: .290,
        diameterMeters: .002,
        densityKgM3: 7850,
      ),
      closeTo(force * 4, .00001),
    );
  });
  test('invalid physical inputs are rejected', () {
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => TensionMath.idealRound(
          frequencyHz: value,
          lengthMeters: .3,
          diameterMeters: .002,
          densityKgM3: 7850,
        ),
        throwsArgumentError,
      );
    }
    expect(TensionMath.cents(880, 440), closeTo(1200, .00001));
    expect(() => TensionMath.cents(double.nan, 440), throwsArgumentError);
  });
  test(
    'calibration recovers a known curve but cannot enable force display',
    () {
      final points = List.generate(5, (i) {
        final hz = 200.0 + i * 50;
        return CalibrationPoint(
          frequencyHz: hz,
          tensionNewtons: .008 * hz * hz - 10,
          instrument: 'reference fixture',
          fingerprint: 'profile',
          createdAt: DateTime(2026),
        );
      });
      final fit = CalibrationFit.fit(points);
      expect(fit.slope, closeTo(.008, 1e-12));
      expect(fit.intercept, closeTo(-10, 1e-8));
      expect(fit.estimateForResearch(300), closeTo(710, 1e-8));
      expect(() => fit.estimateForResearch(500), throwsRangeError);
      expect(
        () => CalibrationFit.fit([
          points.first,
          points.first,
          points.first,
          points.first,
          points.first,
        ]),
        throwsArgumentError,
      );
      expect(TensionMath.forceEstimatesAvailable, isFalse);
    },
  );
}
