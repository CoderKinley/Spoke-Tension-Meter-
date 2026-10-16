# Measuring and revisiting individual spokes

Measure is a fixed dashboard: frequency and waveform at the top, a numbered wheel beneath, and microphone, **Save & next**, and skip controls at the bottom. Portrait and landscape layouts share this workflow. Wheel/preset editing is under **Wheels** or the top-right tools menu; model calculations are under **Tension**. Sound references, calibration and capture sensitivity are menu destinations.

## Map a wheel

1. Choose or create the actual wheel profile. Record front/rear, the actual spoke count, tire state and known spoke/contact details. The Kona equipment preset still requires a confirmed count. Front and rear are different profiles, each with independent left/right measurements.
2. Choose front/rear and left/right with the dashboard switches. If a corresponding wheel is missing, the app opens its setup instead of inventing or copying measurements. With multiple matching profiles, choose the intended one.
3. Number spokes on the selected side clockwise from the valve, viewed from that side. A 32-spoke wheel normally has 16 indexed positions per side in this app. Keep the numbering convention consistent when returning.
4. Tap the microphone. Gently pluck the selected spoke repeatedly, allowing each ring to decay. Live frames provide quick feedback; only separately detected plucks contribute to the repeat set. Three agreeing readings (sample relative standard deviation ≤1.5%) produce a **SETTLED** median and enable saving. This describes repeatability, not established physical accuracy.
5. Press **Save & next**. The selected position is saved and the next one is highlighted. The microphone remains open, but the app waits for quiet before arming the next position, preventing the previous ring from being assigned to it. The arrow button skips without saving. The reset button clears the current unsaved capture.

The final position's save wraps to position one. Switch sides or wheels explicitly; their readings never merge. A session does not erase previous mapped readings. On restart, the most recently stored reading identifies the wheel/side to resume and its following position. Saved records remain available across sessions.

## Inspect a spoke

Tap its numbered point to open details. The page shows the latest stored Hz, repeat count, spread, detection/contact mode, timestamp and earlier readings for the same wheel-side configuration and position. **Measure spoke N** returns with that position selected and a fresh capture. Revisiting a spoke does not delete its history.

If a model estimate was attached at saving time, details also show N/kgf and the exact length, diameter and density assumptions. Otherwise the record stays frequency-only. Changing settings does not retroactively attach a tension estimate to old records. Altering a wheel's geometry/contact configuration separates its current map from incompatible records; raw history/export is retained.

Short clean decays may be mapped as frequency-only after a conservative single-window fallback. Mixed confirmation levels remain frequency-only, even when Hz agrees. Overlapping live windows do not manufacture three independent plucks, and no display precision is a promise of exact frequency or safe tension.

## Verification

The dashboard is covered at 320×640 (150% text), 360×800, 412×915 (200% text), and 800×420 landscape without a Measure scroll view or hidden capture controls. Tests exercise settling despite live-frame variation, saving/advancing, microphone continuity, old-ring suppression, persistent maps, front/rear and side isolation, spoke-detail navigation and saved assumption snapshots. Widget previews use synthetic measurements: [dashboard](previews/measure.png), [landscape](previews/measure-landscape.png), [details](previews/spoke-details.png).
