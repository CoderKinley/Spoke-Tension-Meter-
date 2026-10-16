# Responsive acoustic capture

Updated 2026-10-16 after the owner reported missed plucks on a OnePlus 15 while another spoke tuner detected them.

## Findings and changes

The previous onset detector required RMS above `0.006` or four times the room estimate. Analysis rejected RMS below `0.002` and required two complete 8192-sample windows before displaying anything. These absolute digital cutoffs could exclude audible but quiet phone recordings. Its displayed frequency also pooled repeated plucks, which made comparing different spokes awkward.

Live pitch uses one rolling 8192-sample window and a 4096-sample hop. At 48/44.1 kHz, window accumulation is approximately 171/186 ms and hops are 85/93 ms; processing and device latency are additional. A single outstanding analysis task coalesces newer packets rather than queuing stale windows. An unsettled live result clears after 1.5 seconds without a valid tone. The redesigned dashboard holds a consistent repeat-set median once at least three separately detected plucks agree. Overlapping live frames never count as independent plucks. Save & next clears the capture and waits for the old ring to decay before arming the next spoke.

The analyser's minimum RMS is `0.00003`. Sensitive repeat capture starts above `max(0.00008, roomRms × 1.7)`; Balanced and Noisy room use higher thresholds. Warmup uses the quietest packet rather than letting a tap establish an inflated noise floor. This changes software detection thresholds, not hardware gain or microphone capability. Waveform display gain is capped at 200; the separate dBFS meter reports unamplified digital RMS.

The normal FFT/YIN/harmonic analysis runs first. If it cannot confirm a frequency, a conservative FFT fallback may display a prominent **spectral peak** between 50 and 3000 Hz. It checks spectral prominence, concentrated energy, clipping and competing tones. A peak is not certified as the fundamental. Silence, broad noise and unrelated strong simultaneous tones are covered by rejection tests. Speech and mains hum can still contain real periodic tones.

The earlier pin-and-compare card has been replaced by a persistent per-spoke wheel map; sound-reference controls remain in the tools menu. Saved readings use 80–2500 Hz and at least three consistent, separately detected plucks. A clean short decay may contribute frequency-only if the second window is below one quarter of the first window's RMS and the first passes the conservative live analysis; clipping and competing tones remain rejected. Such a result is marked unconfirmed. Agreeing mixed confirmation levels stay frequency-only, so they cannot inherit the stricter two-window fundamental qualification for tension. Lower/higher pitch alone does not establish a safe tension or prescribe a nipple turn.

## Research and verification

[SpokeTune's Android listing](https://play.google.com/store/apps/details?id=com.havranek.spoketune) describes immediate pitch feedback and a live level meter. Its listing does not disclose its algorithm or prove comparative accuracy. No claim of outperforming it has been established. [Android's recording guidance](https://developer.android.com/media/platform/mediarecorder) recommends UNPROCESSED where supported and VOICE_RECOGNITION as a fallback without AGC/noise suppression; the existing native capture already follows this approach. It was not necessary to change the Android bridge for this update.

70 unit/widget tests passed in the direct Flutter test harness, including quantized quiet PCM16 with noise/decay at 44.1/48 kHz, live low/high boundary peaks, clipping/noise/overlap rejection, a streamed first-window result, expiry, weak repeat capture, short-decay qualification, stable display despite live-frame variation, microphone continuity, persistent maps, context isolation and fixed-layout navigation. Analyzer checks are recorded in the implementation status. Test amplitudes/sample rates are explicit in the DSP/controller tests; these are synthetic fixtures, not wheel recordings.

A diagnostic update was installed on the connected CPH2745/Android 16 phone. The owner confirmed level movement and prompt Hz after a spoke pluck. This is an initial usability check, not independently measured frequency error or tension validation. See [device validation](DEVICE_VALIDATION.md) for the remaining checks.
