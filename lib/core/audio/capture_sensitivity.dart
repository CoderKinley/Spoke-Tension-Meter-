/// Digital detection thresholds, not microphone gain or an accuracy setting.
enum CaptureSensitivity {
  sensitive('Sensitive', .00008, 1.7),
  balanced('Balanced', .00025, 2.2),
  noisyRoom('Noisy room', .0008, 3.2);

  const CaptureSensitivity(this.label, this.minimumRms, this.noiseMultiplier);
  final String label;
  final double minimumRms, noiseMultiplier;
}
