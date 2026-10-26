import '../data/allergen_keywords.dart';
import '../data/countries.dart';
import '../models/allergen.dart';
import '../models/custom_allergen.dart';
import '../models/emergency.dart';
import '../models/profile.dart';
import '../models/travel.dart';
import '../models/trip.dart';
import 'matcher.dart';

// Turns what someone said into form fields, with plain rules.
//
// This is the path every phone gets. On an Apple Intelligence phone the
// on-device model is tried first and these rules fill whatever it leaves
// empty; everywhere else these rules are all there is. They understand
// English only, and they are deliberately literal: a field the rules are not
// sure about stays empty for the user to fill, because a confidently wrong
// field is worse than a blank one.
//
// Nothing here saves anything. Every result lands in a form the user reads
// before tapping Save.

/// Fields heard for a trip.
class TripHeard {
  String? countryCode;
  DateTime? startsOn;
  DateTime? endsOn;
  final Set<String> travelerIds = <String>{};

  bool get isEmpty =>
      countryCode == null && startsOn == null && endsOn == null && travelerIds.isEmpty;
}

/// Fields heard for an exposure. Null means "not heard — leave as is".
class ExposureHeard {
  String? profileId;
  final List<String> allergens = <String>[];
  ExposureRoute? route;
  String? source;
  ExposurePlace? place;
  String? placeName;
  int? row;
  final Set<String> actions = <String>{};
  ExposureOutcome? outcome;
}

/// Fields heard for a reaction.
class ReactionHeard {
  final Set<String> symptoms = <String>{};
  bool? epiUsed;
  bool? soughtCare;
  String? suspectedFood;
}

/// What a spoken sentence asks emergency mode to do.
enum EmergencyCommand {
  epinephrineGiven,
  callForHelp,
  confirmCall,
  textFamily,
  showCrew,
  guidance,

  /// Not a command: record it as a note.
  note,
}

class VoiceParser {
  const VoiceParser._();

  static String _norm(String s) => ' ${s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';

  static bool _has(String n, List<String> phrases) =>
      phrases.any((String p) => n.contains(' $p '));

  // ------------------------------------------------------------------ people

  /// Profiles whose name was said. "me", "I" and "myself" mean [meId].
  static Set<String> peopleIn(String text, List<Profile> profiles, {String? meId}) {
    final String n = _norm(text);
    final Set<String> out = <String>{};
    for (final Profile p in profiles) {
      final String first = p.name.trim().split(RegExp(r'\s+')).first.toLowerCase();
      if (first.isNotEmpty && first != 'me' && n.contains(' $first ')) out.add(p.id);
    }
    if (meId != null && _has(n, <String>['me', 'i', "i'm", 'myself', 'my'])) {
      out.add(meId);
    }
    return out;
  }

  // ------------------------------------------------------------------- dates

  static const List<String> _months = <String>[
    'january', 'february', 'march', 'april', 'may', 'june', 'july',
    'august', 'september', 'october', 'november', 'december',
  ];

  static const List<String> _weekdays = <String>[
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  ];

  static const Map<String, int> _numberWords = <String, int>{
    'a': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
    'fourteen': 14, 'twenty': 20, 'thirty': 30,
  };

  /// Every date mentioned, in the order said. Understands "March 12",
  /// "12th of March", "today", "tomorrow" and "next Friday". A month and day
  /// with no year means the next time that date comes round.
  static List<DateTime> datesIn(String text, DateTime now) {
    final String n = _norm(text)
        .replaceAllMapped(RegExp(r'(\d+)(st|nd|rd|th)\b'), (Match m) => m.group(1)!);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<(int, DateTime)> found = <(int, DateTime)>[];

    DateTime upcoming(int month, int day) {
      DateTime d = DateTime(today.year, month, day);
      if (d.isBefore(today)) d = DateTime(today.year + 1, month, day);
      return d;
    }

    final String monthAlt = _months.join('|');
    // "march 12" / "march 12 2027"
    for (final RegExpMatch m in RegExp('($monthAlt) (\\d{1,2})(?: (\\d{4}))?').allMatches(n)) {
      final int month = _months.indexOf(m.group(1)!) + 1;
      final int day = int.parse(m.group(2)!);
      if (day < 1 || day > 31) continue;
      final String? y = m.group(3);
      found.add((m.start, y == null ? upcoming(month, day) : DateTime(int.parse(y), month, day)));
    }
    // "12 march" / "12 of march"
    for (final RegExpMatch m in RegExp('(\\d{1,2}) (?:of )?($monthAlt)').allMatches(n)) {
      final int day = int.parse(m.group(1)!);
      final int month = _months.indexOf(m.group(2)!) + 1;
      if (day < 1 || day > 31) continue;
      if (found.any(((int, DateTime) f) => (f.$1 - m.start).abs() < 12)) continue;
      found.add((m.start, upcoming(month, day)));
    }
    // "to the 20th" after a month date: same month.
    for (final RegExpMatch m in RegExp(r'(?:to|until|till|through) (?:the )?(\d{1,2})(?! (?:' '$monthAlt' r'))\b').allMatches(n)) {
      final int day = int.parse(m.group(1)!);
      final List<(int, DateTime)> before =
          found.where(((int, DateTime) f) => f.$1 < m.start).toList();
      if (before.isEmpty || day < 1 || day > 31) continue;
      final DateTime ref = before.last.$2;
      DateTime d = DateTime(ref.year, ref.month, day);
      if (d.isBefore(ref)) d = DateTime(ref.year, ref.month + 1, day);
      found.add((m.start, d));
    }
    int at(String word) => n.indexOf(' $word ');
    if (at('today') >= 0) found.add((at('today'), today));
    if (at('tonight') >= 0) found.add((at('tonight'), today));
    if (at('tomorrow') >= 0) found.add((at('tomorrow'), today.add(const Duration(days: 1))));
    for (int i = 0; i < 7; i++) {
      final RegExpMatch? m = RegExp('(next |this )?${_weekdays[i]}').firstMatch(n);
      if (m == null) continue;
      int ahead = (i + 1 - today.weekday) % 7;
      if (ahead == 0 || m.group(1) == 'next ') ahead = ahead == 0 ? 7 : ahead;
      found.add((m.start, today.add(Duration(days: ahead))));
    }
    found.sort(((int, DateTime) a, (int, DateTime) b) => a.$1.compareTo(b.$1));
    return found.map(((int, DateTime) f) => f.$2).toList();
  }

  /// "for a week", "for 10 days", "for two weeks".
  static Duration? durationIn(String text) {
    final String n = _norm(text);
    final RegExpMatch? m =
        RegExp(r' for (a|an|\d+|[a-z]+) (day|days|week|weeks|night|nights) ').firstMatch(n);
    if (m == null) return null;
    final String q = m.group(1)!;
    final int count = int.tryParse(q) ?? _numberWords[q] ?? (q == 'an' ? 1 : 0);
    if (count <= 0) return null;
    final bool weeks = m.group(2)!.startsWith('week');
    return Duration(days: weeks ? count * 7 : count);
  }

  // ----------------------------------------------------------------- places

  /// Major cities travelers name instead of the country.
  static const Map<String, String> _cities = <String, String>{
    'tokyo': 'JP', 'osaka': 'JP', 'kyoto': 'JP', 'london': 'GB', 'manchester': 'GB',
    'edinburgh': 'GB', 'paris': 'FR', 'nice': 'FR', 'lyon': 'FR', 'berlin': 'DE',
    'munich': 'DE', 'frankfurt': 'DE', 'rome': 'IT', 'milan': 'IT', 'venice': 'IT',
    'florence': 'IT', 'madrid': 'ES', 'barcelona': 'ES', 'lisbon': 'PT',
    'porto': 'PT', 'amsterdam': 'NL', 'dublin': 'IE', 'zurich': 'CH', 'geneva': 'CH',
    'vienna': 'AT', 'prague': 'CZ', 'athens': 'GR', 'istanbul': 'TR', 'dubai': 'AE',
    'abu dhabi': 'AE', 'doha': 'QA', 'singapore': 'SG', 'hong kong': 'HK',
    'seoul': 'KR', 'beijing': 'CN', 'shanghai': 'CN', 'taipei': 'TW',
    'bangkok': 'TH', 'phuket': 'TH', 'bali': 'ID', 'delhi': 'IN', 'mumbai': 'IN',
    'sydney': 'AU', 'melbourne': 'AU', 'auckland': 'NZ', 'toronto': 'CA',
    'vancouver': 'CA', 'montreal': 'CA', 'cancun': 'MX', 'mexico city': 'MX',
    'new york': 'US', 'los angeles': 'US', 'san francisco': 'US', 'chicago': 'US',
    'orlando': 'US', 'honolulu': 'US', 'hawaii': 'US', 'sao paulo': 'BR',
    'rio': 'BR', 'buenos aires': 'AR', 'cape town': 'ZA', 'nairobi': 'KE',
    'cairo': 'EG', 'tel aviv': 'IL', 'reykjavik': 'IS', 'copenhagen': 'DK',
    'stockholm': 'SE', 'oslo': 'NO', 'helsinki': 'FI', 'warsaw': 'PL',
    'budapest': 'HU', 'hanoi': 'VN', 'ho chi minh city': 'VN', 'manila': 'PH',
    'kuala lumpur': 'MY',
  };

  /// The destination: a country or city said after "to" or "in" wins over
  /// one said elsewhere (often the place you are leaving).
  static String? countryIn(String text) {
    final String n = _norm(text);
    String? best;
    int bestScore = -1;
    void consider(String name, String code) {
      final int i = n.indexOf(' $name ');
      if (i < 0) return;
      final String before = n.substring(0, i);
      final int score = RegExp(r'(to|in|visiting|for)( the)?$').hasMatch(before) ? 2 : 1;
      if (score > bestScore) {
        best = code;
        bestScore = score;
      }
    }

    for (final Country c in kCountries) {
      consider(c.name.toLowerCase(), c.code);
    }
    consider('the uk', 'GB');
    consider('england', 'GB');
    consider('scotland', 'GB');
    consider('america', 'US');
    consider('the us', 'US');
    consider('the usa', 'US');
    consider('the states', 'US');
    consider('korea', 'KR');
    consider('holland', 'NL');
    consider('turkey', 'TR');
    consider('czech republic', 'CZ');
    _cities.forEach(consider);
    return best;
  }

  // ------------------------------------------------------------------- trip

  static TripHeard trip(
    String text, {
    required DateTime now,
    required List<Profile> profiles,
    String? meId,
  }) {
    final TripHeard out = TripHeard()
      ..countryCode = countryIn(text)
      ..travelerIds.addAll(peopleIn(text, profiles, meId: meId));
    final List<DateTime> dates = datesIn(text, now);
    if (dates.isNotEmpty) out.startsOn = dates.first;
    if (dates.length > 1 && !dates[1].isBefore(dates.first)) out.endsOn = dates[1];
    final Duration? length = durationIn(text);
    if (out.endsOn == null && out.startsOn != null && length != null) {
      out.endsOn = out.startsOn!.add(length);
    }
    return out;
  }

  // -------------------------------------------------------------- allergens

  /// Everyday words for the regulated allergens that a label would never use.
  static const Map<Allergen, List<String>> _spoken = <Allergen, List<String>>{
    Allergen.milk: <String>['dairy', 'milk', 'cheese', 'yogurt', 'yoghurt', 'cream', 'ice cream'],
    Allergen.egg: <String>['egg', 'eggs'],
    Allergen.peanut: <String>['peanut', 'peanuts', 'peanut butter'],
    Allergen.treeNut: <String>['nut', 'nuts', 'tree nut', 'tree nuts', 'almond', 'almonds',
      'cashew', 'cashews', 'walnut', 'walnuts', 'pecan', 'pecans', 'pistachio',
      'pistachios', 'hazelnut', 'hazelnuts', 'trail mix', 'mixed nuts'],
    Allergen.soy: <String>['soy', 'soya', 'tofu'],
    Allergen.wheat: <String>['wheat', 'gluten', 'bread'],
    Allergen.fish: <String>['fish', 'salmon', 'tuna'],
    Allergen.shellfish: <String>['shellfish', 'shrimp', 'prawn', 'prawns', 'crab', 'lobster'],
    Allergen.sesame: <String>['sesame', 'tahini'],
    Allergen.mollusc: <String>['mussels', 'oysters', 'clams', 'squid'],
    Allergen.celery: <String>['celery'],
    Allergen.mustard: <String>['mustard'],
    Allergen.lupin: <String>['lupin'],
    Allergen.sulphite: <String>['sulfites', 'sulphites', 'wine'],
  };

  /// Allergen labels mentioned, in the app's own spelling, plus any of the
  /// person's custom allergens said by name.
  static List<String> allergensIn(String text, {List<CustomAllergen> custom = const <CustomAllergen>[]}) {
    final String n = AllergenMatcher.normalise(text);
    final List<String> out = <String>[];
    for (final Allergen a in Allergen.values) {
      final List<String> terms = <String>[
        ...?_spoken[a],
        ...?kAllergenKeywords[a]?.where((String k) => k.split(' ').length <= 2),
      ];
      if (AllergenMatcher.findTerms(n, terms).isNotEmpty) out.add(a.label);
    }
    // "nuts" said about peanuts should not also log tree nuts.
    if (out.contains(Allergen.peanut.label) &&
        out.contains(Allergen.treeNut.label) &&
        AllergenMatcher.findTerms(n, _spoken[Allergen.treeNut]!
            .where((String t) => t != 'nut' && t != 'nuts')
            .toList()).isEmpty) {
      out.remove(Allergen.treeNut.label);
    }
    for (final CustomAllergen c in custom) {
      if (AllergenMatcher.findTerms(n, <String>[c.name, ...c.keywords]).isNotEmpty &&
          !out.contains(c.name)) {
        out.add(c.name);
      }
    }
    return out;
  }

  // --------------------------------------------------------------- exposure

  static ExposureHeard exposure(
    String text, {
    required List<Profile> people,
    List<CustomAllergen> custom = const <CustomAllergen>[],
  }) {
    final String n = _norm(text);
    final ExposureHeard out = ExposureHeard();

    final Set<String> who = peopleIn(text, people);
    if (who.length == 1) out.profileId = who.single;

    out.allergens.addAll(allergensIn(text, custom: custom));

    if (_has(n, <String>['ate', 'eaten', 'eat', 'swallowed', 'drank', 'bit', 'bite', 'tasted', 'had some'])) {
      out.route = ExposureRoute.ingested;
    } else if (_has(n, <String>['crumbs', 'tray', 'tray table', 'armrest', 'armrests', 'residue', 'surface', 'table', 'seat'])) {
      out.route = ExposureRoute.surface;
    } else if (_has(n, <String>['touched', 'touch', 'skin', 'hands', 'hand', 'kissed', 'rubbed'])) {
      out.route = ExposureRoute.skin;
    } else if (_has(n, <String>['smell', 'smelled', 'air', 'dust', 'steam', 'cooking', 'airborne', 'breathed'])) {
      out.route = ExposureRoute.airborne;
    } else if (_has(n, <String>['may contain', 'cross contact', 'cross contamination', 'shared fryer', 'same fryer'])) {
      out.route = ExposureRoute.crossContact;
    } else if (_has(n, <String>['saw', 'seen', 'nearby', 'next to', 'across the aisle', 'opened', 'eating'])) {
      out.route = ExposureRoute.observedNearby;
    }

    if (_has(n, <String>['plane', 'flight', 'aircraft', 'cabin', 'row', 'flight attendant', 'onboard', 'on board'])) {
      out.place = ExposurePlace.flight;
    } else if (_has(n, <String>['airport', 'gate', 'lounge', 'security'])) {
      out.place = ExposurePlace.airport;
    } else if (_has(n, <String>['hotel', 'airbnb', 'rental', 'room service', 'breakfast buffet'])) {
      out.place = ExposurePlace.hotel;
    } else if (_has(n, <String>['restaurant', 'cafe', 'café', 'diner', 'bakery', 'waiter', 'menu', 'bar'])) {
      out.place = ExposurePlace.restaurant;
    } else if (_has(n, <String>['train', 'bus', 'taxi', 'uber', 'car', 'ferry', 'ship', 'cruise'])) {
      out.place = ExposurePlace.transport;
    }

    final RegExpMatch? row = RegExp(r' row (\d{1,2}) ').firstMatch(n);
    if (row != null) {
      out.row = int.parse(row.group(1)!);
      out.place ??= ExposurePlace.flight;
    }

    final RegExpMatch? from = RegExp(r' from (?:the |a |an |my |his |her |their )?([a-z ]+?)(?: and | but | so | then | in | on | at |$)')
        .firstMatch(n.trimRight());
    if (from != null && from.group(1)!.trim().split(' ').length <= 5) {
      out.source = from.group(1)!.trim();
    }

    final Map<String, List<String>> actions = <String, List<String>>{
      'Washed hands': <String>['washed', 'wash', 'washing'],
      'Wiped the surface': <String>['wiped', 'wipe', 'cleaned'],
      'Moved seats or tables': <String>['moved', 'move', 'changed seats', 'switched seats'],
      'Told the crew or staff': <String>['told', 'tell', 'informed', 'flight attendant', 'waiter', 'staff'],
      'Took an antihistamine': <String>['antihistamine', 'benadryl', 'zyrtec', 'cetirizine', 'claritin', 'allegra'],
      'Gave epinephrine': <String>['epipen', 'epi pen', 'epinephrine', 'adrenaline', 'auvi q', 'injector'],
      'Watched for symptoms': <String>['watched', 'watching', 'monitored', 'keeping an eye'],
    };
    actions.forEach((String label, List<String> words) {
      if (_has(n, words)) out.actions.add(label);
    });

    if (_has(n, <String>['no symptoms', 'no reaction', 'fine', 'okay', 'ok', 'nothing happened', 'all good'])) {
      out.outcome = ExposureOutcome.noSymptoms;
    }
    if (reaction(text).symptoms.isNotEmpty || out.actions.contains('Gave epinephrine')) {
      out.outcome = ExposureOutcome.symptoms;
    }
    return out;
  }

  // --------------------------------------------------------------- reaction

  /// Spoken ways of describing each symptom in the app's vocabulary.
  static const Map<String, List<String>> _symptomWords = <String, List<String>>{
    'Itchy mouth': <String>['itchy mouth', 'mouth itchy', 'tingly mouth', 'tingling mouth', 'itchy throat'],
    'Hives / rash': <String>['hives', 'rash', 'welts', 'blotchy', 'red spots'],
    'Swelling (lips, face, eyes)': <String>['swelling', 'swollen', 'puffy', 'lips swelling', 'face swelling'],
    'Stomach pain': <String>['stomach pain', 'stomach ache', 'tummy ache', 'cramps', 'stomach hurts'],
    'Nausea / vomiting': <String>['nausea', 'nauseous', 'vomiting', 'vomited', 'threw up', 'throwing up', 'sick to'],
    'Diarrhea': <String>['diarrhea', 'diarrhoea'],
    'Runny nose / sneezing': <String>['runny nose', 'sneezing', 'sneezed', 'stuffy nose'],
    'Coughing': <String>['cough', 'coughing'],
    'Wheezing': <String>['wheezing', 'wheeze', 'wheezy'],
    'Throat tightness': <String>['throat tight', 'tight throat', 'throat tightness', 'throat closing', 'throat is closing'],
    'Trouble breathing': <String>["can't breathe", 'cannot breathe', 'trouble breathing', 'hard to breathe', 'short of breath', 'struggling to breathe'],
    'Trouble swallowing': <String>["can't swallow", 'trouble swallowing', 'hard to swallow'],
    'Dizziness / faintness': <String>['dizzy', 'faint', 'lightheaded', 'light headed'],
    'Pale or blue color': <String>['pale', 'blue lips', 'turning blue', 'went blue'],
    'Loss of consciousness': <String>['passed out', 'fainted', 'unconscious', 'unresponsive', 'collapsed'],
  };

  static ReactionHeard reaction(String text) {
    final String n = _norm(text);
    final ReactionHeard out = ReactionHeard();
    _symptomWords.forEach((String symptom, List<String> words) {
      if (_has(n, words) && kSymptomOptions.contains(symptom)) out.symptoms.add(symptom);
    });
    if (_has(n, <String>['epipen', 'epi pen', 'epinephrine', 'adrenaline', 'auvi q', 'injector', 'injected'])) {
      out.epiUsed = true;
    }
    if (_has(n, <String>['ambulance', 'paramedics', 'hospital', 'er', 'emergency room', 'a and e', 'urgent care', 'doctor'])) {
      out.soughtCare = true;
    }
    final RegExpMatch? ate = RegExp(r' (?:after eating|after having|ate|eating|from) (?:the |a |an |some )?([a-z ]+?)(?: and | but | then | at | in |$)')
        .firstMatch(n.trimRight());
    if (ate != null && ate.group(1)!.trim().split(' ').length <= 5) {
      out.suspectedFood = ate.group(1)!.trim();
    }
    return out;
  }

  // --------------------------------------------------------------- incident

  static IncidentKind incidentKind(String text, {required bool onFlight}) {
    final String n = _norm(text);
    if (!onFlight) {
      return _has(n, <String>['restaurant', 'hotel', 'waiter', 'chef', 'kitchen', 'staff', 'menu', 'cafe'])
          ? IncidentKind.venueFailure
          : IncidentKind.other;
    }
    if (_has(n, <String>['refused boarding', 'denied boarding', "wouldn't let", 'would not let', 'not allowed to board', 'refused to let'])) {
      return IncidentKind.refusedBoarding;
    }
    if (_has(n, <String>['reaction', 'hives', 'epipen', 'epinephrine', 'swelling', "couldn't breathe"])) {
      return IncidentKind.allergicReaction;
    }
    if (_has(n, <String>['rude', 'laughed', 'dismissive', 'ignored', 'refused to', 'yelled', 'argued'])) {
      return IncidentKind.crewConduct;
    }
    return IncidentKind.accommodationFailure;
  }

  // -------------------------------------------------------------- emergency

  /// What a sentence said during emergency mode asks for. Deliberately
  /// narrow: anything that is not clearly a command becomes a note, so a
  /// description of symptoms can never trigger an action by accident.
  static EmergencyCommand emergencyCommand(String text) {
    final String n = _norm(text);
    final int words = n.trim().split(' ').length;
    if (_has(n, <String>['yes call', 'yes call them', 'call now', 'yes place the call', 'yes'])
        && words <= 4) {
      return EmergencyCommand.confirmCall;
    }
    if (words <= 8 &&
        _has(n, <String>['epinephrine given', 'epipen given', 'epi given', 'pen given',
          'gave the epipen', 'gave epinephrine', 'used the epipen', 'injected', 'second dose',
          'dose given', 'gave the pen', 'used the pen', 'adrenaline given'])) {
      return EmergencyCommand.epinephrineGiven;
    }
    if (words <= 6 &&
        _has(n, <String>['call for help', 'call an ambulance', 'call ambulance', 'call emergency',
          'call 911', 'call nine one one', 'call the ambulance', 'call help'])) {
      return EmergencyCommand.callForHelp;
    }
    if (words <= 6 && _has(n, <String>['text my family', 'text family', 'message my family',
          'text mom', 'text dad', 'text my contacts', 'send a text', 'tell my family'])) {
      return EmergencyCommand.textFamily;
    }
    if (words <= 6 && _has(n, <String>['show crew card', 'show the crew', 'crew card', 'alert the crew',
          'show crew', 'flight attendant card'])) {
      return EmergencyCommand.showCrew;
    }
    if (words <= 6 && _has(n, <String>['what do i do', 'what should i do', 'guidance', 'help me', 'show guidance'])) {
      return EmergencyCommand.guidance;
    }
    return EmergencyCommand.note;
  }
}
