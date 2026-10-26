import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/voice_fill.dart';
import '../widgets/voice_input.dart';

import 'package:trace_allergy/models/emergency.dart';
import 'package:trace_allergy/models/flight.dart';
import 'package:trace_allergy/models/travel.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/services/incident_composer.dart';
import 'package:trace_allergy/theme.dart';

/// Compiles a complaint out of the records already on the device (FRD 2.3).
///
/// The app assembles and hands over. It does not send. A complaint filed in
/// someone's name is theirs to make, and an app that quietly transmits one on
/// their behalf has taken a decision that was never its to take — so there is
/// no auto-send path here, and the screen says so where the user can see it.
///
/// The live preview is not decoration. It is the mechanism by which the user
/// stays the author: they see the exact text before it leaves the device, and
/// anything they disagree with they can change.
class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({
    super.key,
    required this.flightId,
    this.requestId,
    this.reactionId,
    this.tripId,
    this.existing,
  });

  /// Empty for an incident that did not happen on a flight — a restaurant, a
  /// hotel — which is written up for the venue rather than an airline.
  final String flightId;

  /// The trip the report belongs to.
  final String? tripId;

  /// A saved report being reopened. Its text is the user's, so nothing is
  /// redrafted over it.
  final IncidentReport? existing;

  /// Pre-attached when the user arrives from a failed accommodation request.
  final String? requestId;

  final String? reactionId;

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  late final String _reportId = widget.existing?.id ?? _newId();
  late final DateTime _createdAt = widget.existing?.createdAt ?? DateTime.now();

  bool get _onFlight => widget.flightId.isNotEmpty;
  final TextEditingController _narrative = TextEditingController();
  final Set<String> _requestIds = <String>{};

  late IncidentKind _kind;
  String? _reactionId;
  FilingTarget _target = FilingTarget.airline;
  DateTime? _filedAt;
  bool _saved = false;
  bool _seeded = false;

  /// Once the user has touched the narrative it is theirs. Re-drafting over
  /// their words because they ticked another checkbox would be unforgivable.
  bool _narrativeEdited = false;

  @override
  void initState() {
    super.initState();
    final IncidentReport? existing = widget.existing;
    if (existing != null) {
      _kind = existing.kind;
      _reactionId = existing.reactionId;
      _requestIds.addAll(existing.requestIds);
      _target = existing.filedWith;
      _filedAt = existing.filedAt;
      _saved = true;
      _narrative.text = existing.narrative;
      _narrativeEdited = true;
      _seeded = true;
    } else {
      _kind = !_onFlight
          ? IncidentKind.venueFailure
          : widget.reactionId != null
              ? IncidentKind.allergicReaction
              : IncidentKind.accommodationFailure;
      _reactionId = widget.reactionId;
      if (widget.requestId != null) _requestIds.add(widget.requestId!);
    }
    _narrative.addListener(() {
      if (!_narrativeEdited && _narrative.text != _lastDraft) {
        _narrativeEdited = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tripId ??= widget.tripId ?? widget.existing?.tripId;
    if (_tripId == null) {
      for (final f in context.read<AppState>().flights) {
        if (f.id == widget.flightId) _tripId = f.tripId;
      }
    }
    if (_seeded) return;
    _seeded = true;
    _redraft();
  }

  @override
  void dispose() {
    _narrative.dispose();
    super.dispose();
  }

  String _lastDraft = '';

  // ------------------------------------------------------------------- model

  Flight? _flightIn(AppState app) {
    for (final f in app.flights) {
      if (f.id == widget.flightId) return f;
    }
    return null;
  }

  List<AccommodationRequest> _attachedRequests(
    List<AccommodationRequest> all,
  ) {
    final list = all.where((r) => _requestIds.contains(r.id)).toList()
      ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    return list;
  }

  ReactionLog? _attachedReaction(List<ReactionLog> all) {
    final id = _reactionId;
    if (id == null) return null;
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  IncidentReport _buildReport() => IncidentReport(
        id: _reportId,
        flightId: widget.flightId,
        createdAt: _createdAt,
        kind: _kind,
        narrative: _narrative.text.trim(),
        requestIds: _requestIds.toList(),
        reactionId: _reactionId,
        filedWith: _onFlight ? _target : FilingTarget.airline,
        filedAt: _filedAt,
        tripId: _tripId,
      );

  /// Resolved once, outside build: a report filed from a flight belongs to
  /// that flight's trip.
  String? _tripId;

  String _compose(AppState app) => IncidentComposer.compose(
        report: _buildReport(),
        flight: _flightIn(app),
        profile: app.activeProfile,
        requests: _attachedRequests(app.requestsFor(widget.flightId)),
        reaction: _attachedReaction(app.reactions),
      );

  // ----------------------------------------------------------------- drafting

  /// Writes a first draft into the narrative field from whatever is attached.
  /// Silent when the user has already edited it.
  void _redraft({bool force = false}) {
    if (_narrativeEdited && !force) return;
    final app = context.read<AppState>();
    final draft = _draftNarrative(
      kind: _kind,
      flight: _flightIn(app),
      requests: _attachedRequests(app.requestsFor(widget.flightId)),
      reaction: _attachedReaction(app.reactions),
    );
    _lastDraft = draft;
    _narrative.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    if (force) _narrativeEdited = false;
  }

  /// Sets the kind from what was said and puts the words into the account,
  /// after anything already written there.
  Future<void> _applyVoice(String text) async {
    final IncidentKind kind = await VoiceFill.incidentKind(text, onFlight: _onFlight);
    if (!mounted) return;
    setState(() {
      if (!_narrativeEdited) {
        _kind = kind;
        _redraft();
      }
      final String current = _narrative.text.trim();
      _narrative.text = current.isEmpty ? text : '$current\n\n$text';
      _narrativeEdited = true;
    });
  }

  // ------------------------------------------------------------------ actions

  Future<void> _save() async {
    final app = context.read<AppState>();
    await app.saveIncident(_buildReport());
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Report saved on this device')),
    );
  }

  Future<void> _copy() async {
    final text = _compose(context.read<AppState>());
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Complaint copied')),
    );
  }

  Future<void> _share() async {
    final app = context.read<AppState>();
    final text = _compose(app);
    final subject =
        IncidentComposer.subjectLine(_buildReport(), _flightIn(app));

    // The iPad share sheet needs somewhere to point, or the call fails.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Share.share(
        text,
        subject: subject,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the share sheet.')),
      );
    }
  }

  Future<void> _openDot() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final opened = await launchUrl(
        Uri.parse(IncidentComposer.dotComplaintUrl()),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Could not open the DOT form.')),
        );
      }
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the DOT form.')),
      );
    }
  }

  Future<void> _markSent() async {
    final app = context.read<AppState>();
    setState(() => _filedAt = DateTime.now());
    await app.saveIncident(_buildReport());
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Marked as sent')),
    );
  }

  Future<void> _unmarkSent() async {
    final app = context.read<AppState>();
    setState(() => _filedAt = null);
    await app.saveIncident(_buildReport());
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final requests = app.requestsFor(widget.flightId);
    final reactions = app.reactions
        .where((ReactionLog r) => r.profileId == app.activeProfile.id)
        .toList();
    final flight = _flightIn(app);
    final preview = _compose(app);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident report'),
        actions: <Widget>[
          VoiceButton(
            title: 'Say what happened',
            hint: 'The buffer zone was confirmed on the phone but the crew '
                'said they had no record of it',
            onTranscript: _applyVoice,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          if (flight != null) _FlightLine(flight: flight),
          const SizedBox(height: 12),
          const _HandsOverNotice(),

          const SectionTitle('What happened'),
          DropdownButtonFormField<IncidentKind>(
            initialValue: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kind of incident'),
            items: <DropdownMenuItem<IncidentKind>>[
              for (final k in IncidentKind.values)
                if (_onFlight || !k.concernsFlight)
                DropdownMenuItem<IncidentKind>(
                  value: k,
                  child: Text(k.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (IncidentKind? v) {
              if (v == null) return;
              setState(() => _kind = v);
              _redraft();
            },
          ),

          if (_onFlight) const SectionTitle('Attach requests'),
          if (!_onFlight)
            const SizedBox.shrink()
          else if (requests.isEmpty)
            _Muted(
              'None logged for this flight. The complaint will rest on your '
              'account alone.',
            )
          else
            for (final r in requests)
              _RequestCheck(
                request: r,
                selected: _requestIds.contains(r.id),
                onChanged: (bool on) {
                  setState(() {
                    if (on) {
                      _requestIds.add(r.id);
                    } else {
                      _requestIds.remove(r.id);
                    }
                  });
                  _redraft();
                },
              ),

          const SectionTitle('Attach a reaction'),
          if (reactions.isEmpty)
            _Muted('Nothing in the reaction log.')
          else ...<Widget>[
            _ReactionChoice(
              label: 'No reaction attached',
              detail: 'Accommodation only.',
              selected: _reactionId == null,
              onTap: () {
                setState(() => _reactionId = null);
                _redraft();
              },
            ),
            for (final r in reactions)
              _ReactionChoice(
                label: IncidentComposer.formatDateTime(r.occurredAt),
                detail: r.symptoms.isEmpty
                    ? 'No symptoms recorded'
                    : r.symptoms.join(', '),
                selected: _reactionId == r.id,
                onTap: () {
                  setState(() => _reactionId = r.id);
                  _redraft();
                },
              ),
          ],

          SectionTitle(
            'Your account',
            trailing: TextButton(
              onPressed: () => setState(() => _redraft(force: true)),
              child: const Text('Reset draft'),
            ),
          ),
          Text(
            'Drafted from what you attached. Edit it.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _narrative,
            minLines: 5,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (String _) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'What was asked, what was agreed, what happened.',
              hintMaxLines: 2,
            ),
          ),

          if (_onFlight) ...<Widget>[
            const SectionTitle('Filing with'),
            _TargetSelector(
              target: _target,
              onChanged: (FilingTarget v) => setState(() => _target = v),
            ),
            const SizedBox(height: 10),
            _Muted(_targetNote(_target)),
          ],

          const SectionTitle('The complaint'),
          _Preview(text: preview),

          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy to clipboard'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share'),
          ),
          if (_onFlight && _target != FilingTarget.airline) ...<Widget>[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openDot,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open DOT complaint form'),
            ),
          ],

          const SectionTitle('Keep it'),
          OutlinedButton.icon(
            onPressed: _save,
            icon: Icon(
              _saved ? Icons.check_rounded : Icons.save_outlined,
            ),
            label: Text(_saved ? 'Saved on this device' : 'Save report'),
          ),
          const SizedBox(height: 10),
          if (_filedAt == null)
            OutlinedButton.icon(
              onPressed: _markSent,
              icon: const Icon(Icons.outgoing_mail),
              label: const Text('I have sent this'),
            )
          else
            Row(
              children: <Widget>[
                Icon(Icons.check_circle_outline_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Marked as sent on '
                    '${IncidentComposer.formatDateTime(_filedAt!)}.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _unmarkSent,
                  child: const Text('Undo'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _FlightLine extends StatelessWidget {
  const _FlightLine({required this.flight});

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
            '${IncidentComposer.formatDate(flight.departsAt)}',
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

/// Said plainly, near the top, before anyone starts typing. The app compiles
/// and hands over; the passenger reviews and sends.
class _HandsOverNotice extends StatelessWidget {
  const _HandsOverNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.drafts_outlined, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nothing leaves this device. The app drafts; you read it and '
              'file it yourself.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: scheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCheck extends StatelessWidget {
  const _RequestCheck({
    required this.request,
    required this.selected,
    required this.onChanged,
  });

  final AccommodationRequest request;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = request.status.warrantsReport;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = failed
        ? (dark ? TraceColors.unsafeDark : TraceColors.unsafe)
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      request.type.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${request.status.label} · ${request.channel.label} · '
                      '${IncidentComposer.formatDate(request.requestedAt)}',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: failed ? FontWeight.w600 : FontWeight.w400,
                        color: accent,
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

class _ReactionChoice extends StatelessWidget {
  const _ReactionChoice({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
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
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
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

class _TargetSelector extends StatelessWidget {
  const _TargetSelector({required this.target, required this.onChanged});

  final FilingTarget target;
  final ValueChanged<FilingTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FilingTarget>(
      showSelectedIcon: false,
      segments: const <ButtonSegment<FilingTarget>>[
        ButtonSegment<FilingTarget>(
          value: FilingTarget.airline,
          label: Text('Airline'),
        ),
        ButtonSegment<FilingTarget>(
          value: FilingTarget.dot,
          label: Text('US DOT'),
        ),
        ButtonSegment<FilingTarget>(
          value: FilingTarget.both,
          label: Text('Both'),
        ),
      ],
      selected: <FilingTarget>{target},
      onSelectionChanged: (Set<FilingTarget> s) {
        if (s.isEmpty) return;
        onChanged(s.first);
      },
    );
  }
}

/// The composed text, monospaced and read-only, so what the user reads is
/// character-for-character what they will paste.
class _Preview extends StatelessWidget {
  const _Preview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 360),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: const <String>['Menlo', 'Courier New'],
            fontSize: 14,
            height: 1.45,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.4,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Copy and drafting
// ---------------------------------------------------------------------------

String _targetNote(FilingTarget target) {
  switch (target) {
    case FilingTarget.airline:
      return 'Start here. A regulator will ask whether you contacted the '
          'carrier.';
    case FilingTarget.dot:
      return 'US carriers, and flights to, from or within the US. Anything '
          'else goes to that country\'s own regulator.';
    case FilingTarget.both:
      return 'The airline gets the complaint, the DOT a copy. The DOT covers '
          'US carriers and flights only.';
  }
}

/// A first draft in plain, factual sentences. It exists so the user is editing
/// something rather than facing an empty box at the end of a bad day.
String _draftNarrative({
  required IncidentKind kind,
  required Flight? flight,
  required List<AccommodationRequest> requests,
  required ReactionLog? reaction,
}) {
  final b = StringBuffer();
  final flightLabel = flight == null
      ? 'this flight'
      : '${flight.airlineIata}${flight.flightNumber} from ${flight.origin} '
          'to ${flight.destination}';
  final dateLabel = flight == null
      ? ''
      : ' on ${IncidentComposer.formatDate(flight.departsAt)}';

  final confirmed = requests
      .where((r) => r.status == RequestStatus.notHonoured)
      .toList();
  final refused =
      requests.where((r) => r.status == RequestStatus.refused).toList();

  if (confirmed.isNotEmpty) {
    for (final r in confirmed) {
      b.writeln(
        'I asked for ${_lower(r.type.label)} by '
        '${_lower(r.channel.label)} on '
        '${IncidentComposer.formatDate(r.requestedAt)}'
        '${r.reference.trim().isEmpty ? '' : ' (reference ${r.reference.trim()})'}'
        '${r.agentName.trim().isEmpty ? '' : ', and spoke to ${r.agentName.trim()}'}'
        '. The airline confirmed it. On $flightLabel$dateLabel it was not '
        'provided.',
      );
      b.writeln();
    }
  }

  if (refused.isNotEmpty) {
    for (final r in refused) {
      b.writeln(
        'I asked for ${_lower(r.type.label)} by '
        '${_lower(r.channel.label)} on '
        '${IncidentComposer.formatDate(r.requestedAt)} and the request was '
        'refused.'
        '${r.responseNotes.trim().isEmpty ? '' : ' I was told: ${r.responseNotes.trim()}'}',
      );
      b.writeln();
    }
  }

  if (confirmed.isEmpty && refused.isEmpty) {
    switch (kind) {
      case IncidentKind.accommodationFailure:
        b
          ..writeln(
            'On $flightLabel$dateLabel, an accommodation I had arranged in '
            'advance was not provided.',
          )
          ..writeln();
      case IncidentKind.allergicReaction:
        b
          ..writeln('On $flightLabel$dateLabel I had an allergic reaction on '
              'board.')
          ..writeln();
      case IncidentKind.refusedBoarding:
        b
          ..writeln(
            'On $flightLabel$dateLabel I was refused boarding or refused the '
            'seating I had arranged.',
          )
          ..writeln();
      case IncidentKind.crewConduct:
        b
          ..writeln(
            'On $flightLabel$dateLabel the crew\'s handling of my allergy '
            'fell short of what I had been told to expect.',
          )
          ..writeln();
      case IncidentKind.venueFailure:
        b
          ..writeln(
            'Staff did not act on the allergy I had told them about.',
          )
          ..writeln();
      case IncidentKind.other:
        b
          ..writeln('The following happened$dateLabel.')
          ..writeln();
    }
  }

  if (reaction != null) {
    b
      ..writeln(
        'At ${IncidentComposer.formatTime(reaction.occurredAt)} on '
        '${IncidentComposer.formatDate(reaction.occurredAt)} I recorded '
        '${reaction.symptoms.isEmpty ? 'symptoms' : _lower(reaction.symptoms.join(', '))}.'
        '${reaction.epiUsed ? ' I used my epinephrine auto-injector.' : ''}'
        '${reaction.soughtCare ? ' I sought medical care.' : ''}',
      )
      ..writeln();
  }

  b.write(
    'Add anything else here: what you were told, and by whom.',
  );
  return b.toString().trim();
}

String _lower(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

int _idCounter = 0;
String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
