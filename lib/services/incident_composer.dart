import '../models/allergen.dart';
import '../models/emergency.dart';
import '../models/flight.dart';
import '../models/profile.dart';
import '../models/travel.dart';

/// Turns the accountability records into a complaint someone can actually send.
///
/// The whole value of the accommodation log is evidentiary. A passenger who
/// says "I asked for a buffer zone and they said yes" has nothing to show for
/// it; a passenger with a dated chronology — request, channel, reference
/// number, who they spoke to, what was promised, what happened — has a record
/// a carrier has to answer.
///
/// The register is deliberately flat. No outrage, no legal threats, no claims
/// about what the law requires. A calm chronology is harder to dismiss than an
/// angry letter, and a complaint that overclaims gives the reader an easy reason
/// to close the file. The app writes the facts; the passenger decides what to
/// make of them.
///
/// Nothing here transmits anything. `compose` returns a string.
class IncidentComposer {
  const IncidentComposer._();

  /// A complete, ready-to-send plain-text complaint.
  ///
  /// Plain text on purpose: it pastes into an airline web form, an email, or a
  /// DOT complaint field without losing anything.
  ///
  /// Anywhere the records are incomplete, the draft carries a bracketed
  /// placeholder rather than inventing a fact or quietly dropping the line. The
  /// user is going to read this before sending it — a visible gap is useful, a
  /// silent one is not.
  static String compose({
    required IncidentReport report,
    required Flight? flight,
    required Profile profile,
    required List<AccommodationRequest> requests,
    ReactionLog? reaction,
  }) {
    final b = StringBuffer();
    final name = profile.name.trim().isEmpty ? '[Your name]' : profile.name.trim();

    if (flight == null && !report.kind.concernsFlight) {
      _composeOffFlight(b, report, profile, name, reaction);
      return b.toString().trimRight();
    }

    _writeHeader(b, report, flight, name);
    _writeWhoIsWriting(b, report, profile, name);
    _writeFlight(b, flight);
    _writeRequests(b, requests);
    _writeWhatFailed(b, report, requests);
    if (reaction != null) _writeReaction(b, reaction);
    _writeResolution(b, report, requests, hasReaction: reaction != null);
    _writeClosing(b, report, name);

    return b.toString().trimRight();
  }

  /// The US Department of Transportation's aviation consumer complaint form.
  ///
  /// DOT has jurisdiction over US carriers and over flights to, from or within
  /// the United States. An itinerary that touches none of those — a domestic
  /// flight between two other countries on a foreign carrier — is outside its
  /// remit, and the complaint belongs with that country's national regulator
  /// instead (the relevant national enforcement body in the EU/UK, CTA in
  /// Canada, CASA/ACCC in Australia, and so on). The app does not try to work
  /// out which one; it says so and leaves the choice to the user.
  static String dotComplaintUrl() =>
      'https://www.transportation.gov/airconsumer/file-consumer-complaint';

  /// The subject line for an email or web form.
  static String subjectLine(IncidentReport report, Flight? flight) {
    if (flight == null) {
      return '${report.kind.label} — ${formatDate(report.createdAt)}';
    }
    final detail = <String>[
      '${flight.airlineIata}${flight.flightNumber}'.trim(),
      '${flight.origin} to ${flight.destination}',
      formatDate(flight.departsAt),
    ].where((p) => p.trim().isNotEmpty).join(', ');
    return '${report.kind.label} — $detail';
  }

  // -------------------------------------------------------------- sections

  static void _writeHeader(
    StringBuffer b,
    IncidentReport report,
    Flight? flight,
    String name,
  ) {
    switch (report.filedWith) {
      case FilingTarget.airline:
        b.writeln('To: Customer Relations, ${_carrier(flight)}');
      case FilingTarget.dot:
        b.writeln(
          'To: US Department of Transportation, '
          'Aviation Consumer Protection Division',
        );
      case FilingTarget.both:
        b
          ..writeln('To: Customer Relations, ${_carrier(flight)}')
          ..writeln(
            'Copy: US Department of Transportation, '
            'Aviation Consumer Protection Division',
          );
    }
    b
      ..writeln('From: $name')
      ..writeln('Date: ${formatDate(report.createdAt)}')
      ..writeln('Subject: ${subjectLine(report, flight)}')
      ..writeln();
  }

  static void _writeWhoIsWriting(
    StringBuffer b,
    IncidentReport report,
    Profile profile,
    String name,
  ) {
    b
      ..writeln('1. WHO IS WRITING')
      ..writeln()
      ..writeln(
        'My name is $name. I am writing about ${_kindPhrase(report.kind)} '
        'on the flight identified below.',
      )
      ..writeln();

    if (profile.isEmpty) {
      b
        ..writeln(
          'I have a food allergy. [Add the allergens you must avoid before '
          'sending this.]',
        )
        ..writeln();
      return;
    }

    b
      ..writeln(
        'I have a food allergy. The allergens I must avoid, and how strictly, '
        'are:',
      )
      ..writeln();
    for (final a in profile.sorted) {
      b.writeln('  - ${a.label} (${_severityPhrase(profile.severityOf(a))})');
    }
    for (final c in profile.customAllergens) {
      b.writeln('  - ${c.name} (${_severityPhrase(c.severity)})');
    }
    b.writeln();
    if (profile.hasSevere) {
      b
        ..writeln(
          'At least one of these carries a risk of anaphylaxis. That is the '
          'extent of the medical detail relevant to this complaint.',
        )
        ..writeln();
    }
  }

  static void _writeFlight(StringBuffer b, Flight? flight) {
    b
      ..writeln('2. FLIGHT')
      ..writeln();

    if (flight == null) {
      b
        ..writeln(
          '[Add the carrier, flight number, route and date of travel before '
          'sending this.]',
        )
        ..writeln();
      return;
    }

    b
      ..writeln('  Carrier:        ${_carrier(flight)}')
      ..writeln(
        '  Flight number:  '
        '${'${flight.airlineIata}${flight.flightNumber}'.trim()}',
      )
      ..writeln('  Route:          ${flight.origin} to ${flight.destination}')
      ..writeln('  Date of travel: ${formatDate(flight.departsAt)}')
      ..writeln('  Departure:      ${formatTime(flight.departsAt)} local');
    b.writeln(
      '  Seat:           '
      '${flight.seat.trim().isEmpty ? '[Add your seat number]' : flight.seat.trim()}',
    );
    if (flight.aircraftType.trim().isNotEmpty) {
      b.writeln('  Aircraft:       ${flight.aircraftType.trim()}');
    }
    b.writeln();
  }

  static void _writeRequests(
    StringBuffer b,
    List<AccommodationRequest> requests,
  ) {
    b
      ..writeln('3. ACCOMMODATION REQUESTS')
      ..writeln();

    if (requests.isEmpty) {
      b
        ..writeln('No accommodation requests are attached to this report.')
        ..writeln();
      return;
    }

    b
      ..writeln(
        'Each request below was recorded at the time it was made, with the '
        'channel used and any reference number given. They are listed in the '
        'order they were made.',
      )
      ..writeln();

    final ordered = [...requests]
      ..sort((a, c) => a.requestedAt.compareTo(c.requestedAt));

    for (final r in ordered) {
      b
        ..writeln('  ${formatDateTime(r.requestedAt)}')
        ..writeln('  Request:   ${r.type.label}')
        ..writeln('  Channel:   ${r.channel.label}');
      if (r.reference.trim().isNotEmpty) {
        b.writeln('  Reference: ${r.reference.trim()}');
      }
      if (r.agentName.trim().isNotEmpty) {
        b.writeln('  Spoke to:  ${r.agentName.trim()}');
      }
      b.writeln('  Outcome:   ${_outcomePhrase(r)}');
      if (r.responseNotes.trim().isNotEmpty) {
        b.writeln('  Recorded:  ${r.responseNotes.trim()}');
      }
      if (r.resolvedAt != null) {
        b.writeln('  Resolved:  ${formatDateTime(r.resolvedAt!)}');
      }
      b.writeln();
    }
  }

  static void _writeWhatFailed(
    StringBuffer b,
    IncidentReport report,
    List<AccommodationRequest> requests,
  ) {
    b
      ..writeln('4. WHAT HAPPENED')
      ..writeln();

    final narrative = report.narrative.trim();
    if (narrative.isNotEmpty) {
      b
        ..writeln(narrative)
        ..writeln();
      return;
    }

    final failed = requests.where((r) => r.status.warrantsReport).toList();
    if (failed.isEmpty) {
      b
        ..writeln('[Describe, factually, what was asked for and what happened.]')
        ..writeln();
      return;
    }
    for (final r in failed) {
      b.writeln('  - ${_failureLine(r)}');
    }
    b.writeln();
  }

  /// An incident at a restaurant, hotel or anywhere else that is not a
  /// flight: addressed to whoever runs the place, with none of the airline
  /// sections — there are no accommodation requests or regulators to cite.
  static void _composeOffFlight(
    StringBuffer b,
    IncidentReport report,
    Profile profile,
    String name,
    ReactionLog? reaction,
  ) {
    b
      ..writeln('To: [The manager, and the name of the restaurant, hotel or '
          'venue]')
      ..writeln('From: $name')
      ..writeln('Date: ${formatDate(report.createdAt)}')
      ..writeln('Subject: ${report.kind.label} — ${formatDate(report.createdAt)}')
      ..writeln()
      ..writeln('1. WHO IS WRITING')
      ..writeln()
      ..writeln('My name is $name. I am writing about '
          '${_kindPhrase(report.kind)}.')
      ..writeln();
    if (profile.isEmpty) {
      b
        ..writeln('I have a food allergy. [Add the allergens you must avoid '
            'before sending this.]')
        ..writeln();
    } else {
      b
        ..writeln('I have a food allergy. The allergens I must avoid are:')
        ..writeln();
      for (final a in profile.sorted) {
        b.writeln('  - ${a.label} (${_severityPhrase(profile.severityOf(a))})');
      }
      for (final c in profile.customAllergens) {
        b.writeln('  - ${c.name} (${_severityPhrase(c.severity)})');
      }
      b.writeln();
    }
    b
      ..writeln('2. WHAT HAPPENED')
      ..writeln()
      ..writeln(report.narrative.trim().isEmpty
          ? '[Describe what you told staff, when, and what happened.]'
          : report.narrative.trim())
      ..writeln();
    if (reaction != null) _writeReaction(b, reaction, number: 3);
    b
      ..writeln('${reaction == null ? 3 : 4}. WHAT I AM ASKING FOR')
      ..writeln()
      ..writeln('  - An acknowledgement of what happened.')
      ..writeln('  - Confirmation of how allergy information from customers is '
          'passed to the people preparing and serving food.')
      ..writeln('  - Whatever steps are open to you to prevent it happening to '
          'someone else.')
      ..writeln();
    _writeClosing(b, report, name);
  }

  static void _writeReaction(
    StringBuffer b,
    ReactionLog reaction, {
    int number = 5,
  }) {
    b
      ..writeln('$number. REACTION RECORD')
      ..writeln()
      ..writeln('  Date and time: ${formatDateTime(reaction.occurredAt)}');
    b.writeln(
      '  Symptoms:      '
      '${reaction.symptoms.isEmpty ? 'not recorded' : reaction.symptoms.join(', ')}',
    );
    b
      ..writeln('  Epinephrine:   ${reaction.epiUsed ? 'used' : 'not used'}')
      ..writeln(
        '  Medical care:  '
        '${reaction.soughtCare ? 'sought' : 'not sought'}',
      );
    if (reaction.suspectedFood.trim().isNotEmpty) {
      b.writeln('  Suspected at the time, by me: '
          '${reaction.suspectedFood.trim()}');
    }
    if (reaction.notes.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('  Notes made at the time: ${reaction.notes.trim()}');
    }
    b
      ..writeln()
      ..writeln(
        'These are the symptoms as they were logged. I am not stating a '
        'diagnosis here, and I am not asserting a cause beyond what is set '
        'out above.',
      )
      ..writeln();
  }

  static void _writeResolution(
    StringBuffer b,
    IncidentReport report,
    List<AccommodationRequest> requests, {
    required bool hasReaction,
  }) {
    final n = hasReaction ? 6 : 5;
    b
      ..writeln('$n. WHAT I AM ASKING FOR')
      ..writeln();

    for (final line in _resolutionPoints(report, requests)) {
      b.writeln('  - $line');
    }
    b
      ..writeln()
      ..writeln('I would appreciate a written response.')
      ..writeln();
  }

  static List<String> _resolutionPoints(
    IncidentReport report,
    List<AccommodationRequest> requests,
  ) {
    final points = <String>[
      'An acknowledgement of what happened on this flight.',
    ];

    switch (report.kind) {
      case IncidentKind.accommodationFailure:
        points
          ..add(
            'An explanation of why the accommodation recorded above was not '
            'provided, given that it had been requested in advance.',
          )
          ..add(
            'Confirmation of how a request of this kind is recorded against a '
            'booking, and what is meant to happen at the gate and on board.',
          );
      case IncidentKind.allergicReaction:
        points
          ..add(
            'Confirmation of what was served in the cabin on this flight and '
            'what the crew were told about the request recorded above.',
          )
          ..add(
            'An account of what the crew are trained to do when a passenger '
            'reports an allergic reaction in flight.',
          );
      case IncidentKind.refusedBoarding:
        points
          ..add(
            'The carrier\'s stated grounds for the decision taken at the gate, '
            'in writing.',
          )
          ..add(
            'Confirmation of the policy that was applied and by whom, so that '
            'I know what to expect when I fly with you again.',
          );
      case IncidentKind.crewConduct:
        points.add(
          'Confirmation that this account has been passed to the department '
          'responsible for crew training.',
        );
      case IncidentKind.venueFailure:
        points.add(
          'Confirmation of how allergy information from customers is passed '
          'to the people preparing and serving food.',
        );
      case IncidentKind.other:
        break;
    }

    if (requests.any((r) => r.reference.trim().isNotEmpty)) {
      points.add(
        'Confirmation of what the reference numbers listed above record on '
        'your side.',
      );
    }

    points.add(
      'Whatever steps are open to you to prevent the same failure on a future '
      'flight.',
    );
    return points;
  }

  static void _writeClosing(StringBuffer b, IncidentReport report, String name) {
    if (report.filedWith != FilingTarget.airline) {
      b
        ..writeln(
          'This account is also being submitted to the US Department of '
          'Transportation Aviation Consumer Protection Division.',
        )
        ..writeln();
    }
    b
      ..writeln(
        'This account was compiled from records kept in an app at the time of '
        'each event, not reconstructed from memory afterwards. Every date, '
        'time and reference number above was entered when it happened.',
      )
      ..writeln()
      ..writeln('Yours sincerely,')
      ..writeln(name);
  }

  // --------------------------------------------------------------- phrasing

  static String _carrier(Flight? flight) {
    final iata = flight?.airlineIata.trim() ?? '';
    return iata.isEmpty ? '[Airline]' : iata;
  }

  static String _kindPhrase(IncidentKind kind) {
    switch (kind) {
      case IncidentKind.accommodationFailure:
        return 'an accommodation that was requested and not provided';
      case IncidentKind.allergicReaction:
        return 'an allergic reaction on board';
      case IncidentKind.refusedBoarding:
        return 'being refused boarding or seating';
      case IncidentKind.crewConduct:
        return 'the conduct of crew towards an allergic passenger';
      case IncidentKind.venueFailure:
        return 'an allergy that staff were told about and did not act on';
      case IncidentKind.other:
        return 'an allergy-related incident';
    }
  }

  static String _severityPhrase(Severity s) {
    switch (s) {
      case Severity.severe:
        return 'severe, risk of anaphylaxis';
      case Severity.intolerance:
        return 'intolerance';
      case Severity.preference:
        return 'avoided by choice';
    }
  }

  static String _outcomePhrase(AccommodationRequest r) {
    switch (r.status) {
      case RequestStatus.pending:
        return 'Requested. No response recorded.';
      case RequestStatus.confirmed:
        return 'Confirmed by the airline.';
      case RequestStatus.refused:
        return 'Refused by the airline.';
      case RequestStatus.honoured:
        return 'Confirmed and provided on the day.';
      case RequestStatus.notHonoured:
        return 'Confirmed by the airline, then not provided on the day.';
    }
  }

  static String _failureLine(AccommodationRequest r) {
    final asked = r.type.label;
    final when = formatDate(r.requestedAt);
    switch (r.status) {
      case RequestStatus.notHonoured:
        return '"$asked" was requested on $when, confirmed by the airline, '
            'and was not provided on the day of travel.';
      case RequestStatus.refused:
        return '"$asked" was requested on $when and was refused.';
      default:
        return '"$asked" was requested on $when.';
    }
  }

  // ------------------------------------------------------------ formatting

  /// Written by hand: the app carries no `intl` dependency, and adding one for
  /// four date strings would be a poor trade against an offline-only build.
  static String formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.day} ${_monthNames[local.month - 1]} ${local.year}';
  }

  static String formatTime(DateTime d) {
    final local = d.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatDateTime(DateTime d) =>
      '${formatDate(d)}, ${formatTime(d)}';
}

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
