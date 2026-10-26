// The airlines the app knows by name, keyed by IATA code.
//
// Each of these has a step-by-step request guide in request_guides.dart and
// crew languages below. Earlier versions also stored each carrier's published
// allergy policy to score flights; that scoring was removed (published policies
// are vague and change without notice), and the data with it. It remains in
// the git history.

import '../models/flight.dart';

const Map<String, AirlinePolicy> kAirlinePolicies = <String, AirlinePolicy>{
  'DL': AirlinePolicy(iata: 'DL', name: 'Delta Air Lines'),
  'UA': AirlinePolicy(iata: 'UA', name: 'United Airlines'),
  'AA': AirlinePolicy(iata: 'AA', name: 'American Airlines'),
  'WN': AirlinePolicy(iata: 'WN', name: 'Southwest Airlines'),
  'B6': AirlinePolicy(iata: 'B6', name: 'JetBlue Airways'),
  'AS': AirlinePolicy(iata: 'AS', name: 'Alaska Airlines'),
  'NK': AirlinePolicy(iata: 'NK', name: 'Spirit Airlines'),
  'F9': AirlinePolicy(iata: 'F9', name: 'Frontier Airlines'),
  'HA': AirlinePolicy(iata: 'HA', name: 'Hawaiian Airlines'),
  'AC': AirlinePolicy(iata: 'AC', name: 'Air Canada'),
  'BA': AirlinePolicy(iata: 'BA', name: 'British Airways'),
  'LH': AirlinePolicy(iata: 'LH', name: 'Lufthansa'),
  'AF': AirlinePolicy(iata: 'AF', name: 'Air France'),
  'KL': AirlinePolicy(iata: 'KL', name: 'KLM Royal Dutch Airlines'),
  'EK': AirlinePolicy(iata: 'EK', name: 'Emirates'),
  'QR': AirlinePolicy(iata: 'QR', name: 'Qatar Airways'),
  'SQ': AirlinePolicy(iata: 'SQ', name: 'Singapore Airlines'),
  'QF': AirlinePolicy(iata: 'QF', name: 'Qantas'),
  'FR': AirlinePolicy(iata: 'FR', name: 'Ryanair'),
  'U2': AirlinePolicy(iata: 'U2', name: 'easyJet'),
};

/// The airline for an IATA code, or null when the app does not know it.
/// Case-insensitive and whitespace-tolerant, because the code comes from a
/// text field.
AirlinePolicy? policyFor(String iata) {
  final key = iata.trim().toUpperCase();
  if (key.isEmpty) return null;
  return kAirlinePolicies[key];
}

/// The languages cabin crew on each carrier work in, home language first.
///
/// Drives the language pack suggestion for a trip and the second language on
/// the "show to crew" card. English is listed for every carrier because every
/// one of them briefs and announces in it on international routes.
const Map<String, List<String>> kAirlineCrewLanguages = <String, List<String>>{
  'DL': ['en'],
  'UA': ['en'],
  'AA': ['en'],
  'WN': ['en'],
  'B6': ['en'],
  'AS': ['en'],
  'NK': ['en'],
  'F9': ['en'],
  'HA': ['en'],
  'AC': ['en', 'fr'],
  'BA': ['en'],
  'LH': ['de', 'en'],
  'AF': ['fr', 'en'],
  'KL': ['nl', 'en'],
  'EK': ['en', 'ar'],
  'QR': ['en', 'ar'],
  'SQ': ['en', 'zh', 'ms'],
  'QF': ['en'],
  'FR': ['en'],
  'U2': ['en'],
};

/// Crew languages for [iata], or just English for a carrier we hold no record
/// of — the one language every international crew can be assumed to share.
List<String> crewLanguagesFor(String iata) =>
    kAirlineCrewLanguages[iata.trim().toUpperCase()] ?? const <String>['en'];
