# Implementation and validation status

Updated 2026-10-15. Phase-two source implementation is available for a **frequency/reference beta**. A debug APK has been generated locally. Installation, device integration testing and physical validation remain outstanding.

## Checks completed

- Dart analysis of application, unit/widget tests, device smoke test and test driver: no errors or warnings at the time of the recorded check.
- 52 unit/widget tests executed in Flutter's Windows test engine through a direct in-process test harness. All passed. The normal Flutter CLI runner could not start child processes in this session; this is not a claim that `flutter test` itself completed.
- Covered independent DFT versus FFT, harmonic signals at 44.1/48 kHz, dominant second harmonic, missing fundamental, single-tone labelling, clipping/noise/silence, unrelated tones, unstable windows, SI units, experimental calibration limits, repeat gates, reference context, PCM decoding, packet loss, stream closure, streamed audio through onset detection and the analysis isolate, persistence, corruption handling and navigation.
- Narrow-screen widget checks at 360 × 800 and 150% text scale passed after fixing overflows. Four actual widget previews rendered at 412 × 915; these are not Android device screenshots.
- `MainActivity.kt` independently compiled with Kotlin 2.3.20, Android 36 API stubs, Flutter's matching embedding and lifecycle dependencies. This checks Kotlin/API compatibility, not Android runtime behavior or APK packaging.
- Android resources compiled with AAPT2; launcher artwork and the launch background are customized. The minimum Android version follows Flutter's API 24 requirement.
- A subsequent Android Studio build generated `build/app/outputs/flutter-apk/app-debug.apk` (62,804,647 bytes). An Android emulator is connected as `emulator-5554`. App installation and runtime behavior have not yet been verified.
- Added the 2019 Kona Process 165 / Race Face AR35 27.5-inch equipment preset with approximate 2021 replacement history. Tests cover count confirmation, front/rear identity, edits, persistence and legacy reference compatibility. No frequency target or spoke dimensions are assigned. The prior APK predates this feature and must be rebuilt to include it. See [preset research](KONA_PROCESS_165_PRESET.md).
- Added an explicitly unvalidated ideal-string calculator using the owner's 272 mm length hint and original-spec nominal 2.0 mm steel assumptions. Tests cover independent arithmetic, per-configuration scoping, stale-pluck clearing, incompatible geometry/contact, spectral-peak rejection, provenance and corrupt snapshot rejection, legacy archives, CSV, and the acknowledgement dialog at 150% text scale. Setup and calculated-value previews rendered successfully; the example uses injected 350 Hz readings. No mechanical tension accuracy is established. The existing APK predates this addition too.
- Measure now always shows a tension readout directly beneath Hz, with visible setup and profile actions. Tests cover setup from a fresh installation without changing tabs, unknown-contact suppression, the resulting calculated value, and reuse of an existing Kona wheel. The detailed model panel follows the capture card.

The streamed test found and resolved an isolate closure capturing unsendable controller state. It now uses a top-level analysis function and a data-only request.

## Development environment history

The first emulator launch failed because its system image was missing. A subsequent user launch succeeded, and the emulator is now connected. `tools/Launch-Android.ps1` provides a repeatable launch path from a normal, network-enabled PowerShell terminal; that complete script has not been executed here.

The restricted Flutter CLI encountered Windows child-process access failures and missing offline Gradle dependencies. A temporary SDK copy also lacked integration-test Java sources; active project metadata was corrected to use the complete installed SDK at `C:/flutter`. A subsequent Android Studio build generated an APK. Local SDK copies, diagnostic overrides and caches are excluded from version control. No installation, microphone test, device integration test or measured real-spoke accuracy is claimed.

On a normally connected development machine, run the README commands and [device checklist](DEVICE_VALIDATION.md). Build logs/toolchain copies live in ignored `.tooling/`; the reproducible direct test script writes to ignored `artifacts/direct-tests/`.

## Deliberate implementation choices

- Native Android `AudioRecord` and a small Dart radix-2 FFT/YIN implementation replace the previously proposed `record`/`fftea` packages because those packages were unavailable in the offline cache. The audio adapter is injectable, so a package implementation can replace it later. This increases the native/DSP code that must be maintained and validated.
- ChangeNotifier, constructor injection and a repository separate UI, measurement logic and persistence. Immutable handwritten models and SDK JSON replace code generation for this small offline prototype. These are intentional simplifications of the architecture skill's suggested tooling.
- Local writes use a flushed pending file and a previous snapshot. Corrupt main data is surfaced without silently resetting it. Export uses Android's document picker; no broad storage permission is requested.
- Source configuration, units, capture source, algorithm identifier and contact mode accompany saved readings. Profile changes prevent comparisons with incompatible references.
- Raw audio retention, replay/import, automatic tension targets, stiffness models, validated force conversion, uncertainty estimates and production signing are not implemented. No validated spoke catalogue ships.

## Before a usable release

Rebuild and install the APK and complete the device checklist, investigate real microphone failure modes and collect repeatability evidence. Validate absolute tension separately against a calibrated reference with independent held-out observations before treating any displayed model value as a tension measurement. The user currently has a wheel but no tension meter; frequency-only testing can proceed without changing its tension. The experimental calculator does not replace this validation.
