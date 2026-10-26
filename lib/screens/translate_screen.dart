import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/translator_languages.dart';
import '../models/product.dart';
import '../models/scan_record.dart';
import '../services/app_state.dart';
import '../services/translator.dart';
import 'language_packs_screen.dart';
import 'result_screen.dart';

/// The offline translator.
///
/// Reads a menu, an ingredient list, or what someone just said to you, with no
/// connection at all once the language pack is on the phone.
///
/// It does not decide whether anything is safe. Translated text can be run
/// through the allergen check from here, and that check can warn — but it can
/// never come back clear, because a word the translator dropped is a word the
/// check never saw. The matcher enforces that; this screen says it out loud.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key, this.initialText, this.initialFrom});

  /// Text handed over from somewhere else, such as a scanned label.
  final String? initialText;

  /// The language that text is believed to be in.
  final String? initialFrom;

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  late final TextEditingController _input =
      TextEditingController(text: widget.initialText ?? '');

  late String _from = widget.initialFrom ?? 'es';
  String _to = 'en';

  Set<String> _have = <String>{};
  String? _output;
  String? _missing;
  bool _working = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadPacks({bool refresh = false}) async {
    final have =
        await context.read<AppState>().translator.downloaded(refresh: refresh);
    if (!mounted) return;
    setState(() {
      _have = have;
      _loading = false;
      // Start on something the user actually has, rather than a language that
      // will only produce a "not downloaded" message.
      if (!have.contains(_from)) {
        final first = have.firstWhere(
          (String c) => c != 'en',
          orElse: () => _from,
        );
        _from = first;
      }
    });
  }

  Future<void> _translate() async {
    final text = _input.text.trim();
    if (text.isEmpty || _working) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _output = null;
      _missing = null;
    });

    final result = await context.read<AppState>().translator.translate(
          text: text,
          from: _from,
          to: _to,
        );
    if (!mounted) return;
    setState(() {
      _working = false;
      _output = result.ok ? result.text : null;
      _missing = result.status == TranslateStatus.notDownloaded
          ? result.missing
          : null;
    });
    if (result.status == TranslateStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not translate that.')),
      );
    }
  }

  /// Picking a language clears the previous translation: the caption on it is
  /// built from the current target, so leaving the old text up would re-label
  /// English as French. And the two sides may never match — that would present
  /// untouched text as a machine translation — so choosing the other side's
  /// language swaps them instead.
  void _pickFrom(String code) {
    setState(() {
      if (code == _to) _to = _from;
      _from = code;
      _output = null;
      _missing = null;
    });
  }

  void _pickTo(String code) {
    setState(() {
      if (code == _from) _from = _to;
      _to = code;
      _output = null;
      _missing = null;
    });
  }

  void _swap() {
    setState(() {
      final was = _from;
      _from = _to;
      _to = was;
      final text = _output;
      if (text != null) {
        _input.text = text;
        _output = null;
      }
    });
  }

  Future<void> _openPacks() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LanguagePacksScreen()),
    );
    if (!mounted) return;
    await _loadPacks(refresh: true);
  }

  /// Runs the translated text through the allergen matcher.
  ///
  /// The product is marked as translated, which caps the verdict: it can come
  /// back "do not eat" or "cross-contact risk", never "no match found".
  Future<void> _check() async {
    final text = _output;
    if (text == null || text.isEmpty) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ResultScreen(
          product: Product.fromOcr(text, translatedFrom: _from),
          status: ScanStatus.found,
        ),
      ),
    );
    // Passed up, as the other callers of ResultScreen do, so "Log a reaction"
    // from a translated check lands on the reaction log instead of vanishing.
    if (!mounted) return;
    if (result == 'log-reaction') Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = _have.where((String c) => c != 'en').toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translate'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Language packs',
            onPressed: _openPacks,
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ready.isEmpty
              ? _NoPacks(onOpen: _openPacks)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: <Widget>[
                    _LanguageBar(
                      from: _from,
                      to: _to,
                      available: _have,
                      onFrom: _pickFrom,
                      onTo: _pickTo,
                      onSwap: _swap,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _input,
                      maxLines: 6,
                      minLines: 3,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText:
                            'Type or paste a menu, an ingredient list, or what '
                            'someone said',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: _working ? null : _translate,
                      icon: _working
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.translate_rounded, size: 20),
                      label: Text(_working ? 'Translating' : 'Translate'),
                    ),
                    if (_missing != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _MissingPack(
                        code: _missing!,
                        sizeMb: context
                            .read<AppState>()
                            .translator
                            .approxDownloadMegabytes(_missing!),
                        onOpen: _openPacks,
                      ),
                    ],
                    if (_output != null) ...<Widget>[
                      const SizedBox(height: 18),
                      _Output(
                        text: _output!,
                        language: _to,
                        onCopy: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _output!),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _check,
                        icon: const Icon(Icons.rule_rounded, size: 18),
                        label: const Text('Check this against my allergens'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A check on translated text can warn you. It will never '
                        'come back clear — a word the translator dropped is a '
                        'word the check never saw.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _LanguageBar extends StatelessWidget {
  const _LanguageBar({
    required this.from,
    required this.to,
    required this.available,
    required this.onFrom,
    required this.onTo,
    required this.onSwap,
  });

  final String from;
  final String to;
  final Set<String> available;
  final ValueChanged<String> onFrom;
  final ValueChanged<String> onTo;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _Picker(selected: from, available: available, onPick: onFrom),
        ),
        IconButton(
          tooltip: 'Swap',
          onPressed: onSwap,
          icon: const Icon(Icons.swap_horiz_rounded),
        ),
        Expanded(
          child: _Picker(selected: to, available: available, onPick: onTo),
        ),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.selected,
    required this.available,
    required this.onPick,
  });

  final String selected;
  final Set<String> available;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final options = kTranslatorLanguages
        .where((TranslatorLanguage l) => available.contains(l.code))
        .toList();
    final current = translatorLanguageFor(selected);

    return DropdownButtonFormField<String>(
      initialValue: options.any((TranslatorLanguage l) => l.code == selected)
          ? selected
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      hint: Text(current?.native ?? 'Pick'),
      items: <DropdownMenuItem<String>>[
        for (final TranslatorLanguage l in options)
          DropdownMenuItem<String>(
            value: l.code,
            child: Text(
              '${l.flag}  ${l.native}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (String? code) {
        if (code != null) onPick(code);
      },
    );
  }
}

class _Output extends StatelessWidget {
  const _Output({
    required this.text,
    required this.language,
    required this.onCopy,
  });

  final String text;
  final String language;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = translatorLanguageFor(language);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Machine translation into ${l?.english ?? language}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCopy,
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SelectableText(
                text,
                textDirection:
                    (l?.rtl ?? false) ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(fontSize: 17, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingPack extends StatelessWidget {
  const _MissingPack({
    required this.code,
    required this.sizeMb,
    required this.onOpen,
  });

  final String code;
  final int sizeMb;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = translatorLanguageFor(code);
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${l?.english ?? code} is not downloaded',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              code == kPivotLanguage
                  ? 'English is needed for every translation — it is what the '
                      'others are translated through.'
                  : sizeMb > kApproxModelMegabytes
                      ? 'It is about $sizeMb MB with English, which it is '
                          'translated through, and works offline once it is on '
                          'the phone.'
                      : 'It is about $sizeMb MB and works offline once it is on '
                          'the phone.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: onOpen, child: const Text('Get it')),
          ],
        ),
      ),
    );
  }
}

class _NoPacks extends StatelessWidget {
  const _NoPacks({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.translate_rounded,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'No languages yet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Download a language and the translator works with no '
              'connection — on a plane, in a shop abroad, anywhere your signal '
              'has gone. About 30 MB each; the first also brings English.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Choose languages'),
            ),
          ],
        ),
      ),
    );
  }
}
