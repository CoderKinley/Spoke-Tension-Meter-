import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/audio/audio_source.dart';
import '../core/audio/capture_sensitivity.dart';
import '../core/dsp/pitch_analyzer.dart';
import '../core/dsp/live_pitch.dart';
import '../core/physics/tension.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/wheel_presets.dart';

class LabController extends ChangeNotifier {
  LabController({required this.audio, required this.repository});
  final AudioSource audio;
  final AppRepository repository;
  AppData data = AppData.empty();
  bool loaded = false,
      listening = false,
      starting = false,
      processing = false,
      saving = false;
  String? error;
  String status = 'Ready when you are',
      captureSource = 'Microphone not started';
  String sessionId = DateTime.now().microsecondsSinceEpoch.toString();
  String wheelId = 'first-wheel';
  WheelSide side = WheelSide.left;
  int spokeIndex = 1;
  PitchResult? latest;
  PitchResult? livePitch;
  CaptureSensitivity sensitivity = CaptureSensitivity.sensitive;
  final inputLevelDb = ValueNotifier<double>(-100);
  final List<double> _liveSamples = [];
  bool _liveProcessing = false;
  bool _awaitingSpokeQuiet = false;
  int _liveSinceAnalysis = 0;
  Timer? _liveExpiry;
  double? _comparisonHz;
  String? _comparisonFingerprint;
  PitchKind? _comparisonKind;
  double? get displayFrequencyHz =>
      hasSettledFrequency ? frequencyHz : livePitch?.frequencyHz ?? frequencyHz;
  PitchKind? get displayKind =>
      hasSettledFrequency ? latest?.kind : livePitch?.kind ?? latest?.kind;
  bool get hasSettledFrequency =>
      _plucks.length >= 3 && spreadPercent <= 1.5 && latest?.accepted == true;
  double? get comparisonHz =>
      _comparisonFingerprint == fingerprint ? _comparisonHz : null;
  bool get comparisonCompatible =>
      comparisonHz != null && displayKind == _comparisonKind;
  double? get comparisonCents =>
      comparisonCompatible && displayFrequencyHz != null
      ? TensionMath.cents(displayFrequencyHz!, comparisonHz!)
      : null;
  double get onsetThreshold =>
      math.max(sensitivity.minimumRms, _noise * sensitivity.noiseMultiplier);
  void setSensitivity(CaptureSensitivity value) {
    sensitivity = value;
    _notify();
  }

  bool pinComparison() {
    final hz = displayFrequencyHz;
    if (hz == null) return false;
    _comparisonHz = hz;
    _comparisonFingerprint = fingerprint;
    _comparisonKind = displayKind;
    _notify();
    return true;
  }

  void clearComparison() {
    _comparisonHz = null;
    _comparisonFingerprint = null;
    _comparisonKind = null;
    _notify();
  }

  final waveform = ValueNotifier<List<double>>(const []);
  final List<double> _plucks = [];
  bool _frequencyOnlySet = false;
  StreamSubscription<AudioPacket>? _subscription;
  final List<double> _capture = [];
  int _generation = 0,
      _warmupSamples = 0,
      _lastSequence = -1,
      _rate = 0,
      _quiet = 0;
  double _noise = .00001;
  bool _armed = true, _disposed = false;
  int get pluckCount => _plucks.length;
  WheelProfile get wheel => data.wheels.firstWhere(
    (w) => w.id == wheelId,
    orElse: () => data.wheels.first,
  );
  String get fingerprint => wheel.fingerprint(side);
  double? get frequencyHz {
    if (_plucks.isEmpty) {
      return null;
    }
    final ordered = List<double>.from(_plucks)..sort();
    final middle = ordered.length ~/ 2;
    return ordered.length.isOdd
        ? ordered[middle]
        : (ordered[middle - 1] + ordered[middle]) / 2;
  }

  double get spreadPercent {
    if (_plucks.length < 2) {
      return 0;
    }
    final mean = _plucks.reduce((a, b) => a + b) / _plucks.length;
    return 100 *
        math.sqrt(
          _plucks.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) /
              (_plucks.length - 1),
        ) /
        mean;
  }

  bool get canSave =>
      loaded &&
      !saving &&
      !starting &&
      !processing &&
      _plucks.length >= 3 &&
      spreadPercent <= 1.5 &&
      latest?.accepted == true;
  bool get canReference => canSave && _plucks.length >= 5;
  bool get hasKonaReference =>
      wheel.equipment?.presetId == konaProcess165Ar35.id;
  IdealStringSettings? get idealSettings =>
      data.idealSettings.where((s) => s.fingerprint == fingerprint).lastOrNull;
  String? get idealEstimateIssue {
    if (!hasKonaReference) return 'Select your Kona wheel preset first.';
    if (idealSettings == null || !idealSettings!.isValid) {
      return 'Apply the length and model assumptions to this side.';
    }
    if (wheel.spec(side).contact != ContactMode.individual) {
      return 'Individual tension is unavailable for touching or unconfirmed spokes. Confirm the contact arrangement in the wheel profile.';
    }
    if (!canSave || latest?.kind != PitchKind.fundamental) {
      return 'Capture three consistent, harmonic-supported fundamental readings first. Spectral peaks cannot produce a tension estimate.';
    }
    if (wheel.spec(side).material != 'Unknown' &&
        wheel.spec(side).material != 'Steel') {
      return 'The original-spec model assumes steel. This profile uses a different material.';
    }
    if (wheel.spec(side).shape != 'Unknown' &&
        wheel.spec(side).shape != 'Round / uniform') {
      return 'This ideal-string model does not support butted or bladed spokes.';
    }
    if (wheel.spec(side).buttProfile.trim().isNotEmpty ||
        wheel.spec(side).widthMm != null ||
        wheel.spec(side).thicknessMm != null) {
      return 'The entered section conflicts with a uniform round spoke.';
    }
    final measuredDiameter = wheel.spec(side).diameterMm;
    if (measuredDiameter != null &&
        (!measuredDiameter.isFinite || (measuredDiameter - 2.0).abs() > .01)) {
      return 'The entered diameter conflicts with the assumed 2.0 mm model.';
    }
    return null;
  }

  IdealStringEstimate? get idealEstimate {
    if (idealEstimateIssue != null) return null;
    final settings = idealSettings!;
    final hz = frequencyHz!;
    return IdealStringEstimate(
      frequencyHz: hz,
      newtons: TensionMath.idealRound(
        frequencyHz: hz,
        lengthMeters: settings.lengthMm / 1000,
        diameterMeters: settings.diameterMm / 1000,
        densityKgM3: settings.densityKgM3,
      ),
      settings: settings,
    );
  }

  Future<bool> configureIdealString(double lengthMm) async {
    final settings = IdealStringSettings(
      fingerprint: fingerprint,
      lengthMm: lengthMm,
    );
    if (!hasKonaReference || !settings.isValid) return false;
    // Stop and discard old readings so a new model is never paired with a stale pluck.
    await stop(discard: true);
    if (fingerprint != settings.fingerprint) return false;
    return _persist(
      data.copyWith(
        idealSettings: [
          ...data.idealSettings.where(
            (s) => s.fingerprint != settings.fingerprint,
          ),
          settings,
        ],
      ),
    );
  }

  Future<bool> disableIdealString() => _persist(
    data.copyWith(
      idealSettings: data.idealSettings
          .where((s) => s.fingerprint != fingerprint)
          .toList(),
    ),
  );
  SoundReference? get reference =>
      data.references.where((r) => r.fingerprint == fingerprint).lastOrNull;
  List<SpokeReading> get sessionReadings => data.readings
      .where(
        (r) =>
            r.sessionId == sessionId &&
            r.wheelId == wheel.id &&
            r.side == side &&
            r.fingerprint == fingerprint,
      )
      .toList();
  List<SpokeReading> readingsForSpoke(int index) =>
      data.readings
          .where(
            (r) =>
                r.wheelId == wheel.id &&
                r.side == side &&
                r.fingerprint == fingerprint &&
                r.spokeIndex == index,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  Map<int, SpokeReading> get mappedReadings {
    final result = <int, SpokeReading>{};
    for (final reading in data.readings) {
      if (reading.wheelId != wheel.id ||
          reading.side != side ||
          reading.fingerprint != fingerprint) {
        continue;
      }
      final previous = result[reading.spokeIndex];
      if (previous == null || reading.createdAt.isAfter(previous.createdAt)) {
        result[reading.spokeIndex] = reading;
      }
    }
    return result;
  }

  List<CalibrationPoint> get calibrationPoints =>
      data.calibration.where((p) => p.fingerprint == fingerprint).toList();

  ({CalibrationFit? fit, String? issue}) get calibrationSummary {
    final points = calibrationPoints;
    if (points.length < 5) return (fit: null, issue: null);
    try {
      return (fit: CalibrationFit.fit(points), issue: null);
    } on ArgumentError {
      return (
        fit: null,
        issue:
            'These points cannot form a usable curve. Use five distinct levels with increasing force.',
      );
    }
  }

  Future<void> initialize() async {
    try {
      data = await repository.load();
      wheelId = data.wheels.first.id;
      final previous = data.readings.lastOrNull;
      if (previous != null &&
          data.wheels.any((w) => w.id == previous.wheelId)) {
        wheelId = previous.wheelId;
        side = previous.side;
        spokeIndex = previous.spokeIndex % (wheel.spokeCount ~/ 2) + 1;
      }
      loaded = true;
    } catch (e) {
      error = 'Saved data could not be read. It has been preserved. $e';
    }
    _notify();
  }

  Future<void> start() async {
    if (listening || starting || !loaded) {
      return;
    }
    resetPlucks();
    error = null;
    starting = true;
    status = 'Opening microphone…';
    final generation = ++_generation;
    _warmupSamples = 0;
    _lastSequence = -1;
    _rate = 0;
    _noise = .00001;
    _armed = true;
    _awaitingSpokeQuiet = false;
    _quiet = 0;
    _notify();
    try {
      _subscription = audio.packets.listen(
        _receive,
        onError: (Object e) => _audioError(e),
        onDone: () {
          if (listening) {
            unawaited(_audioError(StateError('Microphone stream closed.')));
          }
        },
      );
      listening = true;
      final description = await audio.start();
      if (generation != _generation || _disposed) {
        await audio.stop();
        return;
      }
      captureSource = description;
      status = 'Listen to the room, then gently pluck one spoke.';
    } catch (e) {
      await _audioError(e);
    } finally {
      starting = false;
      _notify();
    }
  }

  Future<void> stop({bool discard = false}) async {
    ++_generation;
    listening = false;
    starting = false;
    processing = false;
    _liveProcessing = false;
    _liveSamples.clear();
    _liveSinceAnalysis = 0;
    _liveExpiry?.cancel();
    if (!_disposed) waveform.value = const [];
    if (!_disposed) inputLevelDb.value = -100;
    _capture.clear();
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    try {
      await audio.stop();
    } catch (e) {
      error = 'Could not close microphone: $e';
    }
    if (discard) {
      resetPlucks();
    }
    status = 'Microphone stopped';
    _notify();
  }

  Future<void> _audioError(Object e) async {
    if (_disposed) {
      return;
    }
    await stop(discard: true);
    error = e is PlatformException
        ? (e.message ?? 'Microphone unavailable')
        : 'Audio interrupted: $e';
    _notify();
  }

  void resetPlucks() {
    ++_generation;
    _liveProcessing = false;
    _plucks.clear();
    _frequencyOnlySet = false;
    _capture.clear();
    latest = null;
    livePitch = null;
    _liveExpiry?.cancel();
    _liveSamples.clear();
    _liveSinceAnalysis = 0;
    processing = false;
    status = listening
        ? 'Pluck the same spoke at least three times.'
        : 'Ready when you are';
    _notify();
  }

  void _receive(AudioPacket packet) {
    if (!listening || _disposed) {
      return;
    }
    if ((_lastSequence >= 0 && packet.sequence != _lastSequence + 1) ||
        (_rate != 0 && packet.sampleRate != _rate)) {
      unawaited(
        _audioError(
          StateError(
            'Audio buffers were lost or the sample rate changed. Restart capture.',
          ),
        ),
      );
      return;
    }
    _lastSequence = packet.sequence;
    _rate = packet.sampleRate;
    final samples = packet.samples;
    if (packet.sampleRate < 8000 ||
        packet.sampleRate > 96000 ||
        samples.any((sample) => !sample.isFinite)) {
      unawaited(_audioError(const FormatException('Invalid audio packet')));
      return;
    }
    if (samples.isEmpty) {
      return;
    }
    final rms = math.sqrt(
      samples.fold<double>(0, (s, x) => s + x * x) / samples.length,
    );
    inputLevelDb.value = (20 * math.log(math.max(rms, .00001)) / math.ln10)
        .clamp(-100, 0);
    final count = math.min(128, samples.length);
    final peak = samples.fold<double>(0, (s, x) => math.max(s, x.abs()));
    final displayGain = (.6 / math.max(peak, .003)).clamp(1.0, 200.0);
    waveform.value = List<double>.generate(
      count,
      (i) =>
          (samples[i * samples.length ~/ count] * displayGain).clamp(-1.0, 1.0),
      growable: false,
    );
    if (_awaitingSpokeQuiet) {
      _quiet = rms < math.max(sensitivity.minimumRms * .7, _noise * 1.4)
          ? _quiet + samples.length
          : 0;
      if (_quiet >= packet.sampleRate * .08) {
        _awaitingSpokeQuiet = false;
        _armed = true;
        _quiet = 0;
      }
      return;
    }
    _receiveLive(samples, packet.sampleRate);
    if (_warmupSamples < packet.sampleRate * .2) {
      // A tap during warmup must not set the room's noise floor to its peak.
      _noise = _warmupSamples == 0 ? rms : math.min(_noise, rms);
      _warmupSamples += samples.length;
      status = 'Measuring background noise…';
      _notify();
      return;
    }
    if (processing) {
      return;
    }
    if (!_armed && _capture.isEmpty) {
      _quiet = rms < math.max(sensitivity.minimumRms * .7, _noise * 1.4)
          ? _quiet + samples.length
          : 0;
      if (_quiet >= packet.sampleRate * .08) {
        _armed = true;
        _quiet = 0;
      }
      return;
    }
    if (_capture.isNotEmpty || (_armed && rms > onsetThreshold)) {
      _capture.addAll(samples);
      _armed = false;
      if (_capture.length >= 16896) {
        final signal = List<double>.from(_capture.sublist(512, 16896));
        _capture.clear();
        processing = true;
        status = 'Checking resonance…';
        _notify();
        final token = _generation, rate = packet.sampleRate;
        compute(analyzeMappingPluckRequest, (signal, rate))
            .then((result) {
              if (!_disposed && listening && token == _generation) {
                processing = false;
                acceptAnalysis(result);
              }
            })
            .catchError((Object e) {
              if (!_disposed && token == _generation) {
                unawaited(_audioError(e));
              }
            });
      }
    } else {
      _noise = .98 * _noise + .02 * rms;
      if (_plucks.isEmpty) {
        status = 'Gently pluck one spoke. Let it ring between plucks.';
        _notify();
      }
    }
  }

  void _receiveLive(List<double> samples, int rate) {
    _liveSamples.addAll(samples);
    if (_liveSamples.length > 8192) {
      _liveSamples.removeRange(0, _liveSamples.length - 8192);
    }
    _liveSinceAnalysis += samples.length;
    if (_liveProcessing ||
        _liveSamples.length < 8192 ||
        _liveSinceAnalysis < 4096) {
      return;
    }
    _liveProcessing = true;
    _liveSinceAnalysis = 0;
    final token = _generation;
    compute(analyzeLiveRequest, (List<double>.from(_liveSamples), rate))
        .then((result) {
          if (_disposed || !listening || token != _generation) return;
          _liveProcessing = false;
          if (result.accepted) {
            livePitch = result;
            _liveExpiry?.cancel();
            _liveExpiry = Timer(const Duration(milliseconds: 1500), () {
              if (!_disposed && listening && token == _generation) {
                livePitch = null;
                _notify();
              }
            });
            _notify();
          }
          // Coalesce queued packets into the newest frame; never build a backlog.
          if (_liveSinceAnalysis >= 4096) _receiveLive(const [], rate);
        })
        .catchError((Object e) {
          if (!_disposed && token == _generation) {
            _liveProcessing = false;
            unawaited(_audioError(e));
          }
        });
  }

  @visibleForTesting
  void acceptAnalysis(PitchResult result) {
    final oldKind = latest?.kind;
    latest = result;
    status = result.message;
    if (!result.accepted) {
      _plucks.clear();
      _frequencyOnlySet = false;
      _notify();
      return;
    }
    if (oldKind != null && oldKind != result.kind && _plucks.isNotEmpty) {
      if ((result.frequencyHz! / frequencyHz! - 1).abs() > .015) {
        _plucks.clear();
        _frequencyOnlySet = false;
        status = 'Mode changed. Start a fresh repeat set.';
      }
    }
    _frequencyOnlySet =
        _frequencyOnlySet || result.kind == PitchKind.spectralPeak;
    if (_frequencyOnlySet && result.kind == PitchKind.fundamental) {
      latest = PitchResult(
        kind: PitchKind.spectralPeak,
        frequencyHz: result.frequencyHz,
        message:
            'Consistent frequency; this repeat set includes an unconfirmed fundamental.',
        spectrum: result.spectrum,
        rms: result.rms,
      );
    }
    _plucks.add(result.frequencyHz!);
    if (_plucks.length > 10) {
      _plucks.removeAt(0);
    }
    if (_plucks.length >= 3 && spreadPercent > 1.5) {
      status = 'Readings disagree. Reset and repeat on the same spoke.';
    }
    _notify();
  }

  Future<void> select({
    String? selectedWheel,
    WheelSide? selectedSide,
    int? index,
  }) async {
    await stop(discard: true);
    if (selectedWheel != null) {
      wheelId = selectedWheel;
      spokeIndex = 1;
    }
    if (selectedSide != null) {
      side = selectedSide;
      spokeIndex = 1;
    }
    if (index != null) {
      spokeIndex = index;
    }
    spokeIndex = spokeIndex.clamp(1, wheel.spokeCount ~/ 2);
    _notify();
  }

  void selectSpoke(int index) {
    if (saving || starting) return;
    resetPlucks();
    spokeIndex = index.clamp(1, wheel.spokeCount ~/ 2);
    _awaitingSpokeQuiet = listening;
    _armed = !listening;
    _quiet = 0;
    _notify();
  }

  Future<bool> _persist(AppData updated) async {
    if (saving || !loaded) {
      return false;
    }
    saving = true;
    error = null;
    _notify();
    try {
      await repository.save(updated);
      data = updated;
      return true;
    } catch (e) {
      error = 'Could not save. Existing data is unchanged. $e';
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<bool> saveReading({bool continueListening = false}) async {
    if (!canSave) {
      return false;
    }
    final now = DateTime.now();
    final reading = SpokeReading(
      id: now.microsecondsSinceEpoch.toString(),
      wheelId: wheel.id,
      side: side,
      spokeIndex: spokeIndex,
      frequencyHz: frequencyHz!,
      spreadPercent: spreadPercent,
      plucks: pluckCount,
      createdAt: now,
      fingerprint: fingerprint,
      mode: '${wheel.spec(side).contact.name}/${latest!.kind.name}',
      captureSource: captureSource,
      sessionId: sessionId,
      idealEstimate: idealEstimate,
    );
    final success = await _persist(
      data.copyWith(readings: [...data.readings, reading]),
    );
    if (success) {
      final next = spokeIndex % (wheel.spokeCount ~/ 2) + 1;
      if (continueListening) {
        selectSpoke(next);
      } else {
        await stop(discard: true);
        spokeIndex = next;
      }
      _notify();
    }
    return success;
  }

  Future<bool> saveReference(String name, {double? manualHz}) async {
    if (manualHz == null && !canReference) {
      return false;
    }
    if (name.trim().isEmpty ||
        (manualHz != null &&
            (!manualHz.isFinite || manualHz < 80 || manualHz > 2500))) {
      return false;
    }
    final now = DateTime.now();
    final ref = SoundReference(
      id: now.microsecondsSinceEpoch.toString(),
      name: name.trim(),
      fingerprint: fingerprint,
      frequencyHz: manualHz ?? frequencyHz!,
      createdAt: now,
      plucks: manualHz == null ? pluckCount : 0,
      spreadPercent: manualHz == null ? spreadPercent : 0,
      origin: manualHz == null ? 'recorded' : 'manual',
      captureSource: manualHz == null ? captureSource : 'manual target',
    );
    return _persist(data.copyWith(references: [...data.references, ref]));
  }

  Future<bool> saveWheel(WheelProfile profile) async {
    for (final spec in [profile.left, profile.right]) {
      final dimensions = [
        spec.diameterMm,
        spec.lengthMm,
        spec.widthMm,
        spec.thicknessMm,
      ];
      if (dimensions.any(
        (value) => value != null && (!value.isFinite || value <= 0),
      )) {
        error = 'Spoke dimensions must be positive and finite.';
        _notify();
        return false;
      }
    }
    await stop(discard: true);
    final wheels = [...data.wheels.where((w) => w.id != profile.id), profile];
    final success = await _persist(data.copyWith(wheels: wheels));
    if (success) {
      wheelId = profile.id;
      spokeIndex = 1;
      _notify();
    }
    return success;
  }

  Future<bool> addCalibration(CalibrationPoint point) async {
    if (point.fingerprint != fingerprint ||
        !point.frequencyHz.isFinite ||
        point.frequencyHz < 80 ||
        point.frequencyHz > 2500 ||
        !point.tensionNewtons.isFinite ||
        point.tensionNewtons <= 0 ||
        point.instrument.trim().isEmpty) {
      return false;
    }
    return _persist(data.copyWith(calibration: [...data.calibration, point]));
  }

  Future<bool> export({required bool csv}) async {
    await stop();
    try {
      return await repository.export(data, csv: csv);
    } catch (e) {
      error = 'Export failed: $e';
      _notify();
      return false;
    }
  }

  Future<void> newSession() async {
    await stop(discard: true);
    sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    spokeIndex = 1;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _liveExpiry?.cancel();
    inputLevelDb.dispose();
    waveform.dispose();
    _generation++;
    listening = false;
    unawaited(_subscription?.cancel());
    unawaited(audio.stop().catchError((Object _) {}));
    super.dispose();
  }
}
