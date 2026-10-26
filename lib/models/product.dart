/// A food product, normalised from Open Food Facts or USDA FoodData Central.
class Product {
  const Product({
    required this.barcode,
    required this.name,
    this.brand,
    this.quantity,
    this.imageUrl,
    this.ingredientsText,
    this.ingredientsLanguage,
    this.allergenTags = const [],
    this.tracesTags = const [],
    this.additivesTags = const [],
    this.labelsTags = const [],
    this.source = ProductSource.openFoodFacts,
    this.ingredientsComplete = false,
    this.fetchedAt,
    this.translatedFrom,
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? quantity;
  final String? imageUrl;

  /// Verbatim label text. Open Food Facts wraps allergens in `_underscores_`;
  /// strip those before matching, but treat their presence as a high-confidence
  /// signal that OFF's own parser identified an allergen at that position.
  final String? ingredientsText;

  /// Language of the checked text; null means unverified.
  final String? ingredientsLanguage;

  /// From `allergens_tags` — the declared "Contains" statement.
  final List<String> allergenTags;

  /// From `traces_tags` — the "may contain" statement. The cross-contact signal.
  final List<String> tracesTags;

  final List<String> additivesTags;
  final List<String> labelsTags;

  final ProductSource source;

  /// True when OFF's `states_tags` contains `en:ingredients-completed`. When
  /// false, an empty allergen list means nothing and the verdict must be unknown.
  final bool ingredientsComplete;

  final DateTime? fetchedAt;

  /// The language this label was translated OUT of, when the text the matcher
  /// reads is a machine translation rather than what was printed on the pack.
  /// Null for everything the app read directly.
  final String? translatedFrom;

  /// True when the ingredient text is a machine translation. The matcher treats
  /// these differently, and so must any screen that reports a verdict.
  ///
  /// Keyed off [source] as well as [translatedFrom], and that is deliberate.
  /// [source] has been persisted since the first schema, so it survives a save
  /// and a reload even on a database whose migration did not run. Losing this
  /// flag is not a cosmetic bug: a translated label reloaded from history
  /// without it is re-checked as ordinary label text, and comes back clear.
  bool get isTranslated =>
      translatedFrom != null || source == ProductSource.translation;

  bool get hasIngredients =>
      ingredientsText != null && ingredientsText!.trim().isNotEmpty;

  String get displayName => name.trim().isEmpty ? barcode : name.trim();

  /// Carries [translatedFrom] across untouched. Dropping it here would quietly
  /// turn a capped translated verdict back into a clear one.
  Product copyWith({
    String? name,
    String? ingredientsText,
    DateTime? fetchedAt,
  }) {
    return Product(
      barcode: barcode,
      name: name ?? this.name,
      brand: brand,
      quantity: quantity,
      imageUrl: imageUrl,
      ingredientsText: ingredientsText ?? this.ingredientsText,
      ingredientsLanguage:
          ingredientsText == null || ingredientsText == this.ingredientsText
          ? ingredientsLanguage
          : null,
      allergenTags: allergenTags,
      tracesTags: tracesTags,
      additivesTags: additivesTags,
      labelsTags: labelsTags,
      source: source,
      ingredientsComplete: ingredientsComplete,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      translatedFrom: translatedFrom,
    );
  }

  Map<String, dynamic> toMap() => {
    'barcode': barcode,
    'name': name,
    'brand': brand,
    'quantity': quantity,
    'imageUrl': imageUrl,
    'ingredientsText': ingredientsText,
    'ingredientsLanguage': ingredientsLanguage,
    'allergenTags': allergenTags.join(','),
    'tracesTags': tracesTags.join(','),
    'additivesTags': additivesTags.join(','),
    'labelsTags': labelsTags.join(','),
    'source': source.name,
    'ingredientsComplete': ingredientsComplete ? 1 : 0,
    'fetchedAt': (fetchedAt ?? DateTime.now()).millisecondsSinceEpoch,
    'translatedFrom': translatedFrom,
  };

  static List<String> _split(Object? v) {
    final s = (v as String?) ?? '';
    if (s.trim().isEmpty) return const [];
    return s.split(',').where((e) => e.trim().isNotEmpty).toList();
  }

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    barcode: m['barcode'] as String,
    name: (m['name'] as String?) ?? '',
    brand: m['brand'] as String?,
    quantity: m['quantity'] as String?,
    imageUrl: m['imageUrl'] as String?,
    ingredientsText: m['ingredientsText'] as String?,
    ingredientsLanguage: m['ingredientsLanguage'] as String?,
    allergenTags: _split(m['allergenTags']),
    tracesTags: _split(m['tracesTags']),
    additivesTags: _split(m['additivesTags']),
    labelsTags: _split(m['labelsTags']),
    source: ProductSource.values.firstWhere(
      (s) => s.name == m['source'],
      orElse: () => ProductSource.openFoodFacts,
    ),
    ingredientsComplete: (m['ingredientsComplete'] as int? ?? 0) == 1,
    fetchedAt: m['fetchedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['fetchedAt'] as int),
    translatedFrom: m['translatedFrom'] as String?,
  );

  /// A product built from an OCR'd label rather than a database lookup.
  factory Product.fromOcr(
    String text, {
    String? translatedFrom,
    String? ingredientsLanguage,
  }) => Product(
    barcode: 'ocr-${DateTime.now().millisecondsSinceEpoch}',
    name: translatedFrom == null ? 'Scanned label' : 'Translated text',
    ingredientsText: text,
    ingredientsLanguage: translatedFrom == null ? ingredientsLanguage : 'en',
    // A translation is its own source, not a label photo: the words the
    // matcher reads were produced by a model, and may have been typed or
    // pasted rather than photographed at all.
    source: translatedFrom == null
        ? ProductSource.ocr
        : ProductSource.translation,
    ingredientsComplete: true,
    fetchedAt: DateTime.now(),
    translatedFrom: translatedFrom,
  );
}

enum ProductSource {
  openFoodFacts('Open Food Facts'),
  usda('USDA FoodData Central'),
  ocr('Label photo'),
  translation('Machine translation'),
  cache('Saved offline');

  const ProductSource(this.label);
  final String label;
}
