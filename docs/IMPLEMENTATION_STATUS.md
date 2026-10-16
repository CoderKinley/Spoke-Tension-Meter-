# Implementation and validation status

Updated 2026-10-16. Phase-two source implementation is available for a **frequency/reference beta**. A diagnostic update was installed and opened on the owner's OnePlus 15 (CPH2745, Android 16); the owner confirmed microphone-level movement and prompt Hz after a spoke pluck. Full device integration testing and independent physical validation remain outstanding.

The phone confirmation above applies to the preceding responsive-detector update. The subsequent fixed wheel-dashboard redesign has passed software checks and has a verified diagnostic APK ready; its second USB installation is awaiting Android confirmation. It has not yet been verified on the phone.

## Checks completed

- Dart analysis of application, unit/widget tests, device smoke test and test driver: no errors or warnings at the time of the recorded check.
- 65 unit/widget tests executed in Flutter's Windows test engine through a direct in-process test harness. All passed. The normal Flutter CLI runner could not start child processes in this session; this is not a claim that `flutter test` itself completed.
- Covered independent DFT versus FFT, harmonic signals at 44.1/48 kHz, dominant second harmonic, missing fundamental, single-tone labelling, clipping/noise/silence, unrelated tones, unstable windows, SI units, experimental calibration limits, repeat gates, reference context, PCM decoding, packet loss, stream closure, streamed audio through onset detection and the analysis isolate, persistence, corruption handling and navigation.
- The fixed Measure layout passed at 320 × 640 / 150% text, 360 × 800, 412 × 915 / 200% text, and 800 × 420 landscape. Frequency, wheel and controls fit without a Measure scroll view. Actual widget previews include the new dashboard, landscape and spoke details; these use injected data and are not device measurement screenshots.
- `MainActivity.kt` independently compiled with Kotlin 2.3.20, Android 36 API stubs, Flutter's matching embedding and lifecycle dependencies. This checks Kotlin/API compatibility, not Android runtime behavior or APK packaging.
- Android resources compiled with AAPT2; launcher artwork and the launch background are customized. The minimum Android version follows Flutter's API 24 requirement.
- Android Studio previously generated debug APKs, including the current cached `build/app/outputs/flutter-apk/app-debug.apk` (100,401,903 bytes). An emulator had also been launched during earlier setup.
- Added the 2019 Kona Process 165 / Race Face AR35 27.5-inch equipment preset with approximate 2021 replacement history. Tests cover count confirmation, front/rear identity, edits, persistence and legacy reference compatibility. No frequency target or measured spoke dimensions are assigned. See [preset research](KONA_PROCESS_165_PRESET.md).
- Added an explicitly unvalidated ideal-string calculator using the owner's 272 mm length hint and original-spec nominal 2.0 mm steel assumptions. Tests cover independent arithmetic, per-configuration scoping, stale-pluck clearing, incompatible geometry/contact, spectral-peak rejection, provenance and corrupt snapshot rejection, legacy archives, CSV, and the acknowledgement dialog at 150% text scale. Setup and calculated-value previews rendered successfully; examples use injected readings. No mechanical tension accuracy is established.
- Measure is now a fixed dashboard with frequency/waveform above the interactive wheel and Save & next below. Setup/presets and audio tools live in other pages/menu destinations, and Tension is its own page. Separately detected repeats settle to their median; compatible short decays may map frequency-only, while mixed confirmation levels never enable force. Tests cover context separation, saving/advancing with an open microphone, old-ring suppression, map restoration across sessions, details/history and saved tension snapshots. See [wheel mapping](WHEEL_MAPPING.md).
- Quiet-input regression tests cover quantized PCM16 with noise and decay at 44.1/48 kHz, live peak fallback outside the saved-reading range, first-window display, switching to a different pitch, stale-value expiry, mismatched detection modes, and low-amplitude streamed repeat capture. See [responsiveness investigation](RESPONSIVE_AUDIO.md).
- On-device diagnostic update: a newly compiled Dart kernel replaced only the cached debug APK's kernel; native code was unchanged. Cached engine version, merged/stripped native engine hashes and matching debug signing certificates were checked before installation. The update was zip-aligned, signed and verified; installation and launch succeeded. Phone confirmation is user-reported; no independent frequency or tension error was measured. App-process logs showed no matching Flutter exception or overflow at the check.

The streamed test found and resolved an isolate closure capturing unsendable controller state. It now uses a top-level analysis function and a data-only request.

## Development environment history

The first emulator launch failed because its system image was missing. A subsequent user launch succeeded. The latest device check used a USB-connected physical phone. `tools/Launch-Android.ps1` provides a repeatable launch path from a normal, network-enabled PowerShell terminal; that complete script has not been executed here.

The restricted Flutter CLI encountered Windows child-process access failures and missing offline Gradle dependencies. A temporary SDK copy also lacked integration-test Java sources; active project metadata was corrected to use the complete installed SDK at `C:/flutter`. Android Studio subsequently generated APKs. On 2026-10-16 the normal runner could not open the SDK lockfile because the installed SDK is read-only in this session; the temporary SDK copy also could not spawn Git. The batch bootstrap was stopped after it kept retrying the lock. The diagnostic kernel update described above allowed a phone check without modifying the SDK or active project metadata. It is not a completed normal Gradle rebuild. Local SDK copies, diagnostic helpers, APK provenance and caches are excluded from version control.

On a normally connected development machine, run the README commands and [device checklist](DEVICE_VALIDATION.md). Build logs/toolchain copies live in ignored `.tooling/`; the reproducible direct test script writes to ignored `artifacts/direct-tests/`.

## Deliberate implementation choices

- Native Android `AudioRecord` and a small Dart radix-2 FFT/YIN implementation replace the previously proposed `record`/`fftea` packages because those packages were unavailable in the offline cache. The audio adapter is injectable, so a package implementation can replace it later. This increases the native/DSP code that must be maintained and validated.
- ChangeNotifier, constructor injection and a repository separate UI, measurement logic and persistence. Immutable handwritten models and SDK JSON replace code generation for this small offline prototype. These are intentional simplifications of the architecture skill's suggested tooling.
- Local writes use a flushed pending file and a previous snapshot. Corrupt main data is surfaced without silently resetting it. Export uses Android's document picker; no broad storage permission is requested.
- Source configuration, units, capture source, algorithm identifier and contact mode accompany saved readings. Profile changes prevent comparisons with incompatible references.
- Raw audio retention, replay/import, automatic tension targets, stiffness models, validated force conversion, uncertainty estimates and production signing are not implemented. No validated spoke catalogue ships.

## Before a usable release

Rebuild and install the APK and complete the device checklist, investigate real microphone failure modes and collect repeatability evidence. Validate absolute tension separately against a calibrated reference with independent held-out observations before treating any displayed model value as a tension measurement. The user currently has a wheel but no tension meter; frequency-only testing can proceed without changing its tension. The experimental calculator does not replace this validation.
