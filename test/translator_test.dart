import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:trace_allergy/data/translator_languages.dart';
import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/product.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/models/verdict.dart';
import 'package:trace_allergy/services/matcher.dart';
import 'package:trace_allergy/services/translator.dart';

/// Stands in for ML Kit, so these run with no device and no 30 MB download.
class _FakeBackend implements TranslationBackend {
  final Set<String> installed = <String>{};
  final List<String> downloadCalls = <String>[];
  bool downloadSucceeds = true;
  bool translateSucceeds = true;
  Set<String> failDownloadOf = <String>{};
  String? lastText;

  /// When set, every isDownloaded call waits on it — a stand-in for forty
  /// sequential platform calls, so a refresh can be observed mid-scan.
  Completer<void>? gate;

  @override
  Future<bool> isDownloaded(String code) async {
    final Completer<void>? g = gate;
    if (g != null) await g.future;
    return installed.contains(code);
  }

  @override
  Future<bool> download(String code, {required bool wifiOnly}) async {
    downloadCalls.add(code);
    if (!downloadSucceeds || failDownloadOf.contains(code)) return false;
    installed.add(code);
    return true;
  }

  @override
  Future<bool> delete(String code) async => installed.remove(code);

  @override
  Future<String?> translate({
    required String text,
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) async {
    lastText = text;
    if (!translateSucceeds) return null;
    return '[$text in ${to.bcpCode}]';
  }
}

Profile _peanutProfile() => Profile(
  id: 'p',
  name: 'Me',
  allergens: <Allergen, Severity>{Allergen.peanut: Severity.severe},
);

void main() {
  group('the language table', () {
    test('every code is one ML Kit actually has', () {
      for (final l in kTranslatorLanguages) {
        expect(l.model, isNotNull, reason: '${l.english} (${l.code})');
        expect(l.model!.bcpCode, l.code);
      }
    });

    test('codes are unique and English is the pivot', () {
      final codes = kTranslatorLanguages.map((l) => l.code).toList();
      expect(codes.toSet().length, codes.length);
      expect(codes, contains(kPivotLanguage));
    });

    test('every language names itself and has a flag', () {
      for (final l in kTranslatorLanguages) {
        expect(l.native.trim(), isNotEmpty, reason: l.code);
        expect(l.english.trim(), isNotEmpty, reason: l.code);
        expect(l.flag.trim(), isNotEmpty, reason: l.code);
      }
    });
  });

  group('downloads', () {
    test(
      'a language pulls English with it, because English is the pivot',
      () async {
        final backend = _FakeBackend();
        final t = TranslatorService(backend: backend);

        expect(await t.download('hi'), DownloadOutcome.ok);
        expect(backend.installed, containsAll(<String>['hi', 'en']));
        expect(
          backend.downloadCalls.first,
          'en',
          reason: 'the pivot goes first, so a half-download still translates',
        );
      },
    );

    test(
      'a failed pivot download does not leave a language that cannot work',
      () async {
        final backend = _FakeBackend()..downloadSucceeds = false;
        final t = TranslatorService(backend: backend);

        expect(
          await t.download('hi'),
          DownloadOutcome.pivotFailed,
          reason: 'the failure is named as English, not Hindi',
        );
        expect(backend.installed, isEmpty);
        expect(backend.downloadCalls, <String>[
          'en',
        ], reason: 'Hindi is never attempted without its pivot');
      },
    );

    test('English cannot be removed while another language needs it', () async {
      final backend = _FakeBackend();
      final t = TranslatorService(backend: backend);
      await t.download('fr');

      expect(t.canDelete('en'), isFalse);
      expect(await t.delete('en'), isFalse);
      expect(backend.installed, contains('en'));

      await t.delete('fr');
      expect(t.canDelete('en'), isTrue);
      expect(await t.delete('en'), isTrue);
    });

    test('nothing downloads on its own', () async {
      final backend = _FakeBackend();
      final t = TranslatorService(backend: backend);

      final result = await t.translate(text: 'hola', from: 'es', to: 'en');
      expect(result.status, TranslateStatus.notDownloaded);
      expect(result.missing, 'es');
      expect(
        backend.downloadCalls,
        isEmpty,
        reason: '30 MB on a roaming plan is the user decision',
      );
    });
  });

  group('translating', () {
    test('returns the translation once the packs are there', () async {
      final backend = _FakeBackend();
      final t = TranslatorService(backend: backend);
      await t.download('es');

      final result = await t.translate(text: 'cacahuete', from: 'es', to: 'en');
      expect(result.ok, isTrue);
      expect(result.text, '[cacahuete in en]');
    });

    test(
      'the same language in and out is refused, not passed through',
      () async {
        // Passing the text through would present the user's own words as a
        // machine translation, and floor their clear result to unknown.
        final backend = _FakeBackend();
        final t = TranslatorService(backend: backend);
        final result = await t.translate(text: 'peanut', from: 'en', to: 'en');
        expect(result.ok, isFalse);
        expect(backend.lastText, isNull, reason: 'no model call at all');
      },
    );

    test('empty text is not sent anywhere', () async {
      final t = TranslatorService(backend: _FakeBackend());
      final result = await t.translate(text: '   ', from: 'es', to: 'en');
      expect(result.status, TranslateStatus.ok);
      expect(result.text, '');
    });
  });

  group('a translation can raise an alarm but never clear a label', () {
    test('translated text with nothing in it is unknown, not clear', () {
      final direct = AllergenMatcher.evaluate(
        product: Product.fromOcr(
          'Ingredients: rice, water, salt.',
          ingredientsLanguage: 'en',
        ),
        profile: _peanutProfile(),
      );
      expect(
        direct.level,
        VerdictLevel.clear,
        reason: 'the same text read directly is a clear result',
      );

      final translated = AllergenMatcher.evaluate(
        product: Product.fromOcr(
          'Ingredients: rice, water, salt.',
          translatedFrom: 'ja',
        ),
        profile: _peanutProfile(),
      );
      expect(translated.level, VerdictLevel.unknown);
      expect(translated.detail.toLowerCase(), contains('machine translation'));
    });

    test('a hit in translated text still blocks', () {
      final translated = AllergenMatcher.evaluate(
        product: Product.fromOcr(
          'Ingredients: peanut oil, sugar.',
          translatedFrom: 'zh',
        ),
        profile: _peanutProfile(),
      );
      expect(
        translated.level,
        VerdictLevel.unsafe,
        reason: 'a translation naming peanut is worth acting on',
      );
      expect(translated.hits, hasLength(1));
    });

    test('a cross-contact warning in translated text still cautions', () {
      final translated = AllergenMatcher.evaluate(
        product: Product.fromOcr(
          'Ingredients: rice. May contain traces of peanuts.',
          translatedFrom: 'th',
        ),
        profile: Profile(
          id: 'p',
          name: 'Me',
          allergens: <Allergen, Severity>{
            Allergen.peanut: Severity.intolerance,
          },
        ),
      );
      expect(translated.level, VerdictLevel.caution);
    });

    test('a product the app read directly is never marked translated', () {
      expect(Product.fromOcr('x').isTranslated, isFalse);
      expect(Product.fromOcr('x', translatedFrom: 'fr').isTranslated, isTrue);
    });
  });

  group('the translation flag survives being saved', () {
    test('a translated product round-trips through storage', () {
      final original = Product.fromOcr(
        'Ingredients: rice, water, salt.',
        translatedFrom: 'ja',
      );
      final reloaded = Product.fromMap(original.toMap());

      expect(reloaded.isTranslated, isTrue);
      expect(reloaded.translatedFrom, 'ja');
      expect(reloaded.source, ProductSource.translation);
    });

    test('reopened from history, it is still not clear', () {
      // The defect this pins: the first look was capped, the scan was saved
      // without the flag, and reopening it from History came back green.
      final reloaded = Product.fromMap(
        Product.fromOcr(
          'Ingredients: rice, water, salt.',
          translatedFrom: 'ja',
        ).toMap(),
      );
      final verdict = AllergenMatcher.evaluate(
        product: reloaded,
        profile: _peanutProfile(),
      );
      expect(verdict.level, VerdictLevel.unknown);
      expect(verdict.headline, isNot('No match found'));
    });

    test('a row saved without the language code is still a translation', () {
      // If the column were ever missing, `source` alone must carry it — it has
      // been persisted since the first schema.
      final row = Product.fromOcr('x', translatedFrom: 'ja').toMap()
        ..remove('translatedFrom');
      expect(Product.fromMap(row).isTranslated, isTrue);
    });

    test('copyWith keeps it', () {
      final p = Product.fromOcr('x', translatedFrom: 'fr');
      expect(p.copyWith(name: 'renamed').translatedFrom, 'fr');
      expect(p.copyWith(name: 'renamed').isTranslated, isTrue);
    });

    test('text read directly is never a translation, saved or not', () {
      final reloaded = Product.fromMap(Product.fromOcr('x').toMap());
      expect(reloaded.isTranslated, isFalse);
      expect(reloaded.source, ProductSource.ocr);
    });
  });

  group('every path to a verdict respects the cap', () {
    test('an empty profile on translated text is not clear', () {
      final verdict = AllergenMatcher.evaluate(
        product: Product.fromOcr('Ingredients: peanut.', translatedFrom: 'ja'),
        profile: Profile(id: 'p', name: 'Me'),
      );
      expect(
        verdict.level,
        VerdictLevel.unknown,
        reason: 'this branch returns before the floors run',
      );
    });

    test('an empty profile on text read directly keeps its old answer', () {
      final verdict = AllergenMatcher.evaluate(
        product: Product.fromOcr('Ingredients: peanut.'),
        profile: Profile(id: 'p', name: 'Me'),
      );
      expect(verdict.level, VerdictLevel.clear);
    });

    test('the headline does not claim there was no ingredient data', () {
      final verdict = AllergenMatcher.evaluate(
        product: Product.fromOcr(
          'Ingredients: rice, water, salt.',
          translatedFrom: 'ja',
        ),
        profile: _peanutProfile(),
      );
      expect(
        verdict.headline,
        isNot('No ingredient data'),
        reason: 'the translated list is on the same screen',
      );
      expect(verdict.headline.toLowerCase(), contains('translation'));
    });
  });

  group('the cache', () {
    test('a refresh never shows the English guard an empty set', () async {
      final backend = _FakeBackend()..installed.addAll(<String>['en', 'fr']);
      final t = TranslatorService(backend: backend);
      await t.downloaded();
      expect(t.canDelete('en'), isFalse);

      // Hold the rescan open part-way through.
      backend.gate = Completer<void>();
      final Future<Set<String>> scan = t.downloaded(refresh: true);
      expect(
        t.canDelete('en'),
        isFalse,
        reason: 'mid-scan the old answer stands until the new one is whole',
      );

      backend.gate!.complete();
      await scan;
      expect(t.canDelete('en'), isFalse);
    });

    test('download asks the device for English, not the cache', () async {
      final backend = _FakeBackend()..installed.add('en');
      final t = TranslatorService(backend: backend);
      await t.downloaded();

      // English removed outside the app since the last scan.
      backend.installed.remove('en');
      expect(await t.download('hi'), DownloadOutcome.ok);
      expect(
        backend.downloadCalls,
        <String>['en', 'hi'],
        reason: 'a stale "yes" would ship Hindi with nothing to pivot through',
      );
    });

    test('a pack removed outside the app is reported as missing, not as a '
        'broken translator', () async {
      final backend = _FakeBackend();
      final t = TranslatorService(backend: backend);
      await t.download('es');

      backend.installed.remove('es');
      backend.translateSucceeds = false;
      final result = await t.translate(text: 'hola', from: 'es', to: 'en');
      expect(result.status, TranslateStatus.notDownloaded);
      expect(result.missing, 'es');
    });

    test(
      'a real translator failure with everything present is a failure',
      () async {
        final backend = _FakeBackend();
        final t = TranslatorService(backend: backend);
        await t.download('es');
        backend.translateSucceeds = false;
        final result = await t.translate(text: 'hola', from: 'es', to: 'en');
        expect(result.status, TranslateStatus.failed);
      },
    );

    test(
      'the first language is quoted with English, later ones without',
      () async {
        final backend = _FakeBackend();
        final t = TranslatorService(backend: backend);
        await t.downloaded();
        expect(t.approxDownloadMegabytes('es'), 2 * kApproxModelMegabytes);

        await t.download('es');
        expect(t.approxDownloadMegabytes('fr'), kApproxModelMegabytes);
      },
    );

    test(
      'a download in flight is visible to a screen that comes back to it',
      () async {
        final backend = _FakeBackend()..installed.add('en');
        final t = TranslatorService(backend: backend);
        backend.gate = Completer<void>();
        final Future<DownloadOutcome> pending = t.download('ja');
        expect(t.isDownloading('ja'), isTrue);
        backend.gate!.complete();
        await pending;
        expect(t.isDownloading('ja'), isFalse);
      },
    );

    test('a failed language download is not recorded as present', () async {
      final backend = _FakeBackend()..failDownloadOf = <String>{'ja'};
      final t = TranslatorService(backend: backend);
      expect(await t.download('ja'), DownloadOutcome.failed);
      expect(await t.isDownloaded('ja'), isFalse);
    });
  });
}
