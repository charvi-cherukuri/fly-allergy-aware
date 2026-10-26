import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/emergency.dart';
import '../models/flight.dart';
import '../models/profile.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../services/emergency_summary.dart';
import '../theme.dart';
import 'exposure_edit_screen.dart';
import 'incident_report_screen.dart';

/// What emergency mode leaves behind: a summary to hand to paramedics or the
/// emergency department, and the two follow-ups worth doing while it is fresh.
class HandoverScreen extends StatelessWidget {
  const HandoverScreen({super.key, required this.reactionId});

  final String reactionId;

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    ReactionLog? record;
    for (final ReactionLog r in app.reactions) {
      if (r.id == reactionId) record = r;
    }
    if (record == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final ReactionLog r = record;

    Profile person = app.activeProfile;
    for (final Profile p in app.profiles) {
      if (p.id == r.profileId) person = p;
    }
    final Trip? trip = app.tripById(r.tripId);
    Flight? flight;
    for (final Flight f in app.flights) {
      if (f.tripId == r.tripId &&
          !r.occurredAt.isBefore(f.departsAt.subtract(const Duration(minutes: 30))) &&
          !r.occurredAt.isAfter(f.arrivesAt.add(const Duration(minutes: 30)))) {
        flight = f;
      }
    }
    Exposure? cause;
    for (final Exposure e in app.exposures) {
      if (e.id == r.exposureId) cause = e;
    }

    final String text = EmergencySummary.handover(
      profile: person,
      record: r,
      now: DateTime.now(),
      plan: app.defaultActionPlan,
      flight: flight,
      trip: trip,
      cause: cause,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Handover summary'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () async {
              final RenderBox? box = context.findRenderObject() as RenderBox?;
              await Share.share(
                text,
                subject: 'Allergic reaction — ${person.name}',
                sharePositionOrigin: box == null || !box.hasSize
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          Text(
            'Show this to the paramedics or the emergency department.',
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 16, height: 1.45),
              ),
            ),
          ),
          if (trip != null) ...<Widget>[
            const SectionTitle('While it is fresh'),
            if (r.exposureId == null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.back_hand_outlined),
                  title: const Text('Log what caused it'),
                  subtitle: const Text('The exposure, linked to this reaction'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final Exposure? saved = await Navigator.of(context).push<Exposure>(
                      MaterialPageRoute<Exposure>(
                        builder: (BuildContext _) => ExposureEditScreen(
                          tripId: trip.id,
                          draft: Exposure(
                            id: '',
                            tripId: trip.id,
                            profileId: r.profileId,
                            occurredAt: r.occurredAt,
                            outcome: ExposureOutcome.symptoms,
                            reactionId: r.id,
                          ),
                        ),
                      ),
                    );
                    if (saved == null) return;
                    r.exposureId = saved.id;
                    await app.saveReaction(r);
                  },
                ),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('Write an incident report'),
                subtitle: const Text('For the airline, restaurant or hotel'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext _) => IncidentReportScreen(
                      flightId: flight?.id ?? '',
                      tripId: trip.id,
                      reactionId: r.id,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
