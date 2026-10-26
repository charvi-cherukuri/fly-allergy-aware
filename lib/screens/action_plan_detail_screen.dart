import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/models/action_plan.dart';
import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/screens/action_plan_edit_screen.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/services/handoff.dart';
import 'package:trace_allergy/theme.dart';

/// One action plan, read the way it will actually be read — FRD 1.3.
///
/// The reader is often a stranger: a seatmate, a flight attendant, a doctor
/// who answered the call. They have about ten seconds and no context. So the
/// dose and the physical location of the auto-injector come first and biggest,
/// and everything else is ordered by how soon it is needed.
///
/// The plan is the physician's. The app transcribes and displays it; it does
/// not generate a dose, a threshold, or an instruction, and the provenance
/// line on this screen says so and cannot be dismissed.
class ActionPlanDetailScreen extends StatelessWidget {
  const ActionPlanDetailScreen({super.key, required this.plan});

  final ActionPlan plan;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // Re-read by id so an edit made from this screen shows immediately, and
    // falls back to the passed plan if it has since been deleted.
    final ActionPlan current = app.actionPlans.firstWhere(
      (ActionPlan p) => p.id == plan.id,
      orElse: () => plan,
    );
    final Profile profile = app.activeProfile;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          current.title.trim().isEmpty ? 'Action plan' : current.title.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext _) =>
                    ActionPlanEditScreen(plan: current),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          _DoseHero(plan: current),
          const SizedBox(height: 12),
          const _ProvenanceLine(),
          if (current.isExpired || current.isExpiringSoon) ...<Widget>[
            const SizedBox(height: 12),
            _ExpiryLine(plan: current),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(68),
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              textStyle: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => _showToCrew(context, current),
            icon: const Icon(Icons.present_to_all, size: 28),
            label: const Text('Show to crew'),
          ),

          const SectionTitle('Allergic to'),
          _AllergenBlock(profile: profile),

          const SectionTitle('If symptoms start'),
          if (current.symptomSteps.isEmpty)
            const _Muted(text: 'No symptom steps on this plan yet.')
          else
            for (final step in current.symptomSteps) _StepBlock(step: step),

          if (current.medications.isNotEmpty) ...<Widget>[
            const SectionTitle('Other medications'),
            _Panel(
              children: <Widget>[
                for (final m in current.medications) _MedicationRow(med: m),
              ],
            ),
          ],

          const SectionTitle('Emergency contacts'),
          if (current.emergencyContacts.isEmpty)
            const _Muted(text: 'No contacts on this plan.')
          else
            _Panel(
              children: <Widget>[
                for (final c in current.emergencyContacts)
                  _CallRow(
                    title: c.name.trim().isEmpty ? 'Contact' : c.name.trim(),
                    subtitle: <String>[
                      if (c.relationship.trim().isNotEmpty)
                        c.relationship.trim(),
                      if (c.phone.trim().isNotEmpty) c.phone.trim(),
                    ].join(' · '),
                    phone: c.phone,
                  ),
              ],
            ),

          const SectionTitle('Physician'),
          if (_physicianIsBlank(current.physician))
            const _Muted(text: 'No physician on this plan.')
          else
            _Panel(
              children: <Widget>[
                _CallRow(
                  title: current.physician.name.trim().isEmpty
                      ? 'Physician'
                      : current.physician.name.trim(),
                  subtitle: <String>[
                    if (current.physician.clinic.trim().isNotEmpty)
                      current.physician.clinic.trim(),
                    if (current.physician.phone.trim().isNotEmpty)
                      current.physician.phone.trim(),
                  ].join(' · '),
                  phone: current.physician.phone,
                ),
              ],
            ),

          const SectionTitle('Patient'),
          _Panel(children: <Widget>[_PatientRow(plan: current)]),
        ],
      ),
    );
  }

  static void _showToCrew(BuildContext context, ActionPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext _) => _CrewView(plan: plan),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The top of the screen: the two facts a stranger needs first.
// ---------------------------------------------------------------------------

class _DoseHero extends StatelessWidget {
  const _DoseHero({required this.plan});

  final ActionPlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final epi = plan.epinephrine;
    final dose = _doseLine(epi);
    final detail = <String>[
      if (epi.brand.trim().isNotEmpty) epi.brand.trim(),
      '${epi.injectorCount} ${epi.injectorCount == 1 ? 'injector' : 'injectors'}',
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Eyebrow(text: 'Epinephrine', color: scheme.onPrimaryContainer),
          const SizedBox(height: 6),
          Text(
            dose,
            style: TextStyle(
              fontSize: 40,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: scheme.onPrimaryContainer.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          _Eyebrow(text: 'Carried', color: scheme.onPrimaryContainer),
          const SizedBox(height: 6),
          Text(
            epi.carryLocation.trim().isEmpty
                ? 'Not recorded'
                : epi.carryLocation.trim(),
            style: TextStyle(
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color.withValues(alpha: 0.75),
      ),
    );
  }
}

/// Persistent, non-dismissible. The boundary this whole feature rests on.
class _ProvenanceLine extends StatelessWidget {
  const _ProvenanceLine();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Written with the patient’s doctor. Trace stores this plan, it '
              'does not write one.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiryLine extends StatelessWidget {
  const _ExpiryLine({required this.plan});

  final ActionPlan plan;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final expired = plan.isExpired;
    final color = expired
        ? (dark ? TraceColors.unsafeDark : TraceColors.unsafe)
        : (dark ? TraceColors.cautionDark : TraceColors.caution);
    final on = plan.epinephrine.expiresOn;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            expired ? Icons.error_outline : Icons.access_time,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              expired
                  ? 'Auto-injector expired ${on == null ? '' : _formatDate(on)}'
                        .trim()
                  : 'Auto-injector expires ${on == null ? 'soon' : _formatDate(on)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Allergens — read live from the active profile, never copied onto the plan.
// ---------------------------------------------------------------------------

class _Allergy {
  const _Allergy(this.label, this.emoji, this.severity);
  final String label;
  final String emoji;
  final Severity severity;
}

List<_Allergy> _allergiesOf(Profile profile) => <_Allergy>[
  for (final a in profile.sorted)
    _Allergy(a.label, a.emoji, profile.severityOf(a)),
  for (final c in profile.customAllergens) _Allergy(c.name, c.emoji, c.severity),
];

class _AllergenBlock extends StatelessWidget {
  const _AllergenBlock({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final all = _allergiesOf(profile);
    if (all.isEmpty) {
      return const _Muted(text: 'No allergens on the profile yet.');
    }

    final severe = all
        .where((_Allergy a) => a.severity == Severity.severe)
        .toList();
    final rest = all
        .where((_Allergy a) => a.severity != Severity.severe)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (severe.isNotEmpty) ...<Widget>[
          Text(
            'Anaphylaxis risk',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _danger(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final a in severe) _AllergenChip(allergy: a, severe: true),
            ],
          ),
        ],
        if (rest.isNotEmpty) ...<Widget>[
          if (severe.isNotEmpty) const SizedBox(height: 14),
          Text(
            'Also avoids',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final a in rest) _AllergenChip(allergy: a, severe: false),
            ],
          ),
        ],
      ],
    );
  }
}

class _AllergenChip extends StatelessWidget {
  const _AllergenChip({required this.allergy, required this.severe});

  final _Allergy allergy;
  final bool severe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = _danger(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: severe
            ? danger.withValues(alpha: 0.14)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: severe
            ? Border.all(color: danger.withValues(alpha: 0.6), width: 2)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(allergy.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              allergy.label,
              style: TextStyle(
                fontSize: severe ? 17 : 15,
                fontWeight: severe ? FontWeight.w800 : FontWeight.w500,
                color: severe ? danger : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Symptom tiers
// ---------------------------------------------------------------------------

class _StepBlock extends StatelessWidget {
  const _StepBlock({required this.step});

  final SymptomStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = _severityColor(step.severity, dark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          // A non-uniform Border and a borderRadius cannot coexist on a
          // BoxDecoration — Flutter asserts. Uniform, in the tier's color.
          border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _severityLabel(step.severity),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            if (step.symptoms.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                step.symptoms.join(' · '),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (step.actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              for (final action in step.actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 10),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          action,
                          style: const TextStyle(fontSize: 16, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.title,
    required this.subtitle,
    required this.phone,
  });

  final String title;
  final String subtitle;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final callable = phone.trim().isNotEmpty;

    return InkWell(
      onTap: callable ? () => _dial(context, phone) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (callable)
              IconButton(
                tooltip: 'Call $title',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                onPressed: () => _dial(context, phone),
                icon: const Icon(Icons.call),
              ),
          ],
        ),
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  const _MedicationRow({required this.med});

  final Medication med;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = <String>[
      if (med.doseMg != null) '${_exact(med.doseMg)} mg',
      if (med.form.trim().isNotEmpty) med.form.trim(),
      if (med.route.trim().isNotEmpty) med.route.trim(),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            med.name.trim().isEmpty ? 'Medication' : med.name.trim(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(detail, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          if (med.notes.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              med.notes.trim(),
              style: TextStyle(height: 1.3, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.plan});

  final ActionPlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = plan.patient;
    final detail = <String>[
      if (p.dateOfBirth != null) 'Born ${_formatDate(p.dateOfBirth!)}',
      if (p.weightKg != null)
        '${_weight(p.weightKg!)} kg · ${_weight(p.weightLb!)} lb',
      plan.airlineLabel,
    ].join('\n');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            p.name.trim().isEmpty ? 'Patient' : p.name.trim(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(height: 1.4, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Crew mode
//
// Handed to someone else, at arm's length, in cabin light. Maximum contrast,
// very large type, and no gesture or chrome that could close it by accident —
// the back gesture and the system back button are both blocked, so the only
// way out is the Close button.
// ---------------------------------------------------------------------------

class _CrewView extends StatelessWidget {
  const _CrewView({required this.plan});

  final ActionPlan plan;

  @override
  Widget build(BuildContext context) {
    // Read live, like the detail screen: a plan handed to a stranger must not
    // show an allergen list the profile has since moved on from.
    final Profile profile = context.watch<AppState>().activeProfile;
    final epi = plan.epinephrine;
    final severe = _allergiesOf(profile)
        .where((_Allergy a) => a.severity == Severity.severe)
        .toList();
    final others = _allergiesOf(profile)
        .where((_Allergy a) => a.severity != Severity.severe)
        .toList();
    final severeStep = plan.symptomSteps
        .where((SymptomStep s) => s.severity == 'severe')
        .toList();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  children: <Widget>[
                    const _CrewLabel(text: 'Anaphylaxis action plan'),
                    const SizedBox(height: 4),
                    _CrewBig(
                      text: plan.patient.name.trim().isEmpty
                          ? 'Patient'
                          : plan.patient.name.trim(),
                      size: 28,
                    ),

                    const SizedBox(height: 28),
                    const _CrewLabel(text: 'Epinephrine'),
                    _CrewBig(text: _doseLine(epi), size: 46),
                    if (epi.brand.trim().isNotEmpty)
                      _CrewBig(text: epi.brand.trim(), size: 24),

                    const SizedBox(height: 24),
                    const _CrewLabel(text: 'Where it is'),
                    _CrewBig(
                      text: epi.carryLocation.trim().isEmpty
                          ? 'Not recorded'
                          : epi.carryLocation.trim(),
                      size: 34,
                    ),

                    const SizedBox(height: 28),
                    const _CrewLabel(text: 'Allergic to'),
                    if (severe.isEmpty && others.isEmpty)
                      const _CrewBig(text: 'Not recorded', size: 26)
                    else ...<Widget>[
                      for (final a in severe)
                        _CrewBig(
                          text: a.label,
                          size: 34,
                          color: TraceColors.unsafeDark,
                        ),
                      for (final a in others)
                        _CrewBig(text: a.label, size: 24),
                    ],

                    if (severeStep.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 28),
                      const _CrewLabel(text: 'Severe reaction'),
                      for (final s in severeStep) ...<Widget>[
                        if (s.symptoms.isNotEmpty)
                          _CrewBig(text: s.symptoms.join(' · '), size: 22),
                        const SizedBox(height: 10),
                        for (final action in s.actions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CrewBig(text: '• $action', size: 26),
                          ),
                      ],
                    ],

                    const SizedBox(height: 24),
                    Text(
                      'Written with the patient’s doctor.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrewLabel extends StatelessWidget {
  const _CrewLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

class _CrewBig extends StatelessWidget {
  const _CrewBig({required this.text, required this.size, this.color});

  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: color ?? Colors.white,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _doseLine(EpinephrineInfo epi) {
  if (epi.doseMg != null) return '${_exact(epi.doseMg)} mg';
  if (epi.brand.trim().isNotEmpty) return epi.brand.trim();
  return 'Dose not recorded';
}

bool _physicianIsBlank(PhysicianInfo p) =>
    p.name.trim().isEmpty && p.phone.trim().isEmpty && p.clinic.trim().isEmpty;

Color _danger(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? TraceColors.unsafeDark
    : TraceColors.unsafe;

Color _severityColor(String severity, bool dark) => switch (severity) {
  'severe' => dark ? TraceColors.unsafeDark : TraceColors.unsafe,
  'moderate' => dark ? TraceColors.cautionDark : TraceColors.caution,
  _ => dark ? TraceColors.clearDark : TraceColors.clear,
};

String _severityLabel(String severity) => switch (severity) {
  'mild' => 'Mild',
  'moderate' => 'Moderate',
  'severe' => 'Severe',
  _ => severity,
};

/// Doses print exactly as stored — 0.15 mg is a real strength.
String _exact(double? v) {
  if (v == null) return '';
  final s = v.toString();
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String _weight(double v) {
  final rounded = (v * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

Future<void> _dial(BuildContext context, String number) async {
  final cleaned = dialableNumber(number);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (cleaned.isEmpty) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('No phone number saved.')),
    );
    return;
  }
  try {
    final launched = await handOffToPhone(context, Uri(scheme: 'tel', path: cleaned));
    if (!launched) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not start a call to $cleaned.')),
      );
    }
  } catch (_) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not start a call to $cleaned.')),
    );
  }
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
