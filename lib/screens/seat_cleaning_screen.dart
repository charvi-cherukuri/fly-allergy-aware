import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/models/flight.dart';
import 'package:trace_allergy/models/travel.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// Seat wipe-down (FRD 3.2).
///
/// Three things in one place: the case for pre-boarding, a checklist for the
/// wipe itself, and a log of what was actually done.
///
/// **Pop result contract.** The pre-boarding button does not write a
/// [SeatCleaningLog] — asking the airline to let you board early is an
/// accommodation, not a cleaning, and it belongs with the other requests where
/// it can be chased and evidenced. Instead this screen returns
/// `Navigator.pop(context, 'log-preboard')` and the caller is expected to route
/// to the accommodations flow, pre-filling
/// [AccommodationType.preboardToWipe]. Callers that do not handle it lose
/// nothing but the shortcut:
///
/// ```dart
/// final result = await Navigator.of(context).push<String>(
///   MaterialPageRoute<String>(builder: (_) => const SeatCleaningScreen()),
/// );
/// if (result == kPreboardRequest) { /* open the accommodation form */ }
/// ```
class SeatCleaningScreen extends StatefulWidget {
  const SeatCleaningScreen({super.key, required this.flightId});

  /// The flight leg to log against.
  final String flightId;

  @override
  State<SeatCleaningScreen> createState() => _SeatCleaningScreenState();
}

/// The value [SeatCleaningScreen] pops when the user wants to log a
/// pre-boarding request. See the class doc.
const String kPreboardRequest = 'log-preboard';

class _SeatCleaningScreenState extends State<SeatCleaningScreen> {
  final Set<String> _ticked = <String>{};
  CleanedBy _by = CleanedBy.passenger;
  bool _saving = false;

  Future<void> _save(Flight flight) async {
    if (_ticked.isEmpty || _saving) return;
    setState(() => _saving = true);

    // Keep kSeatSurfaces order in the record rather than tick order — the log
    // should read the same way every time.
    final surfaces =
        kSeatSurfaces.where((String s) => _ticked.contains(s)).toList();

    await context.read<AppState>().saveCleaningLog(
          SeatCleaningLog(
            id: _newId(),
            flightId: flight.id,
            cleanedAt: DateTime.now(),
            surfaces: surfaces,
            byWhom: _by,
          ),
        );

    if (!mounted) return;
    setState(() {
      _ticked.clear();
      _saving = false;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'Logged ${surfaces.length} '
          '${surfaces.length == 1 ? 'surface' : 'surfaces'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Flight? found;
    for (final Flight f in app.flights) {
      if (f.id == widget.flightId) found = f;
    }

    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seat wipe-down')),
        body: const Center(child: Text('This flight was removed.')),
      );
    }

    final Flight flight = found;
    final logs = app.cleaningFor(flight.id);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Seat wipe-down')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.flight_takeoff,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${flight.label} · ${flight.route}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SectionTitle('Before you board'),
          const _PreboardCard(),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(kPreboardRequest),
            icon: const Icon(Icons.assignment_turned_in_outlined),
            label: const Text('Log a pre-boarding request'),
          ),
          const SizedBox(height: 8),
          Text(
            'Logged as an accommodation, not a cleaning.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),

          const SectionTitle('Wipe-down checklist'),
          _ChecklistCard(
            ticked: _ticked,
            onToggle: (String surface, bool on) => setState(() {
              if (on) {
                _ticked.add(surface);
              } else {
                _ticked.remove(surface);
              }
            }),
          ),

          const SectionTitle('Who cleaned it'),
          SegmentedButton<CleanedBy>(
            segments: <ButtonSegment<CleanedBy>>[
              for (final c in CleanedBy.values)
                ButtonSegment<CleanedBy>(value: c, label: Text(c.label)),
            ],
            selected: <CleanedBy>{_by},
            showSelectedIcon: false,
            onSelectionChanged: (Set<CleanedBy> s) =>
                setState(() => _by = s.first),
          ),

          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed:
                _ticked.isEmpty || _saving ? null : () => _save(flight),
            icon: const Icon(Icons.check),
            label: Text(
              _ticked.isEmpty
                  ? 'Tick what you cleaned'
                  : 'Log ${_ticked.length} '
                      '${_ticked.length == 1 ? 'surface' : 'surfaces'}',
            ),
          ),

          const SectionTitle('Cleaning log'),
          if (logs.isEmpty)
            const _EmptyLog()
          else
            for (final l in logs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LogCard(log: l),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pre-boarding
// ---------------------------------------------------------------------------

class _PreboardCard extends StatelessWidget {
  const _PreboardCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.cleaning_services_outlined,
                  size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Wiping down beats everything else',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Wipe the tray table, armrests and screen before you sit — two '
            'minutes, and pre-boarding has to be asked for in advance.',
            style: TextStyle(fontSize: 14, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Checklist
// ---------------------------------------------------------------------------

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.ticked, required this.onToggle});

  final Set<String> ticked;
  final void Function(String surface, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < kSeatSurfaces.length; i++) ...<Widget>[
            CheckboxListTile(
              value: ticked.contains(kSeatSurfaces[i]),
              onChanged: (bool? on) => onToggle(kSeatSurfaces[i], on ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                kSeatSurfaces[i],
                style: TextStyle(
                  fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              subtitle: i == 0
                  ? Text(
                      'Highest residue risk — both sides.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : null,
            ),
            if (i < kSeatSurfaces.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});

  final SeatCleaningLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.check_circle_outline_rounded,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cleaned ${_relative(log.cleanedAt)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                log.byWhom.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatDateTime(log.cleanedAt),
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (log.surfaces.isEmpty)
            Text(
              'No surfaces recorded.',
              style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final s in log.surfaces)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(s, style: const TextStyle(fontSize: 14)),
                  ),
              ],
            ),
          if (log.notes.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              log.notes.trim(),
              style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.cleaning_services_outlined,
              size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text(
            'Nothing logged for this flight',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Tick surfaces as you wipe them. If a reaction follows, this is '
            'the only record of the seat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared helpers
// ---------------------------------------------------------------------------

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

String _formatDateTime(DateTime d) {
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $hour:$minute';
}

/// Relative time, written by hand: there is no `intl` dependency and adding one
/// to an offline-only app for this would be a poor trade.
String _relative(DateTime then) {
  final diff = DateTime.now().difference(then);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
  }
  return 'on ${_formatDateTime(then)}';
}

int _idCounter = 0;
String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
