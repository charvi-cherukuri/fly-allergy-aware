// Where the emergency medical kit is *typically* stowed, by aircraft family.
//
// No public database maps the EMK to a tail number, and no carrier publishes
// it. What exists is a consistent operational pattern: the kit is a sealed
// case, it lives in a galley or crew-accessible stowage, and cabin crew know
// exactly where it is because they check it before every flight.
//
// So this file ships *guidance*, deliberately hedged. Every stowage string
// says "typically". Every record's `notes` says the definitive answer is to
// ask a flight attendant. That hedging is the point: a passenger who walks to
// the wrong galley during an emergency because an app told them a location
// with false confidence is worse off than one who simply pressed the call
// button. The value here is knowing the kit exists, that it is sealed, that
// only crew may open it, and that asking is fast.
//
// `kitCount` is 1 on every record. That is the regulatory floor — 14 CFR Part
// 121 Appendix A requires one approved emergency medical kit per aircraft
// regardless of size, and equivalent rules elsewhere follow the same shape.
// Many widebody operators carry a second or enhanced kit, and the widebody
// notes say so, but stating two as fact would be inventing a number we cannot
// check.

import '../models/flight.dart';

const EmkLocation _a320 = EmkLocation(
  aircraftFamily: 'Airbus A320 family (A318 / A319 / A320 / A321)',
  stowage: 'Typically in the forward galley, in an overhead stowage '
      'compartment or a sealed galley position near door 1L.',
  notes: 'Single-aisle with one or two galleys, so the kit is rarely more than '
      'a few rows away. Some operators stow it in the aft galley instead, '
      'particularly on A321s. The definitive answer is to ask a flight '
      'attendant — they check the kit before departure and can go straight '
      'to it.',
);

const EmkLocation _a330 = EmkLocation(
  aircraftFamily: 'Airbus A330',
  stowage: 'Typically in a forward or mid-cabin galley overhead stowage, in a '
      'sealed and secured case.',
  notes: 'Widebody layouts vary a great deal between operators, so which '
      'galley holds the kit differs by airline and cabin configuration. Some '
      'operators carry a supplementary kit on long-haul aircraft. The '
      'definitive answer is to ask a flight attendant.',
);

const EmkLocation _a350 = EmkLocation(
  aircraftFamily: 'Airbus A350',
  stowage: 'Typically in a forward or mid-cabin galley stowage, in a sealed '
      'and secured case.',
  notes: 'The A350 has several galley complexes and the kit position tracks '
      "the operator's cabin layout rather than the aircraft type. Some "
      'operators carry a supplementary kit on long-haul aircraft. The '
      'definitive answer is to ask a flight attendant.',
);

const EmkLocation _b737 = EmkLocation(
  aircraftFamily: 'Boeing 737 family (737-700 / -800 / -900 / MAX)',
  stowage: 'Typically in the forward galley, in an overhead stowage '
      'compartment or a sealed galley position near the forward door.',
  notes: 'Single-aisle with a forward and an aft galley; most operators use '
      'the forward one, but not all. The definitive answer is to ask a flight '
      'attendant — the crew verify the kit pre-flight and know its exact '
      'position on that airframe.',
);

const EmkLocation _b757 = EmkLocation(
  aircraftFamily: 'Boeing 757',
  stowage: 'Typically in the forward galley stowage, near door 1L.',
  notes: 'A long single-aisle cabin, so the kit can be a considerable walk '
      'from an aft seat — press the call button rather than going to find it. '
      'The definitive answer is to ask a flight attendant.',
);

const EmkLocation _b767 = EmkLocation(
  aircraftFamily: 'Boeing 767',
  stowage: 'Typically in a forward galley overhead stowage, in a sealed and '
      'secured case.',
  notes: 'Widebody galley layouts differ by operator and by whether the '
      'aircraft is configured for long-haul. Some operators carry a '
      'supplementary kit. The definitive answer is to ask a flight attendant.',
);

const EmkLocation _b777 = EmkLocation(
  aircraftFamily: 'Boeing 777',
  stowage: 'Typically in a forward or mid-cabin galley stowage, in a sealed '
      'and secured case.',
  notes: 'Large widebody with several galley complexes; which one holds the '
      'kit is an operator decision. Some operators carry a supplementary kit '
      'on long-haul aircraft. The definitive answer is to ask a flight '
      'attendant.',
);

const EmkLocation _b787 = EmkLocation(
  aircraftFamily: 'Boeing 787 Dreamliner',
  stowage: 'Typically in a forward or mid-cabin galley stowage, in a sealed '
      'and secured case.',
  notes: 'Galley positions vary widely between 787-8, -9 and -10 layouts and '
      'between operators. Some operators carry a supplementary kit on '
      'long-haul aircraft. The definitive answer is to ask a flight attendant.',
);

const EmkLocation _eJet = EmkLocation(
  aircraftFamily: 'Embraer E-Jet (E170 / E175 / E190 / E195)',
  stowage: 'Typically in the forward galley or a forward crew stowage '
      'compartment.',
  notes: 'Regional jet with limited galley space and often a single flight '
      'attendant, so the kit sits close to the front and the crew member will '
      'retrieve it themselves. The definitive answer is to ask a flight '
      'attendant.',
);

const EmkLocation _crj = EmkLocation(
  aircraftFamily: 'Bombardier CRJ (CRJ-200 / -700 / -900 / -1000)',
  stowage: 'Typically in the forward galley or forward crew stowage, close to '
      'the main cabin door.',
  notes: 'Very tight cabin with minimal stowage, usually one flight attendant. '
      'Use the call button rather than going to look. The definitive answer '
      'is to ask a flight attendant.',
);

const EmkLocation _a220 = EmkLocation(
  aircraftFamily: 'Airbus A220 (formerly Bombardier C Series)',
  stowage: 'Typically in the forward galley stowage, near the forward door.',
  notes: 'A newer single-aisle type whose galley layout differs noticeably '
      'between the A220-100 and -300 and between operators. The definitive '
      'answer is to ask a flight attendant.',
);

/// Fallback used whenever a type string does not resolve to a known family.
///
/// Returned rather than null on purpose: the useful, always-true guidance is
/// "there is a sealed kit, the crew know where it is, ask them", and that
/// holds on an aircraft type this app has never heard of.
const EmkLocation kGenericEmkLocation = EmkLocation(
  aircraftFamily: 'Unrecognized aircraft type',
  stowage: 'Typically in a galley stowage compartment, in a sealed and '
      'secured case that only crew may open.',
  notes: 'We do not have curated guidance for this aircraft type, so this is '
      'the general pattern rather than anything specific to your aircraft. '
      'Commercial airliners carry at least one emergency medical kit and the '
      'cabin crew check it before every departure. The definitive answer is '
      'to ask a flight attendant.',
);

/// Type-string fragments that identify each family, tested in this order.
///
/// Covers the three ways a type gets written down: ICAO (`B738`, `A20N`),
/// IATA (`738`, `32N`), and the way people actually type it (`Boeing 737`,
/// `737-800`). Order matters — narrower families are tested before broader
/// ones so a short fragment cannot swallow a more specific type.
const List<(EmkLocation, List<String>)> _familyPatterns =
    <(EmkLocation, List<String>)>[
  (_a220, <String>['A220', 'BD500', 'CS100', 'CS300', 'BCS1', 'BCS3', 'CSERIES']),
  (_crj, <String>['CRJ', 'CR2', 'CR7', 'CR9', 'RJ2', 'RJ7', 'RJ9']),
  (
    _eJet,
    <String>['EMBRAER', 'EJET', 'ERJ', 'E17', 'E19', 'E70', 'E75', 'E90', 'E95']
  ),
  (_a350, <String>['A35', '350', '359', '35K']),
  (_a330, <String>['A33', '330', '332', '333', '338', '339', '33X']),
  (
    _a320,
    <String>[
      'A31',
      'A32',
      'A20N',
      'A21N',
      '318',
      '319',
      '320',
      '321',
      '32A',
      '32B',
      '32N',
      '32Q',
      '32S',
    ]
  ),
  (
    _b787,
    <String>['787', 'B78', '788', '789', '78J', '78W', '78X', 'DREAMLINER']
  ),
  (_b777, <String>['777', 'B77', '772', '773', '77F', '77L', '77W', '77X']),
  (_b767, <String>['767', 'B76', '762', '763', '764', '76W']),
  (_b757, <String>['757', 'B75', '752', '753', '75W']),
  (
    _b737,
    <String>[
      '737',
      'B73',
      'B37',
      'B38',
      'B39',
      '73G',
      '73H',
      '73J',
      '73W',
      '738',
      '739',
      '7M7',
      '7M8',
      '7M9',
      '7M0',
      'MAX',
    ]
  ),
];

/// Resolve a free-text aircraft type to curated EMK guidance.
///
/// Accepts anything a schedule, a boarding pass or a user is likely to
/// produce — `'B738'`, `'737-800'`, `'Boeing 737'` and `'a320neo'` all resolve
/// to their family. Punctuation, spacing and case are ignored.
///
/// Never returns null. An unrecognised type falls back to
/// [kGenericEmkLocation], which carries the guidance that is true of every
/// airliner. Guessing wrong would be worse than being general, so the matcher
/// is conservative: a string that does not clearly identify a family is not
/// assigned to one.
EmkLocation emkFor(String aircraftType) {
  final key = aircraftType.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  if (key.isEmpty) return kGenericEmkLocation;

  for (final (location, needles) in _familyPatterns) {
    for (final needle in needles) {
      if (key.contains(needle)) return location;
    }
  }
  return kGenericEmkLocation;
}
