import 'dart:async';
import '../data/safety_copy.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/airline_policies.dart';
import '../data/chef_card_translations.dart';
import '../data/countries.dart';
import '../data/emergency_phrases.dart';
import '../data/emk_locations.dart';
import '../models/emergency.dart';
import '../models/flight.dart';
import '../models/profile.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../services/emergency_actions.dart';
import '../services/emergency_summary.dart';
import '../services/speech.dart';
import '../services/voice_parser.dart';
import '../theme.dart';
import '../widgets/travel_format.dart';
import 'clinical_guidance_screen.dart';
import 'handover_screen.dart';
import 'reaction_log_screen.dart';

/// Emergency mode: one screen for the minutes when someone is reacting.
///
/// In the order the minutes go: epinephrine and when it was given, getting
/// help (the crew and the medical kit when on a plane, the local ambulance
/// number on the ground), the people to tell, guidance for whoever is helping,
/// and a running note of what is happening.
///
/// Everything is saved as it happens — the first dose, every note, every call
/// — into one reaction record, so nothing depends on reaching the end of the
/// screen. Phones get dropped, locked and handed to paramedics.
///
/// It records and it relays. It does not judge symptoms or advise treatment:
/// that comes from the action plan and the guidance screen, both one tap away.
class EmergencyModeScreen extends StatefulWidget {
  const EmergencyModeScreen({super.key, this.tripId});

  /// The trip it started from, when it started from one.
  final String? tripId;

  @override
  State<EmergencyModeScreen> createState() => _EmergencyModeScreenState();
}

/// The manufacturer and guideline window for considering a second dose.
const Duration kSecondDoseFrom = Duration(minutes: 5);
const Duration kSecondDoseTo = Duration(minutes: 15);

class _EmergencyModeScreenState extends State<EmergencyModeScreen>
    with WidgetsBindingObserver {
  final DateTime _startedAt = DateTime.now();
  final TextEditingController _note = TextEditingController();
  late String _profileId;
  final List<DateTime> _doses = <DateTime>[];
  final List<TimelineNote> _notes = <TimelineNote>[];
  String? _recordId;
  bool _calledForHelp = false;
  late final Timer _ticker;

  /// Voice: listening starts by itself when the screen opens, because the
  /// person using it may have both hands busy. [_wantVoice] is the user's
  /// switch; [_listening] is whether the microphone is actually live, which a
  /// phone call interrupts.
  bool _wantVoice = true;
  late final AppState _app;
  bool _foreground = true;
  bool _startingVoice = false;

  bool get _voiceAllowed =>
      mounted && _foreground && !_app.isLocked && _wantVoice;

  void _lockChanged() {
    if (_app.isLocked) {
      _callAskedAt = null;
      SpeechService.instance.stop();
      if (mounted && _listening) setState(() => _listening = false);
    } else if (_voiceAllowed && !_listening) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startVoice());
    }
  }

  bool _listening = false;
  bool _voiceAvailable = false;
  String _heard = '';
  StreamSubscription<SpeechEvent>? _speech;

  /// Set when "call for help" was said: the call waits for "yes, call" or a
  /// tap, so speech alone can never place one by accident.
  DateTime? _callAskedAt;

  @override
  void initState() {
    super.initState();
    final AppState app = context.read<AppState>();
    _app = app;
    _app.addListener(_lockChanged);
    final List<Profile> people = _people(app);
    _profileId = people.any((Profile p) => p.id == app.activeProfile.id)
        ? app.activeProfile.id
        : people.first.id;
    // Once a second is enough for "6 min ago" and the second-dose countdown.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // An unanswered "call for help" lapses after 20 seconds.
      if (_callAskedAt != null &&
          DateTime.now().difference(_callAskedAt!) >
              const Duration(seconds: 20)) {
        _callAskedAt = null;
      }
      setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);
    _speech = SpeechService.instance.events.listen(_onSpeech);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startVoice());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _app.removeListener(_lockChanged);
    _speech?.cancel();
    SpeechService.instance.stop();
    _ticker.cancel();
    _note.dispose();
    super.dispose();
  }

  /// Back from a phone call or Messages: pick listening up again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _callAskedAt = null;
      SpeechService.instance.stop();
      _listening = false;
    }
    // Defer until the app-level observer has reinstated the lock.
    if (_foreground) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_voiceAllowed && !_listening) _startVoice();
      });
    }
  }

  Future<void> _startVoice() async {
    if (!_voiceAllowed || _startingVoice || _listening) return;
    _startingVoice = true;
    try {
      final a = await SpeechService.instance.availability();
      if (!_voiceAllowed) return;
      setState(() => _voiceAvailable = a != SpeechAvailability.unavailable);
      if (a == SpeechAvailability.unavailable) return;
      if (!await SpeechService.instance.ensureReady() || !_voiceAllowed) return;
      final ok = await SpeechService.instance.start();
      if (!_voiceAllowed) {
        await SpeechService.instance.stop();
        return;
      }
      setState(() => _listening = ok);
    } finally {
      _startingVoice = false;
    }
  }

  Future<void> _setVoice(bool on) async {
    setState(() => _wantVoice = on);
    if (on) {
      await _startVoice();
    } else {
      await SpeechService.instance.stop();
      if (mounted) setState(() => _listening = false);
    }
  }

  void _onSpeech(SpeechEvent e) {
    if (!_voiceAllowed) return;
    if (e.isPartial) setState(() => _heard = e.text);
    if (e.isStopped) setState(() => _listening = false);
    if (e.isSegment) {
      setState(() => _heard = '');
      _actOn(e.text);
    }
  }

  /// One spoken sentence. Commands act; everything else is a note.
  Future<void> _actOn(String text) async {
    if (!_voiceAllowed) return;
    final AppState app = context.read<AppState>();
    switch (VoiceParser.emergencyCommand(text)) {
      case EmergencyCommand.epinephrineGiven:
        await _giveDose();
      case EmergencyCommand.callForHelp:
        setState(() => _callAskedAt = DateTime.now());
      case EmergencyCommand.confirmCall:
        if (_callAskedAt == null) {
          await _addNote(text);
          return;
        }
        setState(() => _callAskedAt = null);
        await _call(localEmergencyNumber(app));
      case EmergencyCommand.textFamily:
        if (app.contacts.length == 1) {
          final Trip? trip = _trip(app);
          await _text(
            app.contacts.single,
            EmergencySummary.textToContact(
              name: _person(app).name,
              doses: _doses,
              flight: app.flightInProgress(),
              country: countryFor(trip?.destinationCountry ?? '')?.name,
            ),
          );
        } else {
          await _addNote(text);
        }
      case EmergencyCommand.showCrew:
        final Flight? f = app.flightInProgress();
        if (f == null) {
          await _addNote(text);
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (BuildContext _) => _CrewAlertScreen(
              flight: f,
              person: _person(app),
              doses: _doses,
            ),
          ),
        );
      case EmergencyCommand.guidance:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => const ClinicalGuidanceScreen(),
          ),
        );
      case EmergencyCommand.note:
        await _addNote(text);
    }
  }

  Trip? _trip(AppState app) => app.tripById(widget.tripId) ?? app.activeTrip();

  List<Profile> _people(AppState app) {
    final Trip? trip = _trip(app);
    final List<Profile> picked = app.profiles
        .where((Profile p) => trip?.travelerIds.contains(p.id) ?? false)
        .toList();
    return picked.isEmpty ? app.profiles : picked;
  }

  Profile _person(AppState app) {
    for (final Profile p in app.profiles) {
      if (p.id == _profileId) return p;
    }
    return app.activeProfile;
  }

  bool get _hasRecord =>
      _doses.isNotEmpty || _notes.isNotEmpty || _calledForHelp;

  /// Writes everything so far into one reaction record.
  Future<ReactionLog?> _persist() async {
    if (!_hasRecord) return null;
    final AppState app = context.read<AppState>();
    ReactionLog? existing;
    for (final ReactionLog r in app.reactions) {
      if (r.id == _recordId) existing = r;
    }
    final ReactionLog record = ReactionLog(
      id: _recordId ??= app.newId(),
      profileId: _profileId,
      occurredAt: _startedAt,
      symptoms: existing?.symptoms ?? <String>[],
      suspectedFood: existing?.suspectedFood ?? '',
      epiUsed: _doses.isNotEmpty,
      soughtCare: _calledForHelp || (existing?.soughtCare ?? false),
      notes: existing?.notes ?? '',
      severityRating: _doses.isNotEmpty ? 5 : (existing?.severityRating ?? 4),
      tripId: _trip(app)?.id,
      exposureId: existing?.exposureId,
      epiDoses: List<DateTime>.of(_doses),
      timeline: List<TimelineNote>.of(_notes),
    );
    final saved = await app.saveReaction(record);
    return saved ? record : null;
  }

  Future<void> _giveDose() async {
    final DateTime now = DateTime.now();
    setState(() {
      _doses.add(now);
      _notes.add(
        TimelineNote(at: now, text: 'Epinephrine dose ${_doses.length} given'),
      );
    });
    await _persist();
  }

  Future<void> _addNote([String? text]) async {
    final String t = (text ?? _note.text).trim();
    if (t.isEmpty) return;
    setState(() {
      _notes.add(TimelineNote(at: DateTime.now(), text: t));
      if (text == null) _note.clear();
    });
    await _persist();
  }

  Future<void> _call(LocalEmergencyNumber n) async {
    LocalEmergencyNumber target = n;
    final bool called = await callEmergency(
      context,
      n,
      onConfirmed: (value) => target = value,
    );
    if (!mounted || !called) return;
    _calledForHelp = true;
    await _addNote('Called ${target.number} (${target.where})');
  }

  Future<void> _text(EmergencyContact c, String body) async {
    final bool opened = await sendSms(context, phone: c.phone, body: body);
    if (!mounted || !opened) return;
    await _addNote(
      'Messaged ${c.name.trim().isEmpty ? c.phone : c.name.trim()}',
    );
  }

  /// Saves, lets the user add symptoms, then shows the handover summary.
  Future<void> _finish() async {
    final NavigatorState nav = Navigator.of(context);
    if (!_hasRecord) {
      nav.pop();
      return;
    }
    final ReactionLog? record = await _persist();
    if (!mounted || record == null) return;
    await showReactionForm(context, profileId: _profileId, existing: record);
    if (!mounted) return;
    nav.pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => HandoverScreen(reactionId: record.id),
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final bool end =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('End emergency mode?'),
            content: Text(
              _hasRecord
                  ? (context.read<AppState>().hasUnsavedChanges
                        ? 'Some changes are not saved. Keep this screen open and use Retry before ending emergency mode.'
                        : 'Everything so far is saved. You can add symptoms and see '
                              'the handover summary next.')
                  : 'Nothing has been recorded.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('End'),
              ),
            ],
          ),
        ) ??
        false;
    if (end && mounted) await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;
    final DateTime now = DateTime.now();
    final Trip? trip = _trip(app);
    final Flight? flying = app.flightInProgress(now);
    final LocalEmergencyNumber number = localEmergencyNumber(app);
    final Profile person = _person(app);
    final List<Profile> people = _people(app);

    final Widget help = _HelpSection(
      flying: flying,
      number: number,
      danger: danger,
      onCall: () => _call(number),
      onCrew: flying == null
          ? null
          : () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (BuildContext _) => _CrewAlertScreen(
                  flight: flying,
                  person: person,
                  doses: _doses,
                ),
              ),
            ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: danger,
          foregroundColor: Colors.white,
          title: const Text('Emergency'),
          leading: IconButton(
            tooltip: 'End emergency mode',
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmLeave,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: <Widget>[
            Text(
              'Started ${formatFlightTime(_startedAt)} · '
              '${now.difference(_startedAt).inMinutes} min ago',
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
            if (_voiceAvailable) ...<Widget>[
              const SizedBox(height: 8),
              _VoiceBar(
                listening: _listening,
                wanted: _wantVoice,
                heard: _heard,
                onChanged: _setVoice,
              ),
            ],
            if (_callAskedAt != null) ...<Widget>[
              const SizedBox(height: 10),
              Card(
                color: danger.withValues(alpha: 0.12),
                child: ListTile(
                  leading: Icon(Icons.phone_in_talk, color: danger),
                  title: Text('Call ${number.number}?'),
                  subtitle: const Text('Say “yes, call” or tap Call.'),
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => _actOn('yes call'),
                    child: const Text('Call'),
                  ),
                ),
              ),
            ],
            if (people.length > 1) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final Profile p in people)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: _profileId == p.id,
                      onSelected: (bool _) async {
                        setState(() => _profileId = p.id);
                        await _persist();
                      },
                    ),
                ],
              ),
            ],

            // On a plane the crew comes first: they carry the kit and can
            // reach a doctor on board faster than any phone call.
            if (flying != null) ...<Widget>[
              const SectionTitle('Get help'),
              help,
            ],

            const SectionTitle('Epinephrine'),
            _EpiSection(
              doses: _doses,
              now: now,
              danger: danger,
              pens: app.epiPens,
              onDose: _giveDose,
            ),

            if (flying == null) ...<Widget>[
              const SectionTitle('Get help'),
              help,
            ],

            if (app.contacts.isNotEmpty) ...<Widget>[
              const SectionTitle('Tell someone'),
              for (final EmergencyContact c in app.contacts)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.sms_outlined),
                    title: Text(
                      'Text ${c.name.trim().isEmpty ? c.phone : c.name.trim()}',
                    ),
                    subtitle: const Text(
                      'Opens Messages with it written. You press send.',
                    ),
                    trailing: IconButton(
                      tooltip: 'Call',
                      icon: const Icon(Icons.call),
                      onPressed: () => dialNumber(context, c.phone),
                    ),
                    onTap: () => _text(
                      c,
                      EmergencySummary.textToContact(
                        name: person.name,
                        doses: _doses,
                        flight: flying,
                        country: countryFor(
                          trip?.destinationCountry ?? '',
                        )?.name,
                      ),
                    ),
                  ),
                ),
            ],

            const SectionTitle('For the person helping'),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.medical_services_outlined),
                    title: const Text('Step-by-step guidance'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext _) =>
                            const ClinicalGuidanceScreen(),
                      ),
                    ),
                  ),
                  if (app.actionPlan.trim().isNotEmpty) ...<Widget>[
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text("The doctor's action plan"),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (BuildContext dialogContext) => AlertDialog(
                          title: const Text('Action plan'),
                          content: SingleChildScrollView(
                            child: Text(app.actionPlan),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SectionTitle('What is happening'),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (String _) => _addNote(),
              decoration: InputDecoration(
                hintText: 'Lips swelling, wheezing, moved to galley…',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _addNote,
                ),
              ),
            ),
            for (final TimelineNote n in _notes.reversed)
              ListTile(
                dense: true,
                leading: Text(
                  formatFlightTime(n.at),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                title: Text(n.text),
              ),

            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _confirmLeave,
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: const Text('End and see the handover summary'),
            ),
            const SizedBox(height: 12),
            Text(
              kMedicalNoteShort,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpiSection extends StatelessWidget {
  const _EpiSection({
    required this.doses,
    required this.now,
    required this.danger,
    required this.pens,
    required this.onDose,
  });

  final List<DateTime> doses;
  final DateTime now;
  final Color danger;
  final List<EpiPen> pens;
  final VoidCallback onDose;

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime? last = doses.isEmpty ? null : doses.last;
    final Duration? since = last == null ? null : now.difference(last);

    String? window;
    if (since != null) {
      if (since < kSecondDoseFrom) {
        window =
            'No better after 5 to 15 minutes? A second dose can be given. '
            'That starts in ${_clock(kSecondDoseFrom - since)}.';
      } else if (since <= kSecondDoseTo) {
        window = 'No better yet? A second dose can be given now.';
      } else {
        window = 'More than 15 minutes since the last dose.';
      }
    }

    final List<EpiPen> usable = pens.where((EpiPen p) => !p.isExpired).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(64),
            textStyle: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          onPressed: onDose,
          icon: const Icon(Icons.vaccines_rounded),
          label: Text(
            doses.isEmpty
                ? 'Epinephrine given'
                : 'Dose ${doses.length + 1} given',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          doses.isEmpty
              ? 'Tap when it’s given. Paramedics will ask for the time.'
              : 'Tap again if another dose is given.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        for (int i = 0; i < doses.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Dose ${i + 1} at ${formatFlightTime(doses[i])} · '
              '${_clock(now.difference(doses[i]))} ago',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        if (window != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(window, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
        if (usable.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Auto-injectors: ${usable.map((EpiPen p) => p.location.trim().isEmpty ? p.label : '${p.label} — ${p.location.trim()}').join('; ')}',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.flying,
    required this.number,
    required this.danger,
    required this.onCall,
    required this.onCrew,
  });

  final Flight? flying;
  final LocalEmergencyNumber number;
  final Color danger;
  final VoidCallback onCall;
  final VoidCallback? onCrew;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Flight? f = flying;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (f != null) ...<Widget>[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: onCrew,
            icon: const Icon(Icons.campaign_rounded),
            label: const Text('Alert the crew'),
          ),
          const SizedBox(height: 6),
          Text(
            'Press the call button above your seat and show the crew this '
            'screen. Medical kit: ${emkFor(f.aircraftType).stowage}',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: danger,
            side: BorderSide(color: danger, width: 1.5),
            minimumSize: const Size.fromHeight(60),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          onPressed: onCall,
          icon: const Icon(Icons.phone_in_talk),
          label: Text('Call ${number.number}'),
        ),
        const SizedBox(height: 6),
        Text(
          number.isFallback
              ? 'Location unknown. Confirm your current country before calling.'
              : 'Suggested from trip or profile: ${number.where}. Confirm your current country before calling.'
                    '${f != null ? ' Works once the plane is on the ground or '
                              'connected.' : ''}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Full-screen, high-contrast, for a flight attendant to read at a glance.
/// English, plus the crew's own language from the hand-written emergency
/// phrases when the airline works in one of them.
class _CrewAlertScreen extends StatelessWidget {
  const _CrewAlertScreen({
    required this.flight,
    required this.person,
    required this.doses,
  });

  final Flight flight;
  final Profile person;
  final List<DateTime> doses;

  String? _crewLanguage(AppState app) {
    final Set<String> handWritten = kCardLanguages.map((l) => l.code).toSet();
    for (final String code in crewLanguagesFor(flight.airlineIata)) {
      if (code != 'en' && handWritten.contains(code)) return code;
    }
    final String travel = app.travelLanguage;
    return travel != 'en' ? travel : null;
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final String? lang = _crewLanguage(app);
    EmergencyPhrase? phrase(String id) {
      for (final EmergencyPhrase p in kEmergencyPhrases) {
        if (p.id == id) return p;
      }
      return null;
    }

    final List<String> ids = <String>[
      'reaction',
      if (doses.isNotEmpty) 'used_it',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Show to crew'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: <Widget>[
          const Text(
            'MEDICAL EMERGENCY',
            style: TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${person.name} is having a severe allergic reaction '
            '(anaphylaxis).'
            '${flight.seat.trim().isEmpty ? '' : '\nSeat ${flight.seat.trim()}.'}'
            '${doses.isEmpty ? '' : '\nEpinephrine given at ${doses.map(formatFlightTime).join(', ')}.'}'
            '\nPlease bring the emergency medical kit and ask if there is a '
            'doctor on board.',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 23,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (lang != null) ...<Widget>[
            const SizedBox(height: 24),
            const Divider(color: Colors.black26),
            const SizedBox(height: 12),
            for (final String id in ids)
              if (phrase(id) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    phrase(id)!.inLanguage(lang),
                    textDirection: lang == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      height: 1.35,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// Shows that emergency mode is listening, what it last heard, and the
/// commands it understands — with a switch to turn it off.
class _VoiceBar extends StatelessWidget {
  const _VoiceBar({
    required this.listening,
    required this.wanted,
    required this.heard,
    required this.onChanged,
  });

  final bool listening;
  final bool wanted;
  final String heard;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                listening ? Icons.mic_rounded : Icons.mic_off_rounded,
                size: 18,
                color: listening ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  listening
                      ? 'Listening'
                      : (wanted ? 'Listening paused' : 'Voice off'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Switch(value: wanted, onChanged: onChanged),
            ],
          ),
          Text(
            heard.isNotEmpty
                ? '“$heard”'
                : 'Say “epinephrine given”, “call for help”, “text my family”, '
                      '“show the crew”, or describe what is happening.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
