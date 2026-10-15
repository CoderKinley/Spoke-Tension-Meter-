import 'package:flutter/material.dart';
import '../app/lab_controller.dart';
import '../app/theme.dart';
import '../app/widgets.dart';
import '../data/models.dart';
import '../data/wheel_presets.dart';
import 'kona_reference.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.controller,
    required this.create,
  });
  final LabController controller;
  final bool create;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name,
      count,
      tire,
      diameter,
      length,
      width,
      thickness,
      butt;
  late String material, shape;
  late ContactMode contact;
  late final WheelProfile original;
  late WheelEquipment? equipment;
  BikeWheelPreset? preset;
  String wheelPosition = 'front';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    original = widget.create
        ? WheelProfile(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: '',
          )
        : widget.controller.wheel;
    equipment = original.equipment;
    final spec = original.spec(widget.controller.side);
    name = TextEditingController(text: original.name);
    count = TextEditingController(text: '${original.spokeCount}');
    tire = TextEditingController(
      text: original.tireState == 'Not recorded' ? '' : original.tireState,
    );
    diameter = TextEditingController(text: spec.diameterMm?.toString() ?? '');
    length = TextEditingController(text: spec.lengthMm?.toString() ?? '');
    width = TextEditingController(text: spec.widthMm?.toString() ?? '');
    thickness = TextEditingController(text: spec.thicknessMm?.toString() ?? '');
    butt = TextEditingController(text: spec.buttProfile);
    material = spec.material;
    shape = spec.shape;
    contact = spec.contact;
  }

  void selectPreset(String id) {
    setState(() {
      preset = wheelPresets.where((p) => p.id == id).firstOrNull;
      equipment = preset?.equipmentFor(wheelPosition);
      name.text = preset?.wheelName(wheelPosition) ?? '';
      // Require the actual wheel count; AR35 alone does not identify its build.
      count.text = preset == null ? '32' : '';
      for (final field in [tire, diameter, length, width, thickness, butt]) {
        field.clear();
      }
      material = 'Unknown';
      shape = 'Unknown';
      contact = ContactMode.unknown;
    });
  }

  @override
  void dispose() {
    for (final c in [
      name,
      count,
      tire,
      diameter,
      length,
      width,
      thickness,
      butt,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget dimension(
    TextEditingController controller,
    String label,
    double maximum,
  ) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      suffixText: 'mm',
      hintText: 'Unknown',
    ),
    validator: (s) {
      if (s == null || s.trim().isEmpty) {
        return null;
      }
      final value = double.tryParse(s);
      return value == null || !value.isFinite || value <= 0 || value > maximum
          ? 'Enter a value above 0 and up to $maximum'
          : null;
    },
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.create ? 'Add a wheel' : 'Wheel & spoke profile',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Spoke settings apply to the ${widget.controller.side.name} side.',
                style: const TextStyle(color: mint),
              ),
              const SizedBox(height: 20),
              if (widget.create) ...[
                DropdownButtonFormField<String>(
                  key: const Key('wheel-preset'),
                  initialValue: 'custom',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Start from a preset',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'custom',
                      child: Text('Custom wheel'),
                    ),
                    ...wheelPresets.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.label, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (id) {
                    if (id != null) selectPreset(id);
                  },
                ),
                const SizedBox(height: 14),
                if (preset != null) ...[
                  DropdownButtonFormField<String>(
                    key: const Key('preset-wheel-position'),
                    initialValue: wheelPosition,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Wheel position',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'front',
                        child: Text('Front wheel'),
                      ),
                      DropdownMenuItem(
                        value: 'rear',
                        child: Text('Rear wheel'),
                      ),
                    ],
                    onChanged: (position) {
                      if (position == null) return;
                      setState(() {
                        wheelPosition = position;
                        equipment = preset!.equipmentFor(position);
                        name.text = preset!.wheelName(position);
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ],
              if (equipment != null) ...[
                Note(
                  '${equipment!.summary}\nReplacement rims fitted around ${equipment!.replacementYearApprox}. Spoke build and rim variant need confirmation.',
                ),
                const SizedBox(height: 12),
                const Note(
                  'No target frequency is assigned. Enter the actual spoke count below; leave unknown spoke dimensions blank.',
                  color: amber,
                ),
                const SizedBox(height: 20),
                if (equipment!.presetId == konaProcess165Ar35.id)
                  const KonaFactoryReference(),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const Key('wheel-name'),
                controller: name,
                decoration: const InputDecoration(labelText: 'Wheel name'),
                validator: (s) =>
                    s == null || s.trim().isEmpty ? 'Enter a wheel name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('spoke-count'),
                controller: count,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total spoke count',
                ),
                validator: (s) {
                  final n = int.tryParse(s ?? '');
                  return n == null || n < 8 || n > 64 || n.isOdd
                      ? 'Use an even count from 8 to 64'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: tire,
                decoration: const InputDecoration(
                  labelText: 'Tire state / pressure',
                  hintText: 'e.g. tire off, or 40 psi',
                ),
              ),
              const SizedBox(height: 20),
              const Note(
                'Unknown dimensions are fine for frequency measurements. Never guess a diameter to obtain a force estimate.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('material-${preset?.id ?? 'custom'}'),
                initialValue: material,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Material'),
                items:
                    [
                          'Unknown',
                          'Steel',
                          'Aluminium',
                          'Titanium',
                          'Carbon / fibre',
                        ]
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                onChanged: (s) => setState(() => material = s!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('shape-${preset?.id ?? 'custom'}'),
                initialValue: shape,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Shape'),
                items: ['Unknown', 'Round / uniform', 'Butted', 'Bladed']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (s) => setState(() => shape = s!),
              ),
              const SizedBox(height: 14),
              dimension(length, 'Spoke length (catalogue / measured)', 500),
              const SizedBox(height: 14),
              dimension(diameter, 'Shaft diameter', 6),
              if (shape == 'Butted') ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: butt,
                  decoration: const InputDecoration(
                    labelText: 'Butted profile / model',
                    hintText: 'e.g. 2.0 / 1.8 / 2.0 mm',
                  ),
                ),
              ],
              if (shape == 'Bladed') ...[
                const SizedBox(height: 14),
                dimension(width, 'Blade width', 12),
                const SizedBox(height: 14),
                dimension(thickness, 'Blade thickness', 6),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<ContactMode>(
                key: ValueKey('contact-${preset?.id ?? 'custom'}'),
                initialValue: contact,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Contact arrangement',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ContactMode.unknown,
                    child: Text('Unknown'),
                  ),
                  DropdownMenuItem(
                    value: ContactMode.individual,
                    child: Text('Individual / not touching'),
                  ),
                  DropdownMenuItem(
                    value: ContactMode.coupled,
                    child: Text('Touching / coupled pair'),
                  ),
                ],
                onChanged: (s) => setState(() => contact = s!),
              ),
              const SizedBox(height: 20),
              const Note(
                'Changing this profile makes previous sound references incompatible. Catalogue length is not automatically vibrating length.',
                color: amber,
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('save-profile'),
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) {
                          return;
                        }
                        setState(() => busy = true);
                        final spec = SpokeSpec(
                          material: material,
                          shape: shape,
                          contact: contact,
                          diameterMm: double.tryParse(diameter.text),
                          lengthMm: double.tryParse(length.text),
                          widthMm: shape == 'Bladed'
                              ? double.tryParse(width.text)
                              : null,
                          thicknessMm: shape == 'Bladed'
                              ? double.tryParse(thickness.text)
                              : null,
                          buttProfile: shape == 'Butted'
                              ? butt.text.trim()
                              : '',
                        );
                        final wheel = WheelProfile(
                          id: original.id,
                          name: name.text.trim(),
                          spokeCount: int.parse(count.text),
                          tireState: tire.text.trim().isEmpty
                              ? 'Not recorded'
                              : tire.text.trim(),
                          left: widget.controller.side == WheelSide.left
                              ? spec
                              : original.left,
                          right: widget.controller.side == WheelSide.right
                              ? spec
                              : original.right,
                          equipment: equipment,
                        );
                        final ok = await widget.controller.saveWheel(wheel);
                        if (!context.mounted) {
                          return;
                        }
                        if (ok) {
                          Navigator.pop(context);
                        } else {
                          setState(() => busy = false);
                        }
                      },
                child: Text(busy ? 'Saving…' : 'Save profile'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
