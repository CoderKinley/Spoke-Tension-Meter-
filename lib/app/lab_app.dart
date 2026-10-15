import 'dart:async';
import 'package:flutter/material.dart';
import '../core/dsp/pitch_analyzer.dart';
import '../core/physics/tension.dart';
import '../data/models.dart';
import '../features/profile_editor.dart';
import 'lab_controller.dart';
import 'theme.dart';
import 'widgets.dart';

class LabApp extends StatefulWidget {
  const LabApp({super.key, required this.controller});
  final LabController controller;
  @override
  State<LabApp> createState() => _LabAppState();
}

class _LabAppState extends State<LabApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.controller.stop(discard: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Spoke Lab',
    debugShowCheckedModeBanner: false,
    theme: labTheme(),
    home: LabHome(controller: widget.controller),
  );
}

class LabHome extends StatefulWidget {
  const LabHome({super.key, required this.controller});
  final LabController controller;
  @override
  State<LabHome> createState() => _LabHomeState();
}

class _LabHomeState extends State<LabHome> {
  int tab = 0;
  LabController get c => widget.controller;
  Future<void> editProfile({bool create = false}) async {
    await c.stop(discard: true);
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ProfileEditor(controller: c, create: create),
    );
  }

  void toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> referenceDialog({required bool recorded}) async {
    final name = TextEditingController(
      text: recorded ? '${c.wheel.name} · ${c.side.name}' : 'My target',
    );
    final hz = TextEditingController();
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recorded ? 'Save this sound' : 'Set a frequency target'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Note(
                  'A sound reference does not verify correct tension.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Reference name',
                  ),
                  validator: (s) =>
                      s == null || s.trim().isEmpty ? 'Enter a name' : null,
                ),
                if (!recorded) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: hz,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Target frequency',
                      suffixText: 'Hz',
                    ),
                    validator: (s) {
                      final v = double.tryParse(s ?? '');
                      return v == null || !v.isFinite || v < 80 || v > 2500
                          ? 'Enter 80–2500 Hz'
                          : null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) {
                return;
              }
              final ok = await c.saveReference(
                name.text,
                manualHz: recorded ? null : double.parse(hz.text),
              );
              if (context.mounted) {
                Navigator.pop(context, ok);
              }
            },
            child: const Text('Save reference'),
          ),
        ],
      ),
    );
    // Controllers outlive the dialog's closing transition.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    hz.dispose();
    if (saved == true) {
      toast('Reference saved on this wheel side.');
    }
  }

  Future<void> calibrationDialog() async {
    final hz = TextEditingController(),
        force = TextEditingController(),
        instrument = TextEditingController();
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Known-force observation'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Note(
                  'Enter a mechanical measurement and its matching acoustic frequency. This collects evidence; it does not unlock force estimates.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: hz,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    suffixText: 'Hz',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (s) {
                    final v = double.tryParse(s ?? '');
                    return v == null || !v.isFinite || v < 80 || v > 2500
                        ? 'Enter 80–2500 Hz'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: force,
                  decoration: const InputDecoration(
                    labelText: 'Measured force',
                    suffixText: 'N',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (s) {
                    final v = double.tryParse(s ?? '');
                    return v == null || !v.isFinite || v <= 0 || v > 10000
                        ? 'Enter a positive force up to 10000 N'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: instrument,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Meter, chart & calibration details',
                  ),
                  validator: (s) => s == null || s.trim().length < 5
                      ? 'Record the reference instrument and chart'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) {
                return;
              }
              final ok = await c.addCalibration(
                CalibrationPoint(
                  frequencyHz: double.parse(hz.text),
                  tensionNewtons: double.parse(force.text),
                  instrument: instrument.text.trim(),
                  fingerprint: c.fingerprint,
                  createdAt: DateTime.now(),
                ),
              );
              if (ok && context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save observation'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    hz.dispose();
    force.dispose();
    instrument.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radar, color: mint, size: 28),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'spoke lab',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.7,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Measurement guide',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('A good measurement starts here'),
                content: const SingleChildScrollView(
                  child: Text(
                    '1. Keep the wheel stationary and unloaded. Record the tire state.\n\n'
                    '2. Start in a quiet room. Hold the phone near the spoke without touching it.\n\n'
                    '3. Wait for background-noise measurement. Gently pluck the same spoke and let it ring. Repeat three times to save, or five times for a reference.\n\n'
                    '4. Touching spokes may sound as a pair. Record the contact arrangement in the profile.\n\n'
                    '5. Compare matching configurations on the same wheel side. A matching sound does not establish correct tension or wheel safety.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: !c.loaded
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(c.error ?? 'Opening your workshop…'),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SingleChildScrollView(
                    key: ValueKey('page-$tab'),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (c.error != null) ...[
                          LabCard(child: Note(c.error!, color: amber)),
                          const SizedBox(height: 16),
                        ],
                        ...switch (tab) {
                          0 => measure(),
                          1 => tune(),
                          2 => wheels(),
                          _ => calibration(),
                        },
                      ],
                    ),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) {
          if (i >= 2) {
            unawaited(c.stop());
          }
          setState(() => tab = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.graphic_eq), label: 'Measure'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Tune'),
          NavigationDestination(icon: Icon(Icons.trip_origin), label: 'Wheels'),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            label: 'Calibration',
          ),
        ],
      ),
    ),
  );

  Widget contextSelector() => LabCard(
    padding: 16,
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: c.wheel.id,
                  isExpanded: true,
                  items: c.data.wheels
                      .map(
                        (w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null) {
                      unawaited(c.select(selectedWheel: id));
                    }
                  },
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit wheel profile',
              onPressed: () => editProfile(),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<WheelSide>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: WheelSide.left,
                    label: Text('Left side'),
                  ),
                  ButtonSegment(
                    value: WheelSide.right,
                    label: Text('Right side'),
                  ),
                ],
                selected: {c.side},
                onSelectionChanged: (v) => c.select(selectedSide: v.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${c.wheel.spec(c.side).shape} · ${c.wheel.spec(c.side).material} · ${c.wheel.spec(c.side).contact.name}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget captureButton() => FilledButton.icon(
    key: const Key('capture-button'),
    onPressed: c.starting ? null : () => c.listening ? c.stop() : c.start(),
    icon: Icon(c.listening ? Icons.stop_rounded : Icons.mic_none),
    label: Text(
      c.starting
          ? 'Opening microphone…'
          : c.listening
          ? 'Stop listening'
          : 'Start listening',
    ),
  );

  List<Widget> measure() => [
    const PageHeading(
      'Your pocket workshop',
      'Listen to your wheel.',
      'Measure a spoke’s resonance. Build a repeatable picture, one pluck at a time.',
    ),
    contextSelector(),
    const SizedBox(height: 16),
    LabCard(
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Tag(c.listening ? 'MICROPHONE ON' : 'FREQUENCY MODE'),
              Text(
                '${c.pluckCount}/3 plucks',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            c.processing
                ? 'ANALYSING'
                : c.latest?.kind == PitchKind.spectralPeak
                ? 'SPECTRAL PEAK'
                : 'RESONANCE',
            style: const TextStyle(
              color: muted,
              letterSpacing: 2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  c.frequencyHz?.toStringAsFixed(1) ?? '—',
                  key: const Key('frequency-value'),
                  style: const TextStyle(
                    fontSize: 76,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Hz', style: TextStyle(fontSize: 22, color: mint)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            c.status,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<List<double>>(
            valueListenable: c.waveform,
            builder: (context, samples, _) => AudioWave(samples),
          ),
          const SizedBox(height: 12),
          SpectrumView(c.latest?.spectrum ?? const []),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: captureButton()),
          if (c.pluckCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                Text(
                  'Spread ${c.spreadPercent.toStringAsFixed(2)}%',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                TextButton(
                  onPressed: c.processing ? null : c.resetPlucks,
                  child: const Text('Reset plucks'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 16),
    LabCard(
      padding: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_outline, color: mint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Position ${c.spokeIndex} · ${c.side.name} side',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Previous position',
                onPressed: () => c.select(
                  index: c.spokeIndex == 1
                      ? c.wheel.spokeCount ~/ 2
                      : c.spokeIndex - 1,
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next position',
                onPressed: () => c.select(
                  index: c.spokeIndex % (c.wheel.spokeCount ~/ 2) + 1,
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('save-reading'),
              onPressed: c.canSave
                  ? () async {
                      if (await c.saveReading()) {
                        toast('Reading saved. Ready for the next position.');
                      }
                    }
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Save reading & next'),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    const Note(
      'Force estimates are unavailable until this configuration is physically validated. Frequency repeatability is not tension accuracy.',
      color: amber,
      icon: Icons.science_outlined,
    ),
    const SizedBox(height: 12),
    Text(c.captureSource, style: const TextStyle(color: muted, fontSize: 11)),
  ];

  List<Widget> tune() {
    final ref = c.reference, hz = c.frequencyHz;
    final cents = ref != null && hz != null
        ? TensionMath.cents(hz, ref.frequencyHz)
        : null;
    return [
      const PageHeading(
        'Find your reference',
        'A sound to return to.',
        'Save a repeatable baseline or set your own frequency target.',
      ),
      contextSelector(),
      const SizedBox(height: 16),
      LabCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag('SAVED SOUND REFERENCE'),
            const SizedBox(height: 20),
            Text(
              ref?.name ?? 'No reference yet',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              ref == null
                  ? 'Capture five clean plucks on the Measure page, then save them here.'
                  : '${ref.frequencyHz.toStringAsFixed(1)} Hz',
              style: TextStyle(
                fontSize: ref == null ? 14 : 40,
                color: ref == null ? muted : mint,
              ),
            ),
            if (ref != null) ...[
              const SizedBox(height: 8),
              Text(
                '${ref.origin} · ${ref.plucks} plucks · ${ref.createdAt.toLocal().toString().substring(0, 16)}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('save-reference'),
                onPressed: c.canReference
                    ? () => referenceDialog(recorded: true)
                    : null,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text('Save ${c.pluckCount}/5 plucks as reference'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => referenceDialog(recorded: false),
                child: const Text('Enter target frequency'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      LabCard(
        child: Column(
          children: [
            Text(
              hz == null
                  ? 'Waiting for a pluck'
                  : '${hz.toStringAsFixed(1)} Hz',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 12),
            Text(
              cents == null
                  ? 'Your live comparison appears here.'
                  : '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents',
              style: const TextStyle(color: mint, fontSize: 24),
            ),
            if (cents != null) ...[
              const SizedBox(height: 6),
              Text(
                '${(hz! - ref!.frequencyHz).toStringAsFixed(1)} Hz · ${((hz / ref.frequencyHz - 1) * 100).toStringAsFixed(2)}% frequency difference',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: captureButton()),
            const SizedBox(height: 12),
            Text(
              c.status,
              style: const TextStyle(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Note(
        'Match the same spoke geometry, contact arrangement, tire state and wheel side. A matching tone does not establish correct tension.',
        color: amber,
      ),
      if (c.data.references.isNotEmpty) ...[
        const SizedBox(height: 20),
        ExpansionTile(
          title: Text('Reference history (${c.data.references.length})'),
          children: c.data.references.reversed
              .map(
                (r) => ListTile(
                  title: Text(r.name),
                  subtitle: Text(
                    r.fingerprint == c.fingerprint
                        ? 'Current configuration'
                        : 'Different configuration — comparison disabled',
                  ),
                  trailing: Text('${r.frequencyHz.toStringAsFixed(1)} Hz'),
                ),
              )
              .toList(),
        ),
      ],
    ];
  }

  List<Widget> wheels() {
    final readings = c.sessionReadings;
    final byIndex = <int, SpokeReading>{
      for (final r in readings) r.spokeIndex: r,
    };
    return [
      const PageHeading(
        'Keep the whole picture',
        'Your wheel notebook.',
        'Record positions from the valve, clockwise. Keep the two sides separate.',
      ),
      contextSelector(),
      const SizedBox(height: 16),
      LabCard(
        child: Column(
          children: [
            WheelDiagram(
              count: c.wheel.spokeCount ~/ 2,
              measured: byIndex.keys.toSet(),
              selected: c.spokeIndex,
            ),
            Text(
              '${byIndex.length} / ${c.wheel.spokeCount ~/ 2} positions recorded',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Current session · ${c.side.name} · ${c.wheel.tireState}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            const Note(
              'Touching pairs and unknown contact arrangements are recorded as such. The diagram does not imply individual tension.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () => editProfile(create: true),
            icon: const Icon(Icons.add),
            label: const Text('Add wheel'),
          ),
          OutlinedButton.icon(
            onPressed: () => c.newSession(),
            icon: const Icon(Icons.restart_alt),
            label: const Text('New session'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (byIndex.isEmpty)
        const LabCard(
          child: Note(
            'No readings in this session yet. Measure a position three times, then save it.',
          ),
        )
      else
        LabCard(
          padding: 8,
          child: Column(
            children: (byIndex.keys.toList()..sort()).map((index) {
              final r = byIndex[index]!;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: ink,
                  child: Text('$index', style: const TextStyle(color: mint)),
                ),
                title: Text('${r.frequencyHz.toStringAsFixed(1)} Hz'),
                subtitle: Text('${r.plucks} plucks · ${r.mode}'),
                trailing: Text(
                  '${r.spreadPercent.toStringAsFixed(2)}%',
                  style: const TextStyle(color: muted),
                ),
              );
            }).toList(),
          ),
        ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              if (await c.export(csv: true)) {
                toast('CSV exported.');
              }
            },
            icon: const Icon(Icons.ios_share),
            label: const Text('Export CSV'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              if (await c.export(csv: false)) {
                toast('JSON exported.');
              }
            },
            icon: const Icon(Icons.data_object),
            label: const Text('Export JSON'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ExpansionTile(
        title: Text('All saved readings (${c.data.readings.length})'),
        children: c.data.readings.reversed
            .take(100)
            .map(
              (r) => ListTile(
                title: Text(
                  '${r.frequencyHz.toStringAsFixed(1)} Hz · ${r.side.name} #${r.spokeIndex}',
                ),
                subtitle: Text(
                  '${r.createdAt.toLocal().toString().substring(0, 16)} · ${c.data.wheels.where((w) => w.id == r.wheelId).firstOrNull?.name ?? r.wheelId}\n${r.mode}',
                ),
                isThreeLine: true,
              ),
            )
            .toList(),
      ),
      const Note(
        'Exports include all sessions, profile snapshots and audio metadata. JSON also contains sound references and calibration observations.',
      ),
    ];
  }

  List<Widget> calibration() {
    final points = c.calibrationPoints;
    final summary = c.calibrationSummary;
    final fit = summary.fit, fitIssue = summary.issue;
    return [
      const PageHeading(
        'Evidence before estimates',
        'Calibrate with care.',
        'Collect known-force observations when you have access to a mechanical meter.',
      ),
      contextSelector(),
      const SizedBox(height: 16),
      const LabCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tag('FORCE ESTIMATES UNAVAILABLE', color: amber),
            SizedBox(height: 16),
            Text(
              'A frequency is a measurement.\nTension needs a validated model.',
              style: TextStyle(fontSize: 22, height: 1.3),
            ),
            SizedBox(height: 16),
            Note(
              'This beta measures sound and stores reference observations. It contains no physically validated tension profiles. Adding points does not certify a model or unlock N/kgf readings.',
              color: muted,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      LabCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${points.length} observations',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            const Text(
              'For this exact wheel-side configuration',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: calibrationDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add known-force observation'),
              ),
            ),
            if (fit != null) ...[
              const SizedBox(height: 20),
              const Tag('EXPERIMENTAL FIT', color: amber),
              const SizedBox(height: 10),
              Text(
                'T = ${fit.slope.toStringAsPrecision(5)} × f² ${fit.intercept < 0 ? '−' : '+'} ${fit.intercept.abs().toStringAsFixed(1)} N',
              ),
              const SizedBox(height: 8),
              Text(
                '${fit.minHz.toStringAsFixed(1)}–${fit.maxHz.toStringAsFixed(1)} Hz · training error ${fit.trainingErrorPercent.toStringAsFixed(1)}%',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 8),
              const Note(
                'Training error measures the fit to these points, not accuracy on new spokes. Independent validation is still required.',
              ),
            ],
            if (fitIssue != null) ...[
              const SizedBox(height: 12),
              Note(fitIssue, color: amber),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (points.isNotEmpty)
        LabCard(
          padding: 8,
          child: Column(
            children: points
                .map(
                  (p) => ListTile(
                    title: Text(
                      '${p.frequencyHz.toStringAsFixed(1)} Hz → ${p.tensionNewtons.toStringAsFixed(1)} N',
                    ),
                    subtitle: Text(p.instrument),
                  ),
                )
                .toList(),
          ),
        ),
      const SizedBox(height: 16),
      const ExpansionTile(
        title: Text('The physics, and its limits'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'For an ideal uniform string: T = 4μL²f².\n\nμ is mass per metre, L is vibrating length and f is the fundamental frequency. 1 kgf = 9.80665 N.\n\n'
              'Real spokes have bending stiffness, different end constraints and sometimes contact with other spokes. A wrong harmonic can multiply the estimate by four.\n\n'
              'Use the exact rim manufacturer’s limits and measurement conditions. A saved sound, a fitted curve or a true-looking wheel is not a safety assessment.',
              style: TextStyle(color: muted, height: 1.5),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Note(
        'All processing is on your phone. The microphone stops in the background. Raw recordings are not stored by this version.',
        icon: Icons.phonelink_lock,
      ),
    ];
  }
}
