import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/airline_policies.dart';
import '../models/flight.dart';
import '../models/flight_experience.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/travel_format.dart';
import '../widgets/trip_actions.dart';
import '../widgets/voice_input.dart';
import 'incident_report_screen.dart';

/// "Record your flight experience": how the food information, the staff and
/// the medical kit worked out, and what would make the next flight better.
class FlightExperienceScreen extends StatefulWidget {
  const FlightExperienceScreen({super.key, required this.flightId});

  final String flightId;

  @override
  State<FlightExperienceScreen> createState() => _FlightExperienceScreenState();
}

class _FlightExperienceScreenState extends State<FlightExperienceScreen> {
  final TextEditingController _food = TextEditingController();
  final TextEditingController _staff = TextEditingController();
  final TextEditingController _concerns = TextEditingController();
  final TextEditingController _medication = TextEditingController();
  final TextEditingController _suggestions = TextEditingController();

  Rating _foodRating = Rating.notSet;
  Rating _staffRating = Rating.notSet;
  bool? _askedAboutKit;
  KitEpinephrine _kit = KitEpinephrine.unknown;
  String? _existingId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final FlightExperience? e = context.read<AppState>().experienceFor(widget.flightId);
    if (e != null) {
      _existingId = e.id;
      _foodRating = e.foodRating;
      _food.text = e.foodNotes;
      _staffRating = e.staffRating;
      _staff.text = e.staffNotes;
      _concerns.text = e.concerns;
      _askedAboutKit = e.askedAboutKit;
      _kit = e.kitEpinephrine;
      _medication.text = e.medicationNotes;
      _suggestions.text = e.suggestions;
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _food, _staff, _concerns, _medication, _suggestions,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(Flight flight) async {
    setState(() => _saving = true);
    final AppState app = context.read<AppState>();
    final NavigatorState nav = Navigator.of(context);
    await app.saveExperience(FlightExperience(
      id: _existingId ?? app.newId(),
      flightId: flight.id,
      tripId: flight.tripId,
      recordedAt: DateTime.now(),
      foodRating: _foodRating,
      foodNotes: _food.text.trim(),
      staffRating: _staffRating,
      staffNotes: _staff.text.trim(),
      concerns: _concerns.text.trim(),
      askedAboutKit: _askedAboutKit,
      kitEpinephrine: _kit,
      medicationNotes: _medication.text.trim(),
      suggestions: _suggestions.text.trim(),
    ));
    if (!mounted) return;
    nav.pop();
  }

  Widget _notes(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      minLines: 2,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: VoiceButton(
          title: 'Say it',
          hint: hint,
          onTranscript: (String t) async {
            setState(() => c.text = c.text.trim().isEmpty ? t : '${c.text.trim()} $t');
          },
        ),
      ),
    );
  }

  Widget _rating(Rating value, ValueChanged<Rating> onChanged) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final Rating r in <Rating>[Rating.good, Rating.okay, Rating.poor])
          ChoiceChip(
            label: Text(r.label),
            selected: value == r,
            onSelected: (bool on) => onChanged(on ? r : Rating.notSet),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    Flight? flight;
    for (final Flight f in app.flights) {
      if (f.id == widget.flightId) flight = f;
    }
    if (flight == null) return Scaffold(appBar: AppBar());
    final Flight leg = flight;
    final Trip? trip = app.tripById(leg.tripId);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int logged = (trip == null ? 0 : app.exposuresFor(trip.id).where((e) => e.flightId == leg.id).length) +
        app.incidents.where((i) => i.flightId == leg.id).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Your flight experience')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          Text(
            '${policyFor(leg.airlineIata)?.name ?? leg.airlineIata} ${leg.flightNumber} · '
            '${leg.route} · ${formatFlightDate(leg.departsAt)}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
          ),

          const SectionTitle('Food and allergen information'),
          _rating(_foodRating, (Rating r) => setState(() => _foodRating = r)),
          const SizedBox(height: 8),
          _notes(_food, 'Was there an ingredient list? Were allergens clear?'),

          const SectionTitle('Staff help'),
          _rating(_staffRating, (Rating r) => setState(() => _staffRating = r)),
          const SizedBox(height: 8),
          _notes(_staff, 'Did the gate agent and crew listen and help?'),

          const SectionTitle('Allergy concerns or incidents'),
          _notes(_concerns, 'Anything that worried you'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <Widget>[
              if (trip != null)
                TextButton.icon(
                  onPressed: () => logExposure(context, trip),
                  icon: const Icon(Icons.back_hand_outlined, size: 18),
                  label: const Text('Log an exposure'),
                ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext _) =>
                        IncidentReportScreen(flightId: leg.id, tripId: trip?.id),
                  ),
                ),
                icon: const Icon(Icons.report_outlined, size: 18),
                label: const Text('Report an incident'),
              ),
            ],
          ),
          if (logged > 0)
            Text(
              '$logged already logged for this flight.',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),

          const SectionTitle('Medication on board'),
          const Text('Did you ask what the medical kit had?', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final (bool v, String label) in <(bool, String)>[(true, 'Yes'), (false, 'No')])
                ChoiceChip(
                  label: Text(label),
                  selected: _askedAboutKit == v,
                  onSelected: (bool on) => setState(() => _askedAboutKit = on ? v : null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('What did it have?', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final KitEpinephrine k in KitEpinephrine.values)
                ChoiceChip(
                  label: Text(k.label),
                  selected: _kit == k,
                  onSelected: (bool _) => setState(() => _kit = k),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _notes(_medication, 'Anything else about medication'),

          const SectionTitle('Ideas for next time'),
          _notes(_suggestions, 'What would make the next flight better?'),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : () => _save(leg),
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
