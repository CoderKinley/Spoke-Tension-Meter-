import 'package:flutter/material.dart';
import '../app/lab_controller.dart';
import '../app/theme.dart';
import '../app/widgets.dart';
import '../core/physics/tension.dart';
import '../data/models.dart';
import '../data/wheel_presets.dart';

Future<void> showIdealStringDialog(
  BuildContext context,
  LabController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => _IdealStringDialog(controller: controller),
);

/// Always visible with the frequency result, including before setup.
class MeasureTensionReadout extends StatelessWidget {
  const MeasureTensionReadout({
    super.key,
    required this.controller,
    required this.onSetupWheel,
    required this.onEditProfile,
  });
  final LabController controller;
  final VoidCallback onSetupWheel, onEditProfile;

  @override
  Widget build(BuildContext context) {
    final estimate = controller.idealEstimate;
    final isKona = controller.hasKonaReference;
    final settings = controller.idealSettings;
    final hasExistingKona = controller.data.wheels.any(
      (wheel) => wheel.equipment?.presetId == konaProcess165Ar35.id,
    );
    final contact = controller.wheel.spec(controller.side).contact;
    return Container(
      key: const Key('measure-tension-readout'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: .06),
        border: Border.all(color: amber.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tension estimate',
            style: TextStyle(color: amber, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                estimate == null
                    ? '— N'
                    : '≈ ${estimate.newtons.toStringAsFixed(0)} N',
                key: const Key('measure-tension-newtons'),
                style: const TextStyle(color: amber, fontSize: 28),
              ),
              Text(
                estimate == null
                    ? '— kgf'
                    : '≈ ${(estimate.newtons / TensionMath.newtonsPerKgf).toStringAsFixed(1)} kgf',
                style: const TextStyle(color: amber, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            estimate != null
                ? 'Unvalidated · ${settings!.lengthMm} mm · assumed 2.0 mm steel. Accuracy is unknown.'
                : !isKona
                ? 'Choose your Kona wheel to set up the 272 mm, 2.0 mm steel reference model.'
                : controller.idealEstimateIssue!,
            style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 8),
          if (!isKona)
            OutlinedButton(
              key: const Key('measure-tension-setup'),
              onPressed: controller.saving ? null : onSetupWheel,
              child: Text(
                hasExistingKona ? 'Use Kona wheel' : 'Set up Kona wheel',
              ),
            )
          else ...[
            OutlinedButton(
              key: const Key('measure-tension-setup'),
              onPressed: controller.saving
                  ? null
                  : () => showIdealStringDialog(context, controller),
              child: Text(
                settings == null
                    ? 'Set up tension calculation'
                    : 'Edit calculation settings',
              ),
            ),
            TextButton(
              key: const Key('measure-spoke-profile'),
              onPressed: controller.saving ? null : onEditProfile,
              child: Text(
                contact == ContactMode.unknown
                    ? 'Confirm spoke contact in profile'
                    : 'Edit spoke profile',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class KonaFactoryReference extends StatelessWidget {
  const KonaFactoryReference({super.key});
  @override
  Widget build(BuildContext context) => const ExpansionTile(
    key: Key('kona-factory-reference'),
    tilePadding: EdgeInsets.zero,
    title: Text('Kona original reference (2019)'),
    children: [
      Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spokes: ${KonaOriginalReference.spokeLabel}\nRims: ${KonaOriginalReference.rimLabel}\nFront hub: ${KonaOriginalReference.frontHub}\nRear hub: ${KonaOriginalReference.rearHub}',
              style: TextStyle(color: muted, height: 1.6),
            ),
            SizedBox(height: 12),
            Note(
              '14g is nominally 2.0 mm. A uniform shaft and steel density of 7850 kg/m³ are calculator assumptions. The factory listing does not specify spoke length, exact spoke model, tension or target Hz. Your AR35 rebuild may use different spokes.',
              color: amber,
            ),
            SizedBox(height: 12),
            SelectableText(
              KonaOriginalReference.sourceUrl,
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}

class KonaTensionPanel extends StatelessWidget {
  const KonaTensionPanel({super.key, required this.controller});
  final LabController controller;
  @override
  Widget build(BuildContext context) {
    final settings = controller.idealSettings;
    final estimate = controller.idealEstimate;
    return LabCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('UNVALIDATED IDEAL-STRING MODEL', color: amber),
          const SizedBox(height: 16),
          const Text('Experimental tension', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 12),
          if (settings != null)
            Text(
              'Applied to this side: ${settings.lengthMm.toStringAsFixed(1)} mm vibrating length · assumed uniform 2.0 mm steel · 7850 kg/m³',
              style: const TextStyle(color: muted, height: 1.5),
            ),
          if (estimate != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '≈ ${estimate.newtons.toStringAsFixed(0)} N',
                  key: const Key('ideal-tension-newtons'),
                  style: const TextStyle(color: amber, fontSize: 32),
                ),
                Text(
                  '≈ ${(estimate.newtons / TensionMath.newtonsPerKgf).toStringAsFixed(1)} kgf',
                  style: const TextStyle(color: amber, fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Calculated from ${estimate.frequencyHz.toStringAsFixed(1)} Hz; accuracy is unknown.',
              style: const TextStyle(color: muted),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Note(controller.idealEstimateIssue ?? 'Waiting for readings.'),
          ],
          const SizedBox(height: 16),
          const Note(
            'This is an ideal-string calculation, not a mechanical measurement or a Kona tension target. Do not adjust spokes or decide wheel safety from this number alone.',
            color: amber,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('configure-ideal-model'),
            onPressed: controller.saving
                ? null
                : () => showIdealStringDialog(context, controller),
            child: const Text('Set length & assumptions'),
          ),
          if (settings != null)
            TextButton(
              onPressed: controller.saving
                  ? null
                  : controller.disableIdealString,
              child: const Text('Return to frequency only'),
            ),
          const KonaFactoryReference(),
        ],
      ),
    );
  }
}

class _IdealStringDialog extends StatefulWidget {
  const _IdealStringDialog({required this.controller});
  final LabController controller;
  @override
  State<_IdealStringDialog> createState() => _IdealStringDialogState();
}

class _IdealStringDialogState extends State<_IdealStringDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController length;
  late final String fingerprint;
  bool acknowledged = false, busy = false;
  String? issue;
  @override
  void initState() {
    super.initState();
    fingerprint = widget.controller.fingerprint;
    length = TextEditingController(
      text:
          (widget.controller.idealSettings?.lengthMm ??
                  KonaOriginalReference.ownerLengthHintMm)
              .toString(),
    );
  }

  @override
  void dispose() {
    length.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kona original-spec assumptions'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Note(
              '272 mm is the length supplied by you, not a Kona factory specification. Check it for this wheel side; a crossing is not automatically a fixed endpoint.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('ideal-model-length'),
              controller: length,
              decoration: const InputDecoration(
                labelText: 'Vibrating length assumption',
                suffixText: 'mm',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (s) {
                final value = double.tryParse(s ?? '');
                return value == null ||
                        !value.isFinite ||
                        value <= 0 ||
                        value > 500
                    ? 'Enter a positive length up to 500 mm'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            const Note(
              'Model: uniform 2.0 mm steel, density 7850 kg/m³. It does not model butting, blades, bending stiffness or touching spokes. No accuracy percentage has been established.',
              color: amber,
            ),
            CheckboxListTile(
              key: const Key('acknowledge-ideal-model'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: acknowledged,
              onChanged: busy
                  ? null
                  : (value) => setState(() => acknowledged = value ?? false),
              title: const Text(
                'Use these unverified assumptions for this side.',
              ),
            ),
            if (issue != null) Note(issue!, color: amber),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('apply-ideal-model'),
        onPressed: !acknowledged || busy
            ? null
            : () async {
                if (!form.currentState!.validate()) return;
                if (fingerprint != widget.controller.fingerprint) {
                  setState(
                    () => issue =
                        'Wheel configuration changed. Close this dialog and try again.',
                  );
                  return;
                }
                setState(() => busy = true);
                final ok = await widget.controller.configureIdealString(
                  double.parse(length.text),
                );
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    busy = false;
                    issue =
                        widget.controller.error ??
                        'Could not apply this model.';
                  });
                }
              },
        child: Text(busy ? 'Saving…' : 'Apply to this side'),
      ),
    ],
  );
}
