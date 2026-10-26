import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/models/action_plan.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// Transcribing a physician's anaphylaxis action plan into the app — FRD 1.3.
///
/// Every field here is dictation. The app supplies no dose, no threshold and
/// no instruction of its own; `defaultSymptomLadder()` seeds the three tiers
/// as editable scaffolding and the form says so on the surface.
class ActionPlanEditScreen extends StatefulWidget {
  const ActionPlanEditScreen({super.key, required this.plan});

  /// The plan being edited. A new plan comes from `AppState.newActionPlan()`
  /// and is only persisted if the user saves a valid one.
  final ActionPlan plan;

  @override
  State<ActionPlanEditScreen> createState() => _ActionPlanEditScreenState();
}

class _ActionPlanEditScreenState extends State<ActionPlanEditScreen> {
  // Plan details
  late final TextEditingController _title;
  late final TextEditingController _airlineName;
  late final TextEditingController _iata;

  // Patient
  late final TextEditingController _patientName;
  late final TextEditingController _weightKg;
  late final TextEditingController _weightLb;
  DateTime? _dateOfBirth;

  /// Canonical weight in kilograms. Whichever field the user last typed in is
  /// the source; the other is a rounded mirror, so no round-trip drift ever
  /// reaches storage.
  double? _kg;

  // Epinephrine
  late final TextEditingController _brand;
  late final TextEditingController _doseMg;
  late final TextEditingController _injectorCount;
  late final TextEditingController _carryLocation;
  DateTime? _expiresOn;

  late final List<_MedRow> _meds;
  late final List<_StepRows> _steps;
  late final List<_ContactRow> _contacts;

  // Physician
  late final TextEditingController _physicianName;
  late final TextEditingController _physicianPhone;
  late final TextEditingController _clinic;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;

    _title = TextEditingController(text: p.title);
    _airlineName = TextEditingController(text: p.airlineName);
    _iata = TextEditingController(text: p.airlineIataCode);

    _patientName = TextEditingController(text: p.patient.name);
    _dateOfBirth = p.patient.dateOfBirth;
    _kg = p.patient.weightKg;
    _weightKg = TextEditingController(text: _kg == null ? '' : _num(_kg));
    _weightLb = TextEditingController(
      text: _kg == null ? '' : _num(_kg! * _lbPerKg),
    );

    _brand = TextEditingController(text: p.epinephrine.brand);
    _doseMg = TextEditingController(text: _exact(p.epinephrine.doseMg));
    _injectorCount = TextEditingController(
      text: '${p.epinephrine.injectorCount}',
    );
    _carryLocation = TextEditingController(text: p.epinephrine.carryLocation);
    _expiresOn = p.epinephrine.expiresOn;

    _meds = p.medications.map(_MedRow.new).toList();
    _contacts = p.emergencyContacts.map(_ContactRow.new).toList();
    _steps = _buildSteps(p.symptomSteps);

    _physicianName = TextEditingController(text: p.physician.name);
    _physicianPhone = TextEditingController(text: p.physician.phone);
    _clinic = TextEditingController(text: p.physician.clinic);
  }

  /// Always three tiers, in ladder order, whatever the stored plan holds.
  static List<_StepRows> _buildSteps(List<SymptomStep> stored) {
    final source = stored.isEmpty ? defaultSymptomLadder() : stored;
    return <_StepRows>[
      for (final severity in _severities)
        _StepRows(
          source.firstWhere(
            (SymptomStep s) => s.severity == severity,
            orElse: () => SymptomStep(severity: severity),
          ),
        ),
    ];
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _title,
      _airlineName,
      _iata,
      _patientName,
      _weightKg,
      _weightLb,
      _brand,
      _doseMg,
      _injectorCount,
      _carryLocation,
      _physicianName,
      _physicianPhone,
      _clinic,
    ]) {
      c.dispose();
    }
    for (final m in _meds) {
      m.dispose();
    }
    for (final s in _steps) {
      s.dispose();
    }
    for (final c in _contacts) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------- weight sync

  /// Setting `.text` on a controller does not re-enter `onChanged`, so the two
  /// fields mirror each other without a re-entrancy guard.
  void _onKgTyped(String raw) {
    final kg = _parse(raw);
    _kg = kg;
    _weightLb.text = kg == null ? '' : _num(kg * _lbPerKg);
  }

  void _onLbTyped(String raw) {
    final lb = _parse(raw);
    _kg = lb == null ? null : lb / _lbPerKg;
    _weightKg.text = _kg == null ? '' : _num(_kg);
  }

  // -------------------------------------------------------------------- save

  Future<void> _save() async {
    final app = context.read<AppState>();
    final p = widget.plan;

    // Built as a draft rather than mutated in place: a plan that fails
    // validation must leave the stored instance untouched.
    final draft = ActionPlan(
      id: p.id,
      title: _title.text.trim(),
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      airlineIataCode: _iata.text.trim().toUpperCase(),
      airlineName: _airlineName.text.trim(),
      isDefault: p.isDefault,
      patient: PatientInfo(
        name: _patientName.text.trim(),
        dateOfBirth: _dateOfBirth,
        weightKg: _kg,
      ),
      epinephrine: EpinephrineInfo(
        brand: _brand.text.trim(),
        doseMg: _parse(_doseMg.text),
        injectorCount: int.tryParse(_injectorCount.text.trim()) ?? 1,
        expiresOn: _expiresOn,
        carryLocation: _carryLocation.text.trim(),
      ),
      medications: <Medication>[
        for (final m in _meds)
          if (!m.isBlank) m.toModel(),
      ],
      symptomSteps: <SymptomStep>[
        for (final s in _steps)
          if (!s.isBlank) s.toModel(),
      ],
      emergencyContacts: <PlanContact>[
        for (final c in _contacts)
          if (!c.isBlank) c.toModel(),
      ],
      physician: PhysicianInfo(
        name: _physicianName.text.trim(),
        phone: _physicianPhone.text.trim(),
        clinic: _clinic.text.trim(),
      ),
      version: p.version,
    );

    final problems = draft.validate();
    if (problems.isNotEmpty) {
      await _showProblems(problems);
      return;
    }

    await app.saveActionPlan(draft);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showProblems(List<String> problems) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Missing details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final line in problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $line'),
              ),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresOn ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
      helpText: 'Expiry date on the device',
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _expiresOn = picked);
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit plan')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SectionTitle('Plan'),
              _Field(
                controller: _title,
                label: 'Plan title',
                hint: 'United — Maya',
                capitalization: TextCapitalization.sentences,
              ),
              _Field(
                controller: _airlineName,
                label: 'Airline',
                hint: 'United Airlines',
                capitalization: TextCapitalization.words,
              ),
              _Field(
                controller: _iata,
                label: 'IATA code',
                hint: 'UA',
                capitalization: TextCapitalization.characters,
              ),

              const SectionTitle('Patient'),
              _Field(
                controller: _patientName,
                label: 'Name',
                capitalization: TextCapitalization.words,
              ),
              _DateField(
                label: 'Date of birth',
                value: _dateOfBirth,
                onTap: _pickDateOfBirth,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _Field(
                      controller: _weightKg,
                      label: 'Weight (kg)',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: _onKgTyped,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _weightLb,
                      label: 'Weight (lb)',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: _onLbTyped,
                    ),
                  ),
                ],
              ),

              const SectionTitle('Epinephrine'),
              _Field(
                controller: _brand,
                label: 'Brand',
                hint: 'EpiPen, Jext, Auvi-Q',
                capitalization: TextCapitalization.words,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _Field(
                      controller: _doseMg,
                      label: 'Dose (mg)',
                      hint: '0.3',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _injectorCount,
                      label: 'Injectors',
                      keyboard: TextInputType.number,
                    ),
                  ),
                ],
              ),
              _DateField(
                label: 'Expiry date',
                value: _expiresOn,
                onTap: _pickExpiry,
              ),
              _Field(
                controller: _carryLocation,
                label: 'Where it is carried',
                hint: 'Cabin bag, front pocket',
                capitalization: TextCapitalization.sentences,
              ),

              SectionTitle(
                'Other medications',
                trailing: _AddButton(
                  onPressed: () => setState(
                    () => _meds.add(_MedRow(const Medication())),
                  ),
                ),
              ),
              if (_meds.isEmpty)
                _Hint(text: 'Only what the physician listed.', scheme: scheme)
              else
                for (int i = 0; i < _meds.length; i++)
                  _RowCard(
                    key: ValueKey<_MedRow>(_meds[i]),
                    onRemove: () => setState(() => _meds.removeAt(i).dispose()),
                    children: <Widget>[
                      _Field(
                        controller: _meds[i].name,
                        label: 'Medication',
                        hint: 'Cetirizine',
                        capitalization: TextCapitalization.sentences,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _Field(
                              controller: _meds[i].doseMg,
                              label: 'Dose (mg)',
                              keyboard:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              controller: _meds[i].form,
                              label: 'Form',
                              hint: 'Tablet',
                              capitalization: TextCapitalization.sentences,
                            ),
                          ),
                        ],
                      ),
                      _Field(
                        controller: _meds[i].route,
                        label: 'Route',
                        hint: 'By mouth',
                        capitalization: TextCapitalization.sentences,
                      ),
                      _Field(
                        controller: _meds[i].notes,
                        label: 'Notes',
                        capitalization: TextCapitalization.sentences,
                        lines: 2,
                      ),
                    ],
                  ),

              const SectionTitle('Symptom steps'),
              _Hint(
                text:
                    'Starting text only. Replace each line with what your '
                    'doctor wrote.',
                scheme: scheme,
              ),
              for (final step in _steps)
                _StepCard(
                  step: step,
                  onChanged: () => setState(() {}),
                ),

              SectionTitle(
                'Emergency contacts',
                trailing: _AddButton(
                  onPressed: () => setState(
                    () => _contacts.add(_ContactRow(const PlanContact())),
                  ),
                ),
              ),
              if (_contacts.isEmpty)
                _Hint(
                  text: 'At least one is required to save.',
                  scheme: scheme,
                )
              else
                for (int i = 0; i < _contacts.length; i++)
                  _RowCard(
                    key: ValueKey<_ContactRow>(_contacts[i]),
                    onRemove: () =>
                        setState(() => _contacts.removeAt(i).dispose()),
                    children: <Widget>[
                      _Field(
                        controller: _contacts[i].name,
                        label: 'Name',
                        capitalization: TextCapitalization.words,
                      ),
                      _Field(
                        controller: _contacts[i].relationship,
                        label: 'Relationship',
                        hint: 'Mom, partner, allergist',
                        capitalization: TextCapitalization.sentences,
                      ),
                      _Field(
                        controller: _contacts[i].phone,
                        label: 'Phone',
                        keyboard: TextInputType.phone,
                      ),
                    ],
                  ),

              const SectionTitle('Physician'),
              _Field(
                controller: _physicianName,
                label: 'Name',
                capitalization: TextCapitalization.words,
              ),
              _Field(
                controller: _physicianPhone,
                label: 'Phone',
                keyboard: TextInputType.phone,
              ),
              _Field(
                controller: _clinic,
                label: 'Clinic',
                capitalization: TextCapitalization.words,
                action: TextInputAction.done,
              ),

              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Text('Save plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Symptom tiers
// ---------------------------------------------------------------------------

const List<String> _severities = <String>['mild', 'moderate', 'severe'];

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.onChanged});

  final _StepRows step;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = _severityColor(step.severity, dark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _severityLabel(step.severity),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              _ListEditor(
                label: 'Symptoms',
                rows: step.symptoms,
                hint: 'Trouble breathing',
                onChanged: onChanged,
              ),
              const SizedBox(height: 8),
              _ListEditor(
                label: 'What to do',
                rows: step.actions,
                hint: 'Use the auto-injector now',
                onChanged: onChanged,
              ),
              const SizedBox(height: 4),
              Text(
                'As written on the plan.',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A repeatable list of one-line text rows with add and remove.
class _ListEditor extends StatelessWidget {
  const _ListEditor({
    required this.label,
    required this.rows,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final List<TextEditingController> rows;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            _AddButton(
              onPressed: () {
                rows.add(TextEditingController());
                onChanged();
              },
            ),
          ],
        ),
        for (int i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: ValueKey<TextEditingController>(rows[i]),
                    controller: rows[i],
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: hint,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Remove line',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () {
                    rows.removeAt(i).dispose();
                    onChanged();
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Row models — controllers grouped per repeatable entry
// ---------------------------------------------------------------------------

class _MedRow {
  _MedRow(Medication m)
    : name = TextEditingController(text: m.name),
      form = TextEditingController(text: m.form),
      doseMg = TextEditingController(text: _exact(m.doseMg)),
      route = TextEditingController(text: m.route),
      notes = TextEditingController(text: m.notes);

  final TextEditingController name;
  final TextEditingController form;
  final TextEditingController doseMg;
  final TextEditingController route;
  final TextEditingController notes;

  bool get isBlank =>
      name.text.trim().isEmpty &&
      form.text.trim().isEmpty &&
      doseMg.text.trim().isEmpty &&
      route.text.trim().isEmpty &&
      notes.text.trim().isEmpty;

  Medication toModel() => Medication(
    name: name.text.trim(),
    form: form.text.trim(),
    doseMg: _parse(doseMg.text),
    route: route.text.trim(),
    notes: notes.text.trim(),
  );

  void dispose() {
    name.dispose();
    form.dispose();
    doseMg.dispose();
    route.dispose();
    notes.dispose();
  }
}

class _ContactRow {
  _ContactRow(PlanContact c)
    : name = TextEditingController(text: c.name),
      relationship = TextEditingController(text: c.relationship),
      phone = TextEditingController(text: c.phone),
      email = c.email;

  final TextEditingController name;
  final TextEditingController relationship;
  final TextEditingController phone;
  final String email;

  bool get isBlank =>
      name.text.trim().isEmpty &&
      relationship.text.trim().isEmpty &&
      phone.text.trim().isEmpty;

  PlanContact toModel() => PlanContact(
    name: name.text.trim(),
    relationship: relationship.text.trim(),
    phone: phone.text.trim(),
    email: email,
  );

  void dispose() {
    name.dispose();
    relationship.dispose();
    phone.dispose();
  }
}

class _StepRows {
  _StepRows(SymptomStep s)
    : severity = s.severity,
      symptoms = s.symptoms
          .map((String e) => TextEditingController(text: e))
          .toList(),
      actions = s.actions
          .map((String e) => TextEditingController(text: e))
          .toList();

  final String severity;
  final List<TextEditingController> symptoms;
  final List<TextEditingController> actions;

  bool get isBlank => _lines(symptoms).isEmpty && _lines(actions).isEmpty;

  SymptomStep toModel() => SymptomStep(
    severity: severity,
    symptoms: _lines(symptoms),
    actions: _lines(actions),
  );

  static List<String> _lines(List<TextEditingController> rows) => rows
      .map((TextEditingController c) => c.text.trim())
      .where((String e) => e.isNotEmpty)
      .toList();

  void dispose() {
    for (final c in symptoms) {
      c.dispose();
    }
    for (final c in actions) {
      c.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboard,
    this.capitalization = TextCapitalization.none,
    this.action = TextInputAction.next,
    this.onChanged,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;
  final TextInputAction action;
  final ValueChanged<String>? onChanged;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textCapitalization: capitalization,
        textInputAction: lines > 1 ? TextInputAction.newline : action,
        onChanged: onChanged,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  value == null ? 'Not set' : _formatDate(value!),
                  style: TextStyle(
                    color: value == null
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({super.key, required this.onRemove, required this.children});

  final VoidCallback onRemove;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ...children,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add'),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.scheme});

  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Matches `PatientInfo.weightLb` exactly, so the two never disagree.
const double _lbPerKg = 2.2046226218;

String _severityLabel(String severity) => switch (severity) {
  'mild' => 'Mild',
  'moderate' => 'Moderate',
  'severe' => 'Severe',
  _ => severity,
};

Color _severityColor(String severity, bool dark) => switch (severity) {
  'severe' => dark ? TraceColors.unsafeDark : TraceColors.unsafe,
  'moderate' => dark ? TraceColors.cautionDark : TraceColors.caution,
  _ => dark ? TraceColors.clearDark : TraceColors.clear,
};

double? _parse(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// A dose, printed exactly as stored. Never rounded: 0.15 mg is a real
/// pediatric auto-injector strength and must not become 0.2 mg.
String _exact(double? v) {
  if (v == null) return '';
  final s = v.toString();
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// A weight, to one decimal place. Only ever used for the mirrored field —
/// the canonical kilogram value keeps full precision.
String _num(double? v) {
  if (v == null) return '';
  final rounded = (v * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
  return rounded.toStringAsFixed(1);
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
