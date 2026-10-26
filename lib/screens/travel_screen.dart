import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'day_of_travel_screen.dart';

import '../models/flight.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../services/language_suggestions.dart';
import '../theme.dart';
import '../widgets/language_suggestion_card.dart';
import '../widgets/trip_actions.dart';
import '../widgets/trip_card.dart';
import 'chef_card_screen.dart';
import 'emergency_mode_screen.dart';
import 'trip_detail_screen.dart';
import 'trip_edit_screen.dart';

/// The Travel tab: a journal of trips, with the way into an emergency on the
/// trip you are on.
///
/// It records rather than predicts. An earlier version scored airlines from
/// their published policies; those policies are vague, change without notice
/// and are applied differently by every crew, so a number built on them read
/// as more certain than anything behind it. What a traveler can rely on is
/// what they asked for, what happened, and what they did about it — so that
/// is what this tab keeps.
class TravelScreen extends StatelessWidget {
  const TravelScreen({super.key});

  Future<void> _addTrip(BuildContext context) async {
    final NavigatorState nav = Navigator.of(context);
    final Trip? trip = await nav.push<Trip>(
      MaterialPageRoute<Trip>(builder: (BuildContext _) => const TripEditScreen()),
    );
    // Straight into the new trip, where adding its flights and the language
    // suggestion are waiting.
    if (trip == null) return;
    await nav.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => TripDetailScreen(tripId: trip.id),
      ),
    );
  }

  void _open(BuildContext context, Trip trip) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => TripDetailScreen(tripId: trip.id),
      ),
    );
  }

  void _emergency(BuildContext context, Trip trip) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => EmergencyModeScreen(tripId: trip.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final DateTime now = DateTime.now();
    final Trip? active = app.activeTrip(now);
    final List<Trip> upcoming = app.trips
        .where((Trip t) => t.id != active?.id && !t.isPast(now))
        .toList();
    final List<Trip> past = app.trips
        .where((Trip t) => t.id != active?.id && t.isPast(now))
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel'),
        actions: <Widget>[
          IconButton(
            tooltip: 'At the airport and on board',
            onPressed: () {
              // The next leg of the current trip that has not landed, if
              // any; otherwise the general guide with blanks to fill aloud.
              final Trip? t = app.activeTrip();
              String? legId;
              for (final Flight f in t == null ? const <Flight>[] : app.flightsFor(t.id)) {
                if (f.arrivesAt.isAfter(DateTime.now())) {
                  legId = f.id;
                  break;
                }
              }
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => DayOfTravelScreen(flightId: legId),
                ),
              );
            },
            icon: const Icon(Icons.record_voice_over_outlined),
          ),
          IconButton(
            tooltip: 'Chef card',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ChefCardScreen()),
            ),
            icon: const Icon(Icons.translate_rounded),
          ),
        ],
      ),
      floatingActionButton: app.trips.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addTrip(context),
              icon: const Icon(Icons.add),
              label: const Text('Add trip'),
            ),
      body: app.trips.isEmpty
          ? _EmptyTravel(onAdd: () => _addTrip(context))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                if (active != null) ...<Widget>[
                  ActiveTripCard(
                    trip: active,
                    onOpen: () => _open(context, active),
                    onEmergency: () => _emergency(context, active),
                    footer: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: QuickLogRow(trip: active),
                    ),
                  ),
                  if (LanguageSuggestions.isTimely(active, now)) ...<Widget>[
                    const SizedBox(height: 8),
                    LanguageSuggestionCard(trip: active),
                  ],
                ],
                if (upcoming.isNotEmpty) ...<Widget>[
                  const SectionTitle('Coming up'),
                  for (final Trip t in upcoming)
                    TripTile(trip: t, onTap: () => _open(context, t)),
                ],
                if (past.isNotEmpty) ...<Widget>[
                  const SectionTitle('Past trips'),
                  for (final Trip t in past)
                    TripTile(trip: t, onTap: () => _open(context, t)),
                ],
              ],
            ),
    );
  }
}

class _EmptyTravel extends StatelessWidget {
  const _EmptyTravel({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.luggage_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Travel with your allergy plan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your flights, keep track of what happens, and get help fast '
              'if a reaction starts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add your first trip'),
            ),
          ],
        ),
      ),
    );
  }
}
