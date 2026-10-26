import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_fill.dart';
import '../services/voice_parser.dart';
import '../widgets/voice_input.dart';

import '../data/countries.dart';
import '../models/profile.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/country_picker.dart';
import '../widgets/travel_format.dart';

/// Adding a trip, or editing one.
///
/// Four things matter and everything else is optional: where, when, who, and
/// what to call it. The name fills itself in from the destination so a family
/// heading out the door can save with three taps.
class TripEditScreen extends StatefulWidget {
  const TripEditScreen({super.key, this.existing});

  final Trip? existing;

  @override
  State<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends State<TripEditScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  String _country = '';
  DateTime? _start;
  DateTime? _end;
  final Set<String> _travelers = <String>{};

  /// True once the user has typed a name of their own, so changing the
  /// destination stops overwriting it.
  bool _nameEdited = false;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Trip? t = widget.existing;
    if (t != null) {
      _name.text = t.name;
      _notes.text = t.notes;
      _country = t.destinationCountry;
      _start = t.startsOn;
      _end = t.endsOn;
      _travelers.addAll(t.travelerIds);
      // A name the app made up keeps following the destination and travelers.
      _nameEdited = !isGeneratedTripName(t.name);
    } else {
      // A household of one is travelling by definition; a family picks.
      final AppState app = context.read<AppState>();
      if (app.profiles.length == 1) _travelers.add(app.profiles.single.id);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? get _problem {
    if (_start == null || _end == null) return 'Pick the dates';
    if (_end!.isBefore(_start!)) return 'The trip has to end after it starts';
    return null;
  }

  /// "Domestic travel" or "International travel to Japan", until the user
  /// types a name of their own.
  void _refreshName() {
    if (_nameEdited) return;
    _name.text = _country.isEmpty
        ? ''
        : context.read<AppState>().generatedTripName(
              destination: _country,
              travelerIds: _travelers.toList(),
            );
  }

  Future<void> _pickCountry() async {
    final String? code = await showCountryPicker(context, selected: _country);
    if (code == null || !mounted) return;
    setState(() {
      _country = code;
      _refreshName();
    });
  }

  Future<void> _pickDates() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _start != null && _end != null
          ? DateTimeRange(start: _start!, end: _end!)
          : null,
      helpText: 'Trip dates',
    );
    if (range == null || !mounted) return;
    setState(() {
      _start = range.start;
      _end = range.end;
    });
  }

  Future<void> _applyVoice(String text) async {
    final AppState app = context.read<AppState>();
    final TripHeard heard = await VoiceFill.trip(
      text,
      profiles: app.profiles,
      meId: app.activeProfile.id,
    );
    if (!mounted) return;
    setState(() {
      final String? code = heard.countryCode;
      if (code != null) _country = code;
      if (heard.startsOn != null) _start = heard.startsOn;
      if (heard.endsOn != null) _end = heard.endsOn;
      if (_start != null && _end == null) _end = _start;
      if (heard.travelerIds.isNotEmpty) {
        _travelers
          ..clear()
          ..addAll(heard.travelerIds);
      }
      _refreshName();
    });
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_problem != null) return;
    setState(() => _saving = true);

    final AppState app = context.read<AppState>();
    final NavigatorState nav = Navigator.of(context);
    final String name = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : app.generatedTripName(
            destination: _country,
            travelerIds: _travelers.toList(),
          );

    final Trip? existing = widget.existing;
    final Trip trip = existing ?? Trip(
      id: app.newId(),
      name: name,
      startsOn: _start!,
      endsOn: _end!,
    );
    trip
      ..name = name
      ..destinationCountry = _country
      ..startsOn = _start!
      ..endsOn = _end!
      ..travelerIds = _travelers.toList()
      ..notes = _notes.text.trim();

    await app.saveTrip(trip);
    if (!mounted) return;
    nav.pop<Trip>(trip);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Country? country = countryFor(_country);
    final String? problem = _problem;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add a trip' : 'Edit trip'),
        actions: <Widget>[
          VoiceButton(
            title: 'Describe the trip',
            hint: 'Tokyo from March 12 to March 20 with Maya and me',
            onTranscript: _applyVoice,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: <Widget>[
          const SectionTitle('Where'),
          _PickerField(
            label: 'Destination country',
            value: country == null
                ? (_country.isEmpty && widget.existing != null
                    ? 'Not set'
                    : 'Choose a country')
                : '${country.flag}  ${country.name}',
            icon: Icons.public_rounded,
            onTap: _pickCountry,
          ),
          if (country != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Ambulance: ${country.emergency}'
              '${country.alsoWorks.isEmpty ? '' : ' (also ${country.alsoWorks.join(', ')})'}',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],

          const SectionTitle('When'),
          _PickerField(
            label: 'Dates',
            value: _start == null || _end == null
                ? 'Choose dates'
                : formatTripDates(_start!, _end!),
            icon: Icons.date_range_rounded,
            onTap: _pickDates,
          ),
          if (_submitted && problem != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(problem, style: TextStyle(color: scheme.error, fontSize: 14.5)),
          ],

          const SectionTitle('Who is travelling'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Profile p in app.profiles)
                FilterChip(
                  label: Text(p.name),
                  selected: _travelers.contains(p.id),
                  onSelected: (bool on) => setState(() {
                    if (on) {
                      _travelers.add(p.id);
                    } else {
                      _travelers.remove(p.id);
                    }
                    _refreshName();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Exposures and reactions are logged against one of these people.',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),

          const SectionTitle('Name'),
          TextField(
            controller: _name,
            onChanged: (String v) => _nameEdited = v.trim().isNotEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Trip name',
              hintText: 'Domestic travel, or your own name for it',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Hotel, allergist letter packed, anything to remember',
            ),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save trip'),
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value),
      ),
    );
  }
}
