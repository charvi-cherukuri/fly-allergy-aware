import 'allergen.dart';

/// A user-defined allergen outside the fourteen regulated ones.
///
/// FRD 1.1 asks for triggers beyond the Top 9. Sesame is already one of our
/// fourteen, but the genuinely unserved cases are things no labelling regime
/// covers: alpha-gal (mammalian meat), specific seeds, legumes, nightshades,
/// or a single tree-nut species when the rest are fine. Nobody's label says
/// "contains alpha-gal", so the user supplies the vocabulary themselves.
class CustomAllergen {
  CustomAllergen({
    required this.id,
    required this.name,
    required this.keywords,
    this.severity = Severity.severe,
    this.emoji = '⚠️',
    this.notes = '',
  });

  final String id;
  String name;

  /// The terms to look for in an ingredient list. Lowercased and matched with
  /// the same word-boundary rules as the built-in tables, so a user who types
  /// "nut" does not start matching "coconut".
  List<String> keywords;

  Severity severity;
  String emoji;
  String notes;

  /// Suggested starting vocabularies for triggers people actually ask about.
  /// The user can edit any of these — they are a starting point, not a claim
  /// to completeness.
  static const Map<String, List<String>> suggestions = {
    'Alpha-gal (mammalian meat)': [
      'beef', 'pork', 'lamb', 'mutton', 'venison', 'bison', 'goat', 'veal',
      'gelatin', 'gelatine', 'lard', 'tallow', 'suet', 'bacon', 'ham',
      'prosciutto', 'pancetta', 'chorizo', 'salami', 'pepperoni', 'bone broth',
      'beef stock', 'pork stock', 'rennet', 'carmine', 'glycerin', 'stearate',
      'magnesium stearate', 'oleic acid', 'collagen',
    ],
    'Corn': [
      'corn', 'cornstarch', 'corn starch', 'corn syrup', 'high fructose corn syrup',
      'maize', 'masa', 'hominy', 'polenta', 'grits', 'dextrose', 'maltodextrin',
      'xanthan gum', 'citric acid', 'zein', 'corn flour', 'cornmeal', 'popcorn',
    ],
    'Nightshades': [
      'tomato', 'potato', 'eggplant', 'aubergine', 'bell pepper', 'chili',
      'chilli', 'paprika', 'cayenne', 'pimento', 'tomatillo', 'goji',
      'ashwagandha', 'capsicum',
    ],
    'Sunflower seed': [
      'sunflower', 'sunflower seed', 'sunflower oil', 'sunflower lecithin',
      'helianthus', 'sunflower butter', 'sunbutter',
    ],
    'Poppy seed': ['poppy', 'poppy seed', 'papaver', 'mohn'],
    'Buckwheat': ['buckwheat', 'kasha', 'soba', 'fagopyrum'],
    'Coconut': [
      'coconut', 'coconut milk', 'coconut oil', 'coconut cream', 'copra',
      'coconut flour', 'coconut water', 'cocos nucifera', 'creamed coconut',
    ],
    'Legumes (beyond peanut/soy)': [
      'chickpea', 'garbanzo', 'lentil', 'pea protein', 'green pea', 'split pea',
      'fava', 'broad bean', 'kidney bean', 'black bean', 'pinto', 'navy bean',
      'cannellini', 'gram flour', 'besan', 'dal', 'guar gum', 'carob',
      'locust bean gum',
    ],
    'Kiwi': ['kiwi', 'kiwifruit', 'actinidia', 'chinese gooseberry'],
    'Banana / latex-fruit': [
      'banana', 'plantain', 'avocado', 'chestnut', 'latex', 'papaya', 'mango',
    ],
  };

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'keywords': keywords.join('|'),
        'severity': severity.name,
        'emoji': emoji,
        'notes': notes,
      };

  factory CustomAllergen.fromMap(Map<String, dynamic> m) => CustomAllergen(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        keywords: ((m['keywords'] as String?) ?? '')
            .split('|')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList(),
        severity: Severity.values.firstWhere(
          (s) => s.name == m['severity'],
          orElse: () => Severity.severe,
        ),
        emoji: (m['emoji'] as String?) ?? '⚠️',
        notes: (m['notes'] as String?) ?? '',
      );
}
