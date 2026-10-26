import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/translator_languages.dart';
import '../services/app_state.dart';
import '../services/translator.dart';
import '../theme.dart';

/// Downloading and removing the offline translation packs.
///
/// Nothing downloads on its own. A pack is roughly 30 MB, and the person using
/// this app may be on an expensive roaming plan in the country whose language
/// they are about to need.
class LanguagePacksScreen extends StatefulWidget {
  const LanguagePacksScreen({super.key});

  @override
  State<LanguagePacksScreen> createState() => _LanguagePacksScreenState();
}

class _LanguagePacksScreenState extends State<LanguagePacksScreen> {
  Set<String> _have = <String>{};
  final Set<String> _busy = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final have =
        await context.read<AppState>().translator.downloaded(refresh: true);
    if (!mounted) return;
    setState(() {
      _have = have;
      _loading = false;
    });
  }

  Future<void> _download(TranslatorLanguage l) async {
    final translator = context.read<AppState>().translator;
    // Captured before the await: the download can outlive this screen, and the
    // confirmation should still reach the user wherever they are in the app.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(l.code));
    final outcome = await translator.download(l.code);
    final have = await translator.downloaded(refresh: true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          DownloadOutcome.ok =>
            '${l.english} is ready. It works with no connection now.',
          DownloadOutcome.pivotFailed =>
            'Could not download English, which ${l.english} is translated '
                'through, so ${l.english} was not started. Downloads use Wi-Fi '
                'and need some free space.',
          DownloadOutcome.failed =>
            'Could not download ${l.english}. Downloads use Wi-Fi and need '
                'some free space.',
        }),
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy.remove(l.code);
      _have = have;
    });
  }

  Future<void> _delete(TranslatorLanguage l) async {
    final translator = context.read<AppState>().translator;
    final messenger = ScaffoldMessenger.of(context);

    // The pivot rule is checked before trying, so it is the only thing that
    // produces the pivot message. Any other failure says what it is.
    if (!translator.canDelete(l.code)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'English stays while another language is installed — every other '
            'language is translated through it.',
          ),
        ),
      );
      return;
    }

    setState(() => _busy.add(l.code));
    final ok = await translator.delete(l.code);
    final have = await translator.downloaded(refresh: true);
    if (!mounted) return;
    setState(() {
      _busy.remove(l.code);
      _have = have;
    });
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not remove ${l.english}. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final installed = _have.length;
    final approxMb = installed * kApproxModelMegabytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Language packs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          installed == 0
                              ? 'No languages downloaded'
                              : '$installed downloaded · about $approxMb MB',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Each pack is around 30 MB and downloads over Wi-Fi. '
                          'The first one also brings English, which every other '
                          'language is translated through, so it is about '
                          '60 MB. Once a pack is on the phone the translator '
                          'works with no connection at all.',
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Download before you fly, not after you land.',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionTitle('Languages'),
                Card(
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < kTranslatorLanguages.length; i++)
                        Column(
                          children: <Widget>[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                            _PackRow(
                              language: kTranslatorLanguages[i],
                              downloaded:
                                  _have.contains(kTranslatorLanguages[i].code),
                              busy: _busy.contains(
                                    kTranslatorLanguages[i].code,
                                  ) ||
                                  context
                                      .read<AppState>()
                                      .translator
                                      .isDownloading(
                                        kTranslatorLanguages[i].code,
                                      ),
                              sizeMb: context
                                  .read<AppState>()
                                  .translator
                                  .approxDownloadMegabytes(
                                    kTranslatorLanguages[i].code,
                                  ),
                              onDownload: () =>
                                  _download(kTranslatorLanguages[i]),
                              onDelete: () => _delete(kTranslatorLanguages[i]),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Translation is for reading a menu or a label, not for '
                  'deciding what is safe to eat. A check run on translated text '
                  'can warn you, but it will never come back clear.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.language,
    required this.downloaded,
    required this.busy,
    required this.sizeMb,
    required this.onDownload,
    required this.onDelete,
  });

  final TranslatorLanguage language;
  final bool downloaded;
  final bool busy;

  /// What tapping download will actually pull, English included if needed.
  final int sizeMb;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPivot = language.code == kPivotLanguage;

    return ListTile(
      leading: Text(language.flag, style: const TextStyle(fontSize: 22)),
      title: Text(
        language.native,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        isPivot
            ? 'English · needed by every other language'
            : downloaded
                ? '${language.english} · on this phone'
                : sizeMb > kApproxModelMegabytes
                    ? '${language.english} · about $sizeMb MB with English'
                    : '${language.english} · about $sizeMb MB',
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : downloaded
              ? IconButton(
                  tooltip: 'Remove',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : IconButton(
                  tooltip: 'Download',
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded),
                ),
    );
  }
}
