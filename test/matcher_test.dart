import 'package:flutter_test/flutter_test.dart';
import 'package:trace_allergy/data/allergen_keywords.dart';
import 'package:trace_allergy/data/pal_phrases.dart';
import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/custom_allergen.dart';
import 'package:trace_allergy/models/product.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/models/verdict.dart';
import 'package:trace_allergy/services/matcher.dart';

/// A product whose ingredient list is trusted, so a clear verdict is allowed to
/// stay clear. Anything without `ingredientsComplete` is floored at caution by
/// design, which would hide real failures in these tests.
Product product(
  String? ingredients, {
  List<String> allergenTags = const [],
  List<String> tracesTags = const [],
  bool complete = true,
}) {
  return Product(
    barcode: '0000000000000',
    name: 'Test product',
    ingredientsText: ingredients,
    ingredientsLanguage: 'en',
    allergenTags: allergenTags,
    tracesTags: tracesTags,
    ingredientsComplete: complete,
  );
}

Profile profileWith(
  Map<Allergen, Severity> allergens, {
  bool avoidPal = true,
  List<CustomAllergen> customs = const [],
}) {
  return Profile(
    id: 'p1',
    name: 'Test',
    allergens: allergens,
    customAllergens: [...customs],
    avoidPalWhenUnsure: avoidPal,
  );
}

Verdict check(
  String? ingredients,
  Map<Allergen, Severity> allergens, {
  List<String> allergenTags = const [],
  List<String> tracesTags = const [],
  bool complete = true,
  bool avoidPal = true,
  List<CustomAllergen> customs = const [],
}) {
  return AllergenMatcher.evaluate(
    product: product(
      ingredients,
      allergenTags: allergenTags,
      tracesTags: tracesTags,
      complete: complete,
    ),
    profile: profileWith(allergens, avoidPal: avoidPal, customs: customs),
  );
}

AllergenHit? hitFor(Verdict v, Allergen a) {
  for (final h in v.hits) {
    if (h.allergen == a) return h;
  }
  return null;
}

AllergenHit? customHitFor(Verdict v, String id) {
  for (final h in v.hits) {
    if (h.customId == id) return h;
  }
  return null;
}

/// The trigger no label declares — the case the whole feature exists for.
CustomAllergen alphaGal({
  Severity severity = Severity.severe,
  List<String> keywords = const ['gelatin', 'beef'],
}) {
  return CustomAllergen(
    id: 'c-alpha',
    name: 'Alpha-gal',
    keywords: keywords,
    severity: severity,
    emoji: '🥩',
  );
}

void main() {
  group('normalise', () {
    test('lowercases, folds accents and strips symbols', () {
      expect(
        AllergenMatcher.normalise('ÉCREVISSE® and  PIÑON™'),
        'ecrevisse and pinon',
      );
    });

    test('strips Open Food Facts underscore markup without joining words', () {
      expect(
        AllergenMatcher.normalise('sugar,_milk_powder, cocoa'),
        'sugar, milk powder, cocoa',
      );
    });

    test('normalises curly apostrophes', () {
      expect(AllergenMatcher.normalise('BREWER’S YEAST'), "brewer's yeast");
    });
  });

  group('findTerms word boundaries', () {
    test('never matches mid-word', () {
      expect(AllergenMatcher.findTerms('coconut oil', const ['nut']), isEmpty);
      expect(AllergenMatcher.findTerms('buckwheat', const ['wheat']), isEmpty);
      expect(AllergenMatcher.findTerms('eggplant', const ['egg']), isEmpty);
    });

    test('matches across punctuation and reports the span', () {
      final hits = AllergenMatcher.findTerms('sugar,milk.', const ['milk']);
      expect(hits, hasLength(1));
      expect(hits.first.start, 6);
      expect(hits.first.end, 10);
      expect(hits.first.term, 'milk');
    });

    test('accepts a simple plural', () {
      final hits = AllergenMatcher.findTerms('caseinates', const ['caseinate']);
      expect(hits, hasLength(1));
      expect(hits.first.end, 10);
    });
  });

  // ---------------------------------------------------------------------
  // The false positives that destroy trust
  // ---------------------------------------------------------------------
  group('exclusions', () {
    test('coconut does not trigger tree nut', () {
      final v = check('coconut oil, coconut cream, sugar', {
        Allergen.treeNut: Severity.severe,
      });
      expect(v.level, VerdictLevel.clear);
      expect(v.hits, isEmpty);
    });

    test('coconut milk does not trigger milk', () {
      final v = check('coconut milk, sugar', {Allergen.milk: Severity.severe});
      expect(v.level, VerdictLevel.clear);
    });

    test('buckwheat does not trigger wheat', () {
      final v = check('buckwheat flour, water', {
        Allergen.wheat: Severity.severe,
      });
      expect(v.level, VerdictLevel.clear);
    });

    test('dairy-free does not trigger milk', () {
      final v = check('sugar, dairy-free base, salt', {
        Allergen.milk: Severity.severe,
      });
      expect(v.level, VerdictLevel.clear);
      expect(v.headline, 'No match found');
    });

    test('milkweed does not trigger milk', () {
      final v = check('milkweed extract, water', {
        Allergen.milk: Severity.severe,
      });
      expect(v.level, VerdictLevel.clear);
    });

    test('cocoa butter does not trigger milk', () {
      final v = check('cocoa mass, cocoa butter, sugar', {
        Allergen.milk: Severity.severe,
      });
      expect(v.level, VerdictLevel.clear);
    });

    test('nut-free claim does not trigger tree nut', () {
      final v = check('made with a nut-free recipe, sugar', {
        Allergen.treeNut: Severity.severe,
      });
      expect(v.level, VerdictLevel.clear);
    });

    test('peanut butter still triggers peanut', () {
      final v = check('peanut butter, salt', {
        Allergen.peanut: Severity.severe,
      });
      expect(v.level, VerdictLevel.unsafe);
    });
  });

  // ---------------------------------------------------------------------
  // The hidden names that destroy people
  // ---------------------------------------------------------------------
  group('hidden ingredient names', () {
    test('casein triggers milk', () {
      final v = check('water, sodium caseinate, salt', {
        Allergen.milk: Severity.severe,
      });
      expect(v.level, VerdictLevel.unsafe);
      expect(hitFor(v, Allergen.milk)?.matchedTerms, contains('caseinate'));
    });

    test('whey triggers milk', () {
      final v = check('sugar, whey powder', {Allergen.milk: Severity.severe});
      expect(v.level, VerdictLevel.unsafe);
      expect(hitFor(v, Allergen.milk)?.matchedTerms, contains('whey'));
    });

    test('arachis oil triggers peanut', () {
      final v = check('vegetable oils (arachis oil), salt', {
        Allergen.peanut: Severity.severe,
      });
      expect(v.level, VerdictLevel.unsafe);
      expect(hitFor(v, Allergen.peanut)?.matchedTerms, contains('arachis oil'));
    });

    test('tahini triggers sesame', () {
      final v = check('chickpeas, tahini, lemon juice', {
        Allergen.sesame: Severity.severe,
      });
      expect(v.level, VerdictLevel.unsafe);
    });

    test('semolina triggers wheat', () {
      final v = check('durum wheat semolina, water', {
        Allergen.wheat: Severity.severe,
      });
      expect(v.level, VerdictLevel.unsafe);
      expect(hitFor(v, Allergen.wheat)?.matchedTerms, contains('semolina'));
    });

    test('E220 triggers sulphites', () {
      final v = check('wine, e220', {Allergen.sulphite: Severity.intolerance});
      expect(v.level, VerdictLevel.unsafe);
    });

    test('highlight ranges point at the matched text', () {
      final v = check('sugar, whey powder', {Allergen.milk: Severity.severe});
      final hit = hitFor(v, Allergen.milk);
      expect(hit, isNotNull);
      final ranges = hit!.highlightRanges;
      expect(ranges, isNotEmpty);
      final text = v.ingredientTextUsed;
      expect(text, isNotNull);
      expect(text!.substring(ranges.first.start, ranges.first.end), 'whey');
    });
  });

  // ---------------------------------------------------------------------
  // Precautionary labelling and the severity gate
  // ---------------------------------------------------------------------
  group('precautionary labelling', () {
    test('finds the longest phrase, not the fragments', () {
      final phrases = AllergenMatcher.findPalPhrases(
        AllergenMatcher.normalise('Sugar. May contain traces of peanuts.'),
      );
      expect(phrases, contains('may contain traces of'));
      expect(phrases, isNot(contains('may contain')));
    });

    test('may contain traces of peanuts is a caution for a preference', () {
      final v = check('sugar, salt. may contain traces of peanuts.', {
        Allergen.peanut: Severity.preference,
      });
      expect(v.level, VerdictLevel.caution);
      expect(v.headline, 'May contain peanut');
      final hit = hitFor(v, Allergen.peanut);
      expect(hit?.isFromCrossContact, isTrue);
      expect(hit?.palPhrases, contains('may contain traces of'));
    });

    test('the same text is a caution for an intolerance', () {
      final v = check('sugar, salt. may contain traces of peanuts.', {
        Allergen.peanut: Severity.intolerance,
      });
      expect(v.level, VerdictLevel.caution);
    });

    test('the same text is unsafe for a severe allergy', () {
      final v = check('sugar, salt. may contain traces of peanuts.', {
        Allergen.peanut: Severity.severe,
      });
      expect(v.level, VerdictLevel.unsafe);
      expect(v.headline, 'Contains peanut');
    });

    test('an unattributed phrase warns about every profile allergen', () {
      final v = check('sugar, salt. made on shared equipment.', {
        Allergen.milk: Severity.intolerance,
        Allergen.peanut: Severity.intolerance,
      });
      expect(v.level, VerdictLevel.caution);
      expect(v.hits, hasLength(2));
    });

    test('a phrase naming another allergen does not warn about mine', () {
      final v = check('sugar, salt. may contain soy.', {
        Allergen.peanut: Severity.severe,
      });
      expect(v.level, VerdictLevel.clear);
    });

    test('a trace tag is gated by severity too', () {
      final severe = check(
        'sugar, salt',
        {Allergen.milk: Severity.severe},
        tracesTags: const ['en:milk'],
      );
      expect(severe.level, VerdictLevel.unsafe);
      expect(hitFor(severe, Allergen.milk)?.isFromCrossContact, isTrue);

      final mild = check(
        'sugar, salt',
        {Allergen.milk: Severity.preference},
        tracesTags: const ['en:milk'],
      );
      expect(mild.level, VerdictLevel.caution);
    });

    test('an ingredient after the may-contain line is still an ingredient', () {
      final v = check(
        'may contain traces of nuts. ingredients: sugar, whey powder.',
        {Allergen.milk: Severity.preference},
      );
      expect(v.level, VerdictLevel.unsafe);
    });
  });

  // ---------------------------------------------------------------------
  // Missing data is never a clear verdict
  // ---------------------------------------------------------------------
  group('missing data', () {
    test('empty ingredients and no tags is unknown, never clear', () {
      final v = check('', {Allergen.milk: Severity.severe});
      expect(v.level, VerdictLevel.unknown);
      expect(v.headline, 'No ingredient data');
    });

    test('null ingredients and no tags is unknown', () {
      final v = check(null, {Allergen.milk: Severity.severe});
      expect(v.level, VerdictLevel.unknown);
    });

    test('tags that miss my allergen with no text is unknown, not clear', () {
      final v = check(
        null,
        {Allergen.peanut: Severity.severe},
        allergenTags: const ['en:milk'],
      );
      expect(v.level, VerdictLevel.unknown);
    });

    test('an incomplete ingredient list is floored at caution', () {
      final v = check('sugar, salt', {
        Allergen.milk: Severity.severe,
      }, complete: false);
      expect(v.level, VerdictLevel.caution);
      expect(v.headline, 'Ingredient list incomplete');
    });

    test('the floor is opt-out per profile', () {
      final v = check(
        'sugar, salt',
        {Allergen.milk: Severity.severe},
        complete: false,
        avoidPal: false,
      );
      expect(v.level, VerdictLevel.clear);
    });

    test('an empty profile is clear with its own headline', () {
      final v = check('milk, sugar', const {});
      expect(v.level, VerdictLevel.clear);
      expect(v.headline, 'No allergens set');
    });
  });

  // ---------------------------------------------------------------------
  // Tags and text are unioned, never trusted alone
  // ---------------------------------------------------------------------
  group('tag and text union', () {
    test('allergen tags with no ingredient text still block', () {
      final v = check(
        null,
        {Allergen.milk: Severity.severe},
        allergenTags: const ['en:milk'],
      );
      expect(v.level, VerdictLevel.unsafe);
      expect(hitFor(v, Allergen.milk)?.sourceTags, contains('en:milk'));
    });

    test('ingredient text the tags missed still blocks', () {
      final v = check(
        'sugar, whey protein concentrate, salt',
        {Allergen.milk: Severity.severe},
        allergenTags: const ['en:soybeans'],
      );
      expect(v.level, VerdictLevel.unsafe);
      expect(hitFor(v, Allergen.milk)?.sourceTags, isEmpty);
    });

    test('a species tree nut tag blocks', () {
      final v = check(
        null,
        {Allergen.treeNut: Severity.severe},
        allergenTags: const ['en:hazelnuts'],
      );
      expect(v.level, VerdictLevel.unsafe);
    });

    test('a bare en:nuts tag is a caution, not a block', () {
      final v = check(
        'sugar, cocoa mass',
        {Allergen.treeNut: Severity.severe},
        allergenTags: const ['en:nuts'],
      );
      expect(v.level, VerdictLevel.caution);
      expect(v.detail, contains('without naming which one'));
    });

    test('en:nuts alongside a species tag still blocks', () {
      final v = check(
        'sugar, cocoa mass',
        {Allergen.treeNut: Severity.severe},
        allergenTags: const ['en:nuts', 'en:almonds'],
      );
      expect(v.level, VerdictLevel.unsafe);
    });

    test('gluten grain tags map onto the wheat allergen', () {
      final v = check(
        null,
        {Allergen.wheat: Severity.intolerance},
        allergenTags: const ['en:barley'],
      );
      expect(v.level, VerdictLevel.unsafe);
    });
  });

  // ---------------------------------------------------------------------
  // Ambiguity is its own answer
  // ---------------------------------------------------------------------
  group('ambiguous terms', () {
    test('natural flavor is a caution for milk, not a block', () {
      final v = check('sugar, natural flavor, salt', {
        Allergen.milk: Severity.severe,
      });
      expect(v.level, VerdictLevel.caution);
      expect(
        hitFor(v, Allergen.milk)?.matchedTerms,
        contains('natural flavor'),
      );
    });

    test('spices is a caution for sesame', () {
      final v = check('flour, spices, salt', {
        Allergen.sesame: Severity.severe,
      });
      expect(v.level, VerdictLevel.caution);
    });
  });

  // ---------------------------------------------------------------------
  // Real labels
  // ---------------------------------------------------------------------
  group('real labels', () {
    const nutella =
        'Sugar, Palm Oil, _Hazelnuts_ 13%, Fat-Reduced Cocoa 7.4%, '
        'Skimmed _Milk_ Powder 8.7%, Whey Powder (_Milk_), Emulsifier: '
        'Lecithin (_Soya_), Vanillin.';

    test('resolves hazelnut and milk from underscore markup', () {
      final v = AllergenMatcher.evaluate(
        product: product(nutella, allergenTags: const ['en:nuts', 'en:milk']),
        profile: profileWith({
          Allergen.treeNut: Severity.severe,
          Allergen.milk: Severity.intolerance,
        }),
      );
      expect(v.level, VerdictLevel.unsafe);
      expect(v.hits, hasLength(2));
      expect(hitFor(v, Allergen.treeNut)?.level, VerdictLevel.unsafe);
      expect(hitFor(v, Allergen.treeNut)?.matchedTerms, contains('hazelnuts'));
      expect(hitFor(v, Allergen.milk)?.level, VerdictLevel.unsafe);
      expect(v.headline, 'Contains milk and 1 other');
    });

    test('the same label is clear for a peanut-only profile', () {
      final v = AllergenMatcher.evaluate(
        product: product(nutella),
        profile: profileWith({Allergen.peanut: Severity.severe}),
      );
      expect(v.level, VerdictLevel.clear);
      expect(v.headline, 'No match found');
    });

    test('soy lecithin is reported once, as soy', () {
      final v = check('sugar, emulsifier: soy lecithin', {
        Allergen.soy: Severity.severe,
      });
      expect(v.level, VerdictLevel.unsafe);
      expect(hitFor(v, Allergen.soy)?.matchedTerms, contains('soy lecithin'));
      expect(
        hitFor(v, Allergen.soy)?.matchedTerms,
        isNot(contains('lecithin')),
      );
    });

    test('hits are sorted worst first', () {
      final v = check(
        'wheat flour, sugar, natural flavor. may contain traces of peanuts.',
        {
          Allergen.wheat: Severity.severe,
          Allergen.milk: Severity.intolerance,
          Allergen.peanut: Severity.intolerance,
        },
      );
      expect(v.level, VerdictLevel.unsafe);
      expect(v.hits.first.allergen, Allergen.wheat);
      expect(v.hits.first.level, VerdictLevel.unsafe);
      expect(v.hits.last.level, VerdictLevel.caution);
    });
  });

  // ---------------------------------------------------------------------
  // Triggers no labelling regime declares
  // ---------------------------------------------------------------------
  group('custom allergens', () {
    test('a profile with only custom allergens is a real profile', () {
      final v = check('sugar, salt', const {}, customs: [alphaGal()]);
      expect(v.level, VerdictLevel.clear);
      expect(v.headline, 'No match found');
      expect(v.detail, contains('alpha-gal'));
    });

    test('a custom keyword in the ingredient list is unsafe', () {
      final v = check(
        'water, beef gelatin, sugar',
        const {},
        customs: [alphaGal()],
      );
      expect(v.level, VerdictLevel.unsafe);
      expect(v.headline, 'Contains alpha-gal');
      final hit = customHitFor(v, 'c-alpha');
      expect(hit, isNotNull);
      expect(hit?.isCustom, isTrue);
      expect(hit?.allergen, isNull);
      expect(hit?.label, 'Alpha-gal');
      expect(hit?.emoji, '🥩');
      expect(hit?.matchedTerms, contains('beef'));
      expect(hit?.matchedTerms, contains('gelatin'));
    });

    test('a custom hit highlights the span it matched', () {
      final v = check('water, beef gelatin', const {}, customs: [alphaGal()]);
      final ranges = customHitFor(v, 'c-alpha')?.highlightRanges;
      expect(ranges, isNotEmpty);
      final text = v.ingredientTextUsed;
      expect(text, isNotNull);
      expect(text!.substring(ranges!.first.start, ranges.first.end), 'beef');
    });

    test('word boundaries apply to custom keywords too', () {
      final v = check(
        'beefsteak tomato, water',
        const {},
        customs: [
          alphaGal(keywords: const ['beef']),
        ],
      );
      expect(v.level, VerdictLevel.clear);
    });

    // ------------------------------------------------------- severity gate
    test('a may-contain line is a caution for an intolerance', () {
      final v = check(
        'sugar, salt. may contain traces of beef.',
        const {},
        customs: [alphaGal(severity: Severity.intolerance)],
      );
      expect(v.level, VerdictLevel.caution);
      expect(v.headline, 'May contain alpha-gal');
      final hit = customHitFor(v, 'c-alpha');
      expect(hit?.isFromCrossContact, isTrue);
      expect(hit?.palPhrases, contains('may contain traces of'));
    });

    test('the same line is unsafe for a severe custom allergy', () {
      final v = check(
        'sugar, salt. may contain traces of beef.',
        const {},
        customs: [alphaGal()],
      );
      expect(v.level, VerdictLevel.unsafe);
    });

    test('an unattributed phrase warns about custom allergens as well', () {
      final v = check(
        'sugar, salt. made on shared equipment.',
        {Allergen.milk: Severity.intolerance},
        customs: [alphaGal(severity: Severity.intolerance)],
      );
      expect(v.level, VerdictLevel.caution);
      expect(v.hits, hasLength(2));
      expect(customHitFor(v, 'c-alpha')?.isFromCrossContact, isTrue);
    });

    test('a phrase naming another allergen does not warn about my trigger', () {
      final v = check(
        'sugar, salt. may contain soy.',
        const {},
        customs: [alphaGal()],
      );
      expect(v.level, VerdictLevel.clear);
    });

    test(
      'a phrase naming my trigger does not warn about my other allergens',
      () {
        // "may contain beef" names nothing on the regulated fourteen, so without
        // custom keywords in the attribution pass it would read as unattributed
        // and warn about the milk allergy too.
        final v = check(
          'sugar, salt. may contain beef.',
          {Allergen.milk: Severity.severe},
          customs: [alphaGal(severity: Severity.intolerance)],
        );
        expect(v.level, VerdictLevel.caution);
        expect(v.hits, hasLength(1));
        expect(hitFor(v, Allergen.milk), isNull);
      },
    );

    test('an ingredient after the may-contain line is still an ingredient', () {
      final v = check(
        'may contain traces of nuts. ingredients: water, beef gelatin.',
        const {},
        customs: [alphaGal(severity: Severity.intolerance)],
      );
      expect(v.level, VerdictLevel.unsafe);
    });

    // -------------------------------------------------------- exclusions
    test('a broad custom keyword still cannot match mid-word', () {
      final v = check(
        'coconut oil, sugar',
        const {},
        customs: [
          alphaGal(keywords: const ['nut']),
        ],
      );
      expect(v.level, VerdictLevel.clear);
    });

    test('a free-from claim suppresses a custom keyword', () {
      final v = check(
        'sugar, made with a peanut-free recipe',
        const {},
        customs: [
          alphaGal(keywords: const ['peanut']),
        ],
      );
      expect(v.level, VerdictLevel.clear);
    });

    test('an exclusion the user claimed as their own no longer shadows it', () {
      // "coconut" is a global exclusion because coconut is not a tree nut. It
      // is not there because nobody reacts to coconut, and a coconut-allergic
      // user must not be shown "No match found" over coconut milk.
      final v = check(
        'coconut milk, sugar',
        const {},
        customs: [
          CustomAllergen(
            id: 'c-coco',
            name: 'Coconut',
            keywords: const ['coconut'],
            emoji: '🥥',
          ),
        ],
      );
      expect(v.level, VerdictLevel.unsafe);
      expect(v.headline, 'Contains coconut');
    });

    // ------------------------------------------------------- missing data
    test(
      'no ingredient text is unknown for a custom allergen, never clear',
      () {
        // There is no `allergens_tags` equivalent for a trigger nobody has to
        // declare, so text is the only evidence source and its absence is not
        // an absence of the allergen.
        final v = check(
          null,
          const {},
          allergenTags: const ['en:milk'],
          customs: [alphaGal()],
        );
        expect(v.level, VerdictLevel.unknown);
        expect(v.detail, contains('only be checked against ingredient text'));
      },
    );

    test('no text and no tags is unknown for a custom-only profile', () {
      final v = check('', const {}, customs: [alphaGal()]);
      expect(v.level, VerdictLevel.unknown);
      expect(v.headline, 'No ingredient data');
    });

    test('an incomplete list is floored at caution for customs too', () {
      final v = check(
        'sugar, salt',
        const {},
        complete: false,
        customs: [alphaGal()],
      );
      expect(v.level, VerdictLevel.caution);
      expect(v.headline, 'Ingredient list incomplete');
    });

    // ----------------------------------------------------------- together
    test('standard and custom hits coexist and the worst level wins', () {
      final v = check(
        'sugar, natural flavor, beef gelatin.',
        {Allergen.milk: Severity.severe},
        customs: [alphaGal()],
      );
      expect(v.level, VerdictLevel.unsafe);
      expect(v.hits, hasLength(2));
      // Worst first: the custom hit is unsafe, the milk hit only a caution.
      expect(v.hits.first.isCustom, isTrue);
      expect(v.hits.first.level, VerdictLevel.unsafe);
      expect(v.hits.last.allergen, Allergen.milk);
      expect(v.hits.last.level, VerdictLevel.caution);
      expect(v.headline, 'Contains alpha-gal');
    });

    test('a standard hit still outranks a custom caution', () {
      final v = check(
        'sugar, whey powder. may contain traces of beef.',
        {Allergen.milk: Severity.severe},
        customs: [alphaGal(severity: Severity.preference)],
      );
      expect(v.level, VerdictLevel.unsafe);
      expect(hitFor(v, Allergen.milk)?.level, VerdictLevel.unsafe);
      expect(customHitFor(v, 'c-alpha')?.level, VerdictLevel.caution);
      expect(v.headline, 'Contains milk');
    });

    // --------------------------------------------------- keyword validation
    group('validateKeywords', () {
      test('drops entries under three characters', () {
        expect(
          AllergenMatcher.validateKeywords(const ['ox', 'pb', 'a', 'beef']),
          const ['beef'],
        );
      });

      test('keeps the real three-letter names', () {
        expect(
          AllergenMatcher.validateKeywords(const ['soy', 'egg', 'nut', 'rye']),
          const ['soy', 'egg', 'nut', 'rye'],
        );
      });

      test('de-duplicates and folds case', () {
        expect(
          AllergenMatcher.validateKeywords(const [
            'Beef',
            'beef',
            ' BEEF ',
            'gelatin',
          ]),
          const ['beef', 'gelatin'],
        );
      });

      test('a two-character keyword cannot fire a verdict', () {
        final v = check(
          'ox tail stock, water',
          const {},
          customs: [
            alphaGal(keywords: const ['ox']),
          ],
        );
        expect(v.level, VerdictLevel.clear);
      });
    });
  });

  // ---------------------------------------------------------------------
  // Data tables
  // ---------------------------------------------------------------------
  group('data tables', () {
    test('every allergen has keywords', () {
      for (final a in Allergen.values) {
        expect(kAllergenKeywords[a], isNotEmpty, reason: a.name);
      }
    });

    test('keywords are lowercase and trimmed', () {
      for (final entry in kAllergenKeywords.entries) {
        for (final term in entry.value) {
          expect(term, term.toLowerCase(), reason: '${entry.key.name}: $term');
          expect(term, term.trim(), reason: '${entry.key.name}: $term');
        }
      }
    });

    test('the plant-fat exclusions shadow nothing but butter and cream', () {
      // An exclusion span deletes every match inside it. "coconut milk" and
      // "peanut-free" are supposed to shadow their allergen — that is the whole
      // job. The entries below exist only to stop the word "butter" or "cream"
      // reading as dairy, so shadowing anything else would be a silent, deadly
      // regression. This is the test that stops someone adding "peanut butter"
      // or "almond butter" to the list.
      const plantFats = [
        'cocoa butter',
        'cacao butter',
        'coconut butter',
        'sunflower butter',
        'sunflower seed butter',
        'apple butter',
        'butter bean',
        'butter beans',
        'butter lettuce',
        'cream of tartar',
      ];
      for (final exclusion in plantFats) {
        expect(kGlobalExclusions, contains(exclusion));
        for (final entry in kAllergenKeywords.entries) {
          final hidden = AllergenMatcher.findTerms(
            AllergenMatcher.normalise(exclusion),
            entry.value,
          ).map((h) => h.term).toSet();
          expect(
            hidden.difference(const {'butter', 'cream'}),
            isEmpty,
            reason:
                'exclusion "$exclusion" also hides ${entry.key.name} $hidden',
          );
        }
      }
    });

    test('exclusions never hide a peanut or tree nut species', () {
      // The exceptions are named, not implied: a free-from claim is meant to
      // shadow the allergen it disclaims, and butternut squash is a vegetable.
      const allowed = {'nut-free', 'peanut-free', 'butternut squash'};
      for (final exclusion in kGlobalExclusions) {
        if (allowed.contains(exclusion)) continue;
        for (final allergen in const [Allergen.peanut, Allergen.treeNut]) {
          final hidden = AllergenMatcher.findTerms(
            AllergenMatcher.normalise(exclusion),
            kAllergenKeywords[allergen] ?? const [],
          );
          expect(
            hidden,
            isEmpty,
            reason:
                'exclusion "$exclusion" hides ${allergen.name} '
                '"${hidden.isEmpty ? '' : hidden.first.term}"',
          );
        }
      }
    });

    test('every allergen offTag resolves', () {
      for (final a in Allergen.values) {
        expect(AllergenMatcher.tagAllergen(a.offTag), a, reason: a.name);
      }
    });

    test('the required OFF tags all map', () {
      const required = [
        'en:milk',
        'en:eggs',
        'en:peanuts',
        'en:nuts',
        'en:tree-nuts',
        'en:almonds',
        'en:hazelnuts',
        'en:walnuts',
        'en:cashew-nuts',
        'en:pecan-nuts',
        'en:pistachio',
        'en:brazil-nuts',
        'en:macadamia-nuts',
        'en:soybeans',
        'en:gluten',
        'en:wheat',
        'en:barley',
        'en:rye',
        'en:oats',
        'en:fish',
        'en:crustaceans',
        'en:sesame-seeds',
        'en:molluscs',
        'en:celery',
        'en:mustard',
        'en:lupin',
        'en:sulphur-dioxide-and-sulphites',
      ];
      for (final tag in required) {
        expect(kOffTagToAllergen[tag], isNotNull, reason: tag);
      }
    });

    test('every precautionary phrase is matchable', () {
      for (final phrase in kPalPhrases) {
        expect(
          AllergenMatcher.findPalPhrases(AllergenMatcher.normalise(phrase)),
          isNotEmpty,
          reason: phrase,
        );
      }
    });
  });
}
