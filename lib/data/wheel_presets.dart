import 'models.dart';

/// Equipment identity only. Replacement wheels do not inherit factory spokes,
/// a hole count, a frequency target or a validated force model.
class BikeWheelPreset {
  const BikeWheelPreset({
    required this.id,
    required this.bikeModel,
    required this.bikeYear,
    required this.rimModel,
    required this.diameterInches,
    required this.replacementYearApprox,
  });
  final String id, bikeModel, rimModel;
  final int bikeYear, replacementYearApprox;
  final double diameterInches;
  String get label => '$bikeModel ($bikeYear)';
  String wheelName(String position) =>
      '$bikeModel · $rimModel $diameterInches · $position';
  WheelEquipment equipmentFor(String position) {
    if (position != 'front' && position != 'rear') {
      throw ArgumentError.value(position, 'position');
    }
    return WheelEquipment(
      presetId: id,
      bikeModel: bikeModel,
      bikeYear: bikeYear,
      rimModel: rimModel,
      diameterInches: diameterInches,
      replacementYearApprox: replacementYearApprox,
      position: position,
    );
  }
}

// Bike/year and replacement rim identity confirmed by the user. Rim variant
// and spoke build remain unconfirmed. Research: docs/KONA_PROCESS_165_PRESET.md.
const konaProcess165Ar35 = BikeWheelPreset(
  id: 'kona-process-165-2019-ar35-275',
  bikeModel: 'Kona Process 165',
  bikeYear: 2019,
  rimModel: 'Race Face AR35',
  diameterInches: 27.5,
  replacementYearApprox: 2021,
);

const wheelPresets = [konaProcess165Ar35];

class KonaOriginalReference {
  static const sourceUrl =
      'https://archive.konaworld.com/archive/2019/process_165.cfm';
  static const spokeLabel = 'Stainless black 14g';
  static const rimLabel = 'WTB KOM Trail TCS';
  static const frontHub = 'Formula 110 × 15 mm';
  static const rearHub = 'Formula 148 × 12 mm';
  // Owner-provided length, not a Kona catalogue specification. It is only a
  // form suggestion; it must be applied separately to each measured side.
  static const ownerLengthHintMm = 272.0;
}
