import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flight.dart';
import '../models/profile.dart';
import '../models/trip.dart';
import '../screens/exposure_edit_screen.dart';
import '../screens/incident_report_screen.dart';
import '../screens/reaction_log_screen.dart';
import '../services/app_state.dart';

// The three things a traveler logs, shared by the trip card on the Travel tab
// and the trip screen so both behave identically.

Future<void> logExposure(BuildContext context, Trip trip, {Exposure? draft}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) =>
          ExposureEditScreen(tripId: trip.id, draft: draft),
    ),
  );
}

/// Asks who it happened to when more than one person is on the trip.
Future<void> logReaction(BuildContext context, Trip trip) async {
  final String? profileId = await pickTraveler(context, trip);
  if (profileId == null || !context.mounted) return;
  await showReactionForm(context, profileId: profileId, tripId: trip.id);
}

/// Asks which flight it was on — or none, for a hotel or restaurant — when
/// the trip has flights, then opens the report.
Future<void> logIncident(BuildContext context, Trip trip) async {
  final AppState app = context.read<AppState>();
  final List<Flight> legs = app.flightsFor(trip.id);
  String flightId = '';

  if (legs.isNotEmpty) {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Where did it happen?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            for (final Flight f in legs)
              ListTile(
                leading: const Icon(Icons.flight_rounded),
                title: Text('${f.label}  ${f.route}'),
                onTap: () => Navigator.of(sheetContext).pop(f.id),
              ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Not on a flight'),
              subtitle: const Text('A restaurant, hotel or anywhere else'),
              onTap: () => Navigator.of(sheetContext).pop(''),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    flightId = picked;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) =>
          IncidentReportScreen(flightId: flightId, tripId: trip.id),
    ),
  );
}

/// The person something happened to. Returns immediately when there is only
/// one candidate; null when the user backs out.
Future<String?> pickTraveler(BuildContext context, Trip trip) async {
  final AppState app = context.read<AppState>();
  final List<Profile> picked =
      app.profiles.where((Profile p) => trip.travelerIds.contains(p.id)).toList();
  final List<Profile> people = picked.isEmpty ? app.profiles : picked;
  if (people.length == 1) return people.single.id;

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Who is it for?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          for (final Profile p in people)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(p.name),
              subtitle: Text(p.summary),
              onTap: () => Navigator.of(sheetContext).pop(p.id),
            ),
        ],
      ),
    ),
  );
}

/// The three quick-log buttons, in one row.
class QuickLogRow extends StatelessWidget {
  const QuickLogRow({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            ),
            onPressed: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 20),
                const SizedBox(height: 3),
                Text(label, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        );

    return Row(
      children: <Widget>[
        button(Icons.back_hand_outlined, 'Exposure', () => logExposure(context, trip)),
        const SizedBox(width: 8),
        button(Icons.healing_outlined, 'Reaction', () => logReaction(context, trip)),
        const SizedBox(width: 8),
        button(Icons.report_outlined, 'Incident', () => logIncident(context, trip)),
      ],
    );
  }
}
