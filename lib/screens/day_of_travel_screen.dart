import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/safety_copy.dart';
import 'child_card_screen.dart';
import 'medical_kits_screen.dart';

import '../data/airline_policies.dart';
import '../data/day_of_travel.dart';
import '../data/request_guides.dart';
import '../models/allergen.dart';
import '../models/custom_allergen.dart';
import '../models/emergency.dart';
import '../models/flight.dart';
import '../models/profile.dart';
import '../models/request_guide.dart';
import '../models/travel.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/trip_actions.dart';
import 'crew_card_screen.dart';
import 'how_to_request_screen.dart';
import 'incident_report_screen.dart';

/// What to ask for at check-in, at the gate and on board — who to ask, when,
/// and the exact words — with each ask logged as a request in one tap.
///
/// Opened for a flight, the words carry the seat, the flight number and the
/// travelers' allergens, and every ask can be recorded against that flight.
/// Opened without one, it is the same guide with blanks to fill in aloud.
class DayOfTravelScreen extends StatelessWidget {
  const DayOfTravelScreen({super.key, this.flightId});

  final String? flightId;

  /// The values every script is filled with, from the flight's trip.
  static DayScriptValues valuesFor(AppState app, Flight? flight) {
    final Trip? trip = app.tripById(flight?.tripId);
    final List<Profile> travelers = app.profiles
        .where((Profile p) => trip?.travelerIds.contains(p.id) ?? false)
        .toList();
    final List<Profile> allergic = (travelers.isEmpty
            ? <Profile>[app.activeProfile]
            : travelers)
        .where((Profile p) => !p.isEmpty)
        .toList();

    final List<String> allergens = <String>[];
    for (final Profile p in allergic) {
      for (final Allergen a in p.sorted) {
        final String l = a.label.toLowerCase();
        if (!allergens.contains(l)) allergens.add(l);
      }
      for (final CustomAllergen c in p.customAllergens) {
        final String l = c.name.toLowerCase();
        if (!allergens.contains(l)) allergens.add(l);
      }
    }

    String? names;
    bool plural = false;
    if (allergic.length == 1) {
      final String n = allergic.single.name.trim();
      // A profile still called "Me" is the person speaking.
      if (n.toLowerCase() == 'me') {
        names = 'I';
        plural = true;
      } else {
        names = n;
      }
    } else if (allergic.length > 1) {
      names = _joinAnd(allergic.map((Profile p) => p.name.trim()).toList());
      plural = true;
    }

    final List<String> pens = app.epiPens
        .where((EpiPen p) => !p.isExpired && p.location.trim().isNotEmpty)
        .map((EpiPen p) => p.location.trim())
        .toSet()
        .toList();

    return DayScriptValues(
      name: names,
      allergens: allergens.isEmpty ? null : _joinAnd(allergens),
      seat: flight?.seat,
      flight: flight?.label,
      pen: pens.isEmpty
          ? null
          : 'in ${_joinAnd(pens.map(_lowerFirst).toList())}',
      plural: plural,
    );
  }

  static String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  static String _joinAnd(List<String> items) {
    if (items.length <= 1) return items.join();
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    Flight? flight;
    for (final Flight f in app.flights) {
      if (f.id == flightId) flight = f;
    }
    final DayScriptValues values = valuesFor(app, flight);
    final RequestGuide? guide = flight == null ? null : guideFor(flight.airlineIata);
    final String airline =
        flight == null ? '' : (policyFor(flight.airlineIata)?.name ?? flight.airlineIata);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Trip? trip = app.tripById(flight?.tripId);

    return Scaffold(
      appBar: AppBar(title: const Text('At the airport and on board')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          if (flight != null)
            Text(
              '${flight.label}  ${flight.route}'
              '${flight.seat.trim().isEmpty ? '' : ' · Seat ${flight.seat.trim()}'}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Most airlines only help in person on the day, even if you asked '
              'before. Ask at each step below. Ask early and politely.',
              style: TextStyle(fontSize: 15.5, height: 1.4),
            ),
          ),
          const SectionTitle('Before you fly'),
          for (final SafetyTip tip in kFlightPreventionTips)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.check_circle_outline_rounded, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '${tip.advice} ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: tip.reason),
                        ],
                      ),
                      style: const TextStyle(fontSize: 15.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.medical_services_outlined),
                  title: const Text('Medical kits on planes'),
                  subtitle: const Text('What kits carry, and which airlines have auto-injectors'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (BuildContext _) => const MedicalKitsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.child_care_rounded),
                  title: const Text('“Please don’t feed my child” card'),
                  subtitle: const Text('Show it to other passengers or staff'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (BuildContext _) => const ChildCardScreen()),
                  ),
                ),
              ],
            ),
          ),
          if (flight != null) ...<Widget>[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(guide == null
                    ? 'How to ask an airline before you fly'
                    : 'How to ask $airline before you fly'),
                subtitle: Text(guide == null
                    ? 'Tips that work for most airlines'
                    : 'Who to contact, and when'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext _) => HowToRequestScreen(
                      iata: flight!.airlineIata,
                      flightId: flight.id,
                    ),
                  ),
                ),
              ),
            ),
          ],

          for (final DayStage stage in kDayOfTravel) ...<Widget>[
            SectionTitle(stage.title),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                '${stage.who}. ${stage.when}.',
                style: TextStyle(fontSize: 15, height: 1.35, color: scheme.onSurfaceVariant),
              ),
            ),
            for (final DayAsk ask in stage.asks)
              _AskCard(
                ask: ask,
                stage: stage,
                flight: flight,
                script: fillDayScript(ask.script, values),
              ),
            for (final String tip in stage.tips)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.lightbulb_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tip, style: const TextStyle(fontSize: 15, height: 1.4)),
                    ),
                  ],
                ),
              ),
          ],

          if (flight != null) ...<Widget>[
            const SectionTitle('Also'),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Show to crew'),
                    subtitle: const Text('Your allergy, seat and requests on one screen'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) => CrewCardScreen(flightId: flight!.id),
                      ),
                    ),
                  ),
                  if (trip != null) ...<Widget>[
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.back_hand_outlined),
                      title: const Text('Log an exposure'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => logExposure(context, trip),
                    ),
                  ],
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.report_outlined),
                    title: const Text('Something went wrong'),
                    subtitle: const Text('Write it down while you remember'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) =>
                            IncidentReportScreen(flightId: flight!.id, tripId: trip?.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            kMedicalNoteShort,
            style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AskCard extends StatelessWidget {
  const _AskCard({
    required this.ask,
    required this.stage,
    required this.flight,
    required this.script,
  });

  final DayAsk ask;
  final DayStage stage;
  final Flight? flight;
  final String script;

  /// The request already logged for this ask on this flight, at this stage.
  AccommodationRequest? _logged(AppState app) {
    final Flight? f = flight;
    if (f == null) return null;
    for (final AccommodationRequest r in app.requestsFor(f.id)) {
      if (r.type == ask.type && r.channel == stage.channel) return r;
    }
    return null;
  }

  Future<void> _logAsked(BuildContext context) async {
    final AppState app = context.read<AppState>();
    await app.saveRequest(AccommodationRequest(
      id: app.newId(),
      flightId: flight!.id,
      type: ask.type,
      requestedAt: DateTime.now(),
      channel: stage.channel,
      responseNotes: 'Asked in person: “$script”',
    ));
  }

  Future<void> _setStatus(
    BuildContext context,
    AccommodationRequest r,
    RequestStatus s,
  ) async {
    r
      ..status = s
      ..resolvedAt = DateTime.now();
    await context.read<AppState>().saveRequest(r);
  }

  void _show(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext _) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            title: Text(stage.who),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              script,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 26,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AccommodationRequest? logged = _logged(app);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(ask.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(ask.why, style: TextStyle(fontSize: 14.5, height: 1.35, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('“$script”', style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: script));
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
                TextButton.icon(
                  onPressed: () => _show(context),
                  icon: const Icon(Icons.fullscreen_rounded, size: 20),
                  label: const Text('Show'),
                ),
                const Spacer(),
                if (flight != null && logged == null)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () => _logAsked(context),
                    child: const Text('I asked'),
                  ),
              ],
            ),
            if (logged != null) ...<Widget>[
              const Divider(height: 16),
              Text(
                'Asked · ${logged.status.label}',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final (RequestStatus s, String label) in <(RequestStatus, String)>[
                    (RequestStatus.confirmed, 'They agreed'),
                    (RequestStatus.honoured, 'It was done'),
                    (RequestStatus.refused, 'Refused'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: logged.status == s,
                      onSelected: (bool _) => _setStatus(context, logged, s),
                    ),
                ],
              ),
              if (logged.status.warrantsReport)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) => IncidentReportScreen(
                          flightId: flight!.id,
                          requestId: logged.id,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.report_outlined, size: 18),
                    label: const Text('Write it up as an incident'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
