import '../data/countries.dart';
import '../models/emergency.dart';
import '../models/flight.dart';
import '../models/profile.dart';
import '../models/travel.dart';
import '../models/trip.dart';
import '../widgets/travel_format.dart';
import '../models/flight_experience.dart';

/// What kind of thing a timeline entry is. The order is the filter chip order.
enum JournalKind {
  flight('Flights'),
  request('Requests'),
  exposure('Exposures'),
  reaction('Reactions'),
  incident('Incidents'),
  wipeDown('Wipe-downs'),
  experience('Experiences');

  const JournalKind(this.label);
  final String label;
}

/// One line in a trip's timeline.
class JournalEntry {
  const JournalEntry({
    required this.kind,
    required this.at,
    required this.title,
    required this.detail,
    required this.id,
    this.flightId,
  });

  final JournalKind kind;
  final DateTime at;
  final String title;
  final String detail;

  /// The id of the underlying record, for opening it.
  final String id;

  /// The flight leg it belongs to, when it belongs to one.
  final String? flightId;
}

/// Everything recorded on a trip, gathered into one ordered story.
///
/// Pure: it takes the records rather than reading the app's state, so the
/// ordering and wording can be tested without a database.
class TripJournal {
  const TripJournal._();

  static List<JournalEntry> entries({
    required List<Flight> legs,
    required List<AccommodationRequest> requests,
    required List<Exposure> exposures,
    required List<ReactionLog> reactions,
    required List<IncidentReport> incidents,
    required List<SeatCleaningLog> wipeDowns,
    required List<Profile> profiles,
    List<FlightExperience> experiences = const <FlightExperience>[],
  }) {
    String who(String profileId) {
      for (final Profile p in profiles) {
        if (p.id == profileId) return p.name;
      }
      return '';
    }

    Flight? leg(String? id) {
      for (final Flight f in legs) {
        if (f.id == id) return f;
      }
      return null;
    }

    final List<JournalEntry> out = <JournalEntry>[
      for (final Flight f in legs)
        JournalEntry(
          kind: JournalKind.flight,
          at: f.departsAt,
          title: '${f.label}  ${f.route}',
          detail: 'Departs ${formatFlightTime(f.departsAt)}, arrives '
              '${formatShortDate(f.arrivesAt)} ${formatFlightTime(f.arrivesAt)}'
              '${f.seat.trim().isEmpty ? '' : ' · Seat ${f.seat.trim()}'}',
          id: f.id,
          flightId: f.id,
        ),
      for (final AccommodationRequest r in requests)
        JournalEntry(
          kind: JournalKind.request,
          at: r.requestedAt,
          title: r.type.label,
          detail: <String>[
            r.status.label,
            r.channel.label,
            if (r.reference.trim().isNotEmpty) 'Ref ${r.reference.trim()}',
            if (leg(r.flightId) != null) leg(r.flightId)!.label,
          ].join(' · '),
          id: r.id,
          flightId: r.flightId,
        ),
      for (final Exposure e in exposures)
        JournalEntry(
          kind: JournalKind.exposure,
          at: e.occurredAt,
          title: <String>[
            if (who(e.profileId).isNotEmpty) who(e.profileId),
            e.allergenNames.isEmpty ? 'Allergen exposure' : e.allergenNames.join(', '),
          ].join(': '),
          detail: <String>[
            e.route.label,
            if (e.place == ExposurePlace.flight)
              <String>[
                leg(e.flightId)?.label ?? 'On a flight',
                if (e.row != null) 'row ${e.row}',
              ].join(' ')
            else if (e.placeName.trim().isNotEmpty)
              e.placeName.trim()
            else
              e.place.label,
            e.outcome.label,
          ].join(' · '),
          id: e.id,
          flightId: e.flightId,
        ),
      for (final ReactionLog r in reactions)
        JournalEntry(
          kind: JournalKind.reaction,
          at: r.occurredAt,
          title: <String>[
            if (who(r.profileId).isNotEmpty) who(r.profileId),
            'reaction, severity ${r.severityRating} of 5',
          ].join(': '),
          detail: <String>[
            r.symptoms.isEmpty ? 'No symptoms recorded' : r.symptoms.join(', '),
            if (r.epiDoses.isNotEmpty)
              'epinephrine ${r.epiDoses.map(formatFlightTime).join(', ')}'
            else if (r.epiUsed)
              'epinephrine given',
          ].join(' · '),
          id: r.id,
        ),
      for (final IncidentReport i in incidents)
        JournalEntry(
          kind: JournalKind.incident,
          at: i.createdAt,
          title: i.kind.label,
          detail: <String>[
            if (leg(i.flightId) != null) leg(i.flightId)!.label,
            i.filedAt == null ? 'Not sent yet' : 'Sent ${formatShortDate(i.filedAt!)}',
          ].join(' · '),
          id: i.id,
          flightId: i.flightId.isEmpty ? null : i.flightId,
        ),
      for (final SeatCleaningLog w in wipeDowns)
        JournalEntry(
          kind: JournalKind.wipeDown,
          at: w.cleanedAt,
          title: 'Seat wiped down',
          detail: <String>[
            w.byWhom.label,
            '${w.surfaces.length} surface${w.surfaces.length == 1 ? '' : 's'}',
            if (leg(w.flightId) != null) leg(w.flightId)!.label,
          ].join(' · '),
          id: w.id,
          flightId: w.flightId,
        ),
      for (final FlightExperience x in experiences)
        JournalEntry(
          kind: JournalKind.experience,
          // Placed at landing, so it reads after the flight it describes.
          at: leg(x.flightId)?.arrivesAt ?? x.recordedAt,
          title: 'Flight experience${leg(x.flightId) == null ? '' : ': ${leg(x.flightId)!.label}'}',
          detail: <String>[
            if (x.foodRating != Rating.notSet) 'Food info: ${x.foodRating.label}',
            if (x.staffRating != Rating.notSet) 'Staff: ${x.staffRating.label}',
            if (x.kitEpinephrine != KitEpinephrine.unknown) 'Kit: ${x.kitEpinephrine.label}',
            if (x.suggestions.trim().isNotEmpty) 'Idea: ${x.suggestions.trim()}',
          ].join(' · '),
          id: x.id,
          flightId: x.flightId,
        ),
    ];
    out.sort((JournalEntry a, JournalEntry b) => a.at.compareTo(b.at));
    return out;
  }

  /// The whole trip as plain text, for the share sheet: to send to an
  /// allergist, a family member, or attach to a complaint.
  static String report({
    required Trip trip,
    required List<JournalEntry> entries,
    required String travelers,
  }) {
    final Country? country = countryFor(trip.destinationCountry);
    final StringBuffer b = StringBuffer()
      ..writeln(trip.name)
      ..writeln(formatTripDates(trip.startsOn, trip.endsOn))
      ..writeln('Travelers: $travelers');
    if (country != null) b.writeln('Destination: ${country.name}');
    b.writeln();

    if (entries.isEmpty) {
      b.writeln('Nothing was logged on this trip.');
    } else {
      DateTime? day;
      for (final JournalEntry e in entries) {
        final DateTime d = DateTime(e.at.year, e.at.month, e.at.day);
        if (day != d) {
          if (day != null) b.writeln();
          b.writeln(formatFlightDate(e.at));
          day = d;
        }
        b.writeln('  ${formatFlightTime(e.at)}  ${e.kind.label.toUpperCase()}: '
            '${e.title}');
        if (e.detail.trim().isNotEmpty) b.writeln('         ${e.detail}');
      }
    }
    if (trip.notes.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('Notes: ${trip.notes.trim()}');
    }
    b
      ..writeln()
      ..writeln('Recorded at the time in Fly Allergy Aware. Times are local to '
          'the phone that recorded them.');
    return b.toString().trimRight();
  }
}
