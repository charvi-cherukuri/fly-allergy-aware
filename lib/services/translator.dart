import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../data/translator_languages.dart';

/// What happened when the app asked for a translation.
enum TranslateStatus {
  ok,

  /// The language pack is not on the device. Nothing is downloaded silently:
  /// a 30 MB download is the user's decision, not the app's.
  notDownloaded,

  /// The translator itself failed.
  failed,
}

class TranslationResult {
  const TranslationResult({required this.status, this.text, this.missing});

  final TranslateStatus status;
  final String? text;

  /// Which language pack was missing, when that is the reason.
  final String? missing;

  bool get ok => status == TranslateStatus.ok && text != null;
}

/// The plugin, behind an interface, so tests do not need ML Kit or a device.
abstract class TranslationBackend {
  Future<bool> isDownloaded(String code);
  Future<bool> download(String code, {required bool wifiOnly});
  Future<bool> delete(String code);
  Future<String?> translate({
    required String text,
    required TranslateLanguage from,
    required TranslateLanguage to,
  });
}

class MlKitBackend implements TranslationBackend {
  final OnDeviceTranslatorModelManager _models =
      OnDeviceTranslatorModelManager();

  @override
  Future<bool> isDownloaded(String code) async {
    try {
      return await _models.isModelDownloaded(code);
    } catch (e) {
      debugPrint('Translator: could not check $code ($e)');
      return false;
    }
  }

  @override
  Future<bool> download(String code, {required bool wifiOnly}) async {
    try {
      return await _models.downloadModel(code, isWifiRequired: wifiOnly);
    } catch (e) {
      debugPrint('Translator: could not download $code ($e)');
      return false;
    }
  }

  @override
  Future<bool> delete(String code) async {
    try {
      return await _models.deleteModel(code);
    } catch (e) {
      debugPrint('Translator: could not delete $code ($e)');
      return false;
    }
  }

  @override
  Future<String?> translate({
    required String text,
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) async {
    final translator =
        OnDeviceTranslator(sourceLanguage: from, targetLanguage: to);
    try {
      return await translator.translateText(text);
    } catch (e) {
      debugPrint('Translator: translation failed ($e)');
      return null;
    } finally {
      await translator.close();
    }
  }
}

/// Why a download did or did not happen.
enum DownloadOutcome {
  ok,

  /// English — which every other language is translated through — did not
  /// come down, so the requested language was never attempted.
  pivotFailed,

  /// The requested language itself failed.
  failed,
}

/// On-device translation with downloadable language packs.
///
/// **What this is for, and what it is not for.** It reads a foreign menu, an
/// ingredient list, or what someone just said to you. It does not decide
/// whether food is safe. Google documents these models as "intended for casual
/// and simple translations", and any pair that is not English-to-something
/// pivots through English, which loses more. So a translation may raise an
/// alarm — a hit on translated text is still a hit worth acting on — but it can
/// never clear a label. [AllergenMatcher] enforces that, not this class.
///
/// Nothing downloads without being asked. A pack is roughly 30 MB.
class TranslatorService {
  TranslatorService({TranslationBackend? backend})
      : _backend = backend ?? MlKitBackend();

  final TranslationBackend _backend;

  /// Cached so a list of forty languages does not make forty platform calls
  /// every time the screen rebuilds. Replaced whole, never cleared in place:
  /// a rescan takes forty sequential platform calls, and an empty set visible
  /// part-way through would tell the English guard nothing else is installed.
  Set<String> _downloaded = <String>{};
  bool _scanned = false;

  /// Downloads in flight. Held here rather than in a screen, so leaving the
  /// language list mid-download and coming back still shows it running.
  final Set<String> _inFlight = <String>{};

  bool isDownloading(String code) => _inFlight.contains(code);

  Future<Set<String>> downloaded({bool refresh = false}) async {
    if (_scanned && !refresh) return Set<String>.unmodifiable(_downloaded);
    final Set<String> found = <String>{};
    for (final TranslatorLanguage l in kTranslatorLanguages) {
      if (await _backend.isDownloaded(l.code)) found.add(l.code);
    }
    _downloaded = found;
    _scanned = true;
    return Set<String>.unmodifiable(_downloaded);
  }

  Future<bool> isDownloaded(String code) async {
    final Set<String> have = await downloaded();
    return have.contains(code);
  }

  /// Roughly how much [code] will download right now. The first language also
  /// brings English, so it is about twice the size of every one after it.
  int approxDownloadMegabytes(String code) {
    final bool needsPivot =
        code != kPivotLanguage && !_downloaded.contains(kPivotLanguage);
    return kApproxModelMegabytes * (needsPivot ? 2 : 1);
  }

  /// Downloads [code], and English with it if it is missing.
  ///
  /// ML Kit translates to and from English and pivots every other pair through
  /// it, so a language pack on its own translates nothing. The device is asked
  /// whether English is present rather than the cache, because a pack can be
  /// removed outside the app, and a stale "yes" here ships a download that
  /// translates nothing.
  Future<DownloadOutcome> download(String code, {bool wifiOnly = true}) async {
    if (_inFlight.contains(code)) return DownloadOutcome.failed;
    _inFlight.add(code);
    try {
      if (code != kPivotLanguage) {
        final bool pivot = await _backend.isDownloaded(kPivotLanguage) ||
            await _backend.download(kPivotLanguage, wifiOnly: wifiOnly);
        if (!pivot) return DownloadOutcome.pivotFailed;
        _downloaded = <String>{..._downloaded, kPivotLanguage};
      }
      final bool ok = await _backend.download(code, wifiOnly: wifiOnly);
      if (ok) _downloaded = <String>{..._downloaded, code};
      return ok ? DownloadOutcome.ok : DownloadOutcome.failed;
    } finally {
      _inFlight.remove(code);
    }
  }

  /// Removes a pack. English goes only when it is the last one left, since
  /// every other language needs it.
  Future<bool> delete(String code) async {
    if (!canDelete(code)) return false;
    final bool ok = await _backend.delete(code);
    if (ok) {
      _downloaded = <String>{..._downloaded}..remove(code);
    }
    return ok;
  }

  /// True when [code] can be deleted on its own right now.
  bool canDelete(String code) {
    if (code != kPivotLanguage) return true;
    return !_downloaded.any((String c) => c != kPivotLanguage);
  }

  Future<TranslationResult> translate({
    required String text,
    required String from,
    required String to,
  }) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const TranslationResult(status: TranslateStatus.ok, text: '');
    }
    // Not a translation, and must not be presented as one. The screen refuses
    // an equal pair; this is the backstop.
    if (from == to) {
      return const TranslationResult(status: TranslateStatus.failed);
    }

    final TranslateLanguage? source = translatorLanguageFor(from)?.model;
    final TranslateLanguage? target = translatorLanguageFor(to)?.model;
    if (source == null || target == null) {
      return const TranslationResult(status: TranslateStatus.failed);
    }

    final String? missing = await _firstMissing(<String>{from, to}, refresh: false);
    if (missing != null) {
      return TranslationResult(
        status: TranslateStatus.notDownloaded,
        missing: missing,
      );
    }

    final String? out = await _backend.translate(
      text: trimmed,
      from: source,
      to: target,
    );
    if (out != null) {
      return TranslationResult(status: TranslateStatus.ok, text: out);
    }

    // A failure may mean the cache was wrong — a pack removed outside the app.
    // Ask the device again before telling the user it was the translator's
    // fault, so they get "download Japanese" rather than a dead end.
    final String? actuallyMissing =
        await _firstMissing(<String>{from, to}, refresh: true);
    if (actuallyMissing != null) {
      return TranslationResult(
        status: TranslateStatus.notDownloaded,
        missing: actuallyMissing,
      );
    }
    return const TranslationResult(status: TranslateStatus.failed);
  }

  /// The first pack that is not on the device, naming the language the user
  /// asked for before English: downloading that one brings English with it, so
  /// "download Spanish" is the instruction that actually fixes the problem.
  Future<String?> _firstMissing(Set<String> codes, {required bool refresh}) async {
    final Set<String> have = await downloaded(refresh: refresh);
    final List<String> order = <String>[
      ...codes.where((String c) => c != kPivotLanguage),
      kPivotLanguage,
    ];
    for (final String needed in order) {
      if (!have.contains(needed)) return needed;
    }
    return null;
  }
}
