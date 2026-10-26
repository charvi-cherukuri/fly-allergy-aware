import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'day_of_travel_screen.dart';
import 'flight_experience_screen.dart';
import 'medical_kits_screen.dart';

import '../data/airline_policies.dart';
import '../data/emk_locations.dart';
import '../models/flight.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/travel_format.dart';
import 'accommodations_screen.dart';
import 'add_flight_screen.dart';
import 'crew_card_screen.dart';
import 'how_to_request_screen.dart';
import 'seat_cleaning_screen.dart';

/// One flight leg of a trip: the itinerary, where the medical kit usually
/// is on that aircraft, and the way into asking the airline for help.
class FlightLegScreen extends StatefulWidget {
  const FlightLegScreen({super.key, required this.flightId});

  final String flightId;

  @override
  State<FlightLegScreen> createState() => _FlightLegScreenState();
}

class _FlightLegScreenState extends State<FlightLegScreen> {
  bool _popScheduled = false;

  Future<void> _openGuide(Flight flight) async {
    final bool? asked = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) => HowToRequestScreen(
          iata: flight.airlineIata,
          flightId: flight.id,
        ),
      ),
    );
    // Came back having asked: straight to the log, while the reference
    // number is still on screen in the airline's app or email.
    if (!mounted || asked != true) return;
    await _openRequests(flight);
  }

  Future<void> _openRequests(Flight flight) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => AccommodationsScreen(flightId: flight.id),
      ),
    );
  }

  /// The wipe-down screen pops [kPreboardRequest] when the user wants to ask
  /// to board early; that is a request to the airline, so it goes to the log.
  Future<void> _openWipeDown(Flight flight) async {
    final String? result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext _) => SeatCleaningScreen(flightId: flight.id),
      ),
    );
    if (!mounted || result != kPreboardRequest) return;
    await _openRequests(flight);
  }

  Future<void> _edit(Flight flight) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => AddFlightScreen(
          tripId: flight.tripId ?? '',
          existing: flight,
        ),
      ),
    );
  }

  Future<void> _delete(Flight flight) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Remove this flight?'),
            content: const Text(
              'The flight and its seat wipe-down logs are removed. Requests '
              'made to the airline and incident reports are kept with the '
              'trip.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    await context.read<AppState>().deleteFlight(flight.id);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    Flight? flight;
    for (final Flight f in app.flights) {
      if (f.id == widget.flightId) flight = f;
    }

    if (flight == null) {
      // Deleted, here or elsewhere. Leave rather than show a ghost.
      if (!_popScheduled) {
        _popScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((Duration _) {
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        });
      }
      return const Scaffold(body: SizedBox.shrink());
    }

    final Flight leg = flight;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AirlinePolicy? policy = policyFor(leg.airlineIata);
    final int requestCount = app.requestsFor(leg.id).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(leg.label),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit flight',
            onPressed: () => _edit(leg),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remove flight',
            onPressed: () => _delete(leg),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    leg.route,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${policy?.name ?? leg.airlineIata} ${leg.flightNumber}',
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  _Fact('Departs', formatFlightDateTime(leg.departsAt)),
                  _Fact('Arrives', formatFlightDateTime(leg.arrivesAt)),
                  _Fact('In the air', formatFlightDuration(leg.duration)),
                  _Fact(
                    'Aircraft',
                    leg.aircraftType.trim().isEmpty
                        ? 'Not recorded'
                        : leg.aircraftType.trim(),
                  ),
                  _Fact(
                    'Seat',
                    leg.seat.trim().isEmpty ? 'Not set' : leg.seat.trim(),
                    last: true,
                  ),
                ],
              ),
            ),
          ),

          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => DayOfTravelScreen(flightId: leg.id),
              ),
            ),
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('At the airport and on board'),
          ),
          const SizedBox(height: 6),
          Text(
            'What to ask at the gate and on board, and what to say.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => CrewCardScreen(flightId: leg.id),
              ),
            ),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Show to crew'),
          ),

          const SectionTitle('Before you fly'),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: Text(
                    'How to request on ${policy?.name ?? leg.airlineIata}',
                  ),
                  subtitle: const Text(
                    'Who to contact, what to say, and when',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openGuide(leg),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('Requests made'),
                  subtitle: Text(
                    requestCount == 0
                        ? 'Log each request, its reference number and what '
                            'happened on the day'
                        : '$requestCount logged',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openRequests(leg),
                ),
              ],
            ),
          ),

          const SectionTitle('On board'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Seat wipe-down'),
              subtitle: Text(
                app.cleaningFor(leg.id).isEmpty
                    ? 'Log which surfaces were wiped, and by whom'
                    : '${app.cleaningFor(leg.id).length} logged',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openWipeDown(leg),
            ),
          ),

          const SectionTitle('After the flight'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Record your flight experience'),
              subtitle: Text(
                app.experienceFor(leg.id) == null
                    ? 'Food information, staff help, medication, ideas'
                    : 'Recorded — tap to edit',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) => FlightExperienceScreen(flightId: leg.id),
                ),
              ),
            ),
          ),

          const SectionTitle('Medical kit on this plane'),
          _KitCard(aircraftType: leg.aircraftType),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (BuildContext _) => const MedicalKitsScreen()),
            ),
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: const Text('Which airlines carry auto-injectors?'),
          ),
        ],
      ),
    );
  }
}

class _KitCard extends StatelessWidget {
  const _KitCard({required this.aircraftType});

  final String aircraftType;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final EmkLocation kit = emkFor(aircraftType);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              kit.aircraftFamily,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(kit.stowage, style: const TextStyle(fontSize: 14, height: 1.4)),
            if (kit.notes.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                kit.notes,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (aircraftType.trim().isEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Add the aircraft type to the flight for more specific '
                'guidance.',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14.5))),
        ],
      ),
    );
  }
}
