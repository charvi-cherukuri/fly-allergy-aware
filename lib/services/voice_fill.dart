import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/countries.dart';
import '../models/custom_allergen.dart';
import '../models/emergency.dart';
import '../models/profile.dart';
import '../models/travel.dart';
import '../models/trip.dart';
import 'on_device_ai.dart';
import 'voice_parser.dart';

/// Voice input for the travel journal: speech in, form fields out.
///
/// The rules in [VoiceParser] run on every phone and are trusted first. On an
/// Apple Intelligence phone the on-device model then fills only the fields the
/// rules left empty, and every value it returns is checked against what the
/// form allows — a real country code, a symptom from the app's own list, a
/// person in this household — before it is used. Whatever survives lands in a
/// form the user reads before saving.
class VoiceFill {
  const VoiceFill._();

  static const MethodChannel _ai = MethodChannel('fly_allergy_safe/on_device_ai');

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The model's fields for [kind], or null when it is unavailable or fails.
  static Future<Map<String, dynamic>?> _extract(String kind, String text) async {
    try {
      if (!(await OnDeviceAi.availability()).isAvailable) return null;
      final Map<dynamic, dynamic>? raw = await _ai.invokeMethod<Map<dynamic, dynamic>>(
        'extract',
        <String, String>{'kind': kind, 'text': text, 'today': _iso(DateTime.now())},
      );
      return raw?.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
    } catch (e) {
      debugPrint('VoiceFill: on-device extraction unavailable ($e)');
      return null;
    }
  }

  static String _s(Map<String, dynamic> m, String k) => (m[k] as String? ?? '').trim();

  static List<String> _list(Map<String, dynamic> m, String k) =>
      ((m[k] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => e.toString().trim())
          .where((String e) => e.isNotEmpty)
          .toList();

  static DateTime? _date(String raw) {
    final DateTime? d = DateTime.tryParse(raw);
    if (d == null) return null;
    final DateTime now = DateTime.now();
    // A trip more than five years either side is a misheard date.
    if (d.isBefore(DateTime(now.year - 5)) || d.isAfter(DateTime(now.year + 5))) return null;
    return DateTime(d.year, d.month, d.day);
  }

  static Set<String> _people(List<String> names, List<Profile> profiles, String? meId) {
    final Set<String> out = <String>{};
    for (final String raw in names) {
      final String n = raw.toLowerCase();
      if ((n == 'me' || n == 'i' || n == 'myself') && meId != null) {
        out.add(meId);
        continue;
      }
      for (final Profile p in profiles) {
        if (p.name.toLowerCase().split(' ').first == n.split(' ').first) out.add(p.id);
      }
    }
    return out;
  }

  // ------------------------------------------------------------------- forms

  static Future<TripHeard> trip(
    String text, {
    required List<Profile> profiles,
    String? meId,
  }) async {
    final TripHeard heard = VoiceParser.trip(
      text,
      now: DateTime.now(),
      profiles: profiles,
      meId: meId,
    );
    final Map<String, dynamic>? ai = await _extract('trip', text);
    if (ai != null) {
      final String code = _s(ai, 'countryCode').toUpperCase();
      if (heard.countryCode == null && countryFor(code) != null) heard.countryCode = code;
      heard.startsOn ??= _date(_s(ai, 'startDate'));
      final DateTime? end = _date(_s(ai, 'endDate'));
      if (heard.endsOn == null && end != null &&
          (heard.startsOn == null || !end.isBefore(heard.startsOn!))) {
        heard.endsOn = end;
      }
      if (heard.travelerIds.isEmpty) {
        heard.travelerIds.addAll(_people(_list(ai, 'travelers'), profiles, meId));
      }
    }
    return heard;
  }

  static Future<ExposureHeard> exposure(
    String text, {
    required List<Profile> people,
    List<CustomAllergen> custom = const <CustomAllergen>[],
  }) async {
    final ExposureHeard heard = VoiceParser.exposure(text, people: people, custom: custom);
    final Map<String, dynamic>? ai = await _extract('exposure', text);
    if (ai == null) return heard;

    if (heard.profileId == null) {
      final Set<String> who = _people(<String>[_s(ai, 'person')], people, null);
      if (who.length == 1) heard.profileId = who.single;
    }
    if (heard.allergens.isEmpty) {
      // Re-read through the rules so only recognised allergen names come back.
      for (final String a in _list(ai, 'allergens')) {
        for (final String label in VoiceParser.allergensIn(a, custom: custom)) {
          if (!heard.allergens.contains(label)) heard.allergens.add(label);
        }
      }
    }
    heard.route ??= _enum(ExposureRoute.values, _s(ai, 'route'));
    heard.place ??= _enum(ExposurePlace.values, _s(ai, 'place'));
    heard.outcome ??= _enum(ExposureOutcome.values, _s(ai, 'outcome'));
    if (heard.source == null && _s(ai, 'source').isNotEmpty) heard.source = _s(ai, 'source');
    if (heard.placeName == null && _s(ai, 'placeName').isNotEmpty) {
      heard.placeName = _s(ai, 'placeName');
    }
    final int? row = int.tryParse(_s(ai, 'row'));
    if (heard.row == null && row != null && row > 0 && row < 100) heard.row = row;
    if (heard.actions.isEmpty) {
      // Actions are re-read through the rules too: only the app's own list.
      heard.actions.addAll(
        VoiceParser.exposure(_list(ai, 'actions').join('. '), people: const <Profile>[]).actions,
      );
    }
    return heard;
  }

  static Future<ReactionHeard> reaction(String text) async {
    final ReactionHeard heard = VoiceParser.reaction(text);
    final Map<String, dynamic>? ai = await _extract('reaction', text);
    if (ai == null) return heard;
    if (heard.symptoms.isEmpty) {
      heard.symptoms.addAll(VoiceParser.reaction(_list(ai, 'symptoms').join('. ')).symptoms
          .where(kSymptomOptions.contains));
    }
    // A model saying "given" is not enough on its own to record a dose: the
    // words have to be in what was said, which the rules already checked.
    heard.soughtCare ??= ai['soughtCare'] == true ? true : null;
    if (heard.suspectedFood == null && _s(ai, 'suspectedFood').isNotEmpty) {
      heard.suspectedFood = _s(ai, 'suspectedFood');
    }
    return heard;
  }

  static Future<IncidentKind> incidentKind(String text, {required bool onFlight}) async {
    final IncidentKind rules = VoiceParser.incidentKind(text, onFlight: onFlight);
    final Map<String, dynamic>? ai = await _extract('incident', text);
    final IncidentKind? model = ai == null ? null : _enum(IncidentKind.values, _s(ai, 'kind'));
    // The model may only pick a kind that fits where it happened.
    if (model != null && (onFlight || !model.concernsFlight)) return model;
    return rules;
  }

  static T? _enum<T extends Enum>(List<T> values, String name) {
    for (final T v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
