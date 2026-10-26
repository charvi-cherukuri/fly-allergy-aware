import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_fill.dart';
import '../services/voice_parser.dart';
import '../widgets/voice_input.dart';

import '../models/allergen.dart';
import '../models/custom_allergen.dart';
import '../models/flight.dart';
import '../models/profile.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/travel_format.dart';
import 'reaction_log_screen.dart';

/// Logging an allergen exposure on a trip, or editing one.
///
/// Built to be filled in quickly and mostly by tapping: who, what, how, where,
/// what you did. When symptoms followed, saving goes straight on to the
/// reaction form with the time and the source already filled in, and the two
/// records are linked.
class ExposureEditScreen extends StatefulWidget {
  const ExposureEditScreen({
    super.key,
    required this.tripId,
    this.existing,
    this.draft,
  });

  final String tripId;

  /// A saved exposure being edited.
  final Exposure? existing;

  /// An unsaved exposure to start from — what voice input fills in. Ignored
  /// when [existing] is set.
  final Exposure? draft;

  @override
  State<ExposureEditScreen> createState() => _ExposureEditScreenState();
}

class _ExposureEditScreenState extends State<ExposureEditScreen> {
  final TextEditingController _source = TextEditingController();
  final TextEditingController _placeName = TextEditingController();
  final TextEditingController _row = TextEditingController();
  final TextEditingController _otherAllergen = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  late String _profileId;
  late DateTime _occurredAt;
  final List<String> _allergens = <String>[];
  ExposureRoute _route = ExposureRoute.skin;
  ExposurePlace _place = ExposurePlace.flight;
  String? _flightId;
  final Set<String> _actions = <String>{};
  ExposureOutcome _outcome = ExposureOutcome.noSymptoms;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final AppState app = context.read<AppState>();
    final Exposure? e = widget.existing ?? widget.draft;
    final Trip? trip = app.tripById(widget.tripId);
    final List<Profile> people = _people(app, trip);

    _profileId = (e != null && e.profileId.isNotEmpty)
        ? e.profileId
        : people.any((Profile p) => p.id == app.activeProfile.id)
            ? app.activeProfile.id
            : (people.isEmpty ? app.activeProfile.id : people.first.id);
    _occurredAt = e?.occurredAt ?? DateTime.now();

    final Flight? flying = app.flightInProgress();
    final List<Flight> legs = app.flightsFor(widget.tripId);
    if (e != null) {
      _allergens.addAll(e.allergenNames);
      _route = e.route;
      _place = e.place;
      _flightId = e.flightId;
      _source.text = e.source;
      _placeName.text = e.placeName;
      _row.text = e.row?.toString() ?? '';
      _actions.addAll(e.actions);
      _outcome = e.outcome;
      _notes.text = e.notes;
    } else if (flying != null && flying.tripId == widget.tripId) {
      // On the plane right now: that is almost certainly where it happened.
      _place = ExposurePlace.flight;
      _flightId = flying.id;
      _row.text = _rowOf(flying.seat);
    } else if (legs.isEmpty) {
      _place = ExposurePlace.restaurant;
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _source, _placeName, _row, _otherAllergen, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// "31C" → "31".
  static String _rowOf(String seat) =>
      RegExp(r'\d+').firstMatch(seat)?.group(0) ?? '';

  /// The people the exposure can be logged for: the trip's travelers, or the
  /// whole household when nobody has been picked.
  static List<Profile> _people(AppState app, Trip? trip) {
    final List<String> ids = trip?.travelerIds ?? const <String>[];
    final List<Profile> picked =
        app.profiles.where((Profile p) => ids.contains(p.id)).toList();
    return picked.isEmpty ? app.profiles : picked;
  }

  /// The allergens worth offering as one-tap chips: the chosen person's own,
  /// regulated first, then their custom ones.
  List<String> _offered(AppState app) {
    Profile? person;
    for (final Profile p in app.profiles) {
      if (p.id == _profileId) person = p;
    }
    final List<String> out = <String>[
      ...?person?.sorted.map((Allergen a) => a.label),
      ...?person?.customAllergens.map((CustomAllergen c) => c.name),
    ];
    for (final String a in _allergens) {
      if (!out.contains(a)) out.add(a);
    }
    return out;
  }

  Future<void> _pickWhen() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
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

  void _addOther() {
    final String v = _otherAllergen.text.trim();
    if (v.isEmpty) return;
    setState(() {
      if (!_allergens.contains(v)) _allergens.add(v);
      _otherAllergen.clear();
    });
  }

  /// Fills what was heard. Fields the user already set are left alone, except
  /// where what was said is more specific.
  Future<void> _applyVoice(String text) async {
    final AppState app = context.read<AppState>();
    final List<Profile> people = _people(app, app.tripById(widget.tripId));
    Profile? person;
    for (final Profile p in people) {
      if (p.id == _profileId) person = p;
    }
    final ExposureHeard heard = await VoiceFill.exposure(
      text,
      people: people,
      custom: person?.customAllergens ?? const <CustomAllergen>[],
    );
    if (!mounted) return;
    setState(() {
      if (heard.profileId != null) _profileId = heard.profileId!;
      for (final String a in heard.allergens) {
        if (!_allergens.contains(a)) _allergens.add(a);
      }
      if (heard.route != null) _route = heard.route!;
      if (heard.place != null) _place = heard.place!;
      if (heard.source != null && _source.text.trim().isEmpty) _source.text = heard.source!;
      if (heard.placeName != null && _placeName.text.trim().isEmpty) {
        _placeName.text = heard.placeName!;
      }
      if (heard.row != null) _row.text = '${heard.row}';
      _actions.addAll(heard.actions);
      if (heard.outcome != null) _outcome = heard.outcome!;
      _notes.text = _notes.text.trim().isEmpty ? text : '${_notes.text.trim()}\n$text';
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final AppState app = context.read<AppState>();
    final NavigatorState nav = Navigator.of(context);
    final Exposure? existing = widget.existing;
    final bool onFlight = _place == ExposurePlace.flight;

    final Exposure exposure = Exposure(
      id: existing?.id ?? app.newId(),
      tripId: widget.tripId,
      profileId: _profileId,
      flightId: onFlight ? _flightId : null,
      occurredAt: _occurredAt,
      allergenNames: List<String>.of(_allergens),
      route: _route,
      source: _source.text.trim(),
      place: _place,
      placeName: onFlight ? '' : _placeName.text.trim(),
      row: onFlight ? int.tryParse(_row.text.trim()) : null,
      actions: _actions.toList(),
      outcome: _outcome,
      reactionId: existing?.reactionId ?? widget.draft?.reactionId,
      notes: _notes.text.trim(),
    );
    await app.saveExposure(exposure);

    // Symptoms and no reaction recorded yet: go straight on to it, while the
    // details are fresh, and link the two.
    if (_outcome == ExposureOutcome.symptoms &&
        exposure.reactionId == null &&
        mounted) {
      final reaction = await showReactionForm(
        context,
        profileId: _profileId,
        tripId: widget.tripId,
        exposureId: exposure.id,
        prefillFood: <String>[
          if (exposure.source.isNotEmpty) exposure.source,
          if (exposure.allergenNames.isNotEmpty)
            exposure.allergenNames.join(', '),
        ].join(' — '),
        prefillTime: exposure.occurredAt,
      );
      if (reaction != null) {
        exposure.reactionId = reaction.id;
        await app.saveExposure(exposure);
      }
    }
    if (!mounted) return;
    nav.pop<Exposure>(exposure);
  }

  Future<void> _delete() async {
    final Exposure? existing = widget.existing;
    if (existing == null) return;
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete this exposure?'),
            content: const Text(
              'A reaction linked to it stays in the reaction log.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    final NavigatorState nav = Navigator.of(context);
    await context.read<AppState>().deleteExposure(existing.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Trip? trip = app.tripById(widget.tripId);
    final List<Profile> people = _people(app, trip);
    final List<Flight> legs = app.flightsFor(widget.tripId);
    final List<String> offered = _offered(app);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Log an exposure' : 'Exposure'),
        actions: <Widget>[
          VoiceButton(
            title: 'Describe the exposure',
            hint: 'Maya touched a tray table with peanut crumbs in row 14, '
                'washed her hands, no symptoms',
            onTranscript: _applyVoice,
          ),
          if (widget.existing != null)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: <Widget>[
          if (people.length > 1) ...<Widget>[
            const SectionTitle('Who'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final Profile p in people)
                  ChoiceChip(
                    label: Text(p.name),
                    selected: _profileId == p.id,
                    onSelected: (bool _) => setState(() => _profileId = p.id),
                  ),
              ],
            ),
          ],

          const SectionTitle('When'),
          InkWell(
            onTap: _pickWhen,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              child: Text(formatFlightDateTime(_occurredAt)),
            ),
          ),

          const SectionTitle('Which allergen'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String a in offered)
                FilterChip(
                  label: Text(a),
                  selected: _allergens.contains(a),
                  onSelected: (bool on) => setState(() {
                    on ? _allergens.add(a) : _allergens.remove(a);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otherAllergen,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (String _) => _addOther(),
            decoration: InputDecoration(
              hintText: 'Something else, or not sure',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: _addOther,
              ),
            ),
          ),

          const SectionTitle('How'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ExposureRoute r in ExposureRoute.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: _route == r,
                  onSelected: (bool _) => setState(() => _route = r),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _source,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What it came from',
              hintText: "Seatmate's trail mix, breakfast pastry",
            ),
          ),

          const SectionTitle('Where'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ExposurePlace p in ExposurePlace.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _place == p,
                  onSelected: (bool _) => setState(() {
                    _place = p;
                    if (p == ExposurePlace.flight && _flightId == null && legs.isNotEmpty) {
                      _flightId = legs.first.id;
                      if (_row.text.isEmpty) _row.text = _rowOf(legs.first.seat);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_place == ExposurePlace.flight) ...<Widget>[
            if (legs.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: legs.any((Flight f) => f.id == _flightId)
                    ? _flightId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Flight'),
                items: <DropdownMenuItem<String>>[
                  for (final Flight f in legs)
                    DropdownMenuItem<String>(
                      value: f.id,
                      child: Text('${f.label}  ${f.route}'),
                    ),
                ],
                onChanged: (String? id) => setState(() => _flightId = id),
              )
            else
              Text(
                'No flights on this trip yet — it will be logged as on a '
                'flight without saying which.',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _row,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Row (optional)',
                hintText: '14',
              ),
            ),
          ] else
            TextField(
              controller: _placeName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name of the place (optional)',
                hintText: 'Café on Rua Augusta, Hilton Shinjuku',
              ),
            ),

          const SectionTitle('What you did'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String a in kExposureActions)
                FilterChip(
                  label: Text(a),
                  selected: _actions.contains(a),
                  onSelected: (bool on) => setState(() {
                    on ? _actions.add(a) : _actions.remove(a);
                  }),
                ),
            ],
          ),

          const SectionTitle('What happened next'),
          SegmentedButton<ExposureOutcome>(
            segments: <ButtonSegment<ExposureOutcome>>[
              for (final ExposureOutcome o in ExposureOutcome.values)
                ButtonSegment<ExposureOutcome>(value: o, label: Text(o.label)),
            ],
            selected: <ExposureOutcome>{_outcome},
            onSelectionChanged: (Set<ExposureOutcome> v) =>
                setState(() => _outcome = v.first),
          ),
          if (_outcome == ExposureOutcome.symptoms &&
              (widget.existing ?? widget.draft)?.reactionId == null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'After saving, the reaction form opens so the symptoms are '
              'recorded too.',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save exposure'),
          ),
        ],
      ),
    );
  }
}
