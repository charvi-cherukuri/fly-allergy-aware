// Accommodation requests, incident reports, seat cleaning and cabin
// awareness - the accountability half of the app (FRD 2.2, 2.3, 3.1, 3.2).

import 'trip.dart' show Exposure;

/// Something the passenger asked the airline to do before flying.
///
/// Logged with a timestamp and a channel because the value of this record is
/// evidentiary: when a carrier fails to honour a request, the passenger's
/// account of having made it is otherwise unverifiable.
class AccommodationRequest {
  AccommodationRequest({
    required this.id,
    required this.flightId,
    required this.type,
    required this.requestedAt,
    this.channel = RequestChannel.phone,
    this.reference = '',
    this.agentName = '',
    this.status = RequestStatus.pending,
    this.responseNotes = '',
    this.resolvedAt,
  });

  final String id;
  final String flightId;
  final AccommodationType type;
  final DateTime requestedAt;
  RequestChannel channel;

  /// Confirmation or case number the airline gave.
  String reference;
  String agentName;
  RequestStatus status;
  String responseNotes;
  DateTime? resolvedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'flightId': flightId,
        'type': type.name,
        'requestedAt': requestedAt.millisecondsSinceEpoch,
        'channel': channel.name,
        'reference': reference,
        'agentName': agentName,
        'status': status.name,
        'responseNotes': responseNotes,
        'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
      };

  factory AccommodationRequest.fromMap(Map<String, dynamic> m) =>
      AccommodationRequest(
        id: m['id'] as String,
        flightId: (m['flightId'] as String?) ?? '',
        type: AccommodationType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => AccommodationType.other,
        ),
        requestedAt:
            DateTime.fromMillisecondsSinceEpoch(m['requestedAt'] as int),
        channel: RequestChannel.values.firstWhere(
          (c) => c.name == m['channel'],
          orElse: () => RequestChannel.phone,
        ),
        reference: (m['reference'] as String?) ?? '',
        agentName: (m['agentName'] as String?) ?? '',
        status: RequestStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => RequestStatus.pending,
        ),
        responseNotes: (m['responseNotes'] as String?) ?? '',
        resolvedAt: m['resolvedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['resolvedAt'] as int),
      );
}

enum AccommodationType {
  preboardToWipe('Pre-board to wipe down seat area'),
  bufferZone('Nut-free buffer zone'),
  noNutService('Suspend nut service on board'),
  cabinAnnouncement('Cabin announcement'),
  seatChange('Move away from a known allergen'),
  ownFood('Bring own food through security and on board'),
  epiOnBoard('Carry epinephrine auto-injectors on board'),
  crewNotified('Crew briefed before departure'),
  other('Other request');

  const AccommodationType(this.label);
  final String label;
}

enum RequestChannel {
  phone('Phone'),
  email('Email'),
  chat('Web chat'),
  app('Airline app'),
  checkIn('At check-in or bag drop'),
  gate('At the gate'),
  onboard('On board');

  const RequestChannel(this.label);
  final String label;
}

enum RequestStatus {
  pending('Requested'),
  confirmed('Confirmed by airline'),
  refused('Refused'),
  honoured('Honored on the day'),
  notHonoured('Confirmed but not honored');

  const RequestStatus(this.label);
  final String label;

  /// The status that justifies a formal complaint: the carrier agreed and
  /// then did not follow through.
  bool get warrantsReport =>
      this == RequestStatus.notHonoured || this == RequestStatus.refused;
}

/// A compiled report about a failed accommodation or an in-flight reaction.
///
/// The app assembles and pre-fills this. It does not transmit it — the
/// passenger reviews and sends it themselves, because a complaint filed in
/// someone's name is theirs to make.
class IncidentReport {
  IncidentReport({
    required this.id,
    required this.flightId,
    required this.createdAt,
    required this.kind,
    this.narrative = '',
    this.requestIds = const [],
    this.reactionId,
    this.filedWith = FilingTarget.airline,
    this.filedAt,
    this.tripId,
  });

  final String id;

  /// Empty when the incident did not happen on a flight — a hotel or a
  /// restaurant — which is why [tripId] exists alongside it.
  final String flightId;
  final DateTime createdAt;
  final IncidentKind kind;
  String narrative;
  List<String> requestIds;
  String? reactionId;
  FilingTarget filedWith;
  DateTime? filedAt;

  /// The trip it belongs to.
  String? tripId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'flightId': flightId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'kind': kind.name,
        'narrative': narrative,
        'requestIds': requestIds.join('|'),
        'reactionId': reactionId,
        'filedWith': filedWith.name,
        'filedAt': filedAt?.millisecondsSinceEpoch,
        'tripId': tripId,
      };

  factory IncidentReport.fromMap(Map<String, dynamic> m) => IncidentReport(
        id: m['id'] as String,
        flightId: (m['flightId'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        kind: IncidentKind.values.firstWhere(
          (k) => k.name == m['kind'],
          orElse: () => IncidentKind.accommodationFailure,
        ),
        narrative: (m['narrative'] as String?) ?? '',
        requestIds: ((m['requestIds'] as String?) ?? '')
            .split('|')
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        reactionId: m['reactionId'] as String?,
        filedWith: FilingTarget.values.firstWhere(
          (f) => f.name == m['filedWith'],
          orElse: () => FilingTarget.airline,
        ),
        filedAt: m['filedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['filedAt'] as int),
        tripId: m['tripId'] as String?,
      );
}

enum IncidentKind {
  accommodationFailure('Accommodation not provided'),
  allergicReaction('Allergic reaction on board'),
  refusedBoarding('Refused boarding or seating'),
  crewConduct('Crew conduct'),
  venueFailure('Restaurant, hotel or venue ignored the allergy'),
  other('Something else');

  const IncidentKind(this.label);
  final String label;

  /// Whether this kind of incident is, by definition, about a flight — and so
  /// is written up as a complaint to an airline.
  bool get concernsFlight =>
      this != IncidentKind.venueFailure && this != IncidentKind.other;
}

enum FilingTarget {
  airline('The airline directly'),
  dot('US DOT Aviation Consumer Protection'),
  both('Both');

  const FilingTarget(this.label);
  final String label;
}

/// A logged wipe-down of the seat area (FRD 3.2).
class SeatCleaningLog {
  SeatCleaningLog({
    required this.id,
    required this.flightId,
    required this.cleanedAt,
    required this.surfaces,
    this.byWhom = CleanedBy.passenger,
    this.notes = '',
  });

  final String id;
  final String flightId;
  final DateTime cleanedAt;
  List<String> surfaces;
  CleanedBy byWhom;
  String notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'flightId': flightId,
        'cleanedAt': cleanedAt.millisecondsSinceEpoch,
        'surfaces': surfaces.join('|'),
        'byWhom': byWhom.name,
        'notes': notes,
      };

  factory SeatCleaningLog.fromMap(Map<String, dynamic> m) => SeatCleaningLog(
        id: m['id'] as String,
        flightId: (m['flightId'] as String?) ?? '',
        cleanedAt: DateTime.fromMillisecondsSinceEpoch(m['cleanedAt'] as int),
        surfaces: ((m['surfaces'] as String?) ?? '')
            .split('|')
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        byWhom: CleanedBy.values.firstWhere(
          (c) => c.name == m['byWhom'],
          orElse: () => CleanedBy.passenger,
        ),
        notes: (m['notes'] as String?) ?? '',
      );
}

enum CleanedBy {
  passenger('Passenger'),
  crew('Cabin crew'),
  groundStaff('Ground cleaning crew');

  const CleanedBy(this.label);
  final String label;
}

/// The surfaces worth wiping, in the order they matter. Tray tables are first
/// for a reason — they are the surface most likely to carry food residue and
/// the least likely to be cleaned on a short turnaround.
const kSeatSurfaces = <String>[
  'Tray table (both sides)',
  'Armrests',
  'Seatback screen and controls',
  'Seat belt buckle',
  'Seatback pocket',
  'Window shade and sill',
  'Air vent and light switches',
];

/// A voluntarily declared snack, from the retired cabin proximity view
/// (FRD 3.1).
///
/// Nothing writes these any more. The class stays so the v5 upgrade can read
/// the old `snack_reports` rows and carry each one into an [Exposure] on its
/// trip; the table itself is left in place, unused, so nothing is lost.
///
/// Stored with a row number only — never a seat letter, never an identity.
/// The whole feature depends on other passengers being willing to declare, so
/// it has to be obviously anonymous to be worth anything.
class SnackReport {
  SnackReport({
    required this.id,
    required this.flightId,
    required this.row,
    required this.allergenNames,
    required this.reportedAt,
    this.description = '',
    this.selfReported = true,
  });

  final String id;
  final String flightId;
  final int row;

  /// Names rather than enum values, so a custom allergen can appear here too.
  List<String> allergenNames;

  final DateTime reportedAt;
  String description;

  /// False when the user logged something they observed nearby rather than
  /// something they brought themselves.
  bool selfReported;

  Map<String, dynamic> toMap() => {
        'id': id,
        'flightId': flightId,
        'row': row,
        'allergenNames': allergenNames.join('|'),
        'reportedAt': reportedAt.millisecondsSinceEpoch,
        'description': description,
        'selfReported': selfReported ? 1 : 0,
      };

  factory SnackReport.fromMap(Map<String, dynamic> m) => SnackReport(
        id: m['id'] as String,
        flightId: (m['flightId'] as String?) ?? '',
        row: (m['row'] as int?) ?? 0,
        allergenNames: ((m['allergenNames'] as String?) ?? '')
            .split('|')
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        reportedAt:
            DateTime.fromMillisecondsSinceEpoch(m['reportedAt'] as int),
        description: (m['description'] as String?) ?? '',
        selfReported: (m['selfReported'] as int? ?? 1) == 1,
      );
}
