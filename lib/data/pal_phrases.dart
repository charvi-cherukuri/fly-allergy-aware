/// Precautionary allergen labelling (PAL) and the Open Food Facts tag map.
///
/// PAL is voluntary and unregulated in both the US and the EU. There is no
/// standard wording, no standard threshold, and no obligation to use it at all,
/// which is exactly why the phrase list below has to be this long and this
/// repetitive — "manufactured in a facility that also processes" and "made on
/// shared equipment with" are the same sentence written by two different
/// packaging teams.
///
/// The matcher treats a PAL hit as cross-contact evidence, not as a
/// declaration, and lets [Severity.blocksOnTrace] decide whether that is enough
/// to block the product.
library;

import '../models/allergen.dart';

/// Phrases that introduce cross-contact rather than an ingredient.
///
/// Order does not matter; the matcher keeps the longest phrase when two of
/// these overlap, so "may contain traces of" wins over the "may contain" and
/// "traces of" that sit inside it.
const List<String> kPalPhrases = [
  'may contain',
  'may contain traces of',
  'may contain traces',
  'may contain trace amounts of',
  'contains traces of',
  'traces of',
  'may occasionally contain',
  'manufactured in a facility that also processes',
  'manufactured in a facility that also handles',
  'manufactured in a facility that also uses',
  'manufactured in a facility that processes',
  'made in a facility that also processes',
  'produced in a facility that also processes',
  'packed in a facility that also processes',
  'processed in a facility that also processes',
  'manufactured on shared equipment with',
  'made on shared equipment with',
  'produced on equipment that also processes',
  'processed on the same equipment as',
  'made on equipment that also processes',
  'shared equipment',
  'shared facility',
  'same equipment',
  'same production line',
  'may be present',
  'allergen may be present',
  'not suitable for',
  'cannot guarantee',
  'we cannot guarantee',
  'not suitable for customers with',
  'this product may have come into contact with',
  'may have come in contact with',
  'handled in a facility',
  'packaged in a facility',
  'prepared in a kitchen that handles',
  'prepared on equipment',
  'made in a bakery that uses',
];

/// Open Food Facts taxonomy tags mapped onto our allergen enum.
///
/// OFF puts every tree nut species in its own tag, so a product tagged
/// `en:hazelnuts` never carries `en:nuts`. Both have to map to
/// [Allergen.treeNut] or a hazelnut declaration goes unnoticed.
///
/// `en:shea-nuts` is deliberately absent: shea is not a tree nut and is on the
/// global exclusion list.
const Map<String, Allergen> kOffTagToAllergen = {
  'en:milk': Allergen.milk,
  'en:milk-proteins': Allergen.milk,
  'en:lactose': Allergen.milk,

  'en:eggs': Allergen.egg,
  'en:egg': Allergen.egg,

  'en:peanuts': Allergen.peanut,
  'en:peanut': Allergen.peanut,

  // Tree nuts: the umbrella tags plus every species OFF tracks separately.
  'en:nuts': Allergen.treeNut,
  'en:tree-nuts': Allergen.treeNut,
  'en:almonds': Allergen.treeNut,
  'en:hazelnuts': Allergen.treeNut,
  'en:walnuts': Allergen.treeNut,
  'en:cashew-nuts': Allergen.treeNut,
  'en:cashew': Allergen.treeNut,
  'en:pecan-nuts': Allergen.treeNut,
  'en:pistachio': Allergen.treeNut,
  'en:pistachios': Allergen.treeNut,
  'en:brazil-nuts': Allergen.treeNut,
  'en:macadamia-nuts': Allergen.treeNut,
  'en:queensland-nuts': Allergen.treeNut,
  'en:pine-nuts': Allergen.treeNut,

  'en:soybeans': Allergen.soy,
  'en:soy': Allergen.soy,
  'en:soya': Allergen.soy,

  // OFF files all the gluten grains under en:gluten and also tags the grain.
  'en:gluten': Allergen.wheat,
  'en:wheat': Allergen.wheat,
  'en:barley': Allergen.wheat,
  'en:rye': Allergen.wheat,
  'en:oats': Allergen.wheat,
  'en:spelt': Allergen.wheat,
  'en:kamut': Allergen.wheat,

  'en:fish': Allergen.fish,

  'en:crustaceans': Allergen.shellfish,
  'en:shellfish': Allergen.shellfish,

  'en:sesame-seeds': Allergen.sesame,
  'en:sesame': Allergen.sesame,

  'en:molluscs': Allergen.mollusc,
  'en:mollusks': Allergen.mollusc,

  'en:celery': Allergen.celery,

  'en:mustard': Allergen.mustard,

  'en:lupin': Allergen.lupin,
  'en:lupine': Allergen.lupin,

  'en:sulphur-dioxide-and-sulphites': Allergen.sulphite,
  'en:sulfur-dioxide-and-sulfites': Allergen.sulphite,
  'en:sulphites': Allergen.sulphite,
  'en:sulfites': Allergen.sulphite,
};

/// The umbrella tree-nut tags. A product carrying only one of these has been
/// tagged "some tree nut, unspecified", which is not enough to block a person
/// who is allergic to one species.
const Set<String> kUnspecifiedTreeNutTags = {'en:nuts', 'en:tree-nuts'};
