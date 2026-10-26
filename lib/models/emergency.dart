// The emergency layer. No scanner app in the category ships any of this —
// the one app that ever did (Allergy Force) has 15 ratings and has not been
// updated since June 2021.

import 'dart:convert';

/// An epinephrine auto-injector the user carries. Expiry matters because a
/// device past its date can lose potency, and expiry is silent — nothing
/// reminds you but the label.
class EpiPen {
  EpiPen({
    required this.id,
    required this.label,
    required this.expiresOn,
    this.brand = '',
    this.location = '',
    this.remindDaysBefore = 30,
  });

  final String id;

  /// e.g. "School bag", "Kitchen drawer", "Mom's bag".
  String label;

  DateTime expiresOn;
  String brand;
  String location;
  int remindDaysBefore;

  int get daysUntilExpiry =>
      expiresOn.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;

  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => !isExpired && daysUntilExpiry <= remindDaysBefore;

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'expiresOn': expiresOn.millisecondsSinceEpoch,
        'brand': brand,
        'location': location,
        'remindDaysBefore': remindDaysBefore,
      };

  factory EpiPen.fromMap(Map<String, dynamic> m) => EpiPen(
        id: m['id'] as String,
        label: (m['label'] as String?) ?? 'Auto-injector',
        expiresOn: DateTime.fromMillisecondsSinceEpoch(m['expiresOn'] as int),
        brand: (m['brand'] as String?) ?? '',
        location: (m['location'] as String?) ?? '',
        remindDaysBefore: (m['remindDaysBefore'] as int?) ?? 30,
      );
}

/// Someone to reach during a reaction.
class EmergencyContact {
  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship = '',
  });

  final String id;
  String name;
  String phone;
  String relationship;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  factory EmergencyContact.fromMap(Map<String, dynamic> m) => EmergencyContact(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        relationship: (m['relationship'] as String?) ?? '',
      );
}

/// A recorded reaction. Closing the loop between what was eaten and what
/// happened is something no app in the category does — InTolerApp comes
/// closest and still doesn't join it to scan history.
class ReactionLog {
  ReactionLog({
    required this.id,
    required this.profileId,
    required this.occurredAt,
    required this.symptoms,
    this.suspectedFood = '',
    this.barcode,
    this.epiUsed = false,
    this.soughtCare = false,
    this.notes = '',
    this.severityRating = 3,
    this.tripId,
    this.exposureId,
    List<DateTime>? epiDoses,
    List<TimelineNote>? timeline,
  })  : epiDoses = epiDoses ?? <DateTime>[],
        timeline = timeline ?? <TimelineNote>[];

  final String id;
  final String profileId;
  final DateTime occurredAt;

  /// Free-form list, e.g. ['Hives', 'Throat tightness'].
  List<String> symptoms;

  String suspectedFood;

  /// Links back to the scan that preceded it, when there was one.
  String? barcode;

  bool epiUsed;
  bool soughtCare;
  String notes;

  /// 1 (mild) to 5 (anaphylaxis).
  int severityRating;

  /// The trip it happened on, when it happened while travelling.
  String? tripId;

  /// The logged exposure that led to it, when there was one.
  String? exposureId;

  /// When each epinephrine dose was given, in order. The first question
  /// paramedics and the emergency department ask, and the one nobody can
  /// answer from memory afterwards.
  List<DateTime> epiDoses;

  /// Timestamped notes — typed, or spoken during emergency mode — so the
  /// sequence of symptoms survives into the record.
  List<TimelineNote> timeline;

  Map<String, dynamic> toMap() => {
        'id': id,
        'profileId': profileId,
        'occurredAt': occurredAt.millisecondsSinceEpoch,
        'symptoms': symptoms.join('|'),
        'suspectedFood': suspectedFood,
        'barcode': barcode,
        'epiUsed': epiUsed ? 1 : 0,
        'soughtCare': soughtCare ? 1 : 0,
        'notes': notes,
        'severityRating': severityRating,
        'tripId': tripId,
        'exposureId': exposureId,
        'epiDoses': epiDoses.map((d) => d.millisecondsSinceEpoch).join('|'),
        'timeline': jsonEncode(timeline.map((t) => t.toMap()).toList()),
      };

  factory ReactionLog.fromMap(Map<String, dynamic> m) => ReactionLog(
        id: m['id'] as String,
        profileId: m['profileId'] as String,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(m['occurredAt'] as int),
        symptoms: ((m['symptoms'] as String?) ?? '')
            .split('|')
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        suspectedFood: (m['suspectedFood'] as String?) ?? '',
        barcode: m['barcode'] as String?,
        epiUsed: (m['epiUsed'] as int? ?? 0) == 1,
        soughtCare: (m['soughtCare'] as int? ?? 0) == 1,
        notes: (m['notes'] as String?) ?? '',
        severityRating: (m['severityRating'] as int?) ?? 3,
        tripId: m['tripId'] as String?,
        exposureId: m['exposureId'] as String?,
        epiDoses: ((m['epiDoses'] as String?) ?? '')
            .split('|')
            .map(int.tryParse)
            .whereType<int>()
            .map(DateTime.fromMillisecondsSinceEpoch)
            .toList(),
        timeline: TimelineNote.decodeList(m['timeline'] as String?),
      );
}

/// One timestamped line in a reaction's timeline.
class TimelineNote {
  const TimelineNote({required this.at, required this.text});

  final DateTime at;
  final String text;

  Map<String, dynamic> toMap() => {
        'at': at.millisecondsSinceEpoch,
        'text': text,
      };

  /// Never throws: a damaged timeline must not lose the reaction it belongs to.
  static List<TimelineNote> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <TimelineNote>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .map((m) => TimelineNote(
                at: DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
                text: (m['text'] as String?) ?? '',
              ))
          .toList();
    } catch (_) {
      return <TimelineNote>[];
    }
  }
}

/// The standard symptom vocabulary, ordered mild → severe, mirroring the
/// structure of the FARE / AAP Food Allergy & Anaphylaxis Emergency Care Plan.
const kSymptomOptions = <String>[
  'Itchy mouth',
  'Hives / rash',
  'Swelling (lips, face, eyes)',
  'Stomach pain',
  'Nausea / vomiting',
  'Diarrhea',
  'Runny nose / sneezing',
  'Coughing',
  'Wheezing',
  'Throat tightness',
  'Trouble breathing',
  'Trouble swallowing',
  'Dizziness / faintness',
  'Pale or blue color',
  'Loss of consciousness',
];

/// Symptoms that indicate anaphylaxis and mean epinephrine now, then 911.
const kAnaphylaxisSymptoms = <String>{
  'Throat tightness',
  'Trouble breathing',
  'Trouble swallowing',
  'Wheezing',
  'Dizziness / faintness',
  'Pale or blue color',
  'Loss of consciousness',
};
