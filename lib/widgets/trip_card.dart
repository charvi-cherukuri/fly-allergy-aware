import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/day_of_travel_screen.dart';
import '../screens/child_card_screen.dart';
import '../screens/flight_experience_screen.dart';

import '../data/countries.dart';
import '../models/flight.dart';
import '../models/profile.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../theme.dart';
import 'travel_format.dart';

/// "In 3 days", "Day 2 of 8", "Ended 12 Mar".
String tripStatusLine(Trip trip, DateTime now) {
  if (trip.isUnderway(now)) {
    final int day = -trip.daysUntil(now) + 1;
    final int length = trip.endsOn.difference(trip.startsOn).inDays + 1;
    return length <= 1 ? 'Today' : 'Day $day of $length';
  }
  if (trip.isUpcoming(now)) {
    final int d = trip.daysUntil(now);
    return d == 1 ? 'Tomorrow' : 'In $d days';
  }
  return 'Ended ${formatShortDate(trip.endsOn)}';
}

/// The names of the people on a trip, in household order.
String travelerNames(Trip trip, List<Profile> profiles) {
  final List<String> names = <String>[
    for (final Profile p in profiles)
      if (trip.travelerIds.contains(p.id)) p.name,
  ];
  return names.isEmpty ? 'Travelers not set' : names.join(', ');
}

/// The large card for the trip that is underway or next.
///
/// The red button is deliberately on the card itself, not behind a tap into
/// the trip: when someone is reacting, the screen they are already looking at
/// has to have the way out on it.
class ActiveTripCard extends StatelessWidget {
  const ActiveTripCard({
    super.key,
    required this.trip,
    required this.onOpen,
    required this.onEmergency,
    this.footer,
  });

  final Trip trip;
  final VoidCallback onOpen;
  final VoidCallback onEmergency;

  /// Extra content under the legs — the quick-log buttons and the language
  /// suggestion live here.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime now = DateTime.now();
    final Country? country = countryFor(trip.destinationCountry);
    final List<Flight> legs = app.flightsFor(trip.id);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    trip.isUnderway(now)
                        ? Icons.luggage_rounded
                        : Icons.flight_takeoff_rounded,
                    size: 17,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    (trip.isUnderway(now) ? 'Current trip' : 'Next trip')
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    tripStatusLine(trip, now),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${country == null ? '' : '${country.flag}  '}${trip.name}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatTripDates(trip.startsOn, trip.endsOn)} · '
                '${travelerNames(trip, app.profiles)}',
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              ),
              if (legs.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                for (final Flight f in legs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.flight_rounded,
                            size: 15, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${f.label}  ${f.route}  ·  '
                            '${formatShortDate(f.departsAt)} '
                            '${formatFlightTime(f.departsAt)}',
                            style: const TextStyle(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: onEmergency,
                  icon: const Icon(Icons.emergency_rounded),
                  label: const Text('Anaphylaxis — get help'),
                ),
              ),
              if (_soonestLeg(legs, now) case final Flight soon) ...<Widget>[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext _) =>
                          DayOfTravelScreen(flightId: soon.id),
                    ),
                  ),
                  icon: const Icon(Icons.record_voice_over_outlined),
                  label: Text(
                    '${_dayWord(soon.departsAt, now)}: what to ask for',
                  ),
                ),
              ],
              if (app.flightAwaitingExperience(trip.id) case final Flight landed) ...<Widget>[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext _) => FlightExperienceScreen(flightId: landed.id),
                    ),
                  ),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text('How was ${landed.label}? Record your flight experience'),
                ),
              ],
              if (app.profiles.any((Profile p) => p.isChild && trip.travelerIds.contains(p.id))) ...<Widget>[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (BuildContext _) => const ChildCardScreen()),
                  ),
                  icon: const Icon(Icons.child_care_rounded),
                  label: const Text('“Please don’t feed my child” card'),
                ),
              ],
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}

/// The leg flying now or departing within 36 hours — when the day-of-travel
/// guide is what the traveler needs next.
Flight? _soonestLeg(List<Flight> legs, DateTime now) {
  for (final Flight f in legs) {
    final bool notOver = f.arrivesAt.isAfter(now);
    final bool soon = f.departsAt.difference(now) <= const Duration(hours: 36);
    if (notOver && soon) return f;
  }
  return null;
}

String _dayWord(DateTime departs, DateTime now) {
  final DateTime d = DateTime(departs.year, departs.month, departs.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  if (!departs.isAfter(now)) return 'Flying now';
  if (d == today) return 'Flying today';
  if (d == today.add(const Duration(days: 1))) return 'Flying tomorrow';
  return 'Flying soon';
}

/// A row in the upcoming or past list.
class TripTile extends StatelessWidget {
  const TripTile({super.key, required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final Country? country = countryFor(trip.destinationCountry);
    final int legs = app.flightsFor(trip.id).length;
    final int logged =
        app.exposuresFor(trip.id).length + app.incidentsFor(trip.id).length +
            app.reactionsFor(trip.id).length;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Text(
          country?.flag ?? '🧳',
          style: const TextStyle(fontSize: 26),
        ),
        title: Text(trip.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${formatTripDates(trip.startsOn, trip.endsOn)}'
          '${legs == 0 ? '' : ' · $legs flight${legs == 1 ? '' : 's'}'}'
          '${logged == 0 ? '' : ' · $logged logged'}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
