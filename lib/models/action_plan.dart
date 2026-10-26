import 'dart:convert';

/// An airline-specific Anaphylaxis Action Plan — FRD 1.3.
///
/// The field shape deliberately mirrors the Phase 1 data model in Ashok's
/// prompt pack, so this can be lifted into Firestore later without a rewrite.
///
/// One hard boundary, taken from that pack: this stores **the user's own
/// physician-provided plan**. It is a record, not advice the app generates.
class ActionPlan {
  ActionPlan({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.airlineIataCode = '',
    this.airlineName = '',
    this.isDefault = false,
    this.patient = const PatientInfo(),
    this.epinephrine = const EpinephrineInfo(),
    this.medications = const <Medication>[],
    this.symptomSteps = const <SymptomStep>[],
    this.emergencyContacts = const <PlanContact>[],
    this.physician = const PhysicianInfo(),
    this.version = 1,
  });

  final String id;
  String title;
  String airlineIataCode;
  String airlineName;
  bool isDefault;
  PatientInfo patient;
  EpinephrineInfo epinephrine;
  List<Medication> medications;
  List<SymptomStep> symptomSteps;
  List<PlanContact> emergencyContacts;
  PhysicianInfo physician;
  final DateTime createdAt;
  DateTime updatedAt;
  int version;

  /// True when the auto-injector on this plan expires within 60 days.
  /// Expiry is silent — nothing tells you but the label on the device.
  bool get isExpiringSoon {
    final on = epinephrine.expiresOn;
    if (on == null) return false;
    final now = DateTime.now();
    final days = on.difference(DateTime(now.year, now.month, now.day)).inDays;
    return days <= 60;
  }

  bool get isExpired {
    final on = epinephrine.expiresOn;
    if (on == null) return false;
    final now = DateTime.now();
    return on.difference(DateTime(now.year, now.month, now.day)).inDays < 0;
  }

  /// Missing-required-field messages. Empty means the plan is usable.
  List<String> validate() {
    final out = <String>[];
    if (title.trim().isEmpty) out.add('Give the plan a title.');
    if (patient.name.trim().isEmpty) out.add('Add the patient name.');
    if (epinephrine.brand.trim().isEmpty && epinephrine.doseMg == null) {
      out.add('Add the auto-injector brand or dose.');
    }
    if (epinephrine.expiresOn == null) {
      out.add('Add the auto-injector expiry date.');
    }
    if (emergencyContacts.isEmpty) out.add('Add at least one emergency contact.');
    return out;
  }

  String get airlineLabel =>
      airlineName.isNotEmpty ? airlineName : (airlineIataCode.isNotEmpty ? airlineIataCode : 'Any airline');

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'airlineIataCode': airlineIataCode,
        'airlineName': airlineName,
        'isDefault': isDefault ? 1 : 0,
        'patient': jsonEncode(patient.toJson()),
        'epinephrine': jsonEncode(epinephrine.toJson()),
        'medications': jsonEncode(medications.map((e) => e.toJson()).toList()),
        'symptomSteps': jsonEncode(symptomSteps.map((e) => e.toJson()).toList()),
        'emergencyContacts':
            jsonEncode(emergencyContacts.map((e) => e.toJson()).toList()),
        'physician': jsonEncode(physician.toJson()),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'version': version,
      };

  static Map<String, dynamic> _obj(Object? v) {
    if (v == null) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(
          jsonDecode(v as String) as Map<dynamic, dynamic>);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static List<Map<String, dynamic>> _list(Object? v) {
    if (v == null) return const [];
    try {
      return (jsonDecode(v as String) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  factory ActionPlan.fromMap(Map<String, dynamic> m) => ActionPlan(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        airlineIataCode: (m['airlineIataCode'] as String?) ?? '',
        airlineName: (m['airlineName'] as String?) ?? '',
        isDefault: (m['isDefault'] as int? ?? 0) == 1,
        patient: PatientInfo.fromJson(_obj(m['patient'])),
        epinephrine: EpinephrineInfo.fromJson(_obj(m['epinephrine'])),
        medications:
            _list(m['medications']).map(Medication.fromJson).toList(),
        symptomSteps:
            _list(m['symptomSteps']).map(SymptomStep.fromJson).toList(),
        emergencyContacts:
            _list(m['emergencyContacts']).map(PlanContact.fromJson).toList(),
        physician: PhysicianInfo.fromJson(_obj(m['physician'])),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
        version: (m['version'] as int?) ?? 1,
      );
}

/// Who the plan is for.
class PatientInfo {
  const PatientInfo({this.name = '', this.dateOfBirth, this.weightKg});
  final String name;
  final DateTime? dateOfBirth;
  final double? weightKg;

  double? get weightLb => weightKg == null ? null : weightKg! * 2.2046226218;

  Map<String, dynamic> toJson() => {
        'name': name,
        'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
        'weightKg': weightKg,
      };

  factory PatientInfo.fromJson(Map<String, dynamic> j) => PatientInfo(
        name: (j['name'] as String?) ?? '',
        dateOfBirth: j['dateOfBirth'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['dateOfBirth'] as int),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
      );
}

/// The auto-injector this plan relies on.
class EpinephrineInfo {
  const EpinephrineInfo({
    this.brand = '',
    this.doseMg,
    this.injectorCount = 2,
    this.expiresOn,
    this.carryLocation = '',
  });

  final String brand;
  final double? doseMg;
  final int injectorCount;
  final DateTime? expiresOn;

  /// Where it physically is — "cabin bag, front pocket". The single most
  /// useful line on the whole plan to someone helping you.
  final String carryLocation;

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'doseMg': doseMg,
        'injectorCount': injectorCount,
        'expiresOn': expiresOn?.millisecondsSinceEpoch,
        'carryLocation': carryLocation,
      };

  factory EpinephrineInfo.fromJson(Map<String, dynamic> j) => EpinephrineInfo(
        brand: (j['brand'] as String?) ?? '',
        doseMg: (j['doseMg'] as num?)?.toDouble(),
        injectorCount: (j['injectorCount'] as int?) ?? 2,
        expiresOn: j['expiresOn'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['expiresOn'] as int),
        carryLocation: (j['carryLocation'] as String?) ?? '',
      );
}

/// A non-epinephrine medication the physician listed.
class Medication {
  const Medication({
    this.name = '',
    this.form = '',
    this.doseMg,
    this.route = '',
    this.notes = '',
  });

  final String name;
  final String form;
  final double? doseMg;
  final String route;
  final String notes;

  Map<String, dynamic> toJson() => {
        'name': name,
        'form': form,
        'doseMg': doseMg,
        'route': route,
        'notes': notes,
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        name: (j['name'] as String?) ?? '',
        form: (j['form'] as String?) ?? '',
        doseMg: (j['doseMg'] as num?)?.toDouble(),
        route: (j['route'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
      );
}

/// One tier of the physician's symptom-response ladder.
class SymptomStep {
  const SymptomStep({
    this.severity = 'mild',
    this.symptoms = const <String>[],
    this.actions = const <String>[],
  });

  final String severity;
  final List<String> symptoms;
  final List<String> actions;

  Map<String, dynamic> toJson() => {
        'severity': severity,
        'symptoms': symptoms,
        'actions': actions,
      };

  factory SymptomStep.fromJson(Map<String, dynamic> j) => SymptomStep(
        severity: (j['severity'] as String?) ?? 'mild',
        symptoms: ((j['symptoms'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        actions: ((j['actions'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Someone to call, as written on the plan.
class PlanContact {
  const PlanContact({
    this.name = '',
    this.relationship = '',
    this.phone = '',
    this.email = '',
  });

  final String name;
  final String relationship;
  final String phone;
  final String email;

  Map<String, dynamic> toJson() =>
      {'name': name, 'relationship': relationship, 'phone': phone, 'email': email};

  factory PlanContact.fromJson(Map<String, dynamic> j) => PlanContact(
        name: (j['name'] as String?) ?? '',
        relationship: (j['relationship'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
      );
}

/// The prescribing physician.
class PhysicianInfo {
  const PhysicianInfo({this.name = '', this.phone = '', this.clinic = ''});
  final String name;
  final String phone;
  final String clinic;

  Map<String, dynamic> toJson() =>
      {'name': name, 'phone': phone, 'clinic': clinic};

  factory PhysicianInfo.fromJson(Map<String, dynamic> j) => PhysicianInfo(
        name: (j['name'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        clinic: (j['clinic'] as String?) ?? '',
      );
}

/// A starting ladder for a new plan, mirroring how emergency care plans are
/// normally laid out. Every line is editable — this is scaffolding for the
/// user to replace with what their own doctor wrote, not clinical advice.
List<SymptomStep> defaultSymptomLadder() => <SymptomStep>[
      const SymptomStep(
        severity: 'mild',
        symptoms: <String>['Itchy mouth', 'A few hives', 'Mild stomach ache'],
        actions: <String>[
          'Stay with the person and watch them closely',
          'Follow the plan your doctor wrote for mild symptoms',
          'Tell cabin crew what is happening',
        ],
      ),
      const SymptomStep(
        severity: 'moderate',
        symptoms: <String>['Spreading hives', 'Repeated vomiting', 'Swelling of lips or face'],
        actions: <String>[
          'Get the auto-injector out and keep it in your hand',
          'Tell cabin crew this may become an emergency',
          'Follow your doctor’s written instructions for this tier',
        ],
      ),
      const SymptomStep(
        severity: 'severe',
        symptoms: <String>[
          'Trouble breathing',
          'Throat tightness',
          'Trouble swallowing',
          'Dizziness or faintness',
          'Pale or blue color',
        ],
        actions: <String>[
          'Use the epinephrine auto-injector now',
          'Tell cabin crew to call for medical help immediately',
          'Lie the person flat, legs raised, unless breathing is hard',
          'If vomiting or unresponsive, lay them on their side',
        ],
      ),
    ];
