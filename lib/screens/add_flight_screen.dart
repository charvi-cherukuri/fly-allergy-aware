import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/data/airline_policies.dart';
import 'package:trace_allergy/data/request_guides.dart';
import 'package:trace_allergy/models/flight.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';
import 'package:trace_allergy/widgets/travel_format.dart';

/// Adding a flight leg to a trip, or editing one.
///
/// The aircraft type is worth the extra field: emergency mode uses it to say
/// where the on-board medical kit is usually stowed. The seat is what the crew
/// card shows. Everything else is the itinerary.
class AddFlightScreen extends StatefulWidget {
  const AddFlightScreen({
    super.key,
    required this.tripId,
    this.existing,
    this.suggestedDate,
  });

  /// The trip this leg belongs to.
  final String tripId;

  /// The leg being edited, or null to add one.
  final Flight? existing;

  /// Where the departure picker opens when adding — the trip's first day.
  final DateTime? suggestedDate;

  @override
  State<AddFlightScreen> createState() => _AddFlightScreenState();
}

class _AddFlightScreenState extends State<AddFlightScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _airline = TextEditingController();
  final TextEditingController _number = TextEditingController();
  final TextEditingController _origin = TextEditingController();
  final TextEditingController _destination = TextEditingController();
  final TextEditingController _aircraft = TextEditingController();
  final TextEditingController _seat = TextEditingController();

  final FocusNode _airlineFocus = FocusNode();

  DateTime? _departsAt;
  DateTime? _arrivesAt;

  /// Set once the user has tried to save, so the schedule errors do not shout
  /// at someone who has simply not reached those fields yet.
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Flight? f = widget.existing;
    if (f != null) {
      _airline.text = f.airlineIata;
      _number.text = f.flightNumber;
      _origin.text = f.origin;
      _destination.text = f.destination;
      _aircraft.text = f.aircraftType;
      _seat.text = f.seat;
      _departsAt = f.departsAt;
      _arrivesAt = f.arrivesAt;
    }
    for (final TextEditingController c in <TextEditingController>[
      _airline,
      _number,
      _origin,
      _destination,
      _aircraft,
      _seat,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _airline,
      _number,
      _origin,
      _destination,
      _aircraft,
      _seat,
    ]) {
      c
        ..removeListener(_onFieldChanged)
        ..dispose();
    }
    _airlineFocus.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // ------------------------------------------------------------- validation

  String? _validateAirline(String? value) {
    final String v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'Enter the airline code';
    if (v.length != 2) return 'Two characters, like BA, DL or B6';
    return null;
  }

  String? _validateNumber(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter the flight number';
    if (v.length > 5) return 'Too long for a flight number';
    return null;
  }

  String? _validateAirport(String? value, String which) {
    final String v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'Enter the $which airport';
    if (v.length != 3) return 'Three letters, like JFK';
    return null;
  }

  /// Null when the schedule is usable.
  String? get _scheduleProblem {
    final DateTime? d = _departsAt;
    final DateTime? a = _arrivesAt;
    if (d == null) return 'Set the departure date and time';
    if (a == null) return 'Set the arrival date and time';
    if (!a.isAfter(d)) {
      return 'Arrival has to be after departure — check the date.';
    }
    return null;
  }

  Flight _buildFlight(String id) => Flight(
        id: id,
        airlineIata: _airline.text.trim().toUpperCase(),
        flightNumber: _number.text.trim().toUpperCase(),
        origin: _origin.text.trim().toUpperCase(),
        destination: _destination.text.trim().toUpperCase(),
        departsAt: _departsAt ?? DateTime.now(),
        arrivesAt: _arrivesAt ?? DateTime.now(),
        aircraftType: _aircraft.text.trim(),
        seat: _seat.text.trim(),
        booked: widget.existing?.booked ?? true,
        tripId: widget.tripId,
      );

  // ---------------------------------------------------------------- pickers

  Future<DateTime?> _pickDateTime({
    required DateTime? initial,
    required String helpText,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime seed = initial ?? widget.suggestedDate ?? now;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: helpText,
    );
    if (date == null || !mounted) return null;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
      helpText: helpText,
    );
    if (!mounted) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? seed.hour,
      time?.minute ?? seed.minute,
    );
  }

  Future<void> _pickDeparture() async {
    final DateTime? picked = await _pickDateTime(
      initial: _departsAt,
      helpText: 'Departure',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _departsAt = picked;
      // A sensible arrival beats an empty field, and the user corrects it if
      // the flight is longer than a hop.
      _arrivesAt ??= picked.add(const Duration(hours: 2));
    });
  }

  Future<void> _pickArrival() async {
    final DateTime? picked = await _pickDateTime(
      initial: _arrivesAt ?? _departsAt?.add(const Duration(hours: 2)),
      helpText: 'Arrival',
    );
    if (picked == null || !mounted) return;
    setState(() => _arrivesAt = picked);
  }

  // ------------------------------------------------------------------- save

  Future<void> _save() async {
    setState(() => _submitted = true);
    final bool formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || _scheduleProblem != null) return;

    setState(() => _saving = true);
    final AppState app = context.read<AppState>();
    final NavigatorState nav = Navigator.of(context);
    await app.saveFlight(_buildFlight(widget.existing?.id ?? _newFlightId()));
    if (!mounted) return;
    setState(() => _saving = false);
    nav.pop();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final String? scheduleProblem = _scheduleProblem;
    final DateTime? departs = _departsAt;
    final DateTime? arrives = _arrivesAt;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add a flight' : 'Edit flight'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: <Widget>[
            const SectionTitle('Airline'),
            _AirlineField(
              controller: _airline,
              focusNode: _airlineFocus,
              validator: _validateAirline,
            ),
            const SizedBox(height: 6),
            _KnownCarrierHint(iata: _airline.text.trim().toUpperCase()),
            const SizedBox(height: 12),
            TextFormField(
              controller: _number,
              validator: _validateNumber,
              keyboardType: TextInputType.number,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp('[0-9A-Za-z]')),
                LengthLimitingTextInputFormatter(5),
                const _UpperCaseFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Flight number',
                hintText: '117',
              ),
            ),

            const SectionTitle('Route'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _origin,
                    validator: (String? v) => _validateAirport(v, 'origin'),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: _airportFormatters,
                    decoration: const InputDecoration(
                      labelText: 'From',
                      hintText: 'JFK',
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  child: Icon(Icons.arrow_forward_rounded, size: 18),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _destination,
                    validator: (String? v) =>
                        _validateAirport(v, 'destination'),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: _airportFormatters,
                    decoration: const InputDecoration(
                      labelText: 'To',
                      hintText: 'LHR',
                    ),
                  ),
                ),
              ],
            ),

            const SectionTitle('Schedule'),
            _DateTimeField(
              label: 'Departs',
              value: _departsAt,
              onTap: _pickDeparture,
            ),
            const SizedBox(height: 12),
            _DateTimeField(
              label: 'Arrives',
              value: _arrivesAt,
              onTap: _pickArrival,
            ),
            if (_submitted && scheduleProblem != null) ...<Widget>[
              const SizedBox(height: 8),
              _InlineError(scheduleProblem),
            ],
            if (departs != null &&
                arrives != null &&
                arrives.isAfter(departs)) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'In the air for '
                '${formatFlightDuration(arrives.difference(departs))}.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SectionTitle('Aircraft and seat'),
            TextFormField(
              controller: _aircraft,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Aircraft type (optional)',
                hintText: 'A350-900, 737-800',
                helperText: 'Used to show where the on-board medical kit is '
                    'usually kept.',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _seat,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(4),
                const _UpperCaseFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Seat (optional)',
                hintText: '14A',
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save flight'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

const List<TextInputFormatter> _airportFormatters = <TextInputFormatter>[
  _LettersOnlyFormatter(),
  _UpperCaseFormatter(),
  _MaxLengthFormatter(3),
];

// ---------------------------------------------------------------------------
// Fields
// ---------------------------------------------------------------------------

/// The airline code, with an autocomplete over the carriers the app actually
/// holds a policy for. Typing a name works as well as typing a code, because
/// nobody thinks in IATA codes until they have to.
class _AirlineField extends StatelessWidget {
  const _AirlineField({
    required this.controller,
    required this.focusNode,
    required this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FormFieldValidator<String> validator;

  Iterable<String> _options(TextEditingValue value) {
    final List<String> codes = kAirlinePolicies.keys.toList()..sort();
    final String q = value.text.trim().toUpperCase();
    if (q.isEmpty) return codes.take(8);
    return codes.where((String code) {
      if (code.toUpperCase().startsWith(q)) return true;
      final String name = kAirlinePolicies[code]?.name.toUpperCase() ?? '';
      return name.contains(q);
    }).take(8);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: _options,
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController fieldController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: fieldController,
              focusNode: fieldFocusNode,
              validator: validator,
              textCapitalization: TextCapitalization.characters,
              // Alphanumeric: B6, F9 and U2 are real carrier codes.
              inputFormatters: const <TextInputFormatter>[
                _AlphanumericFormatter(),
                _UpperCaseFormatter(),
                _MaxLengthFormatter(2),
              ],
              onFieldSubmitted: (String _) => onFieldSubmitted(),
              decoration: const InputDecoration(
                labelText: 'Airline code',
                hintText: 'BA',
                prefixIcon: Icon(Icons.flight_rounded),
              ),
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            final List<String> list = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String code = list[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            kAirlinePolicies[code]?.name ?? code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Text(
                            code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          onTap: () => onSelected(code),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Says whether the app has a step-by-step request guide for the carrier.
/// No guide is not a warning — the flight saves the same, and the request log
/// works for any airline.
class _KnownCarrierHint extends StatelessWidget {
  const _KnownCarrierHint({required this.iata});

  final String iata;

  @override
  Widget build(BuildContext context) {
    if (iata.length != 2) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AirlinePolicy? policy = policyFor(iata);
    final bool hasGuide = guideFor(iata) != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          hasGuide ? Icons.menu_book_rounded : Icons.info_outline_rounded,
          size: 15,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hasGuide
                ? '${policy?.name ?? iata} — step-by-step request guide '
                    'available.'
                : 'No request guide for $iata yet. You can still log every '
                    'request you make.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime? v = value;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                v == null ? 'Not set' : formatFlightDateTime(v),
                style: TextStyle(
                  color: v == null ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.error_outline_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, height: 1.35, color: color),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Formatters and ids
// ---------------------------------------------------------------------------

/// Uppercases as the user types, so what is on screen is what is stored and
/// what the policy lookup sees.
class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return TextEditingValue(
      text: upper,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

class _AlphanumericFormatter extends TextInputFormatter {
  const _AlphanumericFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String cleaned =
        newValue.text.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    if (cleaned == newValue.text) return newValue;
    final int offset = newValue.selection.baseOffset.clamp(0, cleaned.length);
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}

class _LettersOnlyFormatter extends TextInputFormatter {
  const _LettersOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String cleaned = newValue.text.replaceAll(RegExp('[^A-Za-z]'), '');
    if (cleaned == newValue.text) return newValue;
    final int offset = newValue.selection.baseOffset
        .clamp(0, cleaned.length);
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}

/// `LengthLimitingTextInputFormatter` is not `const`-constructible, and these
/// formatter lists are shared constants.
class _MaxLengthFormatter extends TextInputFormatter {
  const _MaxLengthFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= max) return newValue;
    final String clipped = newValue.text.substring(0, max);
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
      composing: TextRange.empty,
    );
  }
}

/// Unique within one device's store, which is all any id here has to be.
int _idCounter = 0;
String _newFlightId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
