import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/widgets.dart';

enum _Topic { inspect, turns, lateral, radial }

/// Offline, illustrated education; never derives adjustment advice from audio.
class WheelGuide extends StatefulWidget {
  const WheelGuide({super.key});

  @override
  State<WheelGuide> createState() => _WheelGuideState();
}

class _WheelGuideState extends State<WheelGuide> {
  _Topic topic = _Topic.inspect;
  bool tighten = true;
  bool fromHub = false;
  bool rimRight = true;
  bool highSpot = true;

  bool get clockwise => tighten != fromHub;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('wheel-guide-scroll'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeading(
              'THE WHEEL WORKSHOP',
              'Learn the movement.',
              'See what turns, what moves, and what to check before touching a spoke.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final item in const [
                  (_Topic.inspect, 'Start here', Icons.search),
                  (_Topic.turns, 'Nipple turns', Icons.rotate_right),
                  (_Topic.lateral, 'Side wobble', Icons.swap_horiz),
                  (_Topic.radial, 'Roundness', Icons.circle_outlined),
                ])
                  ChoiceChip(
                    key: Key('guide-topic-${item.$1.name}'),
                    avatar: Icon(item.$3, size: 17),
                    label: Text(item.$2),
                    selected: topic == item.$1,
                    onSelected: (_) => setState(() => topic = item.$1),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ...switch (topic) {
              _Topic.inspect => inspection(),
              _Topic.turns => nippleTurns(),
              _Topic.lateral => lateral(),
              _Topic.radial => radial(),
            },
            const SizedBox(height: 20),
            const Note(
              'Stop for a cracked or sharply dented rim, broken spokes, a damaged tire, or a seized nipple. Have a wheel builder assess damage. This app cannot certify tension or a safe wheel.',
              color: amber,
              icon: Icons.front_hand_outlined,
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              key: const PageStorageKey('guide-sources'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Sources & scope'),
              subtitle: const Text('Offline notes · original diagrams'),
              children: const [
                _Source(
                  'Park Tool · Truing mechanics',
                  'https://www.parktool.com/en-us/blog/repair-help/how-wheel-truing-works',
                ),
                _Source(
                  'Park Tool · Lateral and radial truing',
                  'https://www.parktool.com/en-us/blog/repair-help/wheel-and-rim-truing',
                ),
                _Source(
                  'Park Tool · Basic lateral corrections',
                  'https://www.parktool.com/assets/doc/product/SW-2_instructions.pdf',
                ),
                _Source(
                  'Schwalbe · Tire fitting',
                  'https://www.schwalbe.com/en/technology-faq/mounting/',
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'General guidance for conventional rim-mounted, right-hand-thread nipples. Follow your wheel and tire manufacturer for limits and unusual systems. Illustrations exaggerate deviations; arrows show direction, not a turn amount. Reviewed October 2026.',
                    style: TextStyle(color: muted, height: 1.5, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> inspection() => [
    const _Lesson(
      number: '01',
      title: 'Rim or tire?',
      description: 'A wobbly tire does not always mean a bent wheel.',
      children: [
        _Diagram(
          kind: _Drawing.inspect,
          description:
              'Side view: a blue circular rim inside an uneven amber tire outline. Inspect the rim separately from the tire.',
        ),
        _Legend(first: 'Rim', second: 'Tire / bead line'),
        SizedBox(height: 16),
        _Step(
          '1',
          'Secure and inspect',
          'Seat the axle correctly and check for hub play. Support the bike securely; spin the wheel slowly by hand.',
        ),
        _Step(
          '2',
          'Watch the rim',
          'Use a truing stand or a secure pointer near the rim. Keep tools and fingers clear of the moving wheel. Watch the metal rim, not the tire tread.',
        ),
        _Step(
          '3',
          'Then check the tire',
          'If the rim runs straight but the tire hops, check whether its molded bead line stays evenly spaced from the rim. Uneven seating or a damaged casing needs tire service, not spoke adjustment.',
        ),
        Note(
          'For reseating, deflate and follow the tire/rim maker’s procedure. Never exceed the lower maximum pressure of the tire and rim. Do not try to inflate a visible bulge away.',
          color: amber,
        ),
      ],
    ),
    const SizedBox(height: 16),
    const _Lesson(
      number: 'BEFORE ADJUSTING',
      title: 'Measure first. Change gently.',
      description:
          'Use a correctly fitting spoke wrench. Mark the affected area, make small changes, then check again. Recheck roundness, lateral alignment, dish, and mechanical tension together.',
      children: [
        Note(
          'Frequency helps compare matching spokes on one wheel side. It cannot tell you how far to turn a nipple. Left and right sides may require different tensions and pitches.',
        ),
      ],
    ),
    const SizedBox(height: 16),
    const _Lesson(
      number: 'USING SPOKE LAB',
      title: 'Capture a useful baseline.',
      description:
          'Select the wheel and side. Number spokes clockwise from the valve, viewed from that side, and record tire state and spoke contact.',
      children: [
        Note(
          'In a quiet room, start listening and hold the phone near the spoke without touching it. Let each pluck decay. Three agreeing plucks enable Save & next; five can become a sound reference. Compare matching configurations only. Touching spokes may ring as a pair.',
        ),
      ],
    ),
  ];

  List<Widget> nippleTurns() => [
    _Lesson(
      number: '02',
      title: 'Which way do I turn?',
      description:
          'The nipple rotates around the spoke. The direction reverses when you look from the other end.',
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('guide-tighten'),
              label: const Text('Tighten'),
              selected: tighten,
              onSelected: (_) => setState(() => tighten = true),
            ),
            ChoiceChip(
              key: const Key('guide-loosen'),
              label: const Text('Loosen'),
              selected: !tighten,
              onSelected: (_) => setState(() => tighten = false),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          key: const Key('guide-from-hub'),
          contentPadding: EdgeInsets.zero,
          title: const Text('View from the hub side'),
          subtitle: Text(
            fromHub
                ? 'Looking along the spoke toward the rim.'
                : 'Looking from the tire bed toward the hub.',
          ),
          value: fromHub,
          onChanged: (value) => setState(() => fromHub = value),
        ),
        _Diagram(
          kind: _Drawing.turn,
          clockwise: clockwise,
          description:
              '${tighten ? 'Tighten' : 'Loosen'}: turn ${clockwise ? 'clockwise' : 'counterclockwise'} when looking ${fromHub ? 'from the hub toward the rim' : 'from the tire bed toward the hub'}.',
        ),
        const SizedBox(height: 12),
        Text(
          clockwise ? 'CLOCKWISE' : 'COUNTERCLOCKWISE',
          key: const Key('guide-turn-direction'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: accent,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${tighten ? 'Increases' : 'Decreases'} spoke tension · ${fromHub ? 'hub-side view' : 'tire-bed view'}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.5),
        ),
        const SizedBox(height: 18),
        const Note(
          'Standard right-hand threads only. The arrow illustrates direction, not how much to turn. Avoid twisting the spoke; bladed spokes need the appropriate holder. Stop if the nipple binds.',
          color: amber,
        ),
      ],
    ),
  ];

  List<Widget> lateral() => [
    _Lesson(
      number: '03',
      title: 'Correct side-to-side wobble.',
      description: 'Spokes pull the rim toward the hub flange they attach to.',
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('guide-rim-left'),
              label: const Text('Rim leans left'),
              selected: !rimRight,
              onSelected: (_) => setState(() => rimRight = false),
            ),
            ChoiceChip(
              key: const Key('guide-rim-right'),
              label: const Text('Rim leans right'),
              selected: rimRight,
              onSelected: (_) => setState(() => rimRight = true),
            ),
          ],
        ),
        _Diagram(
          kind: _Drawing.lateral,
          positive: rimRight,
          description:
              'End-on schematic. Rim displaced ${rimRight ? 'right' : 'left'} of center. Blue spokes attach to the ${rimRight ? 'left' : 'right'} hub flange and pull the rim back toward center.',
        ),
        const _Legend(first: 'Corrective pull', second: 'Displaced rim'),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Left hub flange',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                'Right hub flange',
                textAlign: TextAlign.end,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          rimRight ? 'Move the rim LEFT' : 'Move the rim RIGHT',
          key: const Key('guide-lateral-direction'),
          style: const TextStyle(
            color: accent,
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'In the affected zone, increasing tension on the ${rimRight ? 'left' : 'right'}-flange spokes pulls the rim that way. If that side is already highly tensioned, further tightening is not the right choice; opposite-side relief requires checking tension too.',
          style: const TextStyle(height: 1.5),
        ),
        const SizedBox(height: 14),
        const Note(
          'Left/right refer to this drawing. Trace spokes to their hub flange rather than guessing at a crossing. Mark the full deviation, work gradually, and recheck after each small correction.',
        ),
      ],
    ),
  ];

  List<Widget> radial() => [
    _Lesson(
      number: '04',
      title: 'Understand an out-of-round rim.',
      description:
          'Check the rim’s distance from the hub. A tire hop alone is not a radial rim error.',
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('guide-high-spot'),
              label: const Text('High spot'),
              selected: highSpot,
              onSelected: (_) => setState(() => highSpot = true),
            ),
            ChoiceChip(
              key: const Key('guide-low-spot'),
              label: const Text('Low spot'),
              selected: !highSpot,
              onSelected: (_) => setState(() => highSpot = false),
            ),
          ],
        ),
        _Diagram(
          kind: _Drawing.radial,
          positive: highSpot,
          description:
              'Side view. The amber rim has a ${highSpot ? 'high spot farther from' : 'low spot closer to'} the hub at the top. The correction arrow points ${highSpot ? 'toward' : 'away from'} the hub toward the blue reference circle.',
        ),
        const _Legend(first: 'Reference circle', second: 'Actual rim'),
        const SizedBox(height: 16),
        Text(
          highSpot
              ? 'High spot → toward the hub'
              : 'Low spot → away from the hub',
          key: const Key('guide-radial-direction'),
          style: const TextStyle(
            color: accent,
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          highSpot
              ? 'Where the rim lies too far out, tension increases across both flanges in that zone draw it inward. Establish lateral true first and check available tension before adding more.'
              : 'Where the rim lies too far in, reducing tension across both flanges in that zone lets it move outward. Reduce high spots first and reassess; never leave spokes slack.',
          style: const TextStyle(height: 1.5),
        ),
        const SizedBox(height: 14),
        const Note(
          'Work across both flanges to limit sideways movement; this does not mean both sides should have equal tension. Radial, lateral, dish, and tension corrections interact. Sharp dents may need rim replacement, not more adjustment.',
          color: amber,
        ),
      ],
    ),
  ];
}

class _Lesson extends StatelessWidget {
  const _Lesson({
    required this.number,
    required this.title,
    required this.description,
    required this.children,
  });
  final String number, title, description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LabCard(
    padding: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: accent,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(description, style: const TextStyle(color: muted, height: 1.5)),
        const SizedBox(height: 18),
        ...children,
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.description);
  final String number, title, description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: selectedSurface,
          child: Text(
            number,
            style: const TextStyle(color: foreground, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: muted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.first, required this.second});
  final String first, second;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 18,
    runSpacing: 8,
    children: [
      for (final item in [
        (first, accent, Icons.remove),
        (second, amber, Icons.more_horiz),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.$3, color: item.$2, size: 18),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                item.$1,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
    ],
  );
}

class _Source extends StatelessWidget {
  const _Source(this.title, this.url);
  final String title, url;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: accent, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SelectableText(
          url,
          key: PageStorageKey('guide-source-$url'),
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );
}

enum _Drawing { inspect, turn, lateral, radial }

class _Diagram extends StatelessWidget {
  const _Diagram({
    required this.kind,
    required this.description,
    this.clockwise = true,
    this.positive = true,
  });
  final _Drawing kind;
  final String description;
  final bool clockwise, positive;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    image: true,
    label: description,
    child: ExcludeSemantics(
      child: Container(
        height: 215,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: CustomPaint(
          key: Key('guide-diagram-${kind.name}'),
          painter: _GuidePainter(kind, clockwise, positive),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter(this.kind, this.clockwise, this.positive);
  final _Drawing kind;
  final bool clockwise, positive;

  Paint pen(Color color, [double width = 2]) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void arrow(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = pen(color, 2.5);
    canvas.drawLine(start, end, paint);
    final angle = (end - start).direction;
    for (final side in [-.55, .55]) {
      canvas.drawLine(
        end,
        end - Offset(math.cos(angle + side), math.sin(angle + side)) * 10,
        paint,
      );
    }
  }

  void dashedCircle(Canvas canvas, Offset center, double radius, Color color) {
    for (var i = 0; i < 40; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * math.pi / 20,
        math.pi / 36,
        false,
        pen(color),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width * .31, size.height * .34);
    switch (kind) {
      case _Drawing.inspect:
        for (var i = 0; i < 16; i++) {
          final angle = i * math.pi / 8;
          canvas.drawLine(
            center,
            center + Offset(math.cos(angle), math.sin(angle)) * radius,
            pen(muted.withValues(alpha: .25), 1),
          );
        }
        canvas.drawCircle(center, radius, pen(accent, 3));
        final tire = Path();
        for (var i = 0; i <= 120; i++) {
          final angle = i * math.pi / 60;
          final r = radius + 12 + math.sin(angle * 3) * 5;
          final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
          if (i == 0) {
            tire.moveTo(point.dx, point.dy);
          } else {
            tire.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(tire..close(), pen(amber, 2.5));
        canvas.drawCircle(center, 7, Paint()..color = accent);
      case _Drawing.turn:
        canvas.drawCircle(center, 30, pen(muted, 2));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: 16, height: 44),
            const Radius.circular(5),
          ),
          Paint()..color = muted,
        );
        canvas.drawLine(
          center - const Offset(0, 15),
          center + const Offset(0, 15),
          pen(ink, 3),
        );
        final sign = clockwise ? 1.0 : -1.0;
        const start = -math.pi / 2;
        final sweep = sign * math.pi * 1.55;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          pen(accent, 3),
        );
        final angle = start + sweep;
        final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;
        final tangent = Offset(-math.sin(angle), math.cos(angle)) * sign;
        arrow(canvas, end - tangent * 14, end, accent);
      case _Drawing.lateral:
        final top = Offset(center.dx, 30);
        final rimX = top.dx + (positive ? 28 : -28);
        final left = Offset(size.width * .2, size.height - 30);
        final right = Offset(size.width * .8, size.height - 30);
        for (var y = 26.0; y < 108; y += 12) {
          canvas.drawLine(
            Offset(center.dx, y),
            Offset(center.dx, y + 6),
            pen(muted.withValues(alpha: .45), 1),
          );
        }
        canvas.drawLine(left, right, pen(muted.withValues(alpha: .4), 8));
        for (final flange in [left, right]) {
          final corrective = positive ? flange == left : flange == right;
          final color = corrective ? accent : muted.withValues(alpha: .3);
          canvas.drawLine(
            flange,
            Offset(rimX, 92),
            pen(color, corrective ? 2.5 : 1.5),
          );
          canvas.drawCircle(flange, 6, Paint()..color = color);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rimX - 7, 31, 14, 62),
            const Radius.circular(5),
          ),
          pen(amber, 3),
        );
        arrow(canvas, Offset(rimX, 15), Offset(center.dx, 15), accent);
      case _Drawing.radial:
        final circleCenter = center + const Offset(0, 6);
        dashedCircle(canvas, circleCenter, radius, accent);
        final rim = Path();
        for (var i = 0; i <= 160; i++) {
          final angle = i * math.pi / 80;
          final distance = math.atan2(
            math.sin(angle + math.pi / 2),
            math.cos(angle + math.pi / 2),
          );
          final bump =
              math.exp(-distance * distance / .20) *
              radius *
              .25 *
              (positive ? 1 : -1);
          final point =
              circleCenter +
              Offset(math.cos(angle), math.sin(angle)) * (radius + bump);
          if (i == 0) {
            rim.moveTo(point.dx, point.dy);
          } else {
            rim.lineTo(point.dx, point.dy);
          }
          if (i % 10 == 0) {
            canvas.drawLine(
              circleCenter,
              point,
              pen(muted.withValues(alpha: .25), 1),
            );
          }
        }
        canvas.drawPath(rim..close(), pen(amber, 3));
        final start =
            circleCenter - Offset(0, radius * (positive ? 1.25 : .75));
        final end = circleCenter - Offset(0, radius);
        arrow(canvas, start, end, foreground);
        canvas.drawCircle(circleCenter, 7, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) =>
      kind != oldDelegate.kind ||
      clockwise != oldDelegate.clockwise ||
      positive != oldDelegate.positive;
}
