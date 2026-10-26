import 'allergen.dart';

/// Four levels, never three.
///
/// The research turned up failures in both directions in live App Store reviews —
/// almond butter scanned as "no almond detected", and "not a significant source of
/// fiber" flagged as gluten. Both are trust-fatal, so the model has to be able to
/// say "I don't know" and "be careful" as distinct answers.
///
/// Ordered by decreasing seriousness; [VerdictLevel.compareTo] via [index] gives
/// the correct precedence when combining per-allergen results.
enum VerdictLevel {
  /// A declared allergen the user must avoid is present in the product.
  unsafe,

  /// Cross-contact evidence: a precautionary phrase ("may contain", "shared
  /// equipment") or an Open Food Facts trace tag. Never collapses into [clear].
  caution,

  /// No ingredient data at all, or a machine translation with nothing in it —
  /// which cannot clear a label, because a word the translator dropped is a word
  /// the check never saw. The honest answer for text we cannot fully trust; it
  /// is emphatically not [clear].
  unknown,

  /// We found no match. Deliberately not called "safe": the app is asserting the
  /// absence of a match in the data it has, not the safety of the food.
  clear,
}

/// One allergen's worth of evidence within a scan.
class AllergenHit {
  const AllergenHit({
    this.allergen,
    this.customId,
    required this.label,
    required this.emoji,
    required this.severity,
    required this.level,
    required this.matchedTerms,
    this.sourceTags = const [],
    this.palPhrases = const [],
    this.highlightRanges = const [],
  });

  /// Builds a hit for one of the fourteen regulated allergens.
  AllergenHit.standard({
    required Allergen allergen,
    required this.severity,
    required this.level,
    required this.matchedTerms,
    this.sourceTags = const [],
    this.palPhrases = const [],
    this.highlightRanges = const [],
        // The parameter is non-null while the field is nullable, which is what
        // lets this constructor derive label and emoji without a null check.
        // ignore: prefer_initializing_formals
  })  : allergen = allergen,
        customId = null,
        label = allergen.label,
        emoji = allergen.emoji;

  /// Null when this hit came from a user-defined allergen rather than one of
  /// the fourteen regulated ones.
  final Allergen? allergen;

  /// Set instead of [allergen] for a user-defined trigger.
  final String? customId;

  /// Always populated — use this for display rather than branching on which
  /// of [allergen] and [customId] is set.
  final String label;
  final String emoji;

  final Severity severity;

  bool get isCustom => customId != null;

  /// The level this single allergen contributes to the overall verdict.
  final VerdictLevel level;

  /// Literal substrings found in the ingredient text, e.g. `['casein', 'whey']`.
  /// Shown to the user — "doesn't say which ingredient triggered it" is one of
  /// the most common complaints about competing apps.
  final List<String> matchedTerms;

  /// Open Food Facts tags that produced this hit, e.g. `['en:milk']`.
  final List<String> sourceTags;

  /// Precautionary phrases found, e.g. `['may contain traces of']`.
  final List<String> palPhrases;

  /// Character offsets into the ingredient text, for inline highlighting.
  final List<TextRangeHit> highlightRanges;

  bool get isFromCrossContact => palPhrases.isNotEmpty || sourceTags.any((t) => t.startsWith('trace:'));
}

/// A matched span in the ingredient text, so the UI can highlight in place.
class TextRangeHit {
  const TextRangeHit(this.start, this.end, this.term);
  final int start;
  final int end;
  final String term;
}

/// The complete result of checking one product against one profile.
class Verdict {
  const Verdict({
    required this.level,
    required this.hits,
    required this.headline,
    required this.detail,
    this.ingredientTextUsed,
  });

  final VerdictLevel level;

  /// Every allergen with evidence, worst first.
  final List<AllergenHit> hits;

  /// Short line for the result banner, e.g. "Contains milk".
  final String headline;

  /// Explanatory sentence beneath the headline.
  final String detail;

  /// The ingredient text the decision was made from, for highlighting.
  final String? ingredientTextUsed;
}
