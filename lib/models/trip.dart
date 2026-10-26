import 'dart:convert';

// Trips and allergen exposures — the travel journal.
//
// A trip is the unit people actually think in: "Tokyo in March", not "UA837".
// Flights are legs inside it, and everything that happens on the way — a
// request to the airline, a tray table with crumbs on it, a reaction at a hotel
// breakfast — hangs off the trip so it can be read back as one story.

/// The name a trip gets until the user types one: "Domestic travel" when the
/// destination is the traveler's home country, "International travel to
/// Japan" when it is not. The country stays in the international name so two
/// trips abroad can still be told apart.
///
/// [countryName] resolves a code to a name; it is passed in so this file stays
/// free of the country table.
String tripNameFor({
  required String destination,
  required String home,
  required String? Function(String code) countryName,
}) {
  final String? dest = countryName(destination);
  if (dest == null) return 'Travel';
  if (home.isNotEmpty && destination.toUpperCase() == home.toUpperCase()) {
    return 'Domestic travel';
  }
  if (home.isEmpty || countryName(home) == null) return 'Travel to $dest';
  return 'International travel to $dest';
}

/// Whether [name] is one the app made up rather than one the user typed —
/// including the "Trip to …" names earlier versions generated. Such names are
/// safe to replace when the destination or the travelers change.
bool isGeneratedTripName(String name) {
  final String n = name.trim();
  return n.isEmpty ||
      n == 'Trip' ||
      n == 'Travel' ||
      n == 'Domestic travel' ||
      n.startsWith('Trip to ') ||
      n.startsWith('Travel to ') ||
      n.startsWith('International travel to ');
}

/// One journey: a destination, a date range and the people on it.
class Trip {
  Trip({
    required this.id,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    this.destinationCountry = '',
    List<String>? travelerIds,
    this.notes = '',
    DateTime? createdAt,
  })  : travelerIds = travelerIds ?? <String>[],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;

  /// ISO 3166-1 alpha-2, e.g. "JP". Empty when unknown — trips carried over
  /// from the old flight list have no country, because a flight never had one.
  /// Drives the local emergency number and the language pack suggestions.
  String destinationCountry;

  /// First and last day, as dates. The time of day is ignored.
  DateTime startsOn;
  DateTime endsOn;

  /// Profile ids of the household members travelling. Empty means nobody has
  /// been picked yet, not "nobody is travelling".
  List<String> travelerIds;

  String notes;
  final DateTime createdAt;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// True from the first day through the end of the last day.
  bool isUnderway(DateTime now) {
    final today = _day(now);
    return !today.isBefore(_day(startsOn)) && !today.isAfter(_day(endsOn));
  }

  bool isUpcoming(DateTime now) => _day(startsOn).isAfter(_day(now));

  bool isPast(DateTime now) => _day(endsOn).isBefore(_day(now));

  /// Whole days until the trip starts; 0 on the day, negative once started.
  int daysUntil(DateTime now) =>
      _day(startsOn).difference(_day(now)).inDays;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'destinationCountry': destinationCountry,
        'startsOn': _day(startsOn).millisecondsSinceEpoch,
        'endsOn': _day(endsOn).millisecondsSinceEpoch,
        'travelerIds': travelerIds.join('|'),
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Trip.fromMap(Map<String, dynamic> m) => Trip(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        destinationCountry: (m['destinationCountry'] as String?) ?? '',
        startsOn: DateTime.fromMillisecondsSinceEpoch(m['startsOn'] as int),
        endsOn: DateTime.fromMillisecondsSinceEpoch(m['endsOn'] as int),
        travelerIds: ((m['travelerIds'] as String?) ?? '')
            .split('|')
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        notes: (m['notes'] as String?) ?? '',
        createdAt: m['createdAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );
}

/// Contact, or possible contact, with an allergen.
///
/// Distinct from a reaction on purpose. Most exposures cause nothing, and
/// those are exactly the ones nobody writes down — yet "peanut dust from the
/// next row, washed hands, nothing happened" is worth knowing the next time
/// someone asks how sensitive the allergy really is. When symptoms do follow,
/// the exposure links to the reaction rather than duplicating it.
class Exposure {
  Exposure({
    required this.id,
    required this.tripId,
    required this.occurredAt,
    this.profileId = '',
    this.flightId,
    List<String>? allergenNames,
    this.route = ExposureRoute.observedNearby,
    this.source = '',
    this.place = ExposurePlace.flight,
    this.placeName = '',
    this.row,
    List<String>? actions,
    this.outcome = ExposureOutcome.noSymptoms,
    this.reactionId,
    this.notes = '',
  })  : allergenNames = allergenNames ?? <String>[],
        actions = actions ?? <String>[];

  final String id;
  final String tripId;

  /// Who was exposed. Empty when unknown — records imported from the old
  /// cabin view never said.
  String profileId;

  /// Set when it happened on a particular flight leg.
  String? flightId;

  DateTime occurredAt;

  /// Names rather than enum values, so a custom allergen fits too.
  List<String> allergenNames;

  ExposureRoute route;

  /// What it came from: "seatmate's trail mix", "hotel breakfast pastry".
  String source;

  ExposurePlace place;

  /// The restaurant, hotel or airport, in the user's words.
  String placeName;

  /// Cabin row, when on a flight. Rows only, never seat letters.
  int? row;

  /// What was done about it, from [kExposureActions] or free text.
  List<String> actions;

  ExposureOutcome outcome;

  /// The reaction this led to, when it led to one.
  String? reactionId;

  String notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'tripId': tripId,
        'profileId': profileId,
        'flightId': flightId,
        'occurredAt': occurredAt.millisecondsSinceEpoch,
        'allergenNames': allergenNames.join('|'),
        'route': route.name,
        'source': source,
        'place': place.name,
        'placeName': placeName,
        'row': row,
        'actions': jsonEncode(actions),
        'outcome': outcome.name,
        'reactionId': reactionId,
        'notes': notes,
      };

  factory Exposure.fromMap(Map<String, dynamic> m) {
    var actions = <String>[];
    try {
      actions = (jsonDecode((m['actions'] as String?) ?? '[]') as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      // A damaged list of actions must not lose the exposure itself.
    }
    return Exposure(
      id: m['id'] as String,
      tripId: (m['tripId'] as String?) ?? '',
      profileId: (m['profileId'] as String?) ?? '',
      flightId: m['flightId'] as String?,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(m['occurredAt'] as int),
      allergenNames: ((m['allergenNames'] as String?) ?? '')
          .split('|')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      route: ExposureRoute.values.firstWhere(
        (r) => r.name == m['route'],
        orElse: () => ExposureRoute.observedNearby,
      ),
      source: (m['source'] as String?) ?? '',
      place: ExposurePlace.values.firstWhere(
        (p) => p.name == m['place'],
        orElse: () => ExposurePlace.other,
      ),
      placeName: (m['placeName'] as String?) ?? '',
      row: m['row'] as int?,
      actions: actions,
      outcome: ExposureOutcome.values.firstWhere(
        (o) => o.name == m['outcome'],
        orElse: () => ExposureOutcome.noSymptoms,
      ),
      reactionId: m['reactionId'] as String?,
      notes: (m['notes'] as String?) ?? '',
    );
  }
}

/// How the allergen reached the person, most direct first.
enum ExposureRoute {
  ingested('Ate or drank it'),
  skin('Skin contact'),
  surface('Residue on a surface'),
  airborne('In the air (dust, steam, cooking)'),
  crossContact('Possible cross-contact'),
  observedNearby('Seen nearby, no contact');

  const ExposureRoute(this.label);
  final String label;
}

enum ExposurePlace {
  flight('On a flight'),
  airport('Airport'),
  hotel('Hotel or rental'),
  restaurant('Restaurant or café'),
  transport('Train, bus, car or ship'),
  other('Somewhere else');

  const ExposurePlace(this.label);
  final String label;
}

enum ExposureOutcome {
  noSymptoms('No symptoms'),
  symptoms('Symptoms followed');

  const ExposureOutcome(this.label);
  final String label;
}

/// The usual responses, offered as one-tap choices. Recorded, never
/// recommended — the action plan is where advice comes from.
const kExposureActions = <String>[
  'Washed hands',
  'Wiped the surface',
  'Moved seats or tables',
  'Told the crew or staff',
  'Took an antihistamine',
  'Gave epinephrine',
  'Watched for symptoms',
];
