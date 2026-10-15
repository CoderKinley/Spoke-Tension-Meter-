import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class LabCard extends StatelessWidget {
  const LabCard({super.key, required this.child, this.padding = 24});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = mint});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.eyebrow, this.title, this.description, {super.key});
  final String eyebrow, title, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: mint,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(description, style: const TextStyle(color: muted, height: 1.5)),
      ],
    ),
  );
}

class Note extends StatelessWidget {
  const Note(
    this.text, {
    super.key,
    this.icon = Icons.info_outline,
    this.color = muted,
  });
  final String text;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: color, height: 1.5, fontSize: 13),
        ),
      ),
    ],
  );
}

class AudioWave extends StatelessWidget {
  const AudioWave(this.samples, {super.key});
  final List<double> samples;

  @override
  Widget build(BuildContext context) => Semantics(
    label: samples.isEmpty
        ? 'Microphone waveform idle'
        : 'Live microphone waveform',
    child: SizedBox(
      height: 40,
      width: double.infinity,
      child: CustomPaint(painter: _AudioWavePainter(samples)),
    ),
  );
}

class _AudioWavePainter extends CustomPainter {
  _AudioWavePainter(this.samples);
  final List<double> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    canvas.drawLine(
      Offset(0, middle),
      Offset(size.width, middle),
      Paint()
        ..color = mint.withValues(alpha: .15)
        ..strokeWidth = 1,
    );
    if (samples.length < 2) return;
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i].clamp(-1.0, 1.0);
      // Compress the display range so gentle plucks remain visible.
      final amplitude = sample.sign * math.sqrt(sample.abs());
      final x = size.width * i / (samples.length - 1);
      final y = middle - amplitude * (middle - 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = mint
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_AudioWavePainter old) => old.samples != samples;
}

class SpectrumView extends StatelessWidget {
  const SpectrumView(this.values, {super.key});
  final List<double> values;
  @override
  Widget build(BuildContext context) => Semantics(
    label: values.isEmpty
        ? 'No spectrum recorded'
        : 'Recorded spectrum from zero to four kilohertz',
    child: Column(
      children: [
        SizedBox(
          height: 65,
          width: double.infinity,
          child: CustomPaint(painter: _SpectrumPainter(values)),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 Hz', style: TextStyle(color: muted, fontSize: 10)),
            Flexible(
              child: Text(
                'SPECTRUM',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 10, letterSpacing: 2),
              ),
            ),
            Text('4 kHz', style: TextStyle(color: muted, fontSize: 10)),
          ],
        ),
      ],
    ),
  );
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = muted.withValues(alpha: .12)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        grid,
      );
    }
    if (values.isEmpty) {
      return;
    }
    final pen = Paint()
      ..color = mint
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i < values.length; i++) {
      path.lineTo(
        size.width * i / (values.length - 1),
        size.height * (1 - math.sqrt(values[i]) * .9),
      );
    }
    canvas.drawPath(path, pen);
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) => old.values != values;
}

class WheelDiagram extends StatelessWidget {
  const WheelDiagram({
    super.key,
    required this.count,
    required this.measured,
    required this.selected,
  });
  final int count, selected;
  final Set<int> measured;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${measured.length} of $count positions recorded. Selected position $selected.',
    child: SizedBox(
      height: 240,
      width: 240,
      child: CustomPaint(painter: _WheelPainter(count, measured, selected)),
    ),
  );
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.count, this.measured, this.selected);
  final int count, selected;
  final Set<int> measured;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero),
        radius = math.min(size.width, size.height) / 2 - 24;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = muted.withValues(alpha: .3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 1; i <= count; i++) {
      final angle = 2 * math.pi * (i - 1) / count - math.pi / 2;
      final end =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      final color = measured.contains(i) ? mint : muted.withValues(alpha: .25);
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = color
          ..strokeWidth = i == selected ? 2.5 : 1,
      );
      canvas.drawCircle(
        end,
        i == selected ? 6 : 3.5,
        Paint()..color = i == selected ? amber : color,
      );
      if (i == 1 || i == selected) {
        final text = TextPainter(
          text: TextSpan(
            text: '$i',
            style: TextStyle(
              color: i == selected ? amber : muted,
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final at =
            center +
            Offset(
              math.cos(angle) * (radius + 16),
              math.sin(angle) * (radius + 16),
            );
        text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
      }
    }
    canvas.drawCircle(center, 10, Paint()..color = panel);
    canvas.drawCircle(center, 6, Paint()..color = mint);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => true;
}
