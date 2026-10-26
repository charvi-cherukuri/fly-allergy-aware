/// The allergen taxonomy: the union of the US FDA "Big 9" (FALCPA + sesame via the
/// FASTER Act) and the EU 14 (Reg. 1169/2011 Annex II).
///
/// The EU adds celery, mustard, sulfites, lupin and mollusks; the US adds nothing
/// the EU lacks. Mollusks are worth calling out — they are NOT a US major allergen,
/// so on a US label they can hide inside "natural flavor" with no declaration.
///
/// The display names are American ("Sulfites", "Mollusks"). The taxonomy tags
/// beside them keep the Open Food Facts spelling, which is British, because
/// those are keys into someone else's database rather than words anyone reads.
enum Allergen {
  milk('Milk', 'en:milk', '🥛'),
  egg('Egg', 'en:eggs', '🥚'),
  peanut('Peanut', 'en:peanuts', '🥜'),
  treeNut('Tree nuts', 'en:nuts', '🌰'),
  soy('Soy', 'en:soybeans', '🫘'),
  wheat('Wheat / gluten', 'en:gluten', '🌾'),
  fish('Fish', 'en:fish', '🐟'),
  shellfish('Crustacean shellfish', 'en:crustaceans', '🦐'),
  sesame('Sesame', 'en:sesame-seeds', '🫓'),
  mollusc('Mollusks', 'en:molluscs', '🦪'),
  celery('Celery', 'en:celery', '🥬'),
  mustard('Mustard', 'en:mustard', '🌭'),
  lupin('Lupin', 'en:lupin', '🌱'),
  sulphite('Sulfites', 'en:sulphur-dioxide-and-sulphites', '🍷');

  const Allergen(this.label, this.offTag, this.emoji);

  /// Human-readable name shown in the UI.
  final String label;

  /// The canonical Open Food Facts taxonomy tag, matched against
  /// `allergens_tags` and `traces_tags`.
  final String offTag;

  final String emoji;

  static Allergen? fromName(String name) {
    for (final a in Allergen.values) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// True for the nine US major allergens. Everything else is EU-only, which
  /// matters because a US label is not required to declare it at all.
  bool get isUsMajor => const {
        Allergen.milk,
        Allergen.egg,
        Allergen.peanut,
        Allergen.treeNut,
        Allergen.soy,
        Allergen.wheat,
        Allergen.fish,
        Allergen.shellfish,
        Allergen.sesame,
      }.contains(this);
}

/// How strictly to treat evidence for a given allergen.
///
/// This is the axis almost no competitor models. Someone with a preference and
/// someone at risk of anaphylaxis are asking completely different questions of
/// the same ingredient list, and in particular they disagree about whether
/// "may contain" is disqualifying.
enum Severity {
  // These say how strictly to avoid a food — not how bad a reaction will be.
  // Reactions can change quickly, so no label here promises a mild one.

  /// Avoiding by choice. Trace evidence is informational only.
  preference('Prefer to avoid', 'Avoiding by choice. Traces are only noted.'),

  /// Intolerance. Trace evidence is a caution, not a block.
  intolerance('Avoid', 'Makes me unwell. Traces are a warning.'),

  /// Anaphylaxis risk. Trace evidence blocks the product outright.
  severe('Strict', 'Could cause a serious reaction. Avoid even traces.');

  const Severity(this.label, this.description);
  final String label;
  final String description;

  /// Whether cross-contact evidence alone is enough to render a product unsafe.
  bool get blocksOnTrace => this == Severity.severe;
}
