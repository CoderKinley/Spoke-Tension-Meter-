# Device validation

Status: **not performed**. No Android device was connected during implementation. Synthetic signals verify software behavior; they do not establish accuracy on a real spoke.

## First phone check

Run `flutter devices`, then `flutter run -d <device-id>`. Use a stationary, unloaded wheel in a quiet room. Do not adjust spoke tension for this initial check.

1. Deny microphone permission. Confirm a helpful error and no displayed measurement. Allow permission in Android settings and retry.
2. Select the wheel, side, tire state and spoke/contact description. Unknown values are acceptable for frequency collection.
3. Start listening; remain quiet during background measurement. Pluck one spoke gently, let it decay, and repeat. Record phone model, Android version, source/sample rate shown by the app, placement and room conditions.
4. After three consistent plucks, save a position. After five, save a sound reference on Tune. These repeat thresholds are provisional quality gates, not accuracy guarantees.
5. Repeat without changing the wheel. Compare repeatability at multiple phone distances and on both sides separately. Record rejected and octave-shifted readings, not just successful ones.
6. Confirm silence, speech, clipping and nearby ringing spokes do not create a convincing stable reading. A pure tone must be labelled **spectral peak**, never a verified fundamental.
7. Background the app, lock the screen, disconnect/change an audio route, interrupt with another recording app and revoke permission. Capture must stop or show an error; old results must not remain saveable after an interruption.
8. Restart the app. Wheel profiles, references and history must survive. New sessions start empty; previous sessions remain in history.
9. Export CSV and JSON through Android's file picker, including cancellation. Verify the files and their profile/audio metadata.
10. Check small screens, landscape, large text, the profile editor with the keyboard open, and Android back navigation.

## Absolute tension is a separate validation project

This version cannot unlock force estimates. Before implementing that feature, obtain a calibrated mechanical reference and the correct chart for each spoke. Record reference uncertainty, exact geometry, tire state, crossing/contact condition and raw measurement provenance. Reserve independent observations for validation; do not evaluate a fit only on its training points. Define supported configurations, uncertainty and rejection thresholds from those results.

Never tighten a wheel to match an arbitrary tone or compare left and right sides as though their target tensions were equal. Use the rim manufacturer's specified limits and qualified inspection for structural decisions. The detailed study and proposed validation gates are in [PHASE_1_PLAN.md](../PHASE_1_PLAN.md).
