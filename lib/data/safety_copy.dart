// The app's safety wording, in one place so it can be reviewed in one place.
//
// Plain words, short sentences, a reason for every recommendation. Calm, not
// alarming — but never reassuring beyond what is true. Sources for every
// factual claim are listed in docs/SOURCES.md.

/// Shown at the foot of guidance screens.
const String kMedicalNoteShort =
    'Any reaction can get worse quickly. Follow the plan from your doctor.';

/// Shown once in onboarding, and in Settings.
const String kMedicalNoteLong =
    'Allergic reactions can change fast. One that starts mild can become '
    'life-threatening within minutes.\n\n'
    'Work with your doctor on an allergy and emergency plan made for you.\n\n'
    'This app helps you keep records and find information. It is not medical '
    'advice, and it cannot promise that any food or flight is safe.';

/// One piece of advice, with the reason for it.
class SafetyTip {
  const SafetyTip(this.advice, this.reason);
  final String advice;
  final String reason;
}

/// How to prevent a reaction on a flight.
const List<SafetyTip> kFlightPreventionTips = <SafetyTip>[
  SafetyTip(
    'Bring your own safe food.',
    'Airline food may contain allergens, and its ingredient list may be '
        'incomplete.',
  ),
  SafetyTip(
    'Check the full ingredient list.',
    'If the list is missing or incomplete, don’t eat it.',
  ),
  SafetyTip(
    'Don’t rely only on what the crew says.',
    'Crew can’t check every ingredient or stop cross-contact.',
  ),
  SafetyTip(
    'Carry your own emergency medicine.',
    'The plane’s medical kit may not have what you need.',
  ),
  SafetyTip(
    'Have an emergency plan.',
    'A severe reaction needs treatment right away. Sometimes the plane has to '
        'land early.',
  ),
];

/// What US rules require in a plane's medical kit, and what to expect.
const List<String> kMedicalKitFacts = <String>[
  'US airlines must carry epinephrine in their medical kit. Most carry it as a '
      'vial and syringe, not an auto-injector. A trained person has to measure '
      'the dose.',
  'Airlines outside the US follow their own rules. Kits differ by airline and '
      'sometimes by plane.',
  'So always carry your own auto-injectors, and keep them with you — not in a '
      'checked bag.',
  'If a reaction is serious, the crew may ask for a doctor on board, and the '
      'pilots may land early to get medical help.',
];

enum EpiStatus {
  carries('Carries auto-injectors'),
  addingNow('Adding auto-injectors now');

  const EpiStatus(this.label);
  final String label;
}

/// An airline reported to carry epinephrine auto-injectors in its medical kit.
class AirlineEpinephrine {
  const AirlineEpinephrine({
    required this.airline,
    required this.status,
    required this.detail,
    required this.source,
    required this.url,
  });

  final String airline;
  final EpiStatus status;
  final String detail;
  final String source;
  final String url;
}

/// When [kAirlineEpinephrine] was last checked.
const String kAirlineEpinephrineChecked = 'October 2026';

/// Airlines reported to carry auto-injectors. Every entry has a source; none
/// was confirmed on the airline's own website, so the screen says to ask the
/// crew. Equipment can differ from plane to plane.
const List<AirlineEpinephrine> kAirlineEpinephrine = <AirlineEpinephrine>[
  AirlineEpinephrine(
    airline: 'American Airlines',
    status: EpiStatus.carries,
    detail: 'Adult and child doses, since late 2019.',
    source: 'Allergic Living, September 2026',
    url: 'https://www.allergicliving.com/2026/09/28/delta-allegiant-add-epi-injectors-to-medical-kits-to-step-up-safety/',
  ),
  AirlineEpinephrine(
    airline: 'JetBlue',
    status: EpiStatus.carries,
    detail: 'In addition to what US rules require.',
    source: 'CBS News, December 2022; Allergic Living, 2026',
    url: 'https://www.cbsnews.com/news/in-flight-emergencies-airlines-medical-kit-requirements/',
  ),
  AirlineEpinephrine(
    airline: 'Southwest Airlines',
    status: EpiStatus.carries,
    detail: 'Added across the fleet during 2024, alongside vials.',
    source: 'Allergic Living, 2025–2026',
    url: 'https://www.allergicliving.com/2026/09/28/delta-allegiant-add-epi-injectors-to-medical-kits-to-step-up-safety/',
  ),
  AirlineEpinephrine(
    airline: 'Alaska Airlines',
    status: EpiStatus.carries,
    detail: 'Reported in 2022. Ask the crew to confirm.',
    source: 'CBS News, December 2022',
    url: 'https://www.cbsnews.com/news/in-flight-emergencies-airlines-medical-kit-requirements/',
  ),
  AirlineEpinephrine(
    airline: 'Delta Air Lines',
    status: EpiStatus.addingNow,
    detail: 'Being added to every plane through 2027, so some planes may not '
        'have them yet.',
    source: 'Allergic Living, September 2026',
    url: 'https://www.allergicliving.com/2026/09/28/delta-allegiant-add-epi-injectors-to-medical-kits-to-step-up-safety/',
  ),
  AirlineEpinephrine(
    airline: 'Allegiant Air',
    status: EpiStatus.addingNow,
    detail: 'Being added alongside vials. No finish date announced.',
    source: 'Allergic Living, September 2026',
    url: 'https://www.allergicliving.com/2026/09/28/delta-allegiant-add-epi-injectors-to-medical-kits-to-step-up-safety/',
  ),
];

/// The default "please don't feed my child" message.
const String kChildCardDefault =
    'Please do not give my child any food without my permission. This '
    'includes sweets, candy, chocolate, snacks and drinks. My child has food '
    'allergies, and even a small amount may be dangerous. Please check with me '
    'before offering anything.';

/// The short version, for showing at a glance.
const String kChildCardShortDefault =
    'Please don’t give my child any food or drinks. Food allergies — ask me '
    'first.';
