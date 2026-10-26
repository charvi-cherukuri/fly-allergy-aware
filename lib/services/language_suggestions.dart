import '../data/airline_policies.dart';
import '../data/chef_card_translations.dart';
import '../data/countries.dart';
import '../data/translator_languages.dart';
import '../models/flight.dart';
import '../models/trip.dart';

/// Which translator packs are worth having for a trip, and whether the chef
/// card should switch language.
///
/// Suggestions only. Nothing here downloads anything: a traveler on a roaming
/// plan decides when 30 MB moves, and the screen that shows these offers
/// "Not now" and "Don't ask for this trip" alongside "Download".
class LanguageSuggestions {
  const LanguageSuggestions._();

  /// Packs for the destination's languages and the crew languages of every
  /// airline on the trip, destination first, without repeats.
  ///
  /// The phone's own language is left out — nobody needs a pack to read their
  /// own language — and so is anything the translator does not offer.
  static List<String> packsFor({
    required Trip trip,
    required List<Flight> legs,
    required String deviceLanguage,
  }) {
    final offered = kTranslatorLanguages.map((l) => l.code).toSet();
    final out = <String>[];
    void add(String code) {
      if (code == deviceLanguage) return;
      if (!offered.contains(code)) return;
      if (!out.contains(code)) out.add(code);
    }

    for (final code in countryFor(trip.destinationCountry)?.languages ??
        const <String>[]) {
      add(code);
    }
    for (final leg in legs) {
      for (final code in crewLanguagesFor(leg.airlineIata)) {
        add(code);
      }
    }
    return out;
  }

  /// The chef card language to offer for this trip: the first destination
  /// language that has hand-written card translations, when the card is not
  /// already in it. Null when there is nothing worth offering.
  static String? cardLanguageFor({
    required Trip trip,
    required String currentCardLanguage,
  }) {
    final hasCard = kCardLanguages.map((l) => l.code).toSet();
    for (final code in countryFor(trip.destinationCountry)?.languages ??
        const <String>[]) {
      if (!hasCard.contains(code)) continue;
      return code == currentCardLanguage ? null : code;
    }
    return null;
  }

  /// When the trip card starts suggesting: from a week before departure until
  /// the trip ends. Earlier is easy to ignore; later is too late to download
  /// on hotel Wi-Fi.
  static bool isTimely(Trip trip, DateTime now) =>
      !trip.isPast(now) && trip.daysUntil(now) <= 7;
}
