import 'dart:convert';

import 'allergen.dart';
import 'custom_allergen.dart';

/// One person in the household. The app is built around the fact that the
/// allergic person is often not the one holding the phone — the parent, the
/// spouse, the grandparent doing the shopping. Every competing app assumes
/// one account equals one body.
class Profile {
  Profile({
    required this.id,
    required this.name,
    Map<Allergen, Severity>? allergens,
    List<CustomAllergen>? customAllergens,
    this.avoidPalWhenUnsure = true,
    this.notes = '',
    this.isChild = false,
    this.homeCountry = '',
  })  : allergens = allergens ?? {},
        customAllergens = customAllergens ?? [];

  final String id;
  String name;

  /// The regulated allergens this person avoids, each with its own strictness.
  Map<Allergen, Severity> allergens;

  /// User-defined triggers outside the fourteen regulated ones — alpha-gal,
  /// corn, specific seeds. Matched by the same engine against keywords the
  /// user supplies, because no labelling regime declares these.
  List<CustomAllergen> customAllergens;

  /// When a product's data is incomplete, prefer caution over a clear verdict.
  bool avoidPalWhenUnsure;

  /// Free text shown on the chef card, e.g. "cooked in shared oil is fine".
  String notes;

  bool isChild;

  /// Where this person lives, as an ISO 3166-1 alpha-2 code ("US"). Empty
  /// when unknown. Decides whether a trip is domestic or international, and
  /// which emergency number applies when no trip is underway.
  String homeCountry;

  bool get isEmpty => allergens.isEmpty && customAllergens.isEmpty;

  List<Allergen> get sorted {
    final list = allergens.keys.toList();
    list.sort((a, b) {
      final s = allergens[b]!.index.compareTo(allergens[a]!.index);
      return s != 0 ? s : a.label.compareTo(b.label);
    });
    return list;
  }

  bool get hasSevere =>
      allergens.values.any((s) => s == Severity.severe) ||
      customAllergens.any((c) => c.severity == Severity.severe);

  Severity severityOf(Allergen a) => allergens[a] ?? Severity.preference;

  String get summary {
    if (isEmpty) return 'No allergens set';
    return [
      ...sorted.map((a) => a.label),
      ...customAllergens.map((c) => c.name),
    ].join(', ');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'allergens': jsonEncode(
          allergens.map((k, v) => MapEntry(k.name, v.name)),
        ),
        'customAllergens':
            jsonEncode(customAllergens.map((c) => c.toMap()).toList()),
        'avoidPalWhenUnsure': avoidPalWhenUnsure ? 1 : 0,
        'notes': notes,
        'isChild': isChild ? 1 : 0,
        'homeCountry': homeCountry,
      };

  factory Profile.fromMap(Map<String, dynamic> m) {
    final raw = jsonDecode((m['allergens'] as String?) ?? '{}') as Map<String, dynamic>;
    final parsed = <Allergen, Severity>{};
    raw.forEach((k, v) {
      final a = Allergen.fromName(k);
      if (a == null) return;
      parsed[a] = Severity.values.firstWhere(
        (s) => s.name == v,
        orElse: () => Severity.severe,
      );
    });
    final customRaw = (m['customAllergens'] as String?) ?? '[]';
    final customs = <CustomAllergen>[];
    try {
      for (final e in jsonDecode(customRaw) as List<dynamic>) {
        customs.add(CustomAllergen.fromMap(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>)));
      }
    } catch (_) {
      // A malformed custom-allergen blob must not lose the whole profile —
      // the regulated allergens are the more critical half of the record.
    }
    return Profile(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? 'Me',
      allergens: parsed,
      customAllergens: customs,
      avoidPalWhenUnsure: (m['avoidPalWhenUnsure'] as int? ?? 1) == 1,
      notes: (m['notes'] as String?) ?? '',
      isChild: (m['isChild'] as int? ?? 0) == 1,
      homeCountry: (m['homeCountry'] as String?) ?? '',
    );
  }
}
