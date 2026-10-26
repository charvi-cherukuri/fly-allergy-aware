import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'day_of_travel_screen.dart';
import '../models/flight_experience.dart';
import 'flight_experience_screen.dart';

import '../data/countries.dart';
import '../models/emergency.dart';
import '../models/flight.dart';
import '../models/travel.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../services/trip_journal.dart';
import '../theme.dart';
import '../widgets/language_suggestion_card.dart';
import '../widgets/travel_format.dart';
import '../widgets/trip_actions.dart';
import '../widgets/trip_card.dart';
import 'accommodations_screen.dart';
import 'add_flight_screen.dart';
import 'exposure_edit_screen.dart';
import 'flight_leg_screen.dart';
import 'incident_report_screen.dart';
import 'reaction_log_screen.dart';
import 'seat_cleaning_screen.dart';
import 'trip_edit_screen.dart';

/// Everything on a trip, as one ordered list.
List<JournalEntry> journalFor(AppState app, Trip trip) {
  final List<Flight> legs = app.flightsFor(trip.id);
  return TripJournal.entries(
    legs: legs,
    requests: <AccommodationRequest>[
      for (final Flight f in legs) ...app.requestsFor(f.id),
    ],
    exposures: app.exposuresFor(trip.id),
    reactions: app.reactionsFor(trip.id),
    incidents: app.incidentsFor(trip.id),
    wipeDowns: <SeatCleaningLog>[
      for (final Flight f in legs) ...app.cleaningFor(f.id),
    ],
    profiles: app.profiles,
    experiences: <FlightExperience>[
      for (final Flight f in legs)
        if (app.experienceFor(f.id) case final FlightExperience x) x,
    ],
  );
}

/// One trip: who, where, when, its flights and everything logged on it.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  bool _popScheduled = false;

  /// Timeline filter. Null shows everything.
  JournalKind? _filter;

  Future<void> _openEntry(Trip trip, JournalEntry e) async {
    final AppState app = context.read<AppState>();
    final NavigatorState nav = Navigator.of(context);
    Future<void> push(Widget screen) =>
        nav.push<void>(MaterialPageRoute<void>(builder: (BuildContext _) => screen));

    switch (e.kind) {
      case JournalKind.flight:
        await push(FlightLegScreen(flightId: e.id));
      case JournalKind.request:
        await push(AccommodationsScreen(flightId: e.flightId));
      case JournalKind.wipeDown:
        await push(SeatCleaningScreen(flightId: e.flightId ?? ''));
      case JournalKind.experience:
        await push(FlightExperienceScreen(flightId: e.flightId ?? ''));
      case JournalKind.exposure:
        final Exposure? x = _find(app.exposuresFor(trip.id), (Exposure x) => x.id == e.id);
        if (x != null) await push(ExposureEditScreen(tripId: trip.id, existing: x));
      case JournalKind.reaction:
        final ReactionLog? r =
            _find(app.reactionsFor(trip.id), (ReactionLog r) => r.id == e.id);
        if (r != null) {
          await showReactionForm(context, profileId: r.profileId, existing: r);
        }
      case JournalKind.incident:
        final IncidentReport? i =
            _find(app.incidentsFor(trip.id), (IncidentReport i) => i.id == e.id);
        if (i != null) {
          await push(IncidentReportScreen(
            flightId: i.flightId,
            tripId: trip.id,
            existing: i,
          ));
        }
    }
  }

  /// The leg not yet landed, else the last one.
  static Flight? _nextLeg(List<Flight> legs, DateTime now) {
    for (final Flight f in legs) {
      if (f.arrivesAt.isAfter(now)) return f;
    }
    return legs.isEmpty ? null : legs.last;
  }

  static T? _find<T>(List<T> list, bool Function(T) test) {
    for (final T x in list) {
      if (test(x)) return x;
    }
    return null;
  }

  Future<void> _export(Trip trip) async {
    final AppState app = context.read<AppState>();
    final String text = TripJournal.report(
      trip: trip,
      entries: journalFor(app, trip),
      travelers: travelerNames(trip, app.profiles),
    );
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Share.share(text, subject: trip.name, sharePositionOrigin: origin);
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the share sheet.')),
      );
    }
  }

  Future<void> _edit(Trip trip) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => TripEditScreen(existing: trip),
      ),
    );
  }

  Future<void> _addFlight(Trip trip) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => AddFlightScreen(
          tripId: trip.id,
          suggestedDate: DateTime(
            trip.startsOn.year,
            trip.startsOn.month,
            trip.startsOn.day,
            9,
          ),
        ),
      ),
    );
  }

  Future<void> _openFlight(Flight f) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => FlightLegScreen(flightId: f.id),
      ),
    );
  }

  /// Says exactly what goes before asking, because a trip carries evidence —
  /// reference numbers, incident reports — that cannot be recreated.
  Future<void> _delete(Trip trip) async {
    final AppState app = context.read<AppState>();
    final List<Flight> legs = app.flightsFor(trip.id);
    final int requests =
        legs.fold<int>(0, (int n, Flight f) => n + app.requestsFor(f.id).length);
    final int exposures = app.exposuresFor(trip.id).length;
    final int incidents = app.incidentsFor(trip.id).length;

    String count(int n, String one) => '$n $one${n == 1 ? '' : 's'}';
    final List<String> parts = <String>[
      if (legs.isNotEmpty) count(legs.length, 'flight'),
      if (requests > 0) count(requests, 'airline request'),
      if (exposures > 0) count(exposures, 'exposure'),
      if (incidents > 0) count(incidents, 'incident report'),
    ];

    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Delete ${trip.name}?'),
            content: Text(
              parts.isEmpty
                  ? 'Nothing has been logged on this trip yet.'
                  : 'This also deletes ${parts.join(', ')}. Reactions stay in '
                      'the reaction log.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    await app.deleteTrip(trip.id);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final Trip? found = app.tripById(widget.tripId);

    if (found == null) {
      if (!_popScheduled) {
        _popScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((Duration _) {
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        });
      }
      return const Scaffold(body: SizedBox.shrink());
    }

    final Trip trip = found;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Country? country = countryFor(trip.destinationCountry);
    final List<Flight> legs = app.flightsFor(trip.id);
    final DateTime now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit trip',
            onPressed: () => _edit(trip),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (String v) {
              if (v == 'export') _export(trip);
              if (v == 'delete') _delete(trip);
            },
            itemBuilder: (BuildContext _) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.ios_share_rounded),
                  title: Text('Export trip report'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete trip'),
                ),
              ),
            ],
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
                    country == null
                        ? 'Destination not set'
                        : '${country.flag}  ${country.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatTripDates(trip.startsOn, trip.endsOn)} · '
                    '${tripStatusLine(trip, now)}',
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    travelerNames(trip, app.profiles),
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                  if (country != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      'Ambulance in ${country.name}: ${country.emergency}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (trip.notes.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(trip.notes, style: const TextStyle(height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          QuickLogRow(trip: trip),
          const SizedBox(height: 8),
          LanguageSuggestionCard(trip: trip),

          SectionTitle(
            'Flights',
            trailing: TextButton.icon(
              onPressed: () => _addFlight(trip),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add flight'),
            ),
          ),
          if (legs.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.flight_rounded),
                title: const Text('No flights yet'),
                subtitle: const Text(
                  'Add a flight to see what to ask for and where the medical '
                  'kit is.',
                ),
                onTap: () => _addFlight(trip),
              ),
            )
          else
            for (final Flight f in legs)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.flight_rounded),
                  title: Text('${f.label}  ${f.route}'),
                  subtitle: Text(
                    '${formatFlightDateTime(f.departsAt)}'
                    '${f.seat.trim().isEmpty ? '' : ' · Seat ${f.seat.trim()}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openFlight(f),
                ),
              ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('At the airport and on board'),
              subtitle: const Text(
                'What to ask for, and what to say',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) => DayOfTravelScreen(
                    flightId: _nextLeg(legs, now)?.id,
                  ),
                ),
              ),
            ),
          ),

          const SectionTitle('Timeline'),
          _Timeline(
            entries: journalFor(app, trip),
            filter: _filter,
            onFilter: (JournalKind? k) => setState(() => _filter = k),
            onOpen: (JournalEntry e) => _openEntry(trip, e),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.entries,
    required this.filter,
    required this.onFilter,
    required this.onOpen,
  });

  final List<JournalEntry> entries;
  final JournalKind? filter;
  final ValueChanged<JournalKind?> onFilter;
  final ValueChanged<JournalEntry> onOpen;

  static IconData _icon(JournalKind k) {
    switch (k) {
      case JournalKind.flight:
        return Icons.flight_rounded;
      case JournalKind.request:
        return Icons.fact_check_outlined;
      case JournalKind.exposure:
        return Icons.back_hand_outlined;
      case JournalKind.reaction:
        return Icons.healing_outlined;
      case JournalKind.incident:
        return Icons.report_outlined;
      case JournalKind.wipeDown:
        return Icons.cleaning_services_outlined;
      case JournalKind.experience:
        return Icons.rate_review_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Set<JournalKind> present = entries.map((JournalEntry e) => e.kind).toSet();
    final List<JournalEntry> shown = filter == null
        ? entries
        : entries.where((JournalEntry e) => e.kind == filter).toList();

    if (entries.isEmpty) {
      return Text(
        'Nothing logged yet. Use the buttons above when something happens.',
        style: TextStyle(fontSize: 15, height: 1.4, color: scheme.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('All'),
                selected: filter == null,
                onSelected: (bool _) => onFilter(null),
              ),
              for (final JournalKind k in JournalKind.values)
                if (present.contains(k))
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(k.label),
                      selected: filter == k,
                      onSelected: (bool _) => onFilter(k),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < shown.length; i++) ...<Widget>[
          if (i == 0 ||
              !_sameDay(shown[i - 1].at, shown[i].at))
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              child: Text(
                formatFlightDate(shown[i].at),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          Card(
            child: ListTile(
              leading: Icon(_icon(shown[i].kind)),
              title: Text(shown[i].title),
              subtitle: Text(
                '${formatFlightTime(shown[i].at)} · ${shown[i].detail}',
              ),
              onTap: () => onOpen(shown[i]),
            ),
          ),
        ],
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
