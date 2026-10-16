import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/lab_controller.dart';
import '../app/theme.dart';
import '../app/widgets.dart';
import '../data/models.dart';

class MeasureDashboard extends StatelessWidget {
  const MeasureDashboard({
    super.key,
    required this.controller,
    required this.onPosition,
    required this.onSpoke,
    required this.onSave,
  });
  final LabController controller;
  final ValueChanged<String> onPosition;
  final ValueChanged<int> onSpoke;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final landscape = constraints.maxWidth > constraints.maxHeight * 1.25;
      final c = controller;
      final count = c.wheel.spokeCount ~/ 2;
      final wheel = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'WHEEL MAP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${c.mappedReadings.length}/$count recorded',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: InteractiveSpokeWheel(
              count: count,
              selected: c.spokeIndex,
              readings: c.mappedReadings,
              onSpoke: onSpoke,
            ),
          ),
        ],
      );
      final frequency = _FrequencyPanel(controller: c);
      return Padding(
        key: const Key('measure-dashboard'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SwitchPair(
                    labels: const ['Front', 'Rear'],
                    selected: c.wheel.wheelPosition,
                    values: const ['front', 'rear'],
                    onSelected: onPosition,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SwitchPair(
                    labels: const ['Left', 'Right'],
                    selected: c.side.name,
                    values: const ['left', 'right'],
                    onSelected: (value) =>
                        c.select(selectedSide: WheelSide.values.byName(value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  c.error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: amber, fontSize: 11),
                ),
              ),
            Expanded(
              child: landscape
                  ? Row(
                      children: [
                        Expanded(child: frequency),
                        const SizedBox(width: 12),
                        Expanded(child: wheel),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 5, child: frequency),
                        const SizedBox(height: 6),
                        Expanded(flex: 6, child: wheel),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.filledTonal(
                  key: const Key('capture-button'),
                  tooltip: c.listening ? 'Stop listening' : 'Start listening',
                  onPressed: c.starting
                      ? null
                      : () => c.listening ? c.stop() : c.start(),
                  icon: Icon(c.listening ? Icons.stop_rounded : Icons.mic_none),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('save-reading'),
                    onPressed: c.canSave ? onSave : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        c.spokeIndex == count
                            ? 'Save side · spoke $count'
                            : 'Save & next · ${c.spokeIndex + 1}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('skip-spoke'),
                  tooltip: 'Next spoke without saving',
                  onPressed: c.saving || c.starting
                      ? null
                      : () => c.selectSpoke(c.spokeIndex % count + 1),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              c.listening
                  ? 'Pluck 3 times · Save & next · tap a spoke for details.'
                  : 'Tap the microphone to listen. Tap a spoke for details.',
              key: const Key('measure-instruction'),
              maxLines: landscape ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 10, height: 1.3),
            ),
          ],
        ),
      );
    },
  );
}

class _SwitchPair extends StatelessWidget {
  const _SwitchPair({
    required this.labels,
    required this.values,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels, values;
  final String? selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: List.generate(
        2,
        (i) => Expanded(
          child: Semantics(
            selected: selected == values[i],
            child: TextButton(
              key: Key('measure-context-${values[i]}'),
              onPressed: () => onSelected(values[i]),
              style: TextButton.styleFrom(
                minimumSize: const Size(40, 34),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                backgroundColor: selected == values[i]
                    ? accent.withValues(alpha: .15)
                    : Colors.transparent,
                foregroundColor: selected == values[i] ? accent : muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(labels[i], style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FrequencyPanel extends StatelessWidget {
  const _FrequencyPanel({required this.controller});
  final LabController controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = controller;
      final tight = box.maxHeight < 190;
      return Container(
        key: const Key('frequency-panel'),
        width: double.infinity,
        padding: EdgeInsets.all(tight ? 12 : 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [readingSurface, panel],
          ),
          border: Border.all(color: accent.withValues(alpha: .12)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'SPOKE ${c.spokeIndex.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: accent,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    c.hasSettledFrequency
                        ? 'SETTLED'
                        : c.listening
                        ? 'LISTENING'
                        : 'READY',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      color: c.hasSettledFrequency ? accent : muted,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        c.displayFrequencyHz?.toStringAsFixed(1) ?? '—',
                        key: const Key('frequency-value'),
                        style: const TextStyle(
                          fontSize: 84,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Hz',
                        style: TextStyle(fontSize: 20, color: accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: tight ? 24 : 38,
              child: ValueListenableBuilder<List<double>>(
                valueListenable: c.waveform,
                builder: (context, samples, _) => AudioWave(samples),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.hasSettledFrequency
                        ? '${c.pluckCount} plucks · ${c.spreadPercent.toStringAsFixed(2)}% spread'
                        : '${c.pluckCount}/3 plucks · ${c.latest?.accepted == false ? 'try again' : 'repeat this spoke'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: ValueListenableBuilder<double>(
                    valueListenable: c.inputLevelDb,
                    builder: (context, db, _) => Semantics(
                      label: 'Microphone level ${db.toStringAsFixed(0)} dBFS',
                      child: LinearProgressIndicator(
                        key: const Key('microphone-level'),
                        minHeight: 3,
                        value: c.listening ? ((db + 100) / 100).clamp(0, 1) : 0,
                        color: db > -2 ? amber : accent,
                        backgroundColor: muted.withValues(alpha: .15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: IconButton(
                    key: const Key('reset-spoke'),
                    padding: EdgeInsets.zero,
                    iconSize: 17,
                    tooltip: 'Reset current spoke',
                    onPressed: c.saving ? null : c.resetPlucks,
                    icon: const Icon(Icons.refresh_rounded, color: muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class InteractiveSpokeWheel extends StatelessWidget {
  const InteractiveSpokeWheel({
    super.key,
    required this.count,
    required this.selected,
    required this.readings,
    required this.onSpoke,
  });
  final int count, selected;
  final Map<int, SpokeReading> readings;
  final ValueChanged<int> onSpoke;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final diameter = math.min(box.maxWidth, box.maxHeight);
      final radius = diameter * .4;
      return Center(
        child: SizedBox(
          key: const Key('interactive-wheel-map'),
          width: diameter,
          height: diameter,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapPainter(count, selected, readings.keys.toSet()),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: SizedBox(
                    width: diameter * .32,
                    height: diameter * .32,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selected.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 35,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          Text(
                            'OF $count',
                            style: const TextStyle(
                              fontSize: 10,
                              color: muted,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              for (var index = 1; index <= count; index++) ...[
                Positioned(
                  left:
                      diameter / 2 +
                      math.cos(
                            2 * math.pi * (index - .5) / count - math.pi / 2,
                          ) *
                          radius -
                      17,
                  top:
                      diameter / 2 +
                      math.sin(
                            2 * math.pi * (index - .5) / count - math.pi / 2,
                          ) *
                          radius -
                      17,
                  width: 34,
                  height: 34,
                  child: Semantics(
                    button: true,
                    selected: selected == index,
                    label:
                        'Spoke $index, ${readings.containsKey(index) ? '${readings[index]!.frequencyHz.toStringAsFixed(1)} Hz saved' : 'not recorded'}',
                    child: Tooltip(
                      message: 'Spoke $index',
                      child: InkResponse(
                        key: Key('wheel-spoke-$index'),
                        onTap: () => onSpoke(index),
                        radius: 20,
                        child: Center(
                          child: Container(
                            width: selected == index ? 27 : 23,
                            height: selected == index ? 27 : 23,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected == index
                                  ? amber
                                  : readings.containsKey(index)
                                  ? accent
                                  : panel,
                              border: Border.all(
                                color: selected == index
                                    ? amber
                                    : readings.containsKey(index)
                                    ? accent
                                    : muted.withValues(alpha: .4),
                              ),
                            ),
                            child: Text(
                              '$index',
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color:
                                    selected == index ||
                                        readings.containsKey(index)
                                    ? ink
                                    : muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.count, this.selected, this.measured);
  final int count, selected;
  final Set<int> measured;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero),
        radius = math.min(size.width, size.height) * .4;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = muted.withValues(alpha: .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(
      center,
      radius - 7,
      Paint()
        ..color = muted.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var index = 1; index <= count; index++) {
      final angle = 2 * math.pi * (index - .5) / count - math.pi / 2;
      final unit = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + unit * (radius * .43),
        center + unit * (radius - 11),
        Paint()
          ..color =
              (index == selected
                      ? amber
                      : measured.contains(index)
                      ? accent
                      : muted)
                  .withValues(alpha: index == selected ? .65 : .2)
          ..strokeWidth = index == selected ? 2 : 1,
      );
    }
    canvas.drawCircle(
      center,
      radius * .38,
      Paint()
        ..color = panel
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + Offset(0, -radius),
          width: 4,
          height: 13,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.count != count ||
      old.selected != selected ||
      !setEquals(old.measured, measured);
}
