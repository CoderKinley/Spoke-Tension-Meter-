import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/widgets.dart';
import '../core/physics/tension.dart';
import '../data/models.dart';

class SpokeDetailsPage extends StatelessWidget {
  const SpokeDetailsPage({
    super.key,
    required this.wheel,
    required this.side,
    required this.index,
    required this.readings,
    required this.onMeasure,
    required this.onTensionSetup,
  });
  final WheelProfile wheel;
  final WheelSide side;
  final int index;
  final List<SpokeReading> readings;
  final VoidCallback onMeasure, onTensionSetup;

  @override
  Widget build(BuildContext context) {
    final reading = readings.firstOrNull;
    final estimate = reading?.idealEstimate;
    return Scaffold(
      appBar: AppBar(title: Text('Spoke ${index.toString().padLeft(2, '0')}')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(wheel.name, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            '${wheel.wheelPosition ?? 'Wheel'} · ${side.name} side · numbered from the valve',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          LabCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reading == null
                      ? 'No saved reading'
                      : '${reading.frequencyHz.toStringAsFixed(1)} Hz',
                  key: const Key('spoke-detail-frequency'),
                  style: const TextStyle(fontSize: 38, color: accent),
                ),
                const SizedBox(height: 12),
                if (reading == null)
                  const Text(
                    'Pluck this spoke several times, then save its settled frequency. Earlier positions stay on the wheel map.',
                  )
                else ...[
                  Text(
                    '${reading.plucks} plucks · ${reading.spreadPercent.toStringAsFixed(2)}% repeat spread',
                  ),
                  const SizedBox(height: 8),
                  Text(reading.mode, style: const TextStyle(color: muted)),
                  const SizedBox(height: 8),
                  Text(
                    'Saved ${reading.createdAt.toLocal().toString().split('.').first}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LabCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tension estimate', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 12),
                if (estimate != null) ...[
                  Text(
                    '≈ ${estimate.newtons.toStringAsFixed(0)} N · ${(estimate.newtons / TensionMath.newtonsPerKgf).toStringAsFixed(1)} kgf',
                    key: const Key('spoke-detail-tension'),
                    style: const TextStyle(color: amber, fontSize: 25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Saved assumptions: ${estimate.settings.lengthMm} mm vibrating length, ${estimate.settings.diameterMm} mm uniform steel, ${estimate.settings.densityKgM3.toStringAsFixed(0)} kg/m³.',
                    style: const TextStyle(color: muted, height: 1.5),
                  ),
                ] else
                  const Text(
                    'Frequency only. Apply supported assumptions on Tension, then remeasure to save an estimate with its assumptions.',
                    style: TextStyle(color: muted, height: 1.5),
                  ),
                const SizedBox(height: 12),
                const Note(
                  'Ideal-string estimates are unvalidated. A settled pitch does not establish correct tension or wheel safety.',
                  color: amber,
                ),
                TextButton(
                  onPressed: onTensionSetup,
                  child: const Text('Open tension setup'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('measure-this-spoke'),
            onPressed: onMeasure,
            icon: const Icon(Icons.mic_none),
            label: Text('Measure spoke $index'),
          ),
          if (readings.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Saved history · ${readings.length}',
              style: const TextStyle(fontSize: 18),
            ),
            ...readings
                .take(50)
                .map(
                  (r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r.frequencyHz.toStringAsFixed(1)} Hz'),
                    subtitle: Text(
                      '${r.createdAt.toLocal().toString().split('.').first}\n${r.plucks} plucks · ${r.spreadPercent.toStringAsFixed(2)}% spread',
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            SelectableText(
              'Capture: ${reading!.captureSource}\nConfiguration: ${reading.fingerprint}',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
