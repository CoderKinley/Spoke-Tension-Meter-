# Spoke Lab

An offline Flutter Android app for measuring bicycle spoke frequencies and comparing saved sound references. **Version 0.1 is a frequency/reference beta. It does not provide validated tension measurements or certify wheel safety.**

## What is implemented

- **Measure:** microphone PCM, onset detection, FFT spectrum, YIN periodicity, harmonic checks, two-window agreement and repeat measurements. Single tones are explicitly labelled spectral peaks.
- **Tune:** save five consistent plucks or enter a target frequency; compare Hz, percentage and cents within the same wheel-side configuration.
- **Wheels:** profiles for material, round/butted/bladed dimensions, contact arrangement and tire state; indexed readings, sessions, history and CSV/JSON export.
- **Calibration:** collect known-force observations and inspect an experimental quadratic fit. Adding observations never enables N/kgf estimates in this version.

No account, server, paid service or runtime network access is needed. Audio is processed locally and discarded; only measurement metadata and frequency summaries are saved. Uninstalling removes local data: export anything you want to keep. JSON export is an archive; import is not implemented.

## Run on Android

Developed with Flutter 3.44.9 / Dart 3.12.2, Java 17-compatible Android tooling and Android API 24 or newer (the installed Flutter SDK's minimum). Initial dependency downloads need internet access.

```sh
flutter doctor
flutter pub get
flutter devices
flutter run -d <android-device-id>
```

Use USB debugging on a real phone for acoustic tests. A simulator is insufficient for microphone and physical validation. See [device validation](docs/DEVICE_VALIDATION.md) before using a wheel.

```sh
dart format lib test integration_test test_driver tools/direct_test_runner.dart
flutter analyze
flutter test
flutter test integration_test/app_test.dart -d <android-device-id>
flutter build apk --debug
```

The debug APK normally appears at `build/app/outputs/flutter-apk/app-debug.apk`. A debug APK has been generated locally; installation, device integration testing and physical validation have not yet been verified. Release signing still uses the Flutter template's debug key; configure your own signing before distribution.

If Flutter's runner cannot start child processes on Windows, a diagnostic fallback executes the same unit/widget tests directly in Flutter's engine:

```powershell
.\tools\Run-DirectTests.ps1 -FlutterSdk C:\flutter
```

This fallback uses test framework internals, supports the current tests, and does not replace device integration tests or a normal build.

## Measurement assumptions

Capture uses mono PCM16 at 48 kHz, with 44.1 kHz fallback. Android `UNPROCESSED` is preferred where advertised; otherwise `VOICE_RECOGNITION` is requested. Device-specific processing still needs verification. Analysis targets approximately 80–2500 Hz, rejects boundary ambiguity and examines two 8192-sample windows. Three repeats with at most 1.5% sample relative standard deviation permit a saved reading; five permit a recorded reference. These are provisional engineering thresholds.

An ideal uniform string obeys `T = 4 μ L² f²`; actual spokes introduce stiffness, end constraints and crossing interactions. A good tone match cannot establish correct tension. Research, citations and the original validation proposal are in [PHASE_1_PLAN.md](PHASE_1_PLAN.md).

## Source map

| Path | Responsibility |
| --- | --- |
| `lib/core/audio/`, Android `MainActivity.kt` | Audio capture and platform channels |
| `lib/core/dsp/`, `lib/core/physics/` | Signal analysis and research mathematics |
| `lib/app/`, `lib/features/` | ChangeNotifier controller, screens and profile editor |
| `lib/data/` | Immutable records, JSON persistence and exports |
| `test/`, `integration_test/` | Software checks and device smoke test |

See [implementation and validation status](docs/IMPLEMENTATION_STATUS.md) for passed checks, remaining work and design decisions. `AGENTS.md` was preserved as requested.

## Preview

Rendered from the actual Flutter widgets with empty data. Host fonts differ from Android.

<img src="docs/previews/measure.png" alt="Spoke Lab measurement screen" width="300"> <img src="docs/previews/tune.png" alt="Spoke Lab reference tuning screen" width="300">
