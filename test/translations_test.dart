import 'package:flutter_test/flutter_test.dart';
import 'package:trace_allergy/data/chef_card_translations.dart';
import 'package:trace_allergy/data/emergency_phrases.dart';
import 'package:trace_allergy/models/allergen.dart';

/// These are completeness tests, not linguistic ones.
///
/// Every translated surface in the app reads from one of three const tables
/// keyed by the same language codes. A missing key does not crash — the code
/// falls back to English — which is exactly why it needs a test: a Japanese user
/// would silently be handed an English sentence to show a Japanese paramedic.
void main() {
  final codes = kCardLanguages.map((l) => l.code).toList();

  group('language list', () {
    test('codes are unique and English is present', () {
      expect(codes.toSet().length, codes.length);
      expect(codes, contains('en'));
    });

    test('every language names itself and has a flag', () {
      for (final l in kCardLanguages) {
        expect(l.native.trim(), isNotEmpty, reason: l.code);
        expect(l.english.trim(), isNotEmpty, reason: l.code);
        expect(l.flag.trim(), isNotEmpty, reason: l.code);
      }
    });
  });

  group('chef card', () {
    test('every language has card strings', () {
      for (final code in codes) {
        expect(kCardStrings[code], isNotNull, reason: code);
      }
    });

    test('every language names all fourteen allergens', () {
      for (final code in codes) {
        final table = kAllergenTranslations[code];
        expect(table, isNotNull, reason: code);
        for (final a in Allergen.values) {
          expect(table![a], isNotNull, reason: '$code/${a.name}');
          expect(table[a]!.trim(), isNotEmpty, reason: '$code/${a.name}');
        }
      }
    });
  });

  group('emergency phrases', () {
    test('ids are unique', () {
      final ids = kEmergencyPhrases.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every phrase exists in every language', () {
      for (final phrase in kEmergencyPhrases) {
        expect(phrase.english.trim(), isNotEmpty, reason: phrase.id);
        for (final code in codes.where((c) => c != 'en')) {
          final text = phrase.translations[code];
          expect(text, isNotNull, reason: '${phrase.id}/$code');
          expect(text!.trim(), isNotEmpty, reason: '${phrase.id}/$code');
        }
      }
    });

    test('no translation is left as the English string', () {
      for (final phrase in kEmergencyPhrases) {
        for (final code in codes.where((c) => c != 'en')) {
          expect(
            phrase.inLanguage(code),
            isNot(phrase.english),
            reason: '${phrase.id}/$code',
          );
        }
      }
    });

    test('inLanguage falls back to English rather than returning nothing', () {
      expect(kEmergencyPhrases.first.inLanguage('en'),
          kEmergencyPhrases.first.english);
      expect(kEmergencyPhrases.first.inLanguage('xx'),
          kEmergencyPhrases.first.english);
    });

    test('the urgent phrases come first, because the order is the point', () {
      final lastUrgent =
          kEmergencyPhrases.lastIndexWhere((p) => p.urgent);
      final firstCalm = kEmergencyPhrases.indexWhere((p) => !p.urgent);
      expect(lastUrgent, lessThan(firstCalm));
    });

    test('the phrase screen is translated in every language', () {
      for (final code in codes) {
        expect(kPhraseScreenStrings[code], isNotNull, reason: code);
      }
    });
  });

  group('contact messages', () {
    test('every template carries the name placeholder exactly once', () {
      for (final t in kContactMessages) {
        expect(
          '{name}'.allMatches(t.body).length,
          1,
          reason: t.id,
        );
        expect(t.label.trim(), isNotEmpty, reason: t.id);
      }
    });

    test('a real name is substituted in', () {
      final filled = fillContactMessage('{name} here. Help.', 'Charvi');
      expect(filled, 'Charvi here. Help.');
    });

    test('the placeholder profile drops the lead sentence, not the message', () {
      final filled = fillContactMessage(
        '{name} here. I am having a reaction.',
        'Me',
      );
      expect(filled, 'I am having a reaction.');
      expect(filled, isNot(contains('{name}')));
    });

    test('an empty name is handled the same way', () {
      final filled = fillContactMessage('{name} here. Help.', '   ');
      expect(filled, 'Help.');
    });

    test('no template still contains a placeholder once filled', () {
      for (final t in kContactMessages) {
        for (final name in <String>['Shray', 'Me', '']) {
          expect(
            fillContactMessage(t.body, name),
            isNot(contains('{name}')),
            reason: '${t.id}/$name',
          );
        }
      }
    });

    test('the two severe templates are the ones that mention the injector '
        'or ask for a call', () {
      final severe = kContactMessages.where((t) => t.severe).toList();
      expect(severe, isNotEmpty);
      for (final t in severe) {
        expect(t.body.toLowerCase(), contains('call me'));
      }
    });
  });
}
