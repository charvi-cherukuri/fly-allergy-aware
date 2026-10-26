/// How one flight went for a traveler with a food allergy — written after
/// landing, while it is fresh, so the next booking can learn from it.
class FlightExperience {
  FlightExperience({
    required this.id,
    required this.flightId,
    required this.recordedAt,
    this.tripId,
    this.foodRating = Rating.notSet,
    this.foodNotes = '',
    this.staffRating = Rating.notSet,
    this.staffNotes = '',
    this.concerns = '',
    this.askedAboutKit,
    this.kitEpinephrine = KitEpinephrine.unknown,
    this.medicationNotes = '',
    this.suggestions = '',
  });

  final String id;
  final String flightId;
  String? tripId;
  DateTime recordedAt;

  /// Food and allergen information the airline provided.
  Rating foodRating;
  String foodNotes;

  /// How the staff communicated and helped.
  Rating staffRating;
  String staffNotes;

  /// Allergy concerns or incidents, in the traveler's words.
  String concerns;

  /// Whether the traveler asked what the medical kit held. Null: not said.
  bool? askedAboutKit;
  KitEpinephrine kitEpinephrine;
  String medicationNotes;

  /// What would make the next flight better.
  String suggestions;

  bool get isEmpty =>
      foodRating == Rating.notSet &&
      staffRating == Rating.notSet &&
      askedAboutKit == null &&
      kitEpinephrine == KitEpinephrine.unknown &&
      <String>[foodNotes, staffNotes, concerns, medicationNotes, suggestions]
          .every((String s) => s.trim().isEmpty);

  Map<String, dynamic> toMap() => {
        'id': id,
        'flightId': flightId,
        'tripId': tripId,
        'recordedAt': recordedAt.millisecondsSinceEpoch,
        'foodRating': foodRating.name,
        'foodNotes': foodNotes,
        'staffRating': staffRating.name,
        'staffNotes': staffNotes,
        'concerns': concerns,
        'askedAboutKit': askedAboutKit == null ? null : (askedAboutKit! ? 1 : 0),
        'kitEpinephrine': kitEpinephrine.name,
        'medicationNotes': medicationNotes,
        'suggestions': suggestions,
      };

  factory FlightExperience.fromMap(Map<String, dynamic> m) => FlightExperience(
        id: m['id'] as String,
        flightId: (m['flightId'] as String?) ?? '',
        tripId: m['tripId'] as String?,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(m['recordedAt'] as int),
        foodRating: Rating.from(m['foodRating'] as String?),
        foodNotes: (m['foodNotes'] as String?) ?? '',
        staffRating: Rating.from(m['staffRating'] as String?),
        staffNotes: (m['staffNotes'] as String?) ?? '',
        concerns: (m['concerns'] as String?) ?? '',
        askedAboutKit: m['askedAboutKit'] == null ? null : (m['askedAboutKit'] as int) == 1,
        kitEpinephrine: KitEpinephrine.values.firstWhere(
          (KitEpinephrine k) => k.name == m['kitEpinephrine'],
          orElse: () => KitEpinephrine.unknown,
        ),
        medicationNotes: (m['medicationNotes'] as String?) ?? '',
        suggestions: (m['suggestions'] as String?) ?? '',
      );
}

enum Rating {
  notSet('Not rated'),
  good('Good'),
  okay('OK'),
  poor('Poor');

  const Rating(this.label);
  final String label;

  static Rating from(String? name) =>
      Rating.values.firstWhere((Rating r) => r.name == name, orElse: () => Rating.notSet);
}

/// What the plane's medical kit turned out to hold.
enum KitEpinephrine {
  autoInjector('Auto-injector'),
  vial('Vial and syringe'),
  none('No epinephrine'),
  unknown('Don’t know');

  const KitEpinephrine(this.label);
  final String label;
}
