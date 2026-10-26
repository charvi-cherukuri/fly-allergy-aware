import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/chef_card_translations.dart';
import '../data/translator_languages.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../services/language_suggestions.dart';
import '../services/translator.dart';

/// Suggests the language packs a trip needs and offers to switch the chef card.
///
/// It asks; it never acts. Every download is a tap, over Wi-Fi, and "Not now"
/// and "Don't ask for this trip" sit next to it. A suggestion that cannot be
/// turned down is a nag, and a nag gets the whole card ignored — including on
/// the trip where it mattered.
class LanguageSuggestionCard extends StatefulWidget {
  const LanguageSuggestionCard({super.key, required this.trip});

  final Trip trip;

  @override
  State<LanguageSuggestionCard> createState() => _LanguageSuggestionCardState();
}

/// "Not now" lasts until the app is next opened. Static so it survives the
/// card being rebuilt as the user moves between the list and the trip.
final Set<String> _snoozedThisSession = <String>{};

class _LanguageSuggestionCardState extends State<LanguageSuggestionCard> {
  Set<String>? _installed;
  final Set<String> _failed = <String>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final Set<String> have = await context.read<AppState>().translator.downloaded();
    if (!mounted) return;
    setState(() => _installed = have);
  }

  Future<void> _download(String code) async {
    final TranslatorService translator = context.read<AppState>().translator;
    setState(() => _failed.remove(code));
    final Future<DownloadOutcome> pending = translator.download(code);
    setState(() {}); // show the spinner now that the download is in flight
    final DownloadOutcome outcome = await pending;
    if (!mounted) return;
    if (outcome != DownloadOutcome.ok) _failed.add(code);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final Trip trip = widget.trip;
    final Set<String>? installed = _installed;

    if (installed == null ||
        _snoozedThisSession.contains(trip.id) ||
        app.languagePromptDismissed(trip.id)) {
      return const SizedBox.shrink();
    }

    final List<String> missing = LanguageSuggestions.packsFor(
      trip: trip,
      legs: app.flightsFor(trip.id),
      deviceLanguage: app.deviceLanguage,
    ).where((String c) => !installed.contains(c)).toList();

    final String? cardCode = LanguageSuggestions.cardLanguageFor(
      trip: trip,
      currentCardLanguage: app.travelLanguage,
    );

    if (missing.isEmpty && cardCode == null) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TranslatorService translator = app.translator;

    return Card(
      color: scheme.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.translate_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Languages for this trip',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
            if (missing.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Download before you go, so you can translate menus and '
                  'labels with no signal. About '
                  '${translator.approxDownloadMegabytes(missing.first)} MB, over '
                  'Wi-Fi.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final String code in missing)
                _PackRow(
                  code: code,
                  busy: translator.isDownloading(code),
                  failed: _failed.contains(code),
                  onDownload: () => _download(code),
                ),
            ],
            if (cardCode != null) ...<Widget>[
              const SizedBox(height: 4),
              _CardLanguageRow(
                code: cardCode,
                onSwitch: () => app.setTravelLanguage(cardCode),
              ),
            ],
            // Wraps rather than overflowing at larger text sizes.
            Wrap(
              alignment: WrapAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => setState(() => _snoozedThisSession.add(trip.id)),
                  child: const Text('Not now'),
                ),
                TextButton(
                  onPressed: () => app.dismissLanguagePrompt(trip.id),
                  child: const Text("Don't ask for this trip"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.code,
    required this.busy,
    required this.failed,
    required this.onDownload,
  });

  final String code;
  final bool busy;
  final bool failed;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final TranslatorLanguage? l = translatorLanguageFor(code);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.only(right: 8),
      dense: true,
      leading: Text(l?.flag ?? '🌐', style: const TextStyle(fontSize: 20)),
      title: Text(l == null ? code : '${l.english} · ${l.native}'),
      subtitle: failed
          ? Text(
              'Didn’t download. Check Wi-Fi and space, then try again.',
              style: TextStyle(color: scheme.error),
            )
          : null,
      trailing: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : OutlinedButton(
              // The app theme makes buttons full-width; beside a title that
              // would squeeze the language name to one letter per line.
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              onPressed: onDownload,
              child: Text(failed ? 'Retry' : 'Download'),
            ),
    );
  }
}

class _CardLanguageRow extends StatelessWidget {
  const _CardLanguageRow({required this.code, required this.onSwitch});

  final String code;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    String name = code;
    for (final CardLanguage l in kCardLanguages) {
      if (l.code == code) name = l.english;
    }
    return ListTile(
      contentPadding: const EdgeInsets.only(right: 8),
      dense: true,
      leading: const Icon(Icons.badge_outlined),
      title: Text('Show the chef card and emergency phrases in $name?'),
      subtitle: const Text('Hand-written translations, no download needed.'),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: onSwitch,
        child: const Text('Switch'),
      ),
    );
  }
}
