import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/chef_card_translations.dart';
import '../models/product.dart';
import '../models/scan_record.dart';
import '../models/verdict.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/language_picker.dart';
import 'ocr_screen.dart';

/// The answer screen.
///
/// The single most-cited complaint about every competing scanner is that it
/// hands down a verdict without saying which ingredient caused it. So the
/// centre of this screen is not the banner — it is the ingredient list with the
/// offending words highlighted in place, followed by a per-allergen breakdown
/// that says exactly what matched and whether the evidence was a declared
/// "Contains" statement or a cross-contact warning.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.product,
    required this.status,
    this.message,
  });

  final Product? product;
  final ScanStatus status;
  final String? message;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Verdict? _verdict;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) return;

    final verdict = context.read<AppState>().evaluate(product);
    _verdict = verdict;

    // recordScan notifies listeners, so it cannot run during the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().recordScan(product, verdict);
    });
  }

  // ------------------------------------------------------------------ actions

  Future<void> _share() async {
    final product = widget.product;
    final verdict = _verdict;
    if (product == null || verdict == null) return;

    final profile = context.read<AppState>().activeProfile;
    final buffer = StringBuffer()
      ..writeln(product.displayName)
      ..writeln(
        '${TraceColors.titleForLevel(verdict.level)} — ${verdict.headline}',
      )
      ..writeln('Checked against ${profile.name}: ${profile.summary}');

    // A shared translated result travels without this screen around it, so
    // the caveat has to travel inside the text. Otherwise it reads as a claim
    // about the pack.
    if (product.isTranslated) {
      buffer
        ..writeln()
        ..writeln(
          'Checked against a machine translation, not the pack itself. A '
          'translation can flag an allergen; it cannot rule one out.',
        );
    }

    if (verdict.hits.isNotEmpty) {
      buffer.writeln();
      for (final hit in verdict.hits) {
        final evidence = hit.isFromCrossContact
            ? 'cross-contact warning'
            : (product.isTranslated
                ? 'named in the translation'
                : 'declared on the label');
        final terms =
            hit.matchedTerms.isEmpty ? '' : ' (${hit.matchedTerms.join(', ')})';
        buffer.writeln('• ${hit.label} — $evidence$terms');
      }
    }

    buffer
      ..writeln()
      ..writeln('Source: ${product.source.label}.')
      ..write(
        product.isTranslated
            ? 'Checked with Fly Allergy Aware. Not a guarantee — read the pack.'
            : 'Checked with Fly Allergy Aware. Label data, not a guarantee.',
      );

    await Share.share(buffer.toString(), subject: product.displayName);
  }

  Future<void> _toggleSaved() async {
    final product = widget.product;
    if (product == null) return;
    await context.read<AppState>().toggleSaved(product.barcode);
  }

  Future<void> _openOcr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const OcrScreen()),
    );
    if (!mounted) return;
    if (result == 'log-reaction') {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _addToOpenFoodFacts(String? barcode) async {
    final uri = Uri.parse(
      barcode == null
          ? 'https://world.openfoodfacts.org/cgi/product.pl?type=add'
          : 'https://world.openfoodfacts.org/cgi/product.pl?type=add&code=$barcode',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Open Food Facts.')),
      );
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final verdict = _verdict;

    if (product == null || verdict == null) {
      return _RecoveryScaffold(
        status: widget.status,
        message: widget.message,
        onUseLabelPhoto: _openOcr,
        onAddToOpenFoodFacts: _addToOpenFoodFacts,
      );
    }

    final saved = context.watch<AppState>().savedItems.any(
          (r) => r.product.barcode == product.barcode,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        actions: [
          IconButton(
            tooltip: saved ? 'Remove from safe list' : 'Save to safe list',
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            ),
            onPressed: _toggleSaved,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _share,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _VerdictBanner(verdict: verdict),
          const SizedBox(height: 20),
          _ProductIdentity(product: product),
          _IngredientEvidence(product: product, verdict: verdict),
          _AllergenBreakdown(
            verdict: verdict,
            translated: product.isTranslated,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _toggleSaved,
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
            ),
            label: Text(saved ? 'On your safe list' : 'Save to safe list'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'log-reaction'),
            icon: const Icon(Icons.medical_information_outlined),
            label: const Text('Log a reaction'),
          ),
          const SizedBox(height: 20),
          _SourceFootnote(product: product),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verdict banner
// ---------------------------------------------------------------------------

/// Readable at arm's length in an aisle: one word, then one line, then one
/// sentence, in decreasing size.
class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.verdict});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = TraceColors.forLevel(verdict.level, brightness);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                TraceColors.iconForLevel(verdict.level),
                color: onColor,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  TraceColors.titleForLevel(verdict.level),
                  style: TextStyle(
                    color: onColor,
                    fontSize: 34,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            verdict.headline,
            style: TextStyle(
              color: onColor,
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (verdict.detail.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              verdict.detail,
              style: TextStyle(
                color: onColor.withValues(alpha: 0.92),
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Product identity
// ---------------------------------------------------------------------------

class _ProductIdentity extends StatelessWidget {
  const _ProductIdentity({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = product.imageUrl;
    final subtitleParts = <String>[
      if (product.brand != null && product.brand!.trim().isNotEmpty)
        product.brand!.trim(),
      if (product.quantity != null && product.quantity!.trim().isNotEmpty)
        product.quantity!.trim(),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: imageUrl == null || imageUrl.trim().isEmpty
                    ? _ImageFallback(scheme: scheme)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _ImageFallback(scheme: scheme),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return _ImageFallback(scheme: scheme);
                        },
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitleParts.join(' · '),
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _SourceChip(source: product.source),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.inventory_2_outlined,
        color: scheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final ProductSource source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.source_outlined, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(
            source.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The offending-ingredient section — the whole point of the app
// ---------------------------------------------------------------------------

/// A merged highlight span. Two hits can cover overlapping text (e.g. "milk"
/// inside "milk powder"); the merged span takes the worse of the two levels,
/// because [VerdictLevel] is ordered by decreasing seriousness.
class _Highlight {
  const _Highlight(this.start, this.end, this.level);

  final int start;
  final int end;
  final VerdictLevel level;
}

class _IngredientEvidence extends StatelessWidget {
  const _IngredientEvidence({required this.product, required this.verdict});

  final Product product;
  final Verdict verdict;

  static List<_Highlight> mergedHighlights(Verdict verdict, int textLength) {
    final ranges = <_Highlight>[];
    for (final hit in verdict.hits) {
      for (final range in hit.highlightRanges) {
        final start = range.start.clamp(0, textLength).toInt();
        final end = range.end.clamp(0, textLength).toInt();
        if (end <= start) continue;
        ranges.add(_Highlight(start, end, hit.level));
      }
    }

    ranges.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.end.compareTo(b.end);
    });

    final merged = <_Highlight>[];
    for (final range in ranges) {
      if (merged.isEmpty || range.start >= merged.last.end) {
        merged.add(range);
        continue;
      }
      final last = merged.removeLast();
      merged.add(
        _Highlight(
          last.start,
          range.end > last.end ? range.end : last.end,
          // Lower index == more serious.
          last.level.index <= range.level.index ? last.level : range.level,
        ),
      );
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final text = verdict.ingredientTextUsed ?? product.ingredientsText ?? '';

    if (text.trim().isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Ingredients'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.help_outline_rounded, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No ingredient list in this record. Photograph the '
                      'label instead.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final highlights = mergedHighlights(verdict, text.length);
    final baseStyle = TextStyle(
      fontSize: 16.5,
      height: 1.55,
      color: scheme.onSurface,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final highlight in highlights) {
      if (highlight.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, highlight.start)));
      }
      final color = TraceColors.forLevel(highlight.level, brightness);
      spans.add(
        TextSpan(
          text: text.substring(highlight.start, highlight.end),
          style: TextStyle(
            backgroundColor: color.withValues(alpha: 0.30),
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            decorationColor: color,
            decorationThickness: 2.5,
          ),
        ),
      );
      cursor = highlight.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          product.isTranslated
              ? 'Translated text'
              : (highlights.isEmpty ? 'Ingredients' : 'Where it appears'),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (highlights.isNotEmpty) ...[
                  Text(
                    highlights.length == 1
                        ? '1 match'
                        : '${highlights.length} matches',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SelectableText.rich(
                  TextSpan(style: baseStyle, children: spans),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Per-allergen breakdown
// ---------------------------------------------------------------------------

class _AllergenBreakdown extends StatelessWidget {
  const _AllergenBreakdown({required this.verdict, required this.translated});

  final Verdict verdict;

  /// The evidence came from a machine translation, not the pack.
  final bool translated;

  @override
  Widget build(BuildContext context) {
    if (verdict.hits.isEmpty) return const SizedBox.shrink();

    // Abroad, knowing which allergen matched is only half the answer — the
    // other half is being able to say it to the person behind the counter.
    final language = context.watch<AppState>().travelLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('What matched'),
        for (var i = 0; i < verdict.hits.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _AllergenHitCard(
            hit: verdict.hits[i],
            language: language,
            translated: translated,
          ),
        ],
      ],
    );
  }
}

class _AllergenHitCard extends StatelessWidget {
  const _AllergenHitCard({
    required this.hit,
    required this.language,
    required this.translated,
  });

  final AllergenHit hit;

  /// When true, a precautionary phrase was found in a machine translation, so
  /// it must not be presented as something the packaging says.
  final bool translated;

  /// The trip's language, from [AppState.travelLanguage]. English means no
  /// second line; there is nothing to add.
  final String language;

  /// The allergen's name in [language], or null when there is nothing to show:
  /// English, a custom allergen the user typed, or a gap in the table.
  String? get _localName {
    final a = hit.allergen;
    if (language == 'en' || a == null) return null;
    final name = kAllergenTranslations[language]?[a];
    return name == hit.label ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final color = TraceColors.forLevel(hit.level, brightness);
    final crossContact = hit.isFromCrossContact;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(hit.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_localName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _localName!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: languageIsRtl(language)
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    hit.severity.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  crossContact
                      ? Icons.warning_amber_rounded
                      : Icons.receipt_long_outlined,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    crossContact
                        ? 'Cross-contact warning, not a declared ingredient.'
                        : 'Declared as an ingredient or in "Contains".',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (hit.matchedTerms.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Matched',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final term in hit.matchedTerms)
                    _TermChip(term: term, color: color),
                ],
              ),
            ],
            if (hit.palPhrases.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                translated ? 'The translation says' : 'The packaging says',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              for (final phrase in hit.palPhrases)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(color: color, width: 3),
                      ),
                    ),
                    child: Text(
                      '“$phrase”',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TermChip extends StatelessWidget {
  const _TermChip({required this.term, required this.color});

  final String term;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        term,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SourceFootnote extends StatelessWidget {
  const _SourceFootnote({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ocr = product.source == ProductSource.ocr;
    return Text(
      product.isTranslated
          ? 'Machine translation — possibly typed or pasted, not read from a '
              'pack. It can flag an allergen but cannot rule one out.'
          : ocr
              ? 'Read from the label photo. Printed text only.'
              : 'Label data from ${product.source.label}. Believe the '
                  'packaging over this.',
      style: TextStyle(
        fontSize: 14.5,
        height: 1.4,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recovery: not found / offline / error
// ---------------------------------------------------------------------------

/// A barcode that resolves to nothing is the most common functional failure in
/// this category, and in every competitor it is a dead end. Here it is a screen
/// with two ways forward.
class _RecoveryScaffold extends StatelessWidget {
  const _RecoveryScaffold({
    required this.status,
    required this.message,
    required this.onUseLabelPhoto,
    required this.onAddToOpenFoodFacts,
  });

  final ScanStatus status;
  final String? message;
  final Future<void> Function() onUseLabelPhoto;
  final Future<void> Function(String? barcode) onAddToOpenFoodFacts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offline = status == ScanStatus.offline;
    final notFound = status == ScanStatus.notFound;
    final barcode = _barcodeFromMessage(message);

    final String title;
    final String body;
    final IconData icon;

    if (notFound) {
      title = 'This barcode is not in the databases';
      body = 'Common for store brands and new packaging. It says nothing '
          'about the food.';
      icon = Icons.search_off_rounded;
    } else if (offline) {
      title = 'No connection, and nothing cached';
      body = 'This product has not been scanned on this device before.';
      icon = Icons.wifi_off_rounded;
    } else {
      title = 'The lookup did not complete';
      body = message ?? 'The food databases could not be reached.';
      icon = Icons.error_outline_rounded;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(height: 24),
          Icon(icon, size: 60, color: scheme.onSurfaceVariant),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: onUseLabelPhoto,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Photograph the label instead'),
          ),
          const SizedBox(height: 8),
          Text(
            'Works offline.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
          ),
          if (notFound) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => onAddToOpenFoodFacts(barcode),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Add it to Open Food Facts'),
            ),
            const SizedBox(height: 8),
            Text(
              barcode == null
                  ? 'A free, open database. Adding it helps the next person '
                      'who scans it.'
                  : 'A free, open database. Adding $barcode helps the next '
                      'person who scans it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  /// The failed lookup has no [Product], so the only place the barcode can
  /// still be is the outcome message. Anything that looks like an 8–14 digit
  /// run is treated as the code.
  static String? _barcodeFromMessage(String? message) {
    if (message == null) return null;
    final match = RegExp(r'\b\d{8,14}\b').firstMatch(message);
    return match?.group(0);
  }
}
