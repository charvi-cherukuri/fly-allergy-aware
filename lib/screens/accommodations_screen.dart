import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/models/flight.dart';
import 'package:trace_allergy/models/travel.dart';
import 'package:trace_allergy/screens/how_to_request_screen.dart';
import 'package:trace_allergy/screens/incident_report_screen.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// The accommodation log for one flight (FRD 2.2).
///
/// Everything on this screen exists because of one asymmetry: the airline has
/// a record of the call and the passenger does not. A request logged here
/// carries the date, the channel, the reference number and the name of whoever
/// gave it — so when a carrier confirms a buffer zone in June and provides
/// nothing in August, the passenger has something to show rather than a
/// recollection.
///
/// The status of a request is not set once. It changes on the day of travel,
/// from "confirmed" to either "honoured" or "not honoured", and that second
/// transition is the entire point of the feature.
class AccommodationsScreen extends StatefulWidget {
  const AccommodationsScreen({super.key, this.flightId});

  /// When null, the screen asks which flight first.
  final String? flightId;

  @override
  State<AccommodationsScreen> createState() => _AccommodationsScreenState();
}

class _AccommodationsScreenState extends State<AccommodationsScreen> {
  String? _flightId;

  /// The request whose status was just set to something that warrants a
  /// report. Drives the prominent prompt rather than a snackbar the user can
  /// miss while they are still standing in the aisle.
  String? _justFailedId;
  bool _promptDismissed = false;

  @override
  void initState() {
    super.initState();
    _flightId = widget.flightId;
  }

  // ------------------------------------------------------------------ actions

  Future<void> _openForm({
    AccommodationRequest? existing,
    AccommodationType? prefillType,
  }) async {
    final flightId = _flightId;
    if (flightId == null) return;
    final app = context.read<AppState>();

    final result = await showModalBottomSheet<AccommodationRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => _RequestForm(
        existing: existing,
        flightId: flightId,
        prefillType: prefillType,
      ),
    );
    if (result == null) return;
    await app.saveRequest(result);
    if (!mounted) return;
    if (result.status.warrantsReport) {
      setState(() {
        _justFailedId = result.id;
        _promptDismissed = false;
      });
    }
  }

  /// The other half of logging a request is knowing how to make one. Popping
  /// `true` from that screen means the user has just asked, so the form opens
  /// straight away rather than leaving them to find it.
  Future<void> _openHowTo(Flight flight) async {
    final asked = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) => HowToRequestScreen(
          iata: flight.airlineIata,
          flightId: flight.id,
        ),
      ),
    );
    if (!mounted) return;
    if (asked == true) await _openForm();
  }

  Future<void> _updateStatus(AccommodationRequest request) async {
    final app = context.read<AppState>();

    final result = await showModalBottomSheet<_StatusChange>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => _StatusSheet(request: request),
    );
    if (result == null) return;

    final updated = AccommodationRequest(
      id: request.id,
      flightId: request.flightId,
      type: request.type,
      requestedAt: request.requestedAt,
      channel: request.channel,
      reference: request.reference,
      agentName: request.agentName,
      status: result.status,
      responseNotes: result.notes,
      // The moment the outcome was settled is itself part of the record.
      resolvedAt: result.status == RequestStatus.pending
          ? null
          : (result.status == request.status
              ? (request.resolvedAt ?? DateTime.now())
              : DateTime.now()),
    );

    await app.saveRequest(updated);
    if (!mounted) return;
    setState(() {
      if (updated.status.warrantsReport) {
        _justFailedId = updated.id;
        _promptDismissed = false;
      } else if (_justFailedId == updated.id) {
        _justFailedId = null;
      }
    });
  }

  Future<void> _confirmDelete(AccommodationRequest request) async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Remove this request'),
        content: Text(
          '"${request.type.label}", logged '
          '${_formatDate(request.requestedAt)}. You will have no record '
          'that you asked.',
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
    if (ok != true) return;
    await app.deleteRequest(request.id);
    if (!mounted) return;
    setState(() {
      if (_justFailedId == request.id) _justFailedId = null;
    });
  }

  void _compileReport(AccommodationRequest request) {
    final flightId = _flightId;
    if (flightId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => IncidentReportScreen(
          flightId: flightId,
          requestId: request.id,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final flights = app.flights;
    final flight = _flightFor(flights, _flightId);

    if (flight == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accommodations')),
        body: _FlightPicker(
          flights: flights,
          onPick: (Flight f) => setState(() => _flightId = f.id),
        ),
      );
    }

    final requests = app.requestsFor(flight.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accommodations'),
        actions: <Widget>[
          if (widget.flightId == null && flights.length > 1)
            IconButton(
              tooltip: 'Choose another flight',
              onPressed: () => setState(() {
                _flightId = null;
                _justFailedId = null;
              }),
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
        ],
      ),
      floatingActionButton: requests.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Log a request'),
            ),
      body: requests.isEmpty
          ? _EmptyLog(
              flight: flight,
              onAdd: _openForm,
              onHowTo: () => _openHowTo(flight),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: _content(flight, requests),
            ),
    );
  }

  List<Widget> _content(Flight flight, List<AccommodationRequest> requests) {
    final children = <Widget>[
      _FlightHeader(flight: flight),
      const SizedBox(height: 12),
      _HowToTile(
        iata: flight.airlineIata,
        onTap: () => _openHowTo(flight),
      ),
    ];

    final prompt = _promptRequest(requests);
    if (prompt != null) {
      children
        ..add(const SizedBox(height: 14))
        ..add(
          _FailurePrompt(
            request: prompt,
            flight: flight,
            onCompile: () => _compileReport(prompt),
            onDismiss: () => setState(() => _promptDismissed = true),
          ),
        );
    }

    for (final status in RequestStatus.values) {
      final group = requests.where((r) => r.status == status).toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      if (group.isEmpty) continue;
      children.add(SectionTitle('${status.label} (${group.length})'));
      for (var i = 0; i < group.length; i++) {
        if (i > 0) children.add(const SizedBox(height: 10));
        children.add(
          _RequestCard(
            request: group[i],
            onTap: () => _updateStatus(group[i]),
            onEdit: () => _openForm(existing: group[i]),
            onDelete: () => _confirmDelete(group[i]),
            onCompile: group[i].status.warrantsReport
                ? () => _compileReport(group[i])
                : null,
          ),
        );
      }
    }

    final logged = requests.map((r) => r.type).toSet();
    final suggestions = AccommodationType.values
        .where((t) => t != AccommodationType.other && !logged.contains(t))
        .toList();
    if (suggestions.isNotEmpty) {
      children
        ..add(const SectionTitle('Suggested requests'))
        ..add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Rarely offered, never guaranteed.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      for (var i = 0; i < suggestions.length; i++) {
        if (i > 0) children.add(const SizedBox(height: 10));
        children.add(
          _SuggestionCard(
            type: suggestions[i],
            onAdd: () => _openForm(prefillType: suggestions[i]),
          ),
        );
      }
    }

    children
      ..add(const SizedBox(height: 24))
      ..add(
        Text(
          'Update each request on the day you travel.',
          style: TextStyle(
            fontSize: 14.5,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

    return children;
  }

  /// The failure worth putting in front of the user right now: the one just
  /// marked, otherwise the most recent unresolved failure on this flight.
  AccommodationRequest? _promptRequest(List<AccommodationRequest> requests) {
    if (_promptDismissed) return null;
    final failures = requests.where((r) => r.status.warrantsReport).toList();
    if (failures.isEmpty) return null;
    for (final r in failures) {
      if (r.id == _justFailedId) return r;
    }
    failures.sort(
      (a, b) => (b.resolvedAt ?? b.requestedAt)
          .compareTo(a.resolvedAt ?? a.requestedAt),
    );
    return failures.first;
  }

  Flight? _flightFor(List<Flight> flights, String? id) {
    if (id == null) return null;
    for (final f in flights) {
      if (f.id == id) return f;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Flight picker
// ---------------------------------------------------------------------------

class _FlightPicker extends StatelessWidget {
  const _FlightPicker({required this.flights, required this.onPick});

  final List<Flight> flights;
  final ValueChanged<Flight> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (flights.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.flight_takeoff_rounded,
                size: 44,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              const Text(
                'No flights yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Requests are logged against a flight. Add one first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: flights.length + 1,
      separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Which flight are these requests for?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          );
        }
        final f = flights[index - 1];
        return Card(
          child: ListTile(
            onTap: () => onPick(f),
            title: Text(
              '${f.airlineIata}${f.flightNumber}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${f.origin} to ${f.destination} · '
              '${_formatDate(f.departsAt)}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// List pieces
// ---------------------------------------------------------------------------

class _FlightHeader extends StatelessWidget {
  const _FlightHeader({required this.flight});

  final Flight flight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(Icons.flight_rounded, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${flight.airlineIata}${flight.flightNumber} · '
            '${flight.origin} to ${flight.destination} · '
            '${_formatDate(flight.departsAt)}',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The way in to the carrier's own request procedure. Sits above the log
/// because the most common reason there is nothing to log is not knowing which
/// channel the airline actually honours.
class _HowToTile extends StatelessWidget {
  const _HowToTile({required this.iata, required this.onTap});

  final String iata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final carrier = iata.trim().isEmpty ? 'this airline' : iata.trim();

    return Card(
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Icon(Icons.help_outline_rounded, color: scheme.primary),
        title: Text(
          'How do I request on $carrier?',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Channel, window, and what to say.',
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onCompile,
  });

  final AccommodationRequest request;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onCompile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = request;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      r.type.label,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    onSelected: (String value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (BuildContext _) =>
                        const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit details'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 2),
                    _StatusChip(status: r.status),
                    const SizedBox(height: 10),
                    _DetailRow(
                      icon: Icons.forum_outlined,
                      text: '${r.channel.label} · '
                          '${_formatDateTime(r.requestedAt)}',
                    ),
                    _DetailRow(
                      icon: Icons.confirmation_number_outlined,
                      text: r.reference.trim().isEmpty
                          ? 'No reference'
                          : 'Reference ${r.reference.trim()}',
                      muted: r.reference.trim().isEmpty,
                    ),
                    if (r.agentName.trim().isNotEmpty)
                      _DetailRow(
                        icon: Icons.person_outline_rounded,
                        text: 'Spoke to ${r.agentName.trim()}',
                      ),
                    if (r.responseNotes.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        r.responseNotes.trim(),
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (onCompile != null) ...<Widget>[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: _danger(context),
                          side: BorderSide(
                            color: _danger(context).withValues(alpha: 0.5),
                          ),
                        ),
                        onPressed: onCompile,
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Compile an incident report'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = muted
        ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
        : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14.5, height: 1.3, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_statusIcon(status), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The prompt that turns a broken promise into a record. It is deliberately
/// loud: the moment a confirmed accommodation fails is the moment the details
/// are freshest, and it is the only moment the user is motivated to write
/// anything down.
class _FailurePrompt extends StatelessWidget {
  const _FailurePrompt({
    required this.request,
    required this.flight,
    required this.onCompile,
    required this.onDismiss,
  });

  final AccommodationRequest request;
  final Flight flight;
  final VoidCallback onCompile;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final danger = _danger(context);
    final refused = request.status == RequestStatus.refused;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: danger, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.report_gmailerrorred_rounded, color: danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  refused
                      ? 'This request was refused'
                      : 'This was confirmed and not provided',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: danger,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Not now',
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, size: 20, color: danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${request.type.label}" on '
            '${flight.airlineIata}${flight.flightNumber}.',
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 8),
          const Text(
            'Compile it now, while the details are to hand.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: Colors.white,
            ),
            onPressed: onCompile,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Compile an incident report'),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.type, required this.onAdd});

  final AccommodationType type;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      type.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _whyAsk(type),
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.add_circle_outline_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog({
    required this.flight,
    required this.onAdd,
    required this.onHowTo,
  });

  final Flight flight;
  final VoidCallback onAdd;
  final VoidCallback onHowTo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: <Widget>[
        Icon(
          Icons.fact_check_outlined,
          size: 44,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        const Text(
          'Nothing logged for this flight',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'Log the date, the channel, the reference number and who confirmed '
          'it. On the day you fly, mark what happened.',
          style: TextStyle(
            fontSize: 14.5,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Log a request'),
        ),
        const SizedBox(height: 14),
        _HowToTile(iata: flight.airlineIata, onTap: onHowTo),
        const SectionTitle('Worth asking for'),
        for (final type in AccommodationType.values)
          if (type != AccommodationType.other)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SuggestionCard(type: type, onAdd: onAdd),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The request form
// ---------------------------------------------------------------------------

class _RequestForm extends StatefulWidget {
  const _RequestForm({
    required this.existing,
    required this.flightId,
    required this.prefillType,
  });

  final AccommodationRequest? existing;
  final String flightId;
  final AccommodationType? prefillType;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  late final TextEditingController _reference;
  late final TextEditingController _agent;
  late final TextEditingController _notes;
  late AccommodationType _type;
  late RequestChannel _channel;
  late DateTime _requestedAt;
  late RequestStatus _status;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _reference = TextEditingController(text: e?.reference ?? '');
    _agent = TextEditingController(text: e?.agentName ?? '');
    _notes = TextEditingController(text: e?.responseNotes ?? '');
    _type = e?.type ?? widget.prefillType ?? AccommodationType.preboardToWipe;
    _channel = e?.channel ?? RequestChannel.phone;
    _requestedAt = e?.requestedAt ?? DateTime.now();
    _status = e?.status ?? RequestStatus.pending;
  }

  @override
  void dispose() {
    _reference.dispose();
    _agent.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _requestedAt,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      helpText: 'When did you make the request',
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_requestedAt),
    );
    if (!mounted) return;
    setState(() {
      _requestedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _requestedAt.hour,
        time?.minute ?? _requestedAt.minute,
      );
    });
  }

  void _save() {
    final e = widget.existing;
    Navigator.of(context).pop(
      AccommodationRequest(
        id: e?.id ?? _newId(),
        flightId: widget.flightId,
        type: _type,
        requestedAt: _requestedAt,
        channel: _channel,
        reference: _reference.text.trim(),
        agentName: _agent.text.trim(),
        status: _status,
        responseNotes: _notes.text.trim(),
        resolvedAt: _status == RequestStatus.pending
            ? null
            : (e?.resolvedAt ?? DateTime.now()),
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
            Text(
              widget.existing == null ? 'Log a request' : 'Edit request',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),

            const SectionTitle('What you asked for'),
            DropdownButtonFormField<AccommodationType>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Request'),
              items: <DropdownMenuItem<AccommodationType>>[
                for (final t in AccommodationType.values)
                  DropdownMenuItem<AccommodationType>(
                    value: t,
                    child: Text(t.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (AccommodationType? v) {
                if (v == null) return;
                setState(() => _type = v);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _whyAsk(_type),
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),

            const SectionTitle('How and when'),
            DropdownButtonFormField<RequestChannel>(
              initialValue: _channel,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Channel'),
              items: <DropdownMenuItem<RequestChannel>>[
                for (final c in RequestChannel.values)
                  DropdownMenuItem<RequestChannel>(
                    value: c,
                    child: Text(c.label),
                  ),
              ],
              onChanged: (RequestChannel? v) {
                if (v == null) return;
                setState(() => _channel = v);
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickWhen,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date and time'),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(_formatDateTime(_requestedAt))),
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            const SectionTitle('What they gave you'),
            TextField(
              controller: _reference,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Airline reference number',
                hintText: 'Case or confirmation number',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _agent,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Agent name',
                hintText: 'Who you spoke to',
              ),
            ),

            const SectionTitle('Where it stands'),
            DropdownButtonFormField<RequestStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: <DropdownMenuItem<RequestStatus>>[
                for (final s in RequestStatus.values)
                  DropdownMenuItem<RequestStatus>(
                    value: s,
                    child: Text(s.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (RequestStatus? v) {
                if (v == null) return;
                setState(() => _status = v);
              },
            ),

            const SectionTitle('Notes'),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What they said, and anything they would not '
                    'commit to.',
                hintMaxLines: 2,
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save request')),
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

// ---------------------------------------------------------------------------
// The status sheet — the interaction that matters on the day
// ---------------------------------------------------------------------------

class _StatusChange {
  const _StatusChange(this.status, this.notes);
  final RequestStatus status;
  final String notes;
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.request});

  final AccommodationRequest request;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late RequestStatus _status;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _status = widget.request.status;
    _notes = TextEditingController(text: widget.request.responseNotes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
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
            Text(
              widget.request.type.label,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Requested ${_formatDateTime(widget.request.requestedAt)} '
              'by ${widget.request.channel.label.toLowerCase()}.',
              style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
            ),
            const SectionTitle('Where it stands now'),
            for (final s in RequestStatus.values)
              _StatusOption(
                status: s,
                selected: s == _status,
                onTap: () => setState(() => _status = s),
              ),
            if (_status.warrantsReport) ...<Widget>[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _danger(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'What you write below goes into the complaint.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    color: _danger(context),
                  ),
                ),
              ),
            ],
            const SectionTitle('What happened'),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What was said, by whom, and what was done.',
                hintMaxLines: 2,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _StatusChange(_status, _notes.text.trim()),
              ),
              child: const Text('Save status'),
            ),
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

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final RequestStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(context, status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? color : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusHint(status),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Color _danger(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? TraceColors.unsafeDark
    : TraceColors.unsafe;

Color _statusColor(BuildContext context, RequestStatus status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case RequestStatus.refused:
    case RequestStatus.notHonoured:
      return dark ? TraceColors.unsafeDark : TraceColors.unsafe;
    case RequestStatus.honoured:
      return dark ? TraceColors.clearDark : TraceColors.clear;
    case RequestStatus.confirmed:
      return scheme.primary;
    case RequestStatus.pending:
      return scheme.onSurfaceVariant;
  }
}

IconData _statusIcon(RequestStatus status) {
  switch (status) {
    case RequestStatus.pending:
      return Icons.schedule_rounded;
    case RequestStatus.confirmed:
      return Icons.task_alt_rounded;
    case RequestStatus.refused:
      return Icons.block_rounded;
    case RequestStatus.honoured:
      return Icons.check_circle_outline_rounded;
    case RequestStatus.notHonoured:
      return Icons.report_gmailerrorred_rounded;
  }
}

String _statusHint(RequestStatus status) {
  switch (status) {
    case RequestStatus.pending:
      return 'Asked, nothing back yet.';
    case RequestStatus.confirmed:
      return 'They said yes. Not the same as done.';
    case RequestStatus.refused:
      return 'They said no.';
    case RequestStatus.honoured:
      return 'It happened.';
    case RequestStatus.notHonoured:
      return 'Agreed, then did not happen.';
  }
}

/// Why each of these is worth asking for. Most passengers do not know a buffer
/// zone or pre-boarding is even askable, and no carrier volunteers it.
String _whyAsk(AccommodationType type) {
  switch (type) {
    case AccommodationType.preboardToWipe:
      return 'Board early, wipe the tray table, armrests and belt buckle.';
    case AccommodationType.bufferZone:
      return 'Rows around you kept free of nut service. Ask for it by name.';
    case AccommodationType.noNutService:
      return 'Nut service suspended, at least in your cabin.';
    case AccommodationType.cabinAnnouncement:
      return 'Crew ask the cabin not to open nut products.';
    case AccommodationType.seatChange:
      return 'Far easier before the door closes than after.';
    case AccommodationType.ownFood:
      return 'Agreed in advance, so you are not arguing it at security.';
    case AccommodationType.epiOnBoard:
      return 'In the cabin, never the hold — they can freeze.';
    case AccommodationType.crewNotified:
      return 'Operating crew briefed before departure. Check at the gate.';
    case AccommodationType.other:
      return 'Anything else you asked for.';
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

String _formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

String _formatDateTime(DateTime d) {
  final local = d.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_formatDate(local)}, $hour:$minute';
}

int _idCounter = 0;
String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
