import 'dart:async';
import 'package:flutter/material.dart';
import '../core/physics/tension.dart';
import '../data/models.dart';
import '../data/wheel_presets.dart';
import '../core/audio/capture_sensitivity.dart';
import '../features/profile_editor.dart';
import '../features/kona_reference.dart';
import '../features/measure_dashboard.dart';
import '../features/spoke_details.dart';
import '../features/wheel_guide.dart';
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
  Future<void> editProfile({
    bool create = false,
    bool konaPreset = false,
    String? position,
  }) async {
    await c.stop(discard: true);
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ProfileEditor(
        controller: c,
        create: create,
        initialPreset: konaPreset ? konaProcess165Ar35 : null,
        initialPosition: position,
      ),
    );
  }

  Future<void> chooseWheelPosition(String position) async {
    if (c.wheel.wheelPosition == position) return;
    final presetId = c.wheel.equipment?.presetId;
    final candidates = c.data.wheels
        .where(
          (wheel) =>
              wheel.wheelPosition == position &&
              wheel.equipment?.presetId == presetId,
        )
        .toList();
    if (candidates.length == 1) {
      await c.select(selectedWheel: candidates.single.id);
    } else if (candidates.isEmpty) {
      await editProfile(
        create: true,
        konaPreset: c.hasKonaReference,
        position: position,
      );
    } else {
      await openPage(
        'Choose $position wheel',
        () => candidates
            .map(
              (wheel) => ListTile(
                title: Text(wheel.name),
                onTap: () async {
                  await c.select(selectedWheel: wheel.id);
                  if (mounted) Navigator.pop(context);
                },
              ),
            )
            .toList(),
      );
    }
  }

  void showGuide() {
    unawaited(c.stop());
    setState(() => tab = 6);
  }

  Future<void> openPage(String title, List<Widget> Function() contents) async {
    await c.stop();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: c,
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: contents(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSpoke(int index) async {
    await c.stop();
    if (!mounted) return;
    final configuration = c.fingerprint;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SpokeDetailsPage(
          wheel: c.wheel,
          side: c.side,
          index: index,
          readings: c.readingsForSpoke(index),
          onMeasure: () {
            if (configuration == c.fingerprint) c.selectSpoke(index);
            Navigator.pop(context);
          },
          onTensionSetup: () {
            Navigator.pop(context);
            setState(() => tab = 4);
          },
        ),
      ),
    );
  }

  Future<void> saveAndNext() async {
    final completed = c.spokeIndex == c.wheel.spokeCount ~/ 2;
    if (await c.saveReading(continueListening: true)) {
      toast(
        completed
            ? 'Side recorded. You can review any spoke on the map.'
            : 'Spoke saved. Pluck the next selected spoke.',
      );
    }
  }

  List<Widget> tension() => [
    const PageHeading(
      'Model assumptions',
      'Tension, separately.',
      'Measurements stay on the wheel map. Model settings and estimates live here.',
    ),
    contextSelector(),
    const SizedBox(height: 16),
    MeasureTensionReadout(
      controller: c,
      onSetupWheel: setupKonaWheel,
      onEditProfile: () => editProfile(),
    ),
    if (c.hasKonaReference) const KonaFactoryReference(),
    const SizedBox(height: 20),
    const Note(
      'Saved spoke details show the estimate and assumptions that were attached when that reading was saved. Short decays and unconfirmed fundamentals remain frequency-only.',
      color: amber,
    ),
  ];

  List<Widget> captureSettings() => [
    const PageHeading(
      'Audio',
      'Capture settings',
      'Sensitivity affects repeated-pluck capture. Live frequency stays available for quiet tones.',
    ),
    DropdownButtonFormField<CaptureSensitivity>(
      initialValue: c.sensitivity,
      decoration: const InputDecoration(
        labelText: 'Repeat capture sensitivity',
      ),
      items: CaptureSensitivity.values
          .map(
            (value) => DropdownMenuItem(value: value, child: Text(value.label)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) c.setSensitivity(value);
      },
    ),
    const SizedBox(height: 24),
    SpectrumView(c.livePitch?.spectrum ?? c.latest?.spectrum ?? const []),
    const SizedBox(height: 16),
    SelectableText(
      c.captureSource,
      style: const TextStyle(color: muted, fontSize: 12),
    ),
    const SizedBox(height: 20),
    const Note(
      'Waveform scaling makes quiet input visible. The microphone meter reports digital input, not sound pressure. A stable pitch is a repeatability check, not a wheel-safety assessment.',
    ),
  ];

  Future<void> setupKonaWheel() async {
    final existing = c.data.wheels
        .where((wheel) => wheel.equipment?.presetId == konaProcess165Ar35.id)
        .firstOrNull;
    if (existing != null) {
      await c.select(selectedWheel: existing.id);
    } else {
      await editProfile(create: true, konaPreset: true);
    }
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
        title: Row(
          children: [
            const Icon(Icons.radar, color: accent, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'spoke lab',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.7,
                    ),
                  ),
                  Text(
                    c.wheel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            key: const Key('workshop-menu'),
            tooltip: 'Wheel setup and tools',
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              switch (value) {
                case 'wheels':
                  unawaited(c.stop());
                  setState(() => tab = 2);
                case 'kona':
                  unawaited(editProfile(create: true, konaPreset: true));
                case 'tension':
                  unawaited(c.stop());
                  setState(() => tab = 4);
                case 'references':
                  unawaited(openPage('References', tune));
                case 'calibration':
                  unawaited(openPage('Calibration', calibration));
                case 'audio':
                  unawaited(openPage('Capture settings', captureSettings));
                case 'guide':
                  showGuide();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'wheels', child: Text('Wheel profiles')),
              PopupMenuItem(value: 'kona', child: Text('Add Kona preset')),
              PopupMenuItem(value: 'tension', child: Text('Tension setup')),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'references',
                child: Text('Sound references'),
              ),
              PopupMenuItem(value: 'calibration', child: Text('Calibration')),
              PopupMenuItem(value: 'audio', child: Text('Capture settings')),
              PopupMenuItem(value: 'guide', child: Text('Wheel guide')),
            ],
          ),
          IconButton(
            tooltip: 'Wheel guide',
            onPressed: showGuide,
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
            : tab == 6
            ? const WheelGuide()
            : tab == 0
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: MeasureDashboard(
                    controller: c,
                    onPosition: chooseWheelPosition,
                    onSpoke: openSpoke,
                    onSave: saveAndNext,
                  ),
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
                          2 => wheels(),
                          _ => tension(),
                        },
                      ],
                    ),
                  ),
                ),
              ),
      ),
      bottomNavigationBar:
          tab == 0 &&
              MediaQuery.sizeOf(context).width >
                  MediaQuery.sizeOf(context).height
          ? null
          : NavigationBar(
              selectedIndex: tab == 0
                  ? 0
                  : tab == 2
                  ? 1
                  : tab == 4
                  ? 2
                  : 3,
              onDestinationSelected: (i) {
                if (i != 0) {
                  unawaited(c.stop());
                }
                setState(
                  () => tab = i == 0
                      ? 0
                      : i == 1
                      ? 2
                      : i == 2
                      ? 4
                      : 6,
                );
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.graphic_eq),
                  label: 'Measure',
                ),
                NavigationDestination(
                  icon: Icon(Icons.trip_origin),
                  label: 'Wheels',
                ),
                NavigationDestination(
                  icon: Icon(Icons.science_outlined),
                  label: 'Tension',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  label: 'Guide',
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
        if (c.wheel.equipment != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              c.wheel.equipment!.summary,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
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

  List<Widget> tune() {
    final ref = c.reference, hz = c.displayFrequencyHz;
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
                color: ref == null ? muted : accent,
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
              style: const TextStyle(color: accent, fontSize: 24),
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
    final byIndex = c.mappedReadings;
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
              'Latest saved · ${c.side.name} · ${c.wheel.tireState}',
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
            'No saved readings for this configuration yet. Measure a position three times, then save it.',
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
                  child: Text('$index', style: const TextStyle(color: accent)),
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
            Tag('VALIDATED FORCE UNAVAILABLE', color: amber),
            SizedBox(height: 16),
            Text(
              'A frequency is a measurement.\nTension needs a validated model.',
              style: TextStyle(fontSize: 22, height: 1.3),
            ),
            SizedBox(height: 16),
            Note(
              'This beta contains no physically validated tension profiles. The Kona ideal-string calculator provides explicitly unvalidated N/kgf estimates on Measure. Adding calibration points does not certify a model.',
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
