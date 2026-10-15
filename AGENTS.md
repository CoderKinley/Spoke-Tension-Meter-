# Repository Guidelines

## Project Status & Structure

This repository is starting as a Flutter Android application for acoustic bicycle spoke measurements. `PHASE_1_PLAN.md` contains the research, proposed architecture, validation requirements, and implementation stages. No Flutter scaffold, tests, assets, or Git history existed when this guide was created. The user requested review of phase one before application implementation.

Once implementation begins, organize Dart code under `lib/`: `core/audio/`, `core/dsp/`, and `core/physics/` for measurement logic; `features/` for screens and workflows; and `data/` for local persistence. Place unit and widget tests in `test/`, device tests in `integration_test/`, and documented audio fixtures in `test/fixtures/`. Keep Android configuration in `android/` and research in Markdown documents.

## Build, Test, and Development Commands

After the Flutter scaffold exists, run commands from the repository root:

- `flutter doctor`: inspect development prerequisites.
- `flutter pub get`: install declared dependencies.
- `flutter run`: launch on a connected Android device.
- `dart format .` and `flutter analyze`: format and check Dart code.
- `flutter test`: run unit and widget tests.
- `flutter test integration_test`: run device integration tests.
- `flutter build apk --release`: generate a release APK.

## Coding Style & Naming Conventions

Use standard Dart formatting with two-space indentation, `lower_snake_case.dart` filenames, `UpperCamelCase` types, and `lowerCamelCase` members. Configure `flutter_lints` during setup. Keep physics and DSP independent of Flutter widgets. Use explicit units such as `frequencyHz`, `lengthMeters`, and `tensionNewtons`; convert display units at boundaries.

## Testing & Measurement Integrity

Use `flutter_test` and `integration_test`; name tests `*_test.dart`. Test unit conversions, harmonic ambiguity, silence, clipping, invalid profiles, calibration limits, and microphone lifecycle. Document recording provenance and reference instrument uncertainty. Synthetic audio verifies algorithms; physical measurements establish tension accuracy. Never equate a stable pitch or saved reference with a verified safe wheel. Unsupported configurations must retain frequency-only behavior.

## Commits & Pull Requests

No existing commit convention is available. Use concise imperative subjects; prefixes such as `feat:`, `fix:`, and `docs:` are recommended. PRs should describe behavior, reference relevant issues, report checks run, and include screenshots for UI changes. Measurement changes must document assumptions, evidence, and affected validation scope. Keep credentials, signing keys, and private recordings out of commits.
