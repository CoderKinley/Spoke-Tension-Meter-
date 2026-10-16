# Device validation

Status, 2026-10-16: **initial phone check performed; full validation pending**. A diagnostic update was installed and opened on the owner's OnePlus 15 (reported model; Android device identifier CPH2745, Android 16). The owner confirmed that the microphone level moves and Hz appears promptly when trying a spoke pluck. No independent frequency value, repeatability series or mechanical tension reference was supplied. Synthetic signals verify software behavior; they do not establish accuracy on a real spoke.

## First phone check

Run `flutter devices`, then `flutter run -d <device-id>`. Use a stationary, unloaded wheel in a quiet room. Do not adjust spoke tension for this initial check.

1. Deny microphone permission. Confirm a helpful error and no displayed measurement. Allow permission in Android settings and retry.
2. Select the wheel, side, tire state and spoke/contact description. Unknown values are acceptable for frequency collection.
3. Tap the microphone. Check that its level moves and a soft pluck produces a provisional Hz without waiting for three repeats. Repeat the same spoke until **SETTLED** appears and check the median and spread. Record phone model, Android version, source/sample rate (under **tools → Capture settings**), placement and room conditions. Unsettled live Hz should expire after about 1.5 seconds; a settled estimate should hold.
4. Use **Save & next** and verify the spoke dot becomes recorded, the selected number advances, and the microphone remains open. The previous ring must not be assigned to the next spoke. Open a saved dot and check its details/history. After five plucks, a sound reference can be saved through **tools → Sound references**. Repeat thresholds are provisional quality gates, not accuracy guarantees. Try the three sensitivity settings with quiet and noisy surroundings.
5. Repeat without changing the wheel. Compare repeatability at multiple phone distances and on both sides separately. Record rejected and octave-shifted readings, not just successful ones.
6. Confirm silence, clipping and overlapping tones are rejected. Check speech, hum and other tonal interference: a detector can find these, so do not assume displayed Hz belongs to a spoke. Saved single tones/short decays must stay frequency-only. Agreeing readings with mixed confirmation levels may settle numerically but must not enable tension; disagreeing tones must not become a saveable average.
7. Background the app, lock the screen, disconnect/change an audio route, interrupt with another recording app and revoke permission. Capture must stop or show an error; old results must not remain saveable after an interruption.
8. Switch front/rear and left/right and verify all four maps remain separate. Restart: the latest stored wheel/side resumes at its following position, and mapped readings and history survive. A new session retains the historical map while starting a fresh capture.
9. Export CSV and JSON through Android's file picker, including cancellation. Verify the files and their profile/audio metadata.
10. Check small screens, landscape, large text, the profile editor with the keyboard open, and Android back navigation.

## Absolute tension is a separate validation project

This version provides no validated force conversion. The optional Kona ideal-string calculator displays explicitly unvalidated estimates with recorded assumptions; calibration observations do not enable validated measurements. Before relying on absolute tension, obtain a calibrated mechanical reference and the correct chart for each spoke. Record reference uncertainty, exact geometry, tire state, crossing/contact condition and raw measurement provenance. Reserve independent observations for validation; do not evaluate a fit only on its training points. Define supported configurations, uncertainty and rejection thresholds from those results.

Never tighten a wheel to match an arbitrary tone or compare left and right sides as though their target tensions were equal. Use the rim manufacturer's specified limits and qualified inspection for structural decisions. The detailed study and proposed validation gates are in [PHASE_1_PLAN.md](../PHASE_1_PLAN.md).
