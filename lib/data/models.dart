import 'dart:convert';
import 'dart:math' as math;

enum WheelSide { left, right }

enum ContactMode { individual, coupled, unknown }

class SpokeSpec {
  const SpokeSpec({
    this.material = 'Unknown',
    this.shape = 'Unknown',
    this.diameterMm,
    this.lengthMm,
    this.widthMm,
    this.thicknessMm,
    this.buttProfile = '',
    this.contact = ContactMode.unknown,
  });
  final String material, shape, buttProfile;
  final double? diameterMm, lengthMm, widthMm, thicknessMm;
  final ContactMode contact;
  Map<String, dynamic> toJson() => {
    'material': material,
    'shape': shape,
    'diameterMm': diameterMm,
    'lengthMm': lengthMm,
    'widthMm': widthMm,
    'thicknessMm': thicknessMm,
    'buttProfile': buttProfile,
    'contact': contact.name,
  };
  factory SpokeSpec.fromJson(Map<String, dynamic> j) => SpokeSpec(
    material: j['material'] as String,
    shape: j['shape'] as String,
    diameterMm: (j['diameterMm'] as num?)?.toDouble(),
    lengthMm: (j['lengthMm'] as num?)?.toDouble(),
    widthMm: (j['widthMm'] as num?)?.toDouble(),
    thicknessMm: (j['thicknessMm'] as num?)?.toDouble(),
    buttProfile: j['buttProfile'] as String? ?? '',
    contact: ContactMode.values.byName(j['contact'] as String),
  );
}

class WheelEquipment {
  const WheelEquipment({
    required this.presetId,
    required this.bikeModel,
    required this.bikeYear,
    required this.rimModel,
    required this.diameterInches,
    required this.replacementYearApprox,
    required this.position,
  });
  final String presetId, bikeModel, rimModel, position;
  final int bikeYear, replacementYearApprox;
  final double diameterInches;
  String get summary =>
      '$bikeYear $bikeModel · $rimModel · $diameterInches″ · $position';
  Map<String, dynamic> toJson() => {
    'presetId': presetId,
    'bikeModel': bikeModel,
    'bikeYear': bikeYear,
    'rimModel': rimModel,
    'diameterInches': diameterInches,
    'replacementYearApprox': replacementYearApprox,
    'position': position,
  };
  factory WheelEquipment.fromJson(Map<String, dynamic> j) {
    final position = j['position'] as String;
    if (position != 'front' && position != 'rear') {
      throw const FormatException('Invalid wheel position');
    }
    final diameter = (j['diameterInches'] as num).toDouble();
    if (!diameter.isFinite || diameter <= 0) {
      throw const FormatException('Invalid rim diameter');
    }
    return WheelEquipment(
      presetId: j['presetId'] as String,
      bikeModel: j['bikeModel'] as String,
      bikeYear: j['bikeYear'] as int,
      rimModel: j['rimModel'] as String,
      diameterInches: diameter,
      replacementYearApprox: j['replacementYearApprox'] as int,
      position: position,
    );
  }
}

class WheelProfile {
  const WheelProfile({
    required this.id,
    required this.name,
    this.spokeCount = 32,
    this.tireState = 'Not recorded',
    this.left = const SpokeSpec(),
    this.right = const SpokeSpec(),
    this.equipment,
    this.position,
  });
  final String id, name, tireState;
  final int spokeCount;
  final SpokeSpec left, right;
  final WheelEquipment? equipment;
  final String? position;
  String? get wheelPosition => equipment?.position ?? position;
  SpokeSpec spec(WheelSide side) => side == WheelSide.left ? left : right;
  String fingerprint(WheelSide side) => jsonEncode({
    'wheel': id,
    'side': side.name,
    'spokeCount': spokeCount,
    'tireState': tireState,
    'spec': spec(side).toJson(),
    if (equipment != null) 'equipment': equipment!.toJson(),
    if (equipment == null && position != null) 'position': position,
    'protocol': 'stationary-unloaded-gentle-pluck-v1',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'spokeCount': spokeCount,
    'tireState': tireState,
    'left': left.toJson(),
    'right': right.toJson(),
    if (equipment != null) 'equipment': equipment!.toJson(),
    if (position != null) 'position': position,
  };
  factory WheelProfile.fromJson(Map<String, dynamic> j) => WheelProfile(
    id: j['id'] as String,
    name: j['name'] as String,
    spokeCount: j['spokeCount'] as int,
    tireState: j['tireState'] as String,
    left: SpokeSpec.fromJson(j['left'] as Map<String, dynamic>),
    right: SpokeSpec.fromJson(j['right'] as Map<String, dynamic>),
    equipment: j['equipment'] == null
        ? null
        : WheelEquipment.fromJson(j['equipment'] as Map<String, dynamic>),
    position: switch (j['position']) {
      null => null,
      'front' => 'front',
      'rear' => 'rear',
      _ => throw const FormatException('Invalid wheel position'),
    },
  );
}

class SoundReference {
  const SoundReference({
    required this.id,
    required this.name,
    required this.fingerprint,
    required this.frequencyHz,
    required this.createdAt,
    required this.plucks,
    required this.spreadPercent,
    required this.origin,
    required this.captureSource,
  });
  final String id, name, fingerprint, origin, captureSource;
  final double frequencyHz, spreadPercent;
  final int plucks;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fingerprint': fingerprint,
    'frequencyHz': frequencyHz,
    'spreadPercent': spreadPercent,
    'plucks': plucks,
    'createdAt': createdAt.toIso8601String(),
    'origin': origin,
    'captureSource': captureSource,
  };
  factory SoundReference.fromJson(Map<String, dynamic> j) => SoundReference(
    id: j['id'] as String,
    name: j['name'] as String,
    fingerprint: j['fingerprint'] as String,
    frequencyHz: (j['frequencyHz'] as num).toDouble(),
    spreadPercent: (j['spreadPercent'] as num).toDouble(),
    plucks: j['plucks'] as int,
    createdAt: DateTime.parse(j['createdAt'] as String),
    origin: j['origin'] as String,
    captureSource: j['captureSource'] as String,
  );
}

/// Explicit ideal-string assumptions, separate from measured spoke geometry.
class IdealStringSettings {
  const IdealStringSettings({
    required this.fingerprint,
    required this.lengthMm,
  });
  static const basis = 'kona-2019-14g-uniform-steel-assumption';
  final String fingerprint;
  final double lengthMm;
  double get diameterMm => 2.0;
  double get densityKgM3 => 7850;
  bool get isValid =>
      fingerprint.isNotEmpty &&
      lengthMm.isFinite &&
      lengthMm > 0 &&
      lengthMm <= 500;
  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'lengthMm': lengthMm,
    'diameterMm': diameterMm,
    'densityKgM3': densityKgM3,
    'basis': basis,
    'validation': 'unvalidated-ideal-string',
  };
  factory IdealStringSettings.fromJson(Map<String, dynamic> j) {
    final settings = IdealStringSettings(
      fingerprint: j['fingerprint'] as String,
      lengthMm: (j['lengthMm'] as num).toDouble(),
    );
    if (!settings.isValid ||
        j['basis'] != basis ||
        j['validation'] != 'unvalidated-ideal-string' ||
        j['diameterMm'] != 2 ||
        j['densityKgM3'] != 7850) {
      throw const FormatException('Unsupported ideal-string assumptions');
    }
    return settings;
  }
}

class IdealStringEstimate {
  const IdealStringEstimate({
    required this.frequencyHz,
    required this.newtons,
    required this.settings,
  });
  final double frequencyHz, newtons;
  final IdealStringSettings settings;
  Map<String, dynamic> toJson() => {
    'frequencyHz': frequencyHz,
    'newtons': newtons,
    'settings': settings.toJson(),
    'validation': 'unvalidated-ideal-string',
  };
  factory IdealStringEstimate.fromJson(Map<String, dynamic> j) {
    final result = IdealStringEstimate(
      frequencyHz: (j['frequencyHz'] as num).toDouble(),
      newtons: (j['newtons'] as num).toDouble(),
      settings: IdealStringSettings.fromJson(
        j['settings'] as Map<String, dynamic>,
      ),
    );
    if (j['validation'] != 'unvalidated-ideal-string' ||
        !result.newtons.isFinite ||
        result.newtons <= 0 ||
        !result.frequencyHz.isFinite ||
        result.frequencyHz < 80 ||
        result.frequencyHz > 2500) {
      throw const FormatException('Invalid theoretical estimate');
    }
    // Reject a damaged snapshot rather than presenting a force unrelated to
    // its recorded assumptions. This checks arithmetic, not physical accuracy.
    final expected =
        math.pi *
        result.settings.densityKgM3 *
        math.pow(result.settings.diameterMm / 1000, 2) *
        math.pow(result.settings.lengthMm / 1000, 2) *
        result.frequencyHz *
        result.frequencyHz;
    if ((result.newtons - expected).abs() > expected * 1e-9) {
      throw const FormatException('Inconsistent theoretical estimate');
    }
    return result;
  }
}

class SpokeReading {
  const SpokeReading({
    required this.id,
    required this.wheelId,
    required this.side,
    required this.spokeIndex,
    required this.frequencyHz,
    required this.spreadPercent,
    required this.plucks,
    required this.createdAt,
    required this.fingerprint,
    required this.mode,
    required this.captureSource,
    required this.sessionId,
    this.idealEstimate,
  });
  final String id, wheelId, fingerprint, mode, captureSource, sessionId;
  final WheelSide side;
  final int spokeIndex, plucks;
  final double frequencyHz, spreadPercent;
  final DateTime createdAt;
  final IdealStringEstimate? idealEstimate;
  Map<String, dynamic> toJson() => {
    'id': id,
    'wheelId': wheelId,
    'side': side.name,
    'spokeIndex': spokeIndex,
    'frequencyHz': frequencyHz,
    'spreadPercent': spreadPercent,
    'plucks': plucks,
    'createdAt': createdAt.toIso8601String(),
    'fingerprint': fingerprint,
    'mode': mode,
    'captureSource': captureSource,
    'sessionId': sessionId,
    'algorithm': 'fft-yin-v1',
    if (idealEstimate != null) 'idealEstimate': idealEstimate!.toJson(),
  };
  factory SpokeReading.fromJson(Map<String, dynamic> j) => SpokeReading(
    id: j['id'] as String,
    wheelId: j['wheelId'] as String,
    side: WheelSide.values.byName(j['side'] as String),
    spokeIndex: j['spokeIndex'] as int,
    frequencyHz: (j['frequencyHz'] as num).toDouble(),
    spreadPercent: (j['spreadPercent'] as num).toDouble(),
    plucks: j['plucks'] as int,
    createdAt: DateTime.parse(j['createdAt'] as String),
    fingerprint: j['fingerprint'] as String,
    mode: j['mode'] as String,
    captureSource: j['captureSource'] as String,
    sessionId: j['sessionId'] as String,
    idealEstimate: j['idealEstimate'] == null
        ? null
        : IdealStringEstimate.fromJson(
            j['idealEstimate'] as Map<String, dynamic>,
          ),
  );
}

class CalibrationPoint {
  const CalibrationPoint({
    required this.frequencyHz,
    required this.tensionNewtons,
    required this.instrument,
    required this.fingerprint,
    required this.createdAt,
  });
  final double frequencyHz, tensionNewtons;
  final String instrument, fingerprint;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'frequencyHz': frequencyHz,
    'tensionNewtons': tensionNewtons,
    'instrument': instrument,
    'fingerprint': fingerprint,
    'createdAt': createdAt.toIso8601String(),
    'validation': 'unverified-user-reference',
  };
  factory CalibrationPoint.fromJson(Map<String, dynamic> j) => CalibrationPoint(
    frequencyHz: (j['frequencyHz'] as num).toDouble(),
    tensionNewtons: (j['tensionNewtons'] as num).toDouble(),
    instrument: j['instrument'] as String,
    fingerprint: j['fingerprint'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

class AppData {
  AppData({
    required List<WheelProfile> wheels,
    List<SpokeReading> readings = const [],
    List<SoundReference> references = const [],
    List<CalibrationPoint> calibration = const [],
    List<IdealStringSettings> idealSettings = const [],
  }) : wheels = List.unmodifiable(wheels),
       readings = List.unmodifiable(readings),
       references = List.unmodifiable(references),
       calibration = List.unmodifiable(calibration),
       idealSettings = List.unmodifiable(idealSettings);
  factory AppData.empty() => AppData(
    wheels: [const WheelProfile(id: 'first-wheel', name: 'My first wheel')],
  );
  final List<WheelProfile> wheels;
  final List<SpokeReading> readings;
  final List<SoundReference> references;
  final List<CalibrationPoint> calibration;
  final List<IdealStringSettings> idealSettings;
  AppData copyWith({
    List<WheelProfile>? wheels,
    List<SpokeReading>? readings,
    List<SoundReference>? references,
    List<CalibrationPoint>? calibration,
    List<IdealStringSettings>? idealSettings,
  }) => AppData(
    wheels: wheels ?? this.wheels,
    readings: readings ?? this.readings,
    references: references ?? this.references,
    calibration: calibration ?? this.calibration,
    idealSettings: idealSettings ?? this.idealSettings,
  );
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'wheels': wheels.map((e) => e.toJson()).toList(),
    'readings': readings.map((e) => e.toJson()).toList(),
    'references': references.map((e) => e.toJson()).toList(),
    'calibration': calibration.map((e) => e.toJson()).toList(),
    'idealStringSettings': idealSettings.map((e) => e.toJson()).toList(),
  };
  factory AppData.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Unsupported data version');
    }
    final result = AppData(
      wheels: (j['wheels'] as List)
          .map((e) => WheelProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
      readings: (j['readings'] as List)
          .map((e) => SpokeReading.fromJson(e as Map<String, dynamic>))
          .toList(),
      references: (j['references'] as List)
          .map((e) => SoundReference.fromJson(e as Map<String, dynamic>))
          .toList(),
      calibration: (j['calibration'] as List)
          .map((e) => CalibrationPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      idealSettings: (j['idealStringSettings'] as List? ?? [])
          .map((e) => IdealStringSettings.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (result.wheels.isEmpty ||
        result.wheels.any(
          (w) => w.spokeCount < 8 || w.spokeCount > 64 || w.spokeCount.isOdd,
        )) {
      throw const FormatException('Invalid wheel data');
    }
    for (final hz in [
      ...result.readings.map((e) => e.frequencyHz),
      ...result.references.map((e) => e.frequencyHz),
      ...result.calibration.map((e) => e.frequencyHz),
    ]) {
      if (!hz.isFinite || hz < 80 || hz > 2500) {
        throw const FormatException('Invalid frequency');
      }
    }
    for (final reading in result.readings) {
      final estimate = reading.idealEstimate;
      if (estimate != null &&
          (estimate.frequencyHz != reading.frequencyHz ||
              estimate.settings.fingerprint != reading.fingerprint ||
              reading.mode != 'individual/fundamental' ||
              reading.plucks < 3 ||
              !reading.spreadPercent.isFinite ||
              reading.spreadPercent < 0 ||
              reading.spreadPercent > 1.5)) {
        throw const FormatException('Estimate does not match its reading');
      }
    }
    return result;
  }
}
