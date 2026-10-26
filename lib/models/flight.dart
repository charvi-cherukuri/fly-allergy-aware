/// An airline the app knows by name.
class AirlinePolicy {
  const AirlinePolicy({required this.iata, required this.name});

  final String iata;
  final String name;
}

/// A flight the user is considering or has booked.
class Flight {
  Flight({
    required this.id,
    required this.airlineIata,
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.departsAt,
    required this.arrivesAt,
    this.aircraftType = '',
    this.seat = '',
    this.booked = false,
    this.tripId,
  });

  final String id;
  final String airlineIata;
  final String flightNumber;
  final String origin;
  final String destination;
  final DateTime departsAt;
  final DateTime arrivesAt;
  String aircraftType;
  String seat;

  bool booked;

  /// The trip this flight is a leg of.
  String? tripId;

  Duration get duration => arrivesAt.difference(departsAt);

  String get route => '$origin → $destination';
  String get label => '$airlineIata$flightNumber';

  Map<String, dynamic> toMap() => {
        'id': id,
        'airlineIata': airlineIata,
        'flightNumber': flightNumber,
        'origin': origin,
        'destination': destination,
        'departsAt': departsAt.millisecondsSinceEpoch,
        'arrivesAt': arrivesAt.millisecondsSinceEpoch,
        'aircraftType': aircraftType,
        'seat': seat,
        'booked': booked ? 1 : 0,
        'tripId': tripId,
      };

  factory Flight.fromMap(Map<String, dynamic> m) => Flight(
        id: m['id'] as String,
        airlineIata: (m['airlineIata'] as String?) ?? '',
        flightNumber: (m['flightNumber'] as String?) ?? '',
        origin: (m['origin'] as String?) ?? '',
        destination: (m['destination'] as String?) ?? '',
        departsAt: DateTime.fromMillisecondsSinceEpoch(m['departsAt'] as int),
        arrivesAt: DateTime.fromMillisecondsSinceEpoch(m['arrivesAt'] as int),
        aircraftType: (m['aircraftType'] as String?) ?? '',
        seat: (m['seat'] as String?) ?? '',
        booked: (m['booked'] as int? ?? 0) == 1,
        tripId: m['tripId'] as String?,
      );
}

/// Where the emergency medical kit and its epinephrine actually live.
///
/// No public database maps this per tail number, so the app ships curated
/// guidance by aircraft family and is explicit that the definitive answer is
/// to ask a flight attendant. False precision here would be worse than none.
class EmkLocation {
  const EmkLocation({
    required this.aircraftFamily,
    required this.stowage,
    this.kitCount = 1,
    this.notes = '',
  });

  final String aircraftFamily;
  final String stowage;
  final int kitCount;
  final String notes;
}
