/// Countries a trip can go to: the number that reaches an ambulance, and the
/// languages worth having offline there.
///
/// The emergency number is the one that reaches **medical** help, because that
/// is the only reason this app ever dials. Where a country's general number
/// (112, 911) also works it is listed in [Country.alsoWorks], but the medical
/// line comes first — in Japan 110 is the police, and someone mid-reaction
/// should not be routed through them.
///
/// Countries are included only where the number is well established. Anywhere
/// else falls back to [kFallbackEmergencyNumber], and the emergency screen says
/// that it is a fallback rather than presenting it as local knowledge.
///
/// Review before every release. Emergency numbers change rarely, but they do
/// change, and this table is the one place a stale fact could cost a minute.
class Country {
  const Country({
    required this.code,
    required this.name,
    required this.emergency,
    this.alsoWorks = const <String>[],
    this.languages = const <String>[],
  });

  /// ISO 3166-1 alpha-2.
  final String code;
  final String name;

  /// Reaches an ambulance.
  final String emergency;

  /// Other numbers that also reach emergency services.
  final List<String> alsoWorks;

  /// Translator language codes (see `translator_languages.dart`) spoken there,
  /// most widely used first. English is listed only where it is an official
  /// or everyday language, because suggesting an English pack to a traveler
  /// who reads English is noise.
  final List<String> languages;

  /// The flag emoji, derived from the code so it cannot drift from it.
  String get flag => String.fromCharCodes(
        code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
      );
}

/// 112 is answered on mobile networks across Europe and redirected to the
/// local service in many other countries. It is the least-bad guess when the
/// destination is unknown, and it is presented as a guess.
const String kFallbackEmergencyNumber = '112';

/// Sorted by name for the picker.
const List<Country> kCountries = <Country>[
  Country(code: 'AR', name: 'Argentina', emergency: '107', alsoWorks: ['911'], languages: ['es']),
  Country(code: 'AU', name: 'Australia', emergency: '000', alsoWorks: ['112'], languages: ['en']),
  Country(code: 'AT', name: 'Austria', emergency: '144', alsoWorks: ['112'], languages: ['de']),
  Country(code: 'BD', name: 'Bangladesh', emergency: '999', languages: ['bn']),
  Country(code: 'BE', name: 'Belgium', emergency: '112', languages: ['nl', 'fr', 'de']),
  Country(code: 'BR', name: 'Brazil', emergency: '192', languages: ['pt']),
  Country(code: 'CA', name: 'Canada', emergency: '911', languages: ['en', 'fr']),
  Country(code: 'CL', name: 'Chile', emergency: '131', languages: ['es']),
  Country(code: 'CN', name: 'China', emergency: '120', languages: ['zh']),
  Country(code: 'CO', name: 'Colombia', emergency: '123', languages: ['es']),
  Country(code: 'CR', name: 'Costa Rica', emergency: '911', languages: ['es']),
  Country(code: 'CZ', name: 'Czechia', emergency: '155', alsoWorks: ['112'], languages: ['cs']),
  Country(code: 'DK', name: 'Denmark', emergency: '112', languages: ['da']),
  Country(code: 'DO', name: 'Dominican Republic', emergency: '911', languages: ['es']),
  Country(code: 'EG', name: 'Egypt', emergency: '123', languages: ['ar']),
  Country(code: 'FI', name: 'Finland', emergency: '112', languages: ['fi', 'sv']),
  Country(code: 'FR', name: 'France', emergency: '15', alsoWorks: ['112'], languages: ['fr']),
  Country(code: 'DE', name: 'Germany', emergency: '112', languages: ['de']),
  Country(code: 'GR', name: 'Greece', emergency: '166', alsoWorks: ['112'], languages: ['el']),
  Country(code: 'HK', name: 'Hong Kong', emergency: '999', languages: ['zh', 'en']),
  Country(code: 'HU', name: 'Hungary', emergency: '104', alsoWorks: ['112'], languages: ['hu']),
  Country(code: 'IS', name: 'Iceland', emergency: '112'),
  Country(code: 'IN', name: 'India', emergency: '112', alsoWorks: ['108'], languages: ['hi', 'en', 'ta', 'te', 'mr', 'bn', 'gu', 'kn']),
  Country(code: 'ID', name: 'Indonesia', emergency: '112', alsoWorks: ['118', '119'], languages: ['id']),
  Country(code: 'IE', name: 'Ireland', emergency: '112', alsoWorks: ['999'], languages: ['en']),
  Country(code: 'IL', name: 'Israel', emergency: '101', languages: ['he', 'ar']),
  Country(code: 'IT', name: 'Italy', emergency: '112', alsoWorks: ['118'], languages: ['it']),
  Country(code: 'JP', name: 'Japan', emergency: '119', languages: ['ja']),
  Country(code: 'JO', name: 'Jordan', emergency: '911', languages: ['ar']),
  Country(code: 'KE', name: 'Kenya', emergency: '999', alsoWorks: ['112'], languages: ['sw', 'en']),
  Country(code: 'MY', name: 'Malaysia', emergency: '999', alsoWorks: ['112'], languages: ['ms']),
  Country(code: 'MX', name: 'Mexico', emergency: '911', languages: ['es']),
  Country(code: 'NL', name: 'Netherlands', emergency: '112', languages: ['nl']),
  Country(code: 'NZ', name: 'New Zealand', emergency: '111', languages: ['en']),
  Country(code: 'NG', name: 'Nigeria', emergency: '112', languages: ['en']),
  Country(code: 'NO', name: 'Norway', emergency: '113', alsoWorks: ['112'], languages: ['no']),
  Country(code: 'PH', name: 'Philippines', emergency: '911', languages: ['tl', 'en']),
  Country(code: 'PL', name: 'Poland', emergency: '112', alsoWorks: ['999'], languages: ['pl']),
  Country(code: 'PT', name: 'Portugal', emergency: '112', languages: ['pt']),
  Country(code: 'QA', name: 'Qatar', emergency: '999', languages: ['ar']),
  Country(code: 'RO', name: 'Romania', emergency: '112', languages: ['ro']),
  Country(code: 'SA', name: 'Saudi Arabia', emergency: '997', alsoWorks: ['911'], languages: ['ar']),
  Country(code: 'SG', name: 'Singapore', emergency: '995', languages: ['en', 'zh', 'ms', 'ta']),
  Country(code: 'ZA', name: 'South Africa', emergency: '10177', alsoWorks: ['112'], languages: ['en']),
  Country(code: 'KR', name: 'South Korea', emergency: '119', languages: ['ko']),
  Country(code: 'ES', name: 'Spain', emergency: '112', languages: ['es']),
  Country(code: 'SE', name: 'Sweden', emergency: '112', languages: ['sv']),
  Country(code: 'CH', name: 'Switzerland', emergency: '144', alsoWorks: ['112'], languages: ['de', 'fr', 'it']),
  Country(code: 'TW', name: 'Taiwan', emergency: '119', languages: ['zh']),
  Country(code: 'TH', name: 'Thailand', emergency: '1669', alsoWorks: ['191'], languages: ['th']),
  Country(code: 'TR', name: 'Türkiye', emergency: '112', languages: ['tr']),
  Country(code: 'UA', name: 'Ukraine', emergency: '103', alsoWorks: ['112'], languages: ['uk']),
  Country(code: 'AE', name: 'United Arab Emirates', emergency: '998', alsoWorks: ['999'], languages: ['ar']),
  Country(code: 'GB', name: 'United Kingdom', emergency: '999', alsoWorks: ['112'], languages: ['en']),
  Country(code: 'US', name: 'United States', emergency: '911', languages: ['en', 'es']),
  Country(code: 'VN', name: 'Vietnam', emergency: '115', languages: ['vi']),
];

/// The country for an ISO code, or null when it is not in the table.
Country? countryFor(String code) {
  final c = code.trim().toUpperCase();
  if (c.isEmpty) return null;
  for (final country in kCountries) {
    if (country.code == c) return country;
  }
  return null;
}

/// The number to dial for an ambulance in [code], and whether it is a
/// fallback rather than a known local number.
({String number, bool isFallback}) emergencyNumberFor(String code) {
  final country = countryFor(code);
  return country == null
      ? (number: kFallbackEmergencyNumber, isFallback: true)
      : (number: country.emergency, isFallback: false);
}
