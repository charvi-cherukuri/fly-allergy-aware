import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/emergency_actions.dart';
import '../services/voice_fill.dart';
import '../widgets/voice_input.dart';

import 'package:trace_allergy/models/emergency.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// The reaction log.
///
/// Closing the loop between what was eaten and what happened is the thing no
/// app in this category does, and the thing an allergist asks for at every
/// appointment. The log is also a live safety surface: if the symptoms being
/// ticked describe anaphylaxis, the form says so and stops asking for detail.
class ReactionLogScreen extends StatefulWidget {
  const ReactionLogScreen({super.key, this.prefillBarcode, this.prefillFood});

  /// Links the entry back to the scan that preceded it, when there was one.
  final String? prefillBarcode;

  /// The product name from that scan.
  final String? prefillFood;

  @override
  State<ReactionLogScreen> createState() => _ReactionLogScreenState();
}

class _ReactionLogScreenState extends State<ReactionLogScreen> {
  @override
  void initState() {
    super.initState();
    // Arriving from a scan means the user already decided to log something.
    // Open the form rather than making them find the button.
    if (widget.prefillBarcode != null || widget.prefillFood != null) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (!mounted) return;
        _openForm();
      });
    }
  }

  Future<void> _openForm({ReactionLog? existing}) async {
    final app = context.read<AppState>();
    final profileId = app.activeProfile.id;

    final result = await showModalBottomSheet<ReactionLog>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => _ReactionForm(
        existing: existing,
        profileId: profileId,
        prefillBarcode: widget.prefillBarcode,
        prefillFood: widget.prefillFood,
      ),
    );
    if (result == null) return;
    await app.saveReaction(result);
  }

  Future<void> _delete(ReactionLog r) async {
    await context.read<AppState>().deleteReaction(r.id);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Reaction removed')),
    );
  }

  Future<bool> _confirmDelete(ReactionLog r) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Remove this entry'),
        content: Text(
          'Deletes the ${_formatDateTime(r.occurredAt)} entry. This cannot be '
          'undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _danger(dialogContext),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _export(List<ReactionLog> reactions, String profileName) async {
    if (reactions.isEmpty) return;
    final text = _buildExport(reactions, profileName);

    // The share sheet needs an anchor rect on iPad, or it has nowhere to
    // point and the call fails.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Share.share(
        text,
        subject: 'Reaction history — $profileName',
        sharePositionOrigin: origin,
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the share sheet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.activeProfile;
    final reactions = app.reactions
        .where((ReactionLog r) => r.profileId == profile.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reaction log'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Export',
            onPressed: reactions.isEmpty
                ? null
                : () => _export(reactions, profile.name),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      floatingActionButton: reactions.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Log a reaction'),
            ),
      body: reactions.isEmpty
          ? _EmptyLog(onAdd: _openForm)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: reactions.length + 1,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                if (index == reactions.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Bring this to an appointment.',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final r = reactions[index];
                return Dismissible(
                  key: ValueKey<String>(r.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (DismissDirection _) => _confirmDelete(r),
                  onDismissed: (DismissDirection _) => _delete(r),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 22),
                    decoration: BoxDecoration(
                      color: _danger(context).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.delete_outline, color: _danger(context)),
                  ),
                  child: _ReactionCard(
                    reaction: r,
                    onTap: () => _openForm(existing: r),
                    onLongPress: () async {
                      final ok = await _confirmDelete(r);
                      if (!ok) return;
                      await _delete(r);
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// List pieces
// ---------------------------------------------------------------------------

class _ReactionCard extends StatelessWidget {
  const _ReactionCard({
    required this.reaction,
    required this.onTap,
    required this.onLongPress,
  });

  final ReactionLog reaction;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = reaction;

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _SeverityDot(rating: r.severityRating),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formatDateTime(r.occurredAt),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _severityLabel(r.severityRating),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (r.suspectedFood.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  r.suspectedFood.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              if (r.symptoms.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final s in r.symptoms)
                      _SymptomPill(
                        label: s,
                        severe: kAnaphylaxisSymptoms.contains(s),
                      ),
                  ],
                ),
              ],
              if (r.epiUsed || r.soughtCare) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    if (r.epiUsed)
                      _Tag(
                        icon: Icons.medication_liquid,
                        label: 'Epinephrine used',
                      ),
                    if (r.epiUsed && r.soughtCare) const SizedBox(width: 8),
                    if (r.soughtCare)
                      _Tag(
                        icon: Icons.local_hospital_outlined,
                        label: 'Medical care',
                      ),
                  ],
                ),
              ],
              if (r.notes.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  r.notes.trim(),
                  style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomPill extends StatelessWidget {
  const _SymptomPill({required this.label, required this.severe});

  final String label;
  final bool severe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = severe ? _danger(context) : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: severe
            ? color.withValues(alpha: 0.14)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: severe ? FontWeight.w700 : FontWeight.w500,
          color: severe ? color : scheme.onSurface,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SeverityDot extends StatelessWidget {
  const _SeverityDot({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color color = rating >= 5
        ? (dark ? TraceColors.unsafeDark : TraceColors.unsafe)
        : rating >= 3
        ? (dark ? TraceColors.cautionDark : TraceColors.caution)
        : (dark ? TraceColors.clearDark : TraceColors.clear);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.event_note_outlined,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            const Text(
              'No reactions logged',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'What was eaten, what happened, what was done. A record for the '
              'allergist.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Log a reaction'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The form
// ---------------------------------------------------------------------------

/// Opens the reaction form as a sheet, saves what the user enters, and
/// returns it — or null when they back out.
///
/// For callers outside the reaction log: the Travel tab logs a reaction
/// against a trip, and against the exposure that led to it.
Future<ReactionLog?> showReactionForm(
  BuildContext context, {
  required String profileId,
  ReactionLog? existing,
  String? tripId,
  String? exposureId,
  String? prefillFood,
  DateTime? prefillTime,
}) async {
  final app = context.read<AppState>();
  final result = await showModalBottomSheet<ReactionLog>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext _) => _ReactionForm(
      existing: existing,
      profileId: profileId,
      prefillBarcode: null,
      prefillFood: prefillFood,
      prefillTime: prefillTime,
      tripId: tripId,
      exposureId: exposureId,
    ),
  );
  if (result == null) return null;
  await app.saveReaction(result);
  return result;
}

class _ReactionForm extends StatefulWidget {
  const _ReactionForm({
    required this.existing,
    required this.profileId,
    required this.prefillBarcode,
    required this.prefillFood,
    this.prefillTime,
    this.tripId,
    this.exposureId,
  });

  final ReactionLog? existing;
  final String profileId;
  final String? prefillBarcode;
  final String? prefillFood;
  final DateTime? prefillTime;
  final String? tripId;
  final String? exposureId;

  @override
  State<_ReactionForm> createState() => _ReactionFormState();
}

class _ReactionFormState extends State<_ReactionForm> {
  late final TextEditingController _food;
  late final TextEditingController _notes;
  late DateTime _occurredAt;
  late Set<String> _symptoms;
  late double _severity;
  late bool _epiUsed;
  late bool _soughtCare;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _food = TextEditingController(
      text: e?.suspectedFood ?? widget.prefillFood ?? '',
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _occurredAt = e?.occurredAt ?? widget.prefillTime ?? DateTime.now();
    _symptoms = <String>{...?e?.symptoms};
    _severity = (e?.severityRating ?? 3).toDouble();
    _epiUsed = e?.epiUsed ?? false;
    _soughtCare = e?.soughtCare ?? false;
  }

  @override
  void dispose() {
    _food.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _anaphylaxisSuspected =>
      _symptoms.any(kAnaphylaxisSymptoms.contains);

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      helpText: 'When did it happen',
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (!mounted) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _occurredAt.hour,
        time?.minute ?? _occurredAt.minute,
      );
    });
  }

  void _toggleSymptom(String symptom, bool selected) {
    setState(() {
      if (selected) {
        _symptoms.add(symptom);
      } else {
        _symptoms.remove(symptom);
      }
      // Ticking an anaphylaxis symptom is itself information about severity.
      // Nudge the slider up rather than leaving a record that reads mild.
      if (_anaphylaxisSuspected && _severity < 4) _severity = 4;
    });
  }

  /// Fills what was heard, never clearing what the user already set.
  Future<void> _applyVoice(String text) async {
    final heard = await VoiceFill.reaction(text);
    if (!mounted) return;
    setState(() {
      _symptoms.addAll(heard.symptoms);
      if (heard.epiUsed == true) _epiUsed = true;
      if (heard.soughtCare == true) _soughtCare = true;
      if (_food.text.trim().isEmpty && heard.suspectedFood != null) {
        _food.text = heard.suspectedFood!;
      }
      _notes.text = _notes.text.trim().isEmpty ? text : '${_notes.text.trim()}\n$text';
      if (_anaphylaxisSuspected && _severity < 4) _severity = 4;
    });
  }

  void _save() {
    final existing = widget.existing;
    Navigator.of(context).pop(
      ReactionLog(
        id: existing?.id ?? _newId(),
        profileId: existing?.profileId ?? widget.profileId,
        occurredAt: _occurredAt,
        symptoms: _symptoms.toList(),
        suspectedFood: _food.text.trim(),
        barcode: existing?.barcode ?? widget.prefillBarcode,
        epiUsed: _epiUsed,
        soughtCare: _soughtCare,
        notes: _notes.text.trim(),
        severityRating: _severity.round(),
        // Carried through untouched: this form does not edit them, and
        // rebuilding the record without them would silently erase the trip
        // link and the epinephrine dose times.
        tripId: existing?.tripId ?? widget.tripId,
        exposureId: existing?.exposureId ?? widget.exposureId,
        epiDoses: existing?.epiDoses,
        timeline: existing?.timeline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.existing == null ? 'Log a reaction' : 'Edit reaction',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                VoiceButton(
                  title: 'Describe the reaction',
                  hint: 'Hives and lips swelling after eating pad thai, used '
                      'the EpiPen',
                  onTranscript: _applyVoice,
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (_anaphylaxisSuspected) ...<Widget>[
              const _AnaphylaxisBanner(),
              const SizedBox(height: 18),
            ],

            const SectionTitle('When'),
            InkWell(
              onTap: _pickWhen,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date and time'),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(_formatDateTime(_occurredAt))),
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            const SectionTitle('Symptoms'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final symptom in kSymptomOptions)
                  FilterChip(
                    label: Text(symptom),
                    selected: _symptoms.contains(symptom),
                    onSelected: (bool selected) =>
                        _toggleSymptom(symptom, selected),
                    selectedColor: kAnaphylaxisSymptoms.contains(symptom)
                        ? _danger(context).withValues(alpha: 0.18)
                        : null,
                    checkmarkColor: kAnaphylaxisSymptoms.contains(symptom)
                        ? _danger(context)
                        : null,
                  ),
              ],
            ),

            const SectionTitle('Suspected food'),
            TextField(
              controller: _food,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Product name, dish, or ingredient',
              ),
            ),

            const SectionTitle('How bad it got, at its worst'),
            Slider(
              value: _severity,
              min: 1,
              max: 5,
              divisions: 4,
              label: _severityLabel(_severity.round()),
              onChanged: (double v) => setState(() => _severity = v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _severityLabel(1),
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _severityLabel(_severity.round()),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _severity.round() >= 4
                          ? _danger(context)
                          : scheme.onSurface,
                    ),
                  ),
                  Text(
                    _severityLabel(5),
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                'A mild reaction can become severe within minutes. Keep watching, '
                'and follow your doctor’s plan.',
                style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurfaceVariant),
              ),
            ),

            const SectionTitle('What was done'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _epiUsed,
              onChanged: (bool v) => setState(() => _epiUsed = v),
              title: const Text('Epinephrine used'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _soughtCare,
              onChanged: (bool v) => setState(() => _soughtCare = v),
              title: const Text('Sought medical care'),
            ),

            const SectionTitle('Notes'),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'When symptoms started, how long they lasted, what was '
                    'taken.',
                hintMaxLines: 3,
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save reaction')),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The interlock. It appears the moment a symptom in [kAnaphylaxisSymptoms] is
/// ticked, and it says the same thing every emergency care plan says: treat
/// first, record later.
class _AnaphylaxisBanner extends StatelessWidget {
  const _AnaphylaxisBanner();

  @override
  Widget build(BuildContext context) {
    final danger = _danger(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: danger, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.emergency, color: danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This may be anaphylaxis',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Use epinephrine now, then call '
            '${localEmergencyNumber(context.read<AppState>()).number}.\n'
            'Log it afterwards. Treatment first.',
            style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => _call911(context),
            icon: const Icon(Icons.phone_in_talk),
            label: Text(
              'Call ${localEmergencyNumber(context.read<AppState>()).number}',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calling
// ---------------------------------------------------------------------------

Future<void> _call911(BuildContext context) =>
    callEmergency(context, localEmergencyNumber(context.read<AppState>()));

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

/// Plain text, because plain text opens everywhere — mail, notes, a message to
/// the allergist's office — and needs no app on the other end.
String _buildExport(List<ReactionLog> reactions, String profileName) {
  final buffer = StringBuffer()
    ..writeln('Reaction history — $profileName')
    ..writeln('Exported ${_formatDate(DateTime.now())} from Fly Allergy Aware')
    ..writeln('${reactions.length} '
        '${reactions.length == 1 ? 'entry' : 'entries'}')
    ..writeln();

  for (final r in reactions) {
    buffer
      ..writeln('----------------------------------------')
      ..writeln(_formatDateTime(r.occurredAt))
      ..writeln(
        'Severity: ${r.severityRating} of 5 '
        '(${_severityLabel(r.severityRating)})',
      );
    if (r.suspectedFood.trim().isNotEmpty) {
      buffer.writeln('Suspected food: ${r.suspectedFood.trim()}');
    }
    buffer.writeln(
      'Symptoms: ${r.symptoms.isEmpty ? 'not recorded' : r.symptoms.join(', ')}',
    );
    buffer
      ..writeln('Epinephrine used: ${r.epiUsed ? 'yes' : 'no'}')
      ..writeln('Sought medical care: ${r.soughtCare ? 'yes' : 'no'}');
    if (r.notes.trim().isNotEmpty) {
      buffer.writeln('Notes: ${r.notes.trim()}');
    }
    buffer.writeln();
  }

  buffer
    ..writeln('----------------------------------------')
    ..writeln(
      'Recorded by the person affected or their carer. Not a clinical record.',
    );
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Small shared helpers
// ---------------------------------------------------------------------------

Color _danger(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? TraceColors.unsafeDark
    : TraceColors.unsafe;

String _severityLabel(int rating) {
  switch (rating) {
    case 1:
      return 'Mild';
    case 2:
      return 'Uncomfortable';
    case 3:
      return 'Moderate';
    case 4:
      return 'Severe';
    default:
      return 'Anaphylaxis';
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

String _formatDateTime(DateTime d) {
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '${_formatDate(d)}, $hour:$minute';
}

/// No uuid dependency on the list, and none needed: these ids only have to be
/// unique within one device's store.
int _idCounter = 0;
String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
