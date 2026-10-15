# Phase 1: Research and Implementation Plan

**Project:** Flutter Android acoustic spoke meter  
**Date:** 15 October 2026  
**Status:** Research and proposal for user review. Application implementation has not started.  
**Available equipment:** The user has a bicycle wheel but no mechanical tension meter.  
**Budget assumption:** Use the existing phone and wheel, free development tools, and local processing. No paid API or server is required.

## 1. Recommendation

Build an offline instrument with three clearly distinguished capabilities:

1. **Frequency measurement:** capture a plucked spoke, identify a credible fundamental frequency, and show repeatability and signal quality.
2. **Reference matching:** save several plucks as a baseline and compare later measurements under matching conditions. This directly addresses the requested tuning page.
3. **Calibrated tension estimation:** calculate newtons and kilograms-force only for supported configurations that pass physical validation. This capability depends on access to trustworthy force measurements.

Our first usable release can provide the first two capabilities with the equipment available. A saved sound records the wheel's current state; without an independent measurement, we cannot establish that the starting tension is correct. Frequency accuracy and force accuracy will have separate validation records.

## 2. What the research establishes

| Evidence | Finding | Consequence for this application |
| --- | --- | --- |
| John S. Allen, *Human Power* 53, 2002 | Compared 140 spokes across four wheels, yielding 93 acoustic readings because touching pairs were treated together. Reported correlation, systematic disagreement, and a need for better calibration. | Acoustic measurement is plausible, but a touching pair must not silently become two individual tension measurements. [Original study](https://www.ihpva.org/HParchive/PDF/hp53-2002.pdf) |
| University of Illinois engineering project, 2012 | Full results report about 6.2% average percent difference from a Park TM-1; removing two outliers reduced it to 4.8%. Meter calibration history was unknown, and different lacing patterns remained unexamined. | This is feasibility evidence, not a transferable phone accuracy claim. Keep outliers in our evaluation. [Final report, pp. 15–16](https://courses.grainger.illinois.edu/ece445/getfile.asp?id=5217) |
| DT Swiss Tensiometer manual | Appropriate tension depends on the wheel's components; mechanical meters also require correct handling and calibration. | Store reference instrument details and use component-specific targets. [Manufacturer manual, English section](https://d2a13k6araex7u.cloudfront.net/pmt/00/00/00/00/00/00/00/10/00/00/00/89/2/MAN_TDXT2XXNMADEFS_WEB_ZZ_001.pdf?v=67) |
| Park Tool wheel guidance | Manufacturer specifications govern target tension; tire pressure affects readings, and wheel condition involves trueness and dish as well as tension. | Record tire state and wheel side; pitch matching cannot establish overall wheel condition. [Tension guidance](https://www.parktool.com/en-us/blog/repair-help/wheel-tension-balance-app-instructions), [wheel truing](https://www.parktool.com/en-us/blog/repair-help/wheel-and-rim-truing) |

**Evidence limit:** No recordings from the user's wheel, phone measurements, or calibration experiments have been performed. Published results do not validate our future implementation.

## 3. Physics and calculation design

### 3.1 Ideal string baseline

For a uniform, flexible string with fixed endpoints and small transverse vibrations:

```text
f1 = (1 / (2L)) * sqrt(T / mu)
T  = 4 * mu * L^2 * f1^2
mu = rho * A
A_round = pi * d^2 / 4
T_kgf = T_newtons / 9.80665
```

`f1` is fundamental frequency in Hz; `L` is vibrating length in metres; `mu` is mass per length in kg/m; `rho` is material density in kg/m³; `d` is diameter in metres. This is the baseline model, not a complete model of every installed spoke. [Allen's physical explanation](https://sheldonbrown.com/pitch-equation.html)

**Illustrative calculation, not a target:** assuming a uniform 2.0 mm spoke, `rho = 7850 kg/m³`, `L = 0.290 m`, and `f1 = 350 Hz` gives `mu = 0.02466 kg/m` and approximately `1016 N = 103.6 kgf`. Density and vibrating length here are explicit assumptions, not measured properties of the user's wheel.

Consequences derived from this equation:

- A frequency estimate 5% too high produces a tension estimate 10.25% too high.
- Mistaking the second harmonic for the fundamental produces four times the ideal tension.
- Entering 300 mm when the vibrating length is 290 mm produces about 7.0% excess tension, even with perfect audio.
- Diameter matters when computing force. Equal pitch does not imply equal tension for different diameters or lengths.

For small independent random uncertainties in a uniform round model:

```text
(sigmaT / T)^2 ≈ (sigmarho / rho)^2
                + (2 * sigmad / d)^2
                + (2 * sigmaL / L)^2
                + (2 * sigmaf / f)^2
```

Systematic errors from boundary conditions, coupling, or the wrong model are additional. Repeated identical readings do not remove those errors. We will not turn a signal-quality score into a claimed force confidence interval.

### 3.2 Real spoke complications

**Vibrating length:** catalogue spoke length, visible length, and effective vibrating length are different concepts. Contact at the hub, nipple, and crossings changes the motion. We will not automatically treat a crossing as a fixed endpoint or apply a universal length subtraction.

**Butted spokes:** diameter changes along the spoke. DT Competition, for example, includes a 2.0/1.8/2.0 mm profile. Knowing only the middle diameter does not characterize the entire vibrating structure. Store section dimensions where available; initially require matching empirical calibration for force estimates. [DT Competition specifications](https://www.dtswiss.com/en/components/spokes-and-nipples/spokes/dt-competition)

**Bladed spokes:** width and thickness do not establish the exact cross-sectional area or bending stiffness. Sapim describes the CX-Ray as a formed, elliptic profile. Do not assume every blade is a rectangle or a perfect ellipse. Plucking direction is also a test variable. [Sapim product brochure](https://www.sapim.be/sites/default/files/Sapim%20brochure%20def%20A5%202018-LR.pdf)

**Bending stiffness:** an ideal uniform, pinned stiff-string model gives:

```text
fn^2 = (n^2 * T) / (4 * mu * L^2)
     + (n^4 * pi^2 * E * I) / (4 * mu * L^4)
```

Here `n` is mode number, `E` is Young's modulus, and `I` is the second moment of area about the bending axis. Higher modes need not be exact integer multiples of the first. The formula assumes pinned endpoints; an installed spoke may not satisfy them. Use it to generate difficult test signals and investigate model error, not as an automatic universal correction. [Gràcia and Sanz-Perela, stiff-string derivation](https://arxiv.org/pdf/1603.05516)

**Touching spokes:** classify recordings as an individual-spoke protocol, a coupled-pair protocol, or unknown. Until validated, touching pairs support recorded-frequency comparisons only. Damping or separating another spoke can change boundary conditions; any such method needs its own repeatable protocol and calibration.

### 3.3 Support policy

| Profile | Initial capability | Requirement for force estimates |
| --- | --- | --- |
| Uniform round steel | Frequency and matched reference | Verified dimensions, protocol, calibration, and physical validation |
| Butted steel | Frequency and matched reference | Exact profile and validated empirical model |
| Bladed steel | Frequency and matched reference | Profile, orientation, protocol, and dedicated validation |
| Unknown, aluminium, titanium, carbon, or fibre spoke | Frequency recording where a mode is identifiable | Future material-specific research and validation |
| Touching/coupled pair | Pair-labelled frequency comparison | Future validated pair model; never automatically individual force |

The selector will include material, shape, diameter in mm, optional manufacturer/model, length, lacing/contact state, and wheel side. An honest **Unknown** selection is preferable to an invented default. Frequency-only recording must remain usable without these dimensions.

## 4. Audio and signal-processing plan

The following are proposed starting parameters to evaluate, not established specifications.

1. **Capture:** mono PCM16, requesting 48 kHz with a 44.1 kHz fallback. Verify the delivered format and sample rate. Handle partial buffers and dropped audio explicitly; avoid lossy speech encoding.
2. **Android source:** prefer supported `UNPROCESSED`, otherwise evaluate `VOICE_RECOGNITION`; request gain control, noise suppression, and echo cancellation disabled where possible. Device processing still needs testing. [Android recording guidance](https://developer.android.com/media/platform/mediarecorder)
3. **Pluck detection:** estimate background noise, detect an onset, then analyse the decaying sound after the initial impact. Reject clipping, inadequate signal, insufficient decay, and overlapping plucks.
4. **Spectral analysis:** remove DC and apply a Hann window. Start with 8192-sample FFT frames and overlapping analysis; compare shorter frames for rapidly decaying sounds. At 48 kHz this frame lasts 170.7 ms and bins are 5.86 Hz apart. Peak interpolation can improve estimation; zero-padding does not add physical resolution.
5. **Fundamental candidates:** compare spectral peaks and approximately harmonic patterns with a time-domain YIN estimate. YIN is an established periodicity estimator, but its published speech results do not prove spoke performance. [Original YIN paper abstract](https://pubmed.ncbi.nlm.nih.gov/12002874/)
6. **Ambiguity handling:** evaluate half/double-frequency alternatives, weak or missing fundamentals, inharmonic partials, and beating. Two agreeing algorithms are supporting evidence, not proof. A pure isolated peak can be fundamentally ambiguous.
7. **Repeatability:** collect at least three accepted plucks, summarize with median and spread, and preserve disagreement instead of smoothing it away. Repeatability thresholds will be determined on recordings.
8. **Output:** show accepted fundamental Hz or an explicitly labelled spectral peak. Ambiguous readings cannot drive force conversion. Never choose a harmonic merely because it is nearer the user's target.

Start detector evaluation over approximately 80–2500 Hz, retaining higher partials within the captured bandwidth. This is a research range, not a claim that all wheels fall within it. Report boundary hits rather than clamping estimates to the range.

Run DSP in a Dart isolate so recording and analysis do not stall the UI. Preserve test metadata: actual sample rate, source, phone/OS, clipping, signal metrics, candidate frequencies, selected mode, algorithm version, and rejection reason.

## 5. Screens and workflows

### Measure

Large frequency display, clear listening/accepted/retry states, repeat-pluck progress, and an optional spectrum. Show estimated N/kgf only when a valid calibrated profile applies; otherwise explain the missing requirement next to the result. Signal quality must remain distinct from tension-model validity.

### Reference and Tune

Capture at least five clean reference plucks, or enter a manual target Hz. Save the median, spread, date, wheel side, spoke/pair identity, profile, capture method, and tire state. The comparison shows Hz difference, percentage frequency difference, and optionally cents:

```text
cents = 1200 * log2(f / f_reference)
```

A reference without measured force is labelled **Saved sound reference**. It must never acquire a “correct tension” label just because it sounds clean or the user calls it perfect. Matching another spoke requires equivalent geometry and conditions; left and right sides have separate references.

For an identical, validated configuration under the ideal model:

```text
T / T_reference ≈ (f / f_reference)^2
```

This ratio is approximate when stiffness and coupling contribute. A one-point measured reference supports an experimental local comparison; it does not establish accuracy over a tension range. Manual tuning remains available, but changing targets does not change calibration status.

Optional reference-tone playback pauses measurement, then waits for speaker sound to decay before capture resumes.

### Wheels and History

Save profiles, number spokes from a recorded starting point, track each side separately, and distinguish pairs from individual spokes. Display missing and rejected readings explicitly. Include an accessible table and wheel diagram, session comparison, and local CSV/JSON export with units and calibration metadata. Unequal left/right targets are allowed; the app must not encourage equalizing the sides of a dished wheel. [Wheelbuilding guidance](https://sheldonbrown.com/wheelbuilding/)

### Calibration and Settings

Keep **sound reference**, **known-force reference**, and **validated calibration profile** as different records. Record the reference meter/model, applicable chart, calibration status, repeated readings, units, date, and operator. Fit `T = a*f^2 + b` only as a candidate empirical model with sufficient data; compare against the physical baseline and reject poor fits. This proposed fit is our engineering hypothesis, not a universal law.

Disable extrapolation beyond the validated frequency/tension interval. Profile, contact method, spoke orientation, or relevant capture changes trigger requalification. Store model versions; never silently rewrite historic results after an algorithm change.

## 6. Safety-related product requirements

- The app reports measurements and comparisons; it does not declare a wheel safe to ride.
- Manufacturer target ranges are entered with source, model, and measurement conditions. No universal “correct kgf” preset. Maximum permitted tension and recommended working tension are different fields.
- Unknown limits show **Target not established**. A value near a limit, or an uncertainty interval crossing it, cannot receive a reassuring in-range status.
- Unsupported geometry, out-of-range calibration, unstable mode selection, or invalid audio suppress force output rather than retaining a stale number.
- Ordinary users cannot turn a rejected reading into a validated force by manually selecting a peak. Diagnostic overrides remain clearly marked and outside validation.
- Frequency agreement cannot detect rim cracks, nipple damage, poor dish, or every tension imbalance. The measurement workflow must preserve that distinction.
- No automatic instructions such as “tighten one turn”; nipple adjustment and wheel geometry need broader assessment.

These are functional acceptance requirements driven by the user's stated safety concern, not substitutes for physical validation.

## 7. Validation with little or no equipment budget

### Stage A: Available now

Use the existing wheel without changing its tension. Mark spoke identities, photograph the configuration, and record whether crossings touch. Measure accessible dimensions if a ruler/caliper is available; keep unknowns unknown.

Collect repeated plucks across both sides and several phone positions. Start close to the spoke, for example 5–15 cm, and evaluate rather than prescribe that distance. Keep the wheel stationary and unloaded, record tire pressure/state, and use a consistent gentle pluck. Do not deflect or pinch a spoke while recording unless that is the explicitly tested protocol.

Test quiet conditions, ordinary room noise, different pluck positions and strengths, and supported orientations. A second phone or computer can play known tones to check capture behavior; that checks frequency, not spoke force. Synthetic fixtures verify exact mathematical cases independently.

**Stage A outcome:** a frequency/reference beta with measured repeatability and disclosed limitations. No absolute-tension validation claim.

### Stage B: Obtain reference force measurements

Try a borrowed calibrated meter, community workshop, or bike shop willing to measure spokes. This is a future access need, not a purchase requirement or an assumption that help will be free. Use the correct chart and repeated measurements; meter error contributes to the reference uncertainty. [Park Tool measurement procedure](https://www.parktool.com/en-us/blog/repair-help/wheel-tension-measurement)

Plan a pilot with at least three representative wheels for the proposed supported class, three Android phones, two operators, and ten independent plucks per tested condition. Measure all selected spokes mechanically. Obtain at least five reference-tension levels spanning the intended calibration interval using suitable workshop equipment or supervised wheel work. Do not intentionally over-tension a riding wheel to create test data.

Reserve whole wheels and sessions for evaluation rather than splitting neighbouring audio frames between fitting and testing. A family-wide profile needs evidence from unseen wheels; otherwise restrict it to the particular measured wheel and protocol. Repeated plucks are not independent examples of different wheels.

Report signed bias, median and 95th-percentile absolute relative error, worst error, rejection/acceptance rate, repeatability, and results by phone, profile, and contact state. Include rejected cases and outliers; uncertainty in the reference must be visible.

### Proposed engineering gates

These are starting targets for review, **not established safety standards or promised accuracy**:

| Capability | Proposed gate |
| --- | --- |
| Synthetic pitch estimation | At least 95% of accepted supported test cases within 1%; no accepted octave mistakes in the defined adversarial suite |
| Real-spoke repeatability | At least 95% of tested repeat sets have relative standard deviation no greater than 1% under the supported protocol |
| Practical usability | At least 90% acceptance on clean supported plucks; report rejection on difficult cases separately |
| Calibrated tension beta | On held-out data, median absolute relative error ≤5%, 95th percentile ≤10%, absolute signed mean bias ≤5%, and no accepted error >20%, reported with sample sizes and reference uncertainty |
| General release of a force profile | Independent wheelbuilder review plus evidence that the uncertainty is suitable for the intended manufacturer's range; passing beta targets alone is insufficient |

No finite suite proves zero risk. Failure to obtain reference data or meet the gates keeps that profile in frequency/reference mode. The app can still be useful while force estimation remains unavailable.

## 8. Flutter architecture and development choices

```text
lib/
  app/                  # theme, navigation, application composition
  core/audio/           # microphone source, lifecycle, PCM buffering
  core/dsp/             # pluck detection, FFT, YIN, mode selection
  core/physics/         # units, models, uncertainty, validity rules
  features/measure/
  features/reference/
  features/wheels/
  features/calibration/
  data/                 # versioned local records and repositories
test/
  fixtures/             # synthetic and consented labelled recordings
integration_test/
android/
```

Use Flutter stable and Dart, pinning the actual SDK/dependency versions when implementation starts. Candidate dependencies are [`record`](https://pub.dev/packages/record) for PCM streaming and [`fftea`](https://pub.dev/packages/fftea) for Fourier analysis. Evaluate the plugin's source-selection API; use a small Kotlin `AudioRecord` bridge only if required controls or format reporting are missing. These are proposed choices, not installed dependencies.

Keep physics and DSP as pure Dart modules with explicit result states. Use a small repository abstraction for versioned local storage, atomic writes, and export. Start with Flutter's built-in state primitives; additional state-management packages need a concrete benefit. Provisionally target Android API 23 or newer, subject to the selected Flutter/toolchain and device requirements.

No account, cloud processing, advertising, or background microphone use. Request microphone access when measuring; stop capture on backgrounding, permission loss, audio interruption, or device-route change. Raw audio is optional and saved only through an explicit user action. Session metadata remains local by default.

## 9. Phase two implementation milestones

| Milestone | Deliverable | Exit condition |
| --- | --- | --- |
| 1. Foundation | Flutter Android scaffold, navigation, units, result models, local schema, lint/test setup | Builds and launches on an actual phone; permission and lifecycle tests pass |
| 2. Capture and frequency | PCM pipeline, FFT/YIN evaluation, ambiguity rejection, recording diagnostics | Synthetic tests and initial real-wheel repeatability report |
| 3. Reference tuning | Record/manual baseline, comparisons, profile matching, local persistence | Reference workflows work offline; unknown force stays unknown |
| 4. Wheel sessions | Side-specific records, diagram/table, history and export | No missing, stale, coupled, or rejected reading represented as valid individual force |
| 5. Calibration engine | Candidate physical/empirical models, validity intervals, reference-data import | Mathematics and failure states tested; force output remains gated by physical evidence |
| 6. Field validation | Recorded evaluation with accessible reference equipment | Profile-specific report supports or rejects force availability |
| 7. Delivery | Installable release APK, usage guide, test report, dependency/license record | Final behavior and limitations documented; available capabilities meet their gates |

Implement milestones 1–4 first to produce a useful no-purchase frequency/reference app. Milestones 5–6 can progress technically, but reference equipment access controls whether absolute tension can be enabled. No calendar promise is made before the capture prototype and device testing establish feasibility.

Use unit tests for units, analytic examples, calibration bounds, and result validity; widget tests for ambiguous/rejected states; and device tests for PCM capture and lifecycle. Add adversarial fixtures for dominant second harmonics, missing fundamentals, inharmonic modes, coupled tones, speech/music, clipping, short decays, resampling, and truncated buffers. [Flutter testing guidance](https://docs.flutter.dev/testing/overview)

Expected development checks after scaffolding:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
flutter build apk --release
```

These commands are planned; no application exists yet to run them against. [Flutter CLI](https://docs.flutter.dev/reference/flutter-cli), [Dart formatter](https://dart.dev/tools/dart-format)

## 10. Review decisions and remaining information

**Recommended scope to review:** Android-only, offline, frequency and reference matching first, with physically validated tension as a gated capability. Start force research with uniform round steel spokes and expand only when evidence supports it.

The user's phone model/Android version, wheel/rim identity, spoke material/profile, lacing/contact arrangement, and any future access to a workshop will refine the plan. None is required to review this proposal. If the first wheel uses butted or bladed spokes, its frequency/reference workflows still remain in scope.

Phase one is complete as a research and planning artifact. Phase two begins after the user's requested review; physical accuracy remains an experimental question until measured.
