import 'dart:convert';

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

class WheelProfile {
  const WheelProfile({
    required this.id,
    required this.name,
    this.spokeCount = 32,
    this.tireState = 'Not recorded',
    this.left = const SpokeSpec(),
    this.right = const SpokeSpec(),
  });
  final String id, name, tireState;
  final int spokeCount;
  final SpokeSpec left, right;
  SpokeSpec spec(WheelSide side) => side == WheelSide.left ? left : right;
  String fingerprint(WheelSide side) => jsonEncode({
    'wheel': id,
    'side': side.name,
    'spokeCount': spokeCount,
    'tireState': tireState,
    'spec': spec(side).toJson(),
    'protocol': 'stationary-unloaded-gentle-pluck-v1',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'spokeCount': spokeCount,
    'tireState': tireState,
    'left': left.toJson(),
    'right': right.toJson(),
  };
  factory WheelProfile.fromJson(Map<String, dynamic> j) => WheelProfile(
    id: j['id'] as String,
    name: j['name'] as String,
    spokeCount: j['spokeCount'] as int,
    tireState: j['tireState'] as String,
    left: SpokeSpec.fromJson(j['left'] as Map<String, dynamic>),
    right: SpokeSpec.fromJson(j['right'] as Map<String, dynamic>),
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
  });
  final String id, wheelId, fingerprint, mode, captureSource, sessionId;
  final WheelSide side;
  final int spokeIndex, plucks;
  final double frequencyHz, spreadPercent;
  final DateTime createdAt;
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
  }) : wheels = List.unmodifiable(wheels),
       readings = List.unmodifiable(readings),
       references = List.unmodifiable(references),
       calibration = List.unmodifiable(calibration);
  factory AppData.empty() => AppData(
    wheels: [const WheelProfile(id: 'first-wheel', name: 'My first wheel')],
  );
  final List<WheelProfile> wheels;
  final List<SpokeReading> readings;
  final List<SoundReference> references;
  final List<CalibrationPoint> calibration;
  AppData copyWith({
    List<WheelProfile>? wheels,
    List<SpokeReading>? readings,
    List<SoundReference>? references,
    List<CalibrationPoint>? calibration,
  }) => AppData(
    wheels: wheels ?? this.wheels,
    readings: readings ?? this.readings,
    references: references ?? this.references,
    calibration: calibration ?? this.calibration,
  );
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'wheels': wheels.map((e) => e.toJson()).toList(),
    'readings': readings.map((e) => e.toJson()).toList(),
    'references': references.map((e) => e.toJson()).toList(),
    'calibration': calibration.map((e) => e.toJson()).toList(),
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
    return result;
  }
}
