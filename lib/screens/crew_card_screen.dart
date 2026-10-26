import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/airline_policies.dart';
import '../data/translator_languages.dart';
import '../models/emergency.dart';
import '../models/flight.dart';
import '../models/profile.dart';
import '../models/travel.dart';
import '../services/app_state.dart';
import '../services/translator.dart';

/// A card to hand a flight attendant: who has the allergy, what the airline
/// already agreed to, and where the epinephrine is.
///
/// Written in English, which every international crew works in. The airline's
/// own language, when it has one, is added below by the on-device translator
/// and labelled as a machine translation — it helps a crew member who reads
/// it faster, and the English above it stays the version of record.
/// The English card. Built from records, never from guesses: a request the
/// airline refused is left off, because showing it would invite the crew to
/// believe something was agreed that was not.
String composeCrewCard({
  required Flight flight,
  required List<Profile> travelers,
  required List<AccommodationRequest> requests,
  required List<EpiPen> pens,
}) {
  final List<Profile> allergic =
      travelers.where((Profile p) => !p.isEmpty).toList();
  final StringBuffer b = StringBuffer();

  if (allergic.isEmpty) {
    b.writeln('I am travelling with a severe food allergy.');
  } else {
    for (final Profile p in allergic) {
      final String severe = p.hasSevere ? 'severe ' : '';
      b.writeln('${p.name} has a ${severe}food allergy to '
          '${p.summary.toLowerCase()}.');
    }
  }
  if (allergic.any((Profile p) => p.hasSevere)) {
    b.writeln('A reaction can be life-threatening (anaphylaxis).');
  }
  b.writeln();
  b.writeln('Flight ${flight.label}, ${flight.origin} to ${flight.destination}'
      '${flight.seat.trim().isEmpty ? '' : ', seat ${flight.seat.trim()}'}.');

  final List<AccommodationRequest> agreed = requests
      .where((AccommodationRequest r) =>
          r.status == RequestStatus.confirmed ||
          r.status == RequestStatus.honoured)
      .toList();
  final List<AccommodationRequest> asked = requests
      .where((AccommodationRequest r) => r.status == RequestStatus.pending)
      .toList();
  if (agreed.isNotEmpty) {
    b
      ..writeln()
      ..writeln('The airline confirmed:');
    for (final AccommodationRequest r in agreed) {
      b.writeln('  • ${r.type.label}'
          '${r.reference.trim().isEmpty ? '' : ' (ref. ${r.reference.trim()})'}');
    }
  }
  if (asked.isNotEmpty) {
    b
      ..writeln()
      ..writeln('I have asked for:');
    for (final AccommodationRequest r in asked) {
      b.writeln('  • ${r.type.label}');
    }
  }

  final List<String> where = pens
      .map((EpiPen p) => p.location.trim().isEmpty ? p.label : p.location.trim())
      .where((String s) => s.trim().isNotEmpty)
      .toSet()
      .toList();
  b.writeln();
  b.writeln(where.isEmpty
      ? 'I carry an epinephrine auto-injector.'
      : 'My epinephrine auto-injector is in: ${where.join('; ')}.');
  b
    ..writeln()
    ..writeln('Thank you for your help.');
  return b.toString().trimRight();
}

class CrewCardScreen extends StatefulWidget {
  const CrewCardScreen({super.key, required this.flightId});

  final String flightId;

  @override
  State<CrewCardScreen> createState() => _CrewCardScreenState();
}

class _CrewCardScreenState extends State<CrewCardScreen> {
  String? _translated;
  String? _translatedFor;
  bool _missingPack = false;
  bool _downloading = false;

  /// The first crew language that is not English, if the airline has one.
  String? _crewLanguage(Flight flight) {
    for (final String code in crewLanguagesFor(flight.airlineIata)) {
      if (code != 'en') return code;
    }
    return null;
  }

  Future<void> _translate(String text, String to) async {
    final TranslatorService t = context.read<AppState>().translator;
    final TranslationResult r = await t.translate(text: text, from: 'en', to: to);
    if (!mounted) return;
    setState(() {
      _translatedFor = '$to|$text';
      _translated = r.ok ? r.text : null;
      _missingPack = r.status == TranslateStatus.notDownloaded;
    });
  }

  Future<void> _download(String code, String text) async {
    setState(() => _downloading = true);
    await context.read<AppState>().translator.download(code);
    if (!mounted) return;
    setState(() => _downloading = false);
    await _translate(text, code);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    Flight? flight;
    for (final Flight f in app.flights) {
      if (f.id == widget.flightId) flight = f;
    }
    if (flight == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    final trip = app.tripById(flight.tripId);
    final List<Profile> travelers = app.profiles
        .where((Profile p) => trip?.travelerIds.contains(p.id) ?? false)
        .toList();
    final String english = composeCrewCard(
      flight: flight,
      travelers: travelers.isEmpty ? <Profile>[app.activeProfile] : travelers,
      requests: app.requestsFor(flight.id),
      pens: app.epiPens,
    );
    final String? lang = _crewLanguage(flight);
    final TranslatorLanguage? langInfo =
        lang == null ? null : translatorLanguageFor(lang);

    if (lang != null && _translatedFor != '$lang|$english') {
      _translatedFor = '$lang|$english';
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) _translate(english, lang);
      });
    }

    // High contrast whatever the phone's theme: this is read by someone else,
    // at arm's length, often in a dim cabin.
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
          Text(
            english,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 21,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (lang != null) ...<Widget>[
            const SizedBox(height: 24),
            const Divider(color: Colors.black26),
            const SizedBox(height: 12),
            if (_translated != null) ...<Widget>[
              Text(
                'MACHINE-TRANSLATED · ${langInfo?.native ?? lang}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _translated!,
                textDirection:
                    (langInfo?.rtl ?? false) ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 19,
                  height: 1.4,
                ),
              ),
            ] else if (_missingPack)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
                onPressed: _downloading ? null : () => _download(lang, english),
                icon: _downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  'Add ${langInfo?.english ?? lang} '
                  '(download, about ${app.translator.approxDownloadMegabytes(lang)} MB)',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
