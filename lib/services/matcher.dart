/// The decision engine.
///
/// Everything in here is pure and synchronous: same product plus same profile
/// always gives the same verdict, with no I/O in the middle. That is what makes
/// it testable, and this is the one file in the app where a bug can put someone
/// in an ambulance.
library;

import 'dart:math' as math;

import '../data/allergen_keywords.dart';
import '../data/pal_phrases.dart';
import '../models/allergen.dart';
import '../models/custom_allergen.dart';
import '../models/product.dart';
import '../models/profile.dart';
import '../models/verdict.dart';

class AllergenMatcher {
  const AllergenMatcher._();

  /// How far past a precautionary phrase to look for the allergen it names.
  /// "May contain peanuts and tree nuts" needs a window; a whole ingredient
  /// list does not.
  static const int palWindowChars = 120;

  // ---------------------------------------------------------------------
  // Public entry point
  // ---------------------------------------------------------------------

  static Verdict evaluate({
    required Product product,
    required Profile profile,
  }) {
    // 1. Nothing to check against. Custom allergens count: a profile that only
    //    tracks alpha-gal is a real profile.
    if (profile.isEmpty) {
      // Returns before the floors below, so the translation rule has to be
      // applied here too: an empty profile checked against a machine
      // translation would otherwise paint a green banner over translated text.
      if (product.isTranslated) {
        return const Verdict(
          level: VerdictLevel.unknown,
          hits: [],
          headline: 'No allergens set',
          detail:
              'This profile has no allergens yet, and this is a machine '
              'translation, which cannot clear a label on its own. Add the '
              'allergens this profile needs to avoid.',
        );
      }
      return const Verdict(
        level: VerdictLevel.clear,
        hits: [],
        headline: 'No allergens set',
        detail:
            'This profile has no allergens yet. Add the ones it needs to avoid '
            'and every scan will be checked against them.',
      );
    }

    // 2. Nothing to check. An empty allergen list is never a clear verdict —
    //    a product we cannot read is unknown, not safe.
    if (!product.hasIngredients &&
        product.allergenTags.isEmpty &&
        product.tracesTags.isEmpty) {
      return const Verdict(
        level: VerdictLevel.unknown,
        hits: [],
        headline: 'No ingredient data',
        detail:
            'This product has no ingredient list and no allergen tags in the '
            'database, so nothing could be checked. Read the pack before eating.',
      );
    }

    // 3. Fold the label text into the shape the keyword tables are written in.
    final text = normalise(product.ingredientsText ?? '');

    // 4. Exclusion pass first, so its spans are available to every later match.
    final exclusions = findTerms(text, kGlobalExclusions);

    // 7 (part one). Precautionary phrases and the window each one governs, so
    //    a keyword inside "may contain peanuts" is never read as an ingredient.
    final palHits = _palHits(text);
    final windows = [
      for (final p in palHits) _PalWindow(p, _windowEnd(text, p, palHits)),
    ];

    // Keyword hits for every allergen, not just the profile's: attributing a
    // "may contain soy" to a milk-only profile would be wrong, and we can only
    // tell that soy was named if we look for allergens the user does not have.
    final keywordHits = <Allergen, List<TextRangeHit>>{
      for (final a in Allergen.values)
        a: _reject(
          findTerms(text, kAllergenKeywords[a] ?? const []),
          exclusions,
        ),
    };

    // 5. The user's own vocabulary, run through exactly the same primitives:
    //    word-boundary matching, the exclusion pass, and the precautionary
    //    windows below. The only difference is that there is no tag pass —
    //    see step 6b.
    final customTerms = <String, List<String>>{
      for (final c in profile.customAllergens)
        c.id: validateKeywords(c.keywords),
    };
    final customKeywordHits = <String, List<TextRangeHit>>{
      for (final c in profile.customAllergens)
        c.id: _reject(
          findTerms(text, customTerms[c.id] ?? const []),
          _exclusionsForCustom(exclusions, customTerms[c.id] ?? const []),
        ),
    };

    bool insideWindow(TextRangeHit h) =>
        windows.any((w) => h.start >= w.phrase.start && h.start < w.end);

    final evidence = <Allergen, _Evidence>{
      for (final entry in profile.allergens.entries)
        entry.key: _Evidence.standard(entry.key, entry.value),
    };
    final customEvidence = <String, _Evidence>{
      for (final c in profile.customAllergens) c.id: _Evidence.custom(c),
    };

    // 6. Two independent matchers, unioned.
    //
    // Open Food Facts `allergens_tags` is the output of a volunteer typing the
    // ingredient list into a form, and it is missing or incomplete on roughly a
    // third of US products. Trusting the tags alone produces false clears;
    // trusting the text alone misses products whose ingredient field is blank
    // but whose tags are filled in. Both run, and the worse answer wins.
    for (final e in evidence.values) {
      final a = e.allergen;
      if (a == null) continue;
      _applyTags(e, a, product);
      _applyText(
        e,
        a,
        keywordHits[a] ?? const [],
        text,
        exclusions,
        insideWindow,
      );
    }

    // 6b. One matcher only, because there is no second one to union with.
    //
    //     No labelling regime declares alpha-gal or corn, so there is no
    //     `allergens_tags` equivalent and no ambiguous-term table: the
    //     ingredient text is the sole source of evidence. That makes the
    //     no-ingredient-text floor below load-bearing for custom allergens in
    //     a way it is not for the regulated fourteen — without a text there is
    //     literally nothing to check, and the answer has to be unknown.
    for (final c in profile.customAllergens) {
      final e = customEvidence[c.id];
      if (e == null) continue;
      _applyDeclared(e, customKeywordHits[c.id] ?? const [], insideWindow);
    }

    // 7 (part two). Attribute each precautionary phrase to the allergens it
    //    names, or to all of them when it names none.
    _applyPal(
      evidence,
      customEvidence,
      windows,
      keywordHits,
      customKeywordHits,
      profile,
    );

    // 11. Worst level wins overall; hits are sorted worst first. Standard and
    //     custom hits live in one list and fold into one level.
    final hits =
        [
          ...evidence.values,
          ...customEvidence.values,
        ].where((e) => e.isHit).toList()..sort((a, b) {
          final byLevel = a.level.index.compareTo(b.level.index);
          return byLevel != 0 ? byLevel : a.label.compareTo(b.label);
        });

    var level = hits.isEmpty
        ? VerdictLevel.clear
        : hits.map((e) => e.level).reduce(_worse);

    // A clear result we reached without ever seeing an ingredient list is not
    // a clear result. We checked tags; tags are a declaration of what is
    // present, never a declaration of what is absent.
    final noTextFloor = level == VerdictLevel.clear && !product.hasIngredients;
    if (noTextFloor) level = VerdictLevel.unknown;

    // 9. The user asked us to prefer caution when the record is incomplete.
    final incompleteFloor =
        level == VerdictLevel.clear &&
        profile.avoidPalWhenUnsure &&
        product.hasIngredients &&
        !product.ingredientsComplete;
    if (incompleteFloor) level = VerdictLevel.caution;

    // 10. A machine translation can raise an alarm. It can never clear a
    // label. Google documents the on-device translator as "intended for casual
    // and simple translations", and between two non-English languages it
    // pivots through English — so a word it drops is a word this matcher never
    // sees, and a word it never sees reads as an absence. Absence is the one
    // thing this app does not infer from a weaker source. A hit still stands:
    // a translation naming peanut is worth acting on either way.
    final translationFloor =
        level == VerdictLevel.clear && product.isTranslated;
    if (translationFloor) level = VerdictLevel.unknown;

    // An English keyword table cannot establish absence in unverified text.
    final languageFloor =
        level == VerdictLevel.clear && product.ingredientsLanguage != 'en';
    if (languageFloor) level = VerdictLevel.unknown;

    return Verdict(
      level: level,
      hits: hits.map((e) => e.toHit()).toList(),
      headline: languageFloor
          ? 'Ingredient language not verified'
          : _headline(level, hits, translationFloor: translationFloor),
      detail: languageFloor
          ? 'The matcher checks English ingredient text. Confirm the full list is in English or translate it first. No match does not establish that this label is safe.'
          : _detail(
              level: level,
              evidence: hits,
              product: product,
              profile: profile,
              incompleteFloor: incompleteFloor,
              noTextFloor: noTextFloor,
              translationFloor: translationFloor,
            ),
      ingredientTextUsed: text.isEmpty ? null : text,
    );
  }

  // ---------------------------------------------------------------------
  // Text primitives — public so the tests can pin them down directly
  // ---------------------------------------------------------------------

  /// Folds raw label text into the shape the keyword tables are written in.
  ///
  /// All offsets in a [Verdict] are into the *normalised* string, which is why
  /// [Verdict.ingredientTextUsed] carries it: the UI highlights that text, not
  /// the raw field.
  static String normalise(String raw) {
    final lower = raw.toLowerCase();
    final buf = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final c = lower[i];
      final folded = _folds[c];
      if (folded != null) {
        buf.write(folded);
        continue;
      }
      // Open Food Facts wraps allergens it recognised in _underscores_. Swap
      // them for spaces rather than deleting them so "sugar,_milk_" cannot
      // become a single run-together word.
      if (c == '_') {
        buf.write(' ');
        continue;
      }
      if (_dropped.contains(c)) continue;
      buf.write(c);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Every word-boundary occurrence of every term, sorted by position.
  ///
  /// Word boundary is mandatory and non-negotiable: a plain `contains()` reads
  /// `coconut` as a nut, `buckwheat` as wheat and `eggplant` as egg. A trailing
  /// plural "s" is accepted as part of the boundary so "caseinates" still hits
  /// "caseinate".
  static List<TextRangeHit> findTerms(String normalised, List<String> terms) {
    final out = <TextRangeHit>[];
    if (normalised.isEmpty) return out;
    for (final raw in terms) {
      final term = normalise(raw);
      if (term.isEmpty) continue;
      var from = 0;
      while (from <= normalised.length - term.length) {
        final start = normalised.indexOf(term, from);
        if (start < 0) break;
        from = start + 1;
        if (start > 0 && _isWordChar(normalised.codeUnitAt(start - 1))) {
          continue;
        }
        final end = _boundedEnd(normalised, start + term.length);
        if (end < 0) continue;
        out.add(TextRangeHit(start, end, raw));
      }
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  /// The precautionary phrases present in the text, longest form only.
  static List<String> findPalPhrases(String normalised) {
    final seen = <String>{};
    final out = <String>[];
    for (final h in _palHits(normalised)) {
      if (seen.add(h.term)) out.add(h.term);
    }
    return out;
  }

  /// Cleans a user-supplied keyword list before anything is matched with it.
  ///
  /// The fourteen regulated allergens ship with vocabularies that were written
  /// and tested here. A custom allergen's vocabulary is typed by whoever owns
  /// the phone, at whatever hour they got the diagnosis, and two things in it
  /// will quietly wreck the scanner:
  ///
  /// * **Keywords under three characters.** Word boundaries stop `nut` reading
  ///   `coconut`, but they cannot stop `ox` reading "ox" in an ox-tail stock,
  ///   or `pb`, `gm`, `hf` matching abbreviations all over a label. A matcher
  ///   that flags every product is a matcher people stop reading, and that is
  ///   the same failure as flagging none. Three characters is the shortest
  ///   length that still admits the real short names — soy, egg, nut, cod,
  ///   rye, pea — so the floor sits there rather than higher.
  /// * **Duplicates.** The same term twice reports the same evidence twice and
  ///   makes one keyword look like corroboration from two.
  ///
  /// Terms are folded through [normalise] here so the stored vocabulary and
  /// the matched text are in the same shape, and so `Beef` and `beef` collapse
  /// to one entry.
  static List<String> validateKeywords(List<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final term in raw) {
      final folded = normalise(term);
      if (folded.length < 3) continue;
      if (seen.add(folded)) out.add(folded);
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // Matching stages
  // ---------------------------------------------------------------------

  static void _applyTags(_Evidence e, Allergen allergen, Product product) {
    // Does the record name a specific tree nut anywhere? If it does, a bare
    // "nuts" tag alongside it is not the only thing we are going on.
    final namesSpecies = product.allergenTags.any((t) {
      final tag = _canonical(t);
      return tagAllergen(tag) == Allergen.treeNut &&
          !kUnspecifiedTreeNutTags.contains(tag);
    });

    for (final raw in product.allergenTags) {
      final tag = _canonical(raw);
      if (tagAllergen(tag) != allergen) continue;
      e.tags.add(tag);
      // 10. `en:nuts` on its own means "some tree nut, unspecified". Someone
      //     allergic to cashew alone should not be blocked out of every product
      //     a contributor tagged with the umbrella term.
      if (allergen == Allergen.treeNut &&
          kUnspecifiedTreeNutTags.contains(tag) &&
          !namesSpecies) {
        e.unspecifiedTreeNut = true;
        e.raise(VerdictLevel.caution);
      } else {
        e.declared = true;
        e.raise(VerdictLevel.unsafe);
      }
    }

    for (final raw in product.tracesTags) {
      final tag = _canonical(raw);
      if (tagAllergen(tag) != allergen) continue;
      // The 'trace:' prefix is what AllergenHit.isFromCrossContact keys off.
      e.tags.add('trace:$tag');
      e.crossContact = true;
      e.raise(_crossContactLevel(e.severity));
    }
  }

  /// Keyword hits that sit outside every precautionary window: the allergen is
  /// an ingredient, not a trace. Shared by the regulated allergens and the
  /// custom ones, so a user-defined trigger is blocked by exactly the rule the
  /// tested fourteen are.
  static void _applyDeclared(
    _Evidence e,
    List<TextRangeHit> keywordHits,
    bool Function(TextRangeHit) insideWindow,
  ) {
    for (final h in keywordHits.where((h) => !insideWindow(h))) {
      e.declared = true;
      e.declaredTerms.add(h.term);
      e.add(h);
      e.raise(VerdictLevel.unsafe);
    }
  }

  static void _applyText(
    _Evidence e,
    Allergen allergen,
    List<TextRangeHit> keywordHits,
    String text,
    List<TextRangeHit> exclusions,
    bool Function(TextRangeHit) insideWindow,
  ) {
    _applyDeclared(e, keywordHits, insideWindow);

    final ambiguous = _reject(
      findTerms(text, kAmbiguousTerms[allergen] ?? const []),
      exclusions,
    );
    for (final h in ambiguous) {
      // "soy lecithin" is a soy keyword and "lecithin" is a soy ambiguous term.
      // Reporting both for the same span is just noise.
      final covered = keywordHits.any(
        (k) => k.start <= h.start && h.end <= k.end,
      );
      if (covered) continue;
      e.ambiguous = true;
      e.add(h);
      e.raise(VerdictLevel.caution);
    }
  }

  static void _applyPal(
    Map<Allergen, _Evidence> evidence,
    Map<String, _Evidence> customEvidence,
    List<_PalWindow> windows,
    Map<Allergen, List<TextRangeHit>> keywordHits,
    Map<String, List<TextRangeHit>> customKeywordHits,
    Profile profile,
  ) {
    for (final w in windows) {
      List<TextRangeHit> inWindow(List<TextRangeHit> hits) => hits
          .where((h) => h.start >= w.phrase.end && h.start < w.end)
          .toList();

      List<TextRangeHit> named(Allergen a) =>
          inWindow(keywordHits[a] ?? const []);
      List<TextRangeHit> namedCustom(String id) =>
          inWindow(customKeywordHits[id] ?? const []);

      final namedAllergens = Allergen.values
          .where((a) => named(a).isNotEmpty)
          .toList();
      // A phrase can name a custom trigger and no regulated allergen at all —
      // "may contain beef" names nothing on the Top 14 list. Without this the
      // phrase would read as unattributed and warn about every allergen on the
      // profile instead of the one it actually names.
      final namedCustoms = customEvidence.keys
          .where((id) => namedCustom(id).isNotEmpty)
          .toList();

      // 7. If the phrase names triggers, it only applies to those. If it names
      //    none ("made on shared equipment"), it applies to all of them.
      final namesNothing = namedAllergens.isEmpty && namedCustoms.isEmpty;
      final targets = namesNothing
          ? profile.allergens.keys.toList()
          : namedAllergens.where(profile.allergens.containsKey).toList();
      final customTargets = namesNothing
          ? customEvidence.keys.toList()
          : namedCustoms;

      for (final a in targets) {
        _raiseCrossContact(evidence[a], w.phrase, named(a));
      }
      for (final id in customTargets) {
        _raiseCrossContact(customEvidence[id], w.phrase, namedCustom(id));
      }
    }
  }

  static void _raiseCrossContact(
    _Evidence? e,
    TextRangeHit phrase,
    List<TextRangeHit> named,
  ) {
    if (e == null) return;
    e.crossContact = true;
    e.phrases.add(phrase.term);
    e.addRangeOnly(phrase);
    for (final h in named) {
      e.add(h);
    }
    // 8. Severity decides whether cross-contact blocks or only warns. A
    //    preference is never blocked by a trace, and a custom allergen is
    //    gated by the same `blocksOnTrace` rule as a regulated one.
    e.raise(_crossContactLevel(e.severity));
  }

  /// Resolves an Open Food Facts tag to an allergen, tolerating a missing
  /// language prefix.
  static Allergen? tagAllergen(String raw) {
    final tag = _canonical(raw);
    if (tag.isEmpty) return null;
    final direct = kOffTagToAllergen[tag];
    if (direct != null) return direct;
    if (!tag.contains(':')) {
      final prefixed = kOffTagToAllergen['en:$tag'];
      if (prefixed != null) return prefixed;
    }
    for (final a in Allergen.values) {
      if (a.offTag == tag) return a;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  static String _canonical(String raw) => raw.trim().toLowerCase();

  static VerdictLevel _crossContactLevel(Severity severity) =>
      severity.blocksOnTrace ? VerdictLevel.unsafe : VerdictLevel.caution;

  static VerdictLevel _worse(VerdictLevel a, VerdictLevel b) =>
      a.index <= b.index ? a : b;

  /// The global exclusion spans that still apply to one custom vocabulary.
  ///
  /// [kGlobalExclusions] is written against the regulated fourteen. "coconut",
  /// "buckwheat", "chestnut" and "kasha" are in it because coconut is not a
  /// tree nut and buckwheat is not wheat — not because nobody reacts to them.
  /// Applied verbatim to a vocabulary the user typed, the table produces the
  /// precise failure this app exists to prevent: the shipped Coconut and
  /// Buckwheat starter vocabularies would match nothing at all, and the user
  /// would be shown "No match found" over a tin of coconut milk.
  ///
  /// So an exclusion stops suppressing a custom keyword once the user has
  /// claimed that word as their own — "coconut milk" cannot shadow a keyword
  /// list containing "coconut".
  ///
  /// Free-from claims are exempt from that release and always suppress.
  /// Reading "peanut-free" as peanut is wrong whoever supplied the word, and
  /// matching an allergen inside its own negation is the one exclusion that is
  /// about the sentence rather than about the species.
  static List<TextRangeHit> _exclusionsForCustom(
    List<TextRangeHit> exclusions,
    List<String> keywords,
  ) {
    if (exclusions.isEmpty || keywords.isEmpty) return exclusions;
    return exclusions.where((x) {
      if (_isFreeFromClaim(x.term)) return true;
      return findTerms(normalise(x.term), keywords).isEmpty;
    }).toList();
  }

  /// Whether an exclusion is a negation or free-from claim rather than the
  /// name of an ingredient that merely reads like an allergen.
  static bool _isFreeFromClaim(String term) {
    final t = normalise(term);
    return t.contains('-free') ||
        t.startsWith('free ') ||
        t.startsWith('non-') ||
        t.startsWith('no ') ||
        t.contains('does not contain');
  }

  /// Drops any hit that sits inside the span of a global exclusion.
  static List<TextRangeHit> _reject(
    List<TextRangeHit> hits,
    List<TextRangeHit> exclusions,
  ) {
    if (exclusions.isEmpty) return hits;
    return hits
        .where(
          (h) => !exclusions.any((x) => x.start <= h.start && h.end <= x.end),
        )
        .toList();
  }

  /// Precautionary phrases, with any phrase wholly inside a longer one dropped
  /// so "may contain traces of" is reported instead of "may contain".
  static List<TextRangeHit> _palHits(String text) {
    final all = findTerms(text, kPalPhrases);
    return all.where((h) {
      final len = h.end - h.start;
      return !all.any(
        (o) => o.start <= h.start && h.end <= o.end && (o.end - o.start) > len,
      );
    }).toList();
  }

  /// How far a precautionary phrase's influence reaches.
  ///
  /// [palWindowChars] past the phrase, but cut short at the next "ingredient"
  /// or "contains", because a label that puts its may-contain line first must
  /// not have its actual ingredient list swallowed and downgraded.
  static int _windowEnd(
    String text,
    TextRangeHit phrase,
    List<TextRangeHit> pal,
  ) {
    var end = math.min(text.length, phrase.end + palWindowChars);
    for (final marker in const ['ingredient', 'contains']) {
      var from = phrase.end;
      while (true) {
        final at = text.indexOf(marker, from);
        if (at < 0 || at >= end) break;
        final insidePhrase = pal.any((p) => at >= p.start && at < p.end);
        if (!insidePhrase) {
          end = at;
          break;
        }
        from = at + 1;
      }
    }
    return end;
  }

  static bool _isWordChar(int code) =>
      (code >= 0x61 && code <= 0x7a) || (code >= 0x30 && code <= 0x39);

  /// The end offset of a match, or -1 if the term runs into another word.
  /// A single trailing "s" is treated as part of the term.
  static int _boundedEnd(String text, int end) {
    if (end >= text.length) return end;
    if (!_isWordChar(text.codeUnitAt(end))) return end;
    if (text[end] == 's' &&
        (end + 1 >= text.length || !_isWordChar(text.codeUnitAt(end + 1)))) {
      return end + 1;
    }
    return -1;
  }

  static const Map<String, String> _folds = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
    'ý': 'y',
    'ÿ': 'y',
    '’': "'",
    '‘': "'",
    'ʼ': "'",
    '“': '"',
    '”': '"',
    '–': '-',
    '—': '-',
    ' ': ' ',
  };

  static const Set<String> _dropped = {'®', '™', '©', '​', '﻿'};

  // ---------------------------------------------------------------------
  // Copy
  // ---------------------------------------------------------------------

  static String _headline(
    VerdictLevel level,
    List<_Evidence> evidence, {
    bool translationFloor = false,
  }) {
    switch (level) {
      case VerdictLevel.unsafe:
        return _countPhrase(
          'Contains',
          evidence.where((e) => e.level == VerdictLevel.unsafe).toList(),
        );
      case VerdictLevel.caution:
        final cautions = evidence
            .where((e) => e.level == VerdictLevel.caution)
            .toList();
        if (cautions.isEmpty) return 'Ingredient list incomplete';
        return _countPhrase('May contain', cautions);
      case VerdictLevel.unknown:
        // The translation floor lands here with a full ingredient list on the
        // same screen, so "No ingredient data" would be false.
        return translationFloor
            ? 'Translation can’t confirm this'
            : 'No ingredient data';
      case VerdictLevel.clear:
        return 'No match found';
    }
  }

  static String _countPhrase(String verb, List<_Evidence> list) {
    if (list.isEmpty) return verb;
    // `label` rather than `allergen.label`, so a user-defined trigger reads the
    // same way as a regulated one: "Contains alpha-gal", "May contain corn".
    final first = list.first.label.toLowerCase();
    if (list.length == 1) return '$verb $first';
    final others = list.length - 1;
    return '$verb $first and $others ${others == 1 ? 'other' : 'others'}';
  }

  static String _detail({
    required VerdictLevel level,
    required List<_Evidence> evidence,
    required Product product,
    required Profile profile,
    required bool incompleteFloor,
    required bool noTextFloor,
    required bool translationFloor,
  }) {
    final parts = <String>[];

    for (final e in evidence.take(3)) {
      parts.add(_evidenceSentence(e));
    }
    if (evidence.length > 3) {
      final rest = evidence.length - 3;
      parts.add(
        '$rest other ${rest == 1 ? 'allergen' : 'allergens'} '
        'on this profile also matched.',
      );
    }

    final tracked = profile.allergens.length + profile.customAllergens.length;

    if (translationFloor) {
      parts.add(
        'Nothing in the translated text matched ${_labels(profile)}. That is '
        'not a clear result: this is a machine translation, and a word it '
        'dropped is a word this check never saw. Read the pack itself, or show '
        'someone your allergy card.',
      );
    } else if (noTextFloor) {
      parts.add(
        'There is no ingredient list for this product, only allergen tags, so '
        '${_labels(profile)} could not be ruled out.',
      );
    } else if (incompleteFloor) {
      parts.add(
        'Nothing in the ingredient list matched ${_labels(profile)}, '
        'but the list is marked incomplete in the database, so this is not a '
        'clear result.',
      );
    } else if (level == VerdictLevel.clear) {
      parts.add('No match for ${_labels(profile)} in ${_sources(product)}.');
      parts.add(
        'Cross-contact is not always labeled, so check the pack if you are unsure.',
      );
    } else {
      parts.add(
        'Checked $tracked ${tracked == 1 ? 'allergen' : 'allergens'} against '
        '${_sources(product)}.',
      );
      if (product.hasIngredients && !product.ingredientsComplete) {
        parts.add('The ingredient list is marked incomplete in the database.');
      }
      if (!product.hasIngredients) {
        parts.add('There is no ingredient list for this product, only tags.');
      }
    }

    // Said every time it is true, because it is the one limit of this feature
    // the user cannot see: no database tags exist for a trigger nobody has to
    // declare, so an unreadable label means unknown, not clear.
    if (profile.customAllergens.isNotEmpty && !product.hasIngredients) {
      parts.add(
        'Your own triggers can only be checked against ingredient text, and '
        'this product has none.',
      );
    }

    return parts.join(' ');
  }

  static String _evidenceSentence(_Evidence e) {
    final name = e.label;
    final lower = name.toLowerCase();

    if (e.declared) {
      if (e.declaredTerms.isEmpty) {
        return '$name is declared in this product’s allergen tags.';
      }
      return '$name is in the ingredient list '
          '(${e.declaredTerms.take(4).join(', ')}).';
    }

    if (e.unspecifiedTreeNut) {
      return 'This record is tagged for tree nuts without naming which one, so '
          'it is a caution rather than a block — check the pack for the species '
          'you react to.';
    }

    if (e.crossContact) {
      final how = e.phrases.isNotEmpty
          ? 'the label says "${e.phrases.first}"'
          : 'the database records it as a trace';
      final gate = e.severity.blocksOnTrace
          ? 'You have $lower set to severe, so cross-contact blocks this product.'
          : 'This is cross-contact only — no $lower ingredient was found.';
      return '$name may be present: $how. $gate';
    }

    if (e.ambiguous && e.terms.isNotEmpty) {
      return '$name could be hidden in ${e.terms.take(3).join(', ')}, which '
          'does not have to name its source.';
    }
    return '$name could not be ruled out from the data on this product.';
  }

  static String _sources(Product product) {
    final s = <String>[];
    if (product.hasIngredients) s.add('the ingredient list');
    if (product.allergenTags.isNotEmpty) s.add('the declared allergen tags');
    if (product.tracesTags.isNotEmpty) s.add('the may-contain tags');
    if (s.isEmpty) return 'the data available';
    return _join(s);
  }

  static String _labels(Profile profile) => _join([
    ...profile.allergens.keys.map((a) => a.label.toLowerCase()),
    ...profile.customAllergens.map((c) => c.name.toLowerCase()),
  ]);

  static String _join(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }
}

/// A precautionary phrase and the stretch of text it governs.
class _PalWindow {
  const _PalWindow(this.phrase, this.end);
  final TextRangeHit phrase;
  final int end;
}

/// Everything found for one allergen while a single product is evaluated —
/// one of the regulated fourteen, or one the user defined themselves.
class _Evidence {
  _Evidence.standard(Allergen this.allergen, this.severity)
    : customId = null,
      label = allergen.label,
      emoji = allergen.emoji;

  _Evidence.custom(CustomAllergen custom)
    : allergen = null,
      customId = custom.id,
      label = custom.name,
      emoji = custom.emoji,
      severity = custom.severity;

  /// Null for a user-defined trigger.
  final Allergen? allergen;
  final String? customId;

  /// Always populated: what the user is shown, whichever kind this is.
  final String label;
  final String emoji;

  final Severity severity;

  VerdictLevel level = VerdictLevel.clear;
  final Set<String> terms = <String>{};

  /// The subset of [terms] found outside any precautionary phrase — i.e. the
  /// ones that mean the allergen is an ingredient rather than a trace.
  final Set<String> declaredTerms = <String>{};

  final List<String> tags = <String>[];
  final Set<String> phrases = <String>{};
  final List<TextRangeHit> ranges = <TextRangeHit>[];

  /// The allergen is named outright, by tag or by ingredient.
  bool declared = false;

  /// Cross-contact evidence only: a precautionary phrase or a trace tag.
  bool crossContact = false;

  /// An ingredient that is allowed to hide the allergen was found.
  bool ambiguous = false;

  /// Tagged `en:nuts` with no species named.
  bool unspecifiedTreeNut = false;

  bool get isHit => level != VerdictLevel.clear;

  void raise(VerdictLevel candidate) {
    if (candidate.index < level.index) level = candidate;
  }

  void add(TextRangeHit hit) {
    terms.add(hit.term);
    if (ranges.any((r) => r.start == hit.start && r.end == hit.end)) return;
    ranges.add(hit);
  }

  /// Records a span for highlighting without counting it as a matched
  /// ingredient term.
  ///
  /// Used for precautionary phrases. "May contain traces of" should be
  /// highlighted in the label text, but it is not an ingredient — listing it
  /// among [matchedTerms] tells the user the label declares something it does
  /// not. The phrase is already carried separately in [phrases].
  void addRangeOnly(TextRangeHit hit) {
    if (ranges.any((r) => r.start == hit.start && r.end == hit.end)) return;
    ranges.add(hit);
  }

  AllergenHit toHit() {
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    final a = allergen;
    if (a != null) {
      return AllergenHit.standard(
        allergen: a,
        severity: severity,
        level: level,
        matchedTerms: terms.toList(),
        sourceTags: tags,
        palPhrases: phrases.toList(),
        highlightRanges: sorted,
      );
    }
    return AllergenHit(
      customId: customId,
      label: label,
      emoji: emoji,
      severity: severity,
      level: level,
      matchedTerms: terms.toList(),
      sourceTags: tags,
      palPhrases: phrases.toList(),
      highlightRanges: sorted,
    );
  }
}
