import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/custom_allergen.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/services/matcher.dart';
import 'package:trace_allergy/theme.dart';

/// Triggers outside the fourteen regulated allergens — FRD 1.1.
///
/// Nobody's label says "contains alpha-gal", so the user supplies the
/// vocabulary. The critical design point is that they should almost never have
/// to: [CustomAllergen.suggestions] ships ten curated starting lists, because
/// no one recalls unprompted that gelatin, magnesium stearate and carmine are
/// all alpha-gal concerns. A blank text box here would be a feature that
/// technically exists and never gets used correctly.
class CustomAllergensScreen extends StatefulWidget {
  const CustomAllergensScreen({super.key});

  @override
  State<CustomAllergensScreen> createState() => _CustomAllergensScreenState();
}

class _CustomAllergensScreenState extends State<CustomAllergensScreen> {
  Profile _withCustoms(Profile p, List<CustomAllergen> customs) {
    return Profile(
      id: p.id,
      name: p.name,
      allergens: Map<Allergen, Severity>.from(p.allergens),
      customAllergens: customs,
      avoidPalWhenUnsure: p.avoidPalWhenUnsure,
      notes: p.notes,
      isChild: p.isChild,
      homeCountry: p.homeCountry,
    );
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _edit({
    CustomAllergen? existing,
    String? presetName,
    List<String>? presetKeywords,
  }) async {
    final app = context.read<AppState>();
    final profile = app.activeProfile;

    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => _CustomAllergenSheet(
        existing: existing,
        presetName: presetName,
        presetKeywords: presetKeywords,
      ),
    );
    if (result == null) return;

    final next = List<CustomAllergen>.from(profile.customAllergens);
    final index = next.indexWhere((c) => c.id == result.allergen.id);
    if (index >= 0) {
      next[index] = result.allergen;
    } else {
      next.add(result.allergen);
    }
    await app.saveProfile(_withCustoms(profile, next));
    if (!mounted) return;

    if (result.dropped.isEmpty) {
      _say('${result.allergen.name} saved');
    } else {
      _say(
        '${result.allergen.name} saved. '
        '${result.dropped.length} keyword${result.dropped.length == 1 ? '' : 's'} '
        'not saved: ${result.dropped.join(', ')}',
      );
    }
  }

  Future<void> _delete(CustomAllergen c) async {
    final app = context.read<AppState>();
    final profile = app.activeProfile;
    final next = profile.customAllergens.where((e) => e.id != c.id).toList();
    await app.saveProfile(_withCustoms(profile, next));
    if (!mounted) return;
    _say('${c.name} removed');
  }

  Future<bool> _confirmDelete(CustomAllergen c) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Remove ${c.name}?'),
        content: const Text('Its keywords stop being checked.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _pickSuggestion() async {
    final taken = context
        .read<AppState>()
        .activeProfile
        .customAllergens
        .map((c) => c.name.trim().toLowerCase())
        .toSet();

    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => _SuggestionSheet(taken: taken),
    );
    if (chosen == null) return;
    if (!mounted) return;
    await _edit(
      presetName: chosen,
      presetKeywords: List<String>.from(
        CustomAllergen.suggestions[chosen] ?? const <String>[],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.activeProfile;
    final customs = profile.customAllergens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom allergens'),
        actions: <Widget>[
          if (customs.isNotEmpty)
            IconButton(
              tooltip: 'Add custom allergen',
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          Text(
            'Triggers for ${profile.name} that no label declares: alpha-gal, '
            'corn, nightshades.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const _MatchingCaveatCard(),
          if (customs.isEmpty) ...<Widget>[
            const SectionTitle('Nothing added yet'),
            _EmptyState(
              onStarter: _pickSuggestion,
              onBlank: () => _edit(),
            ),
          ] else ...<Widget>[
            SectionTitle('${customs.length} added'),
            Card(
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < customs.length; i++) ...<Widget>[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    Dismissible(
                      key: ValueKey<String>(customs[i].id),
                      direction: DismissDirection.endToStart,
                      background: const _DeleteBackground(),
                      confirmDismiss: (_) => _confirmDelete(customs[i]),
                      onDismissed: (_) => _delete(customs[i]),
                      child: _CustomTile(
                        allergen: customs[i],
                        onTap: () => _edit(existing: customs[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Swipe left to remove.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickSuggestion,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Start from a prepared list'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add from scratch'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List pieces
// ---------------------------------------------------------------------------

class _CustomTile extends StatelessWidget {
  const _CustomTile({required this.allergen, required this.onTap});

  final CustomAllergen allergen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = allergen.keywords.length;

    return ListTile(
      onTap: onTap,
      leading: Text(
        allergen.emoji,
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(
        allergen.name.trim().isEmpty ? 'Unnamed trigger' : allergen.name.trim(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          count == 1 ? '1 keyword' : '$count keywords',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
      trailing: _SeverityChip(severity: allergen.severity),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final Severity severity;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final Color tint;
    switch (severity) {
      case Severity.severe:
        tint = dark ? TraceColors.unsafeDark : TraceColors.unsafe;
      case Severity.intolerance:
        tint = dark ? TraceColors.cautionDark : TraceColors.caution;
      case Severity.preference:
        tint = scheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: danger.withValues(alpha: 0.18),
      child: Icon(Icons.delete_outline, color: danger),
    );
  }
}

class _MatchingCaveatCard extends StatelessWidget {
  const _MatchingCaveatCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Matched against printed ingredient text only, so a product '
                'with no list comes back "Can\'t verify", not clear.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStarter, required this.onBlank});

  final VoidCallback onStarter;
  final VoidCallback onBlank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.playlist_add_rounded,
              size: 34,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text(
              'No custom allergens',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Alpha-gal alone means gelatin, carmine, magnesium stearate and '
              'two dozen more terms.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onStarter,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Start from a prepared list'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onBlank,
              child: const Text('Add one from scratch'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Starter vocabularies
// ---------------------------------------------------------------------------

class _SuggestionSheet extends StatelessWidget {
  const _SuggestionSheet({required this.taken});

  final Set<String> taken;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = CustomAllergen.suggestions.entries.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Prepared lists',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Starting points, not complete lists.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (BuildContext _, int _) =>
                    const Divider(height: 1),
                itemBuilder: (BuildContext _, int i) {
                  final name = entries[i].key;
                  final keywords = entries[i].value;
                  final already = taken.contains(name.trim().toLowerCase());
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => Navigator.of(context).pop(name),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        already
                            ? '${keywords.length} keywords · already on the list'
                            : '${keywords.length} keywords · '
                                  '${keywords.take(3).join(', ')}…',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

/// What the editor hands back: the saved trigger plus anything the matcher
/// refused to accept, so the caller can say so out loud.
class _EditResult {
  const _EditResult(this.allergen, this.dropped);

  final CustomAllergen allergen;
  final List<String> dropped;
}

class _CustomAllergenSheet extends StatefulWidget {
  const _CustomAllergenSheet({
    required this.existing,
    this.presetName,
    this.presetKeywords,
  });

  final CustomAllergen? existing;
  final String? presetName;
  final List<String>? presetKeywords;

  @override
  State<_CustomAllergenSheet> createState() => _CustomAllergenSheetState();
}

class _CustomAllergenSheetState extends State<_CustomAllergenSheet> {
  /// A small fixed set. An emoji is a glance-level identifier here, not
  /// decoration — it is what distinguishes two rows on the profile summary.
  static const List<String> _emojiOptions = <String>[
    '⚠️',
    '🥩',
    '🌽',
    '🍅',
    '🌻',
    '🌾',
    '🥥',
    '🫘',
    '🥝',
    '🍌',
    '🧅',
    '🍄',
    '🐟',
    '🍫',
    '🌶️',
    '🫚',
  ];

  late final TextEditingController _name;
  late final TextEditingController _keyword;
  late List<String> _keywords;
  late Severity _severity;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? widget.presetName ?? '');
    _keyword = TextEditingController();
    _keywords = <String>[
      ...(e?.keywords ?? widget.presetKeywords ?? const <String>[]),
    ];
    _severity = e?.severity ?? Severity.severe;
    _emoji = e?.emoji ?? '⚠️';
  }

  @override
  void dispose() {
    _name.dispose();
    _keyword.dispose();
    super.dispose();
  }

  void _addKeyword([String? raw]) {
    final text = (raw ?? _keyword.text).trim().toLowerCase();
    if (text.isEmpty) return;
    setState(() {
      if (!_keywords.contains(text)) _keywords.add(text);
      _keyword.clear();
    });
  }

  void _removeKeyword(String k) {
    setState(() => _keywords.remove(k));
  }

  Future<void> _save() async {
    // Anything sitting in the field but not yet committed to a chip still
    // counts — losing it silently on save is the classic chip-input trap.
    final pending = _keyword.text.trim().toLowerCase();
    final candidates = <String>[
      ..._keywords,
      if (pending.isNotEmpty && !_keywords.contains(pending)) pending,
    ];

    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Give this trigger a name.')),
      );
      return;
    }
    if (candidates.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Add at least one keyword.')),
      );
      return;
    }

    // `validateKeywords` folds terms through `normalise` and collapses
    // duplicates, so compare in the same shape. A term that survived as a
    // duplicate of one already in the list is not a loss and is not reported.
    final accepted = AllergenMatcher.validateKeywords(candidates);
    final kept = accepted.toSet();
    final dropped = candidates
        .where((k) => !kept.contains(AllergenMatcher.normalise(k)))
        .toList();

    if (dropped.isNotEmpty) {
      final proceed = await _explainDropped(dropped, accepted.isNotEmpty);
      if (!mounted) return;
      if (!proceed) return;
    }
    if (accepted.isEmpty) return;

    final existing = widget.existing;
    final saved = CustomAllergen(
      id: existing?.id ?? _newId(),
      name: name,
      keywords: accepted,
      severity: _severity,
      emoji: _emoji,
      notes: existing?.notes ?? '',
    );
    if (!mounted) return;
    Navigator.of(context).pop(_EditResult(saved, dropped));
  }

  /// Say plainly which terms were refused and why. A silently shortened
  /// keyword list is worse than none, because the user believes it is watching
  /// for something it is not.
  Future<bool> _explainDropped(List<String> dropped, bool anythingLeft) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          dropped.length == 1
              ? 'One keyword cannot be used'
              : '${dropped.length} keywords cannot be used',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(dropped.join(', ')),
            const SizedBox(height: 12),
            Text(
              anythingLeft
                  ? 'Under three characters matches fragments of other words. '
                        'Saving the rest.'
                  : 'Under three characters matches fragments of other words. '
                        'Nothing left to save.',
              style: const TextStyle(height: 1.4),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(anythingLeft ? 'Go back' : 'OK'),
          ),
          if (anythingLeft)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save the rest'),
            ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.existing == null
                  ? 'Add custom allergen'
                  : 'Edit custom allergen',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Alpha-gal, corn, nightshades',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Icon',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final e in _emojiOptions)
                  _EmojiChoice(
                    emoji: e,
                    selected: e == _emoji,
                    onTap: () => setState(() => _emoji = e),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'How strict',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<Severity>(
                segments: <ButtonSegment<Severity>>[
                  for (final s in Severity.values)
                    ButtonSegment<Severity>(value: s, label: Text(s.label)),
                ],
                selected: <Severity>{_severity},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onSelectionChanged: (Set<Severity> set) =>
                    setState(() => _severity = set.first),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _severity.description,
              style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Text(
              'Keywords',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (_keywords.isEmpty)
              Text(
                'None yet. Add every name the trigger hides behind.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final k in _keywords)
                    InputChip(
                      label: Text(k),
                      onDeleted: () => _removeKeyword(k),
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyword,
              textInputAction: TextInputAction.done,
              onSubmitted: (String v) => _addKeyword(v),
              decoration: InputDecoration(
                labelText: 'Add a keyword',
                hintText: 'gelatin',
                suffixIcon: IconButton(
                  tooltip: 'Add keyword',
                  onPressed: _addKeyword,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Whole-word match, so "nut" will not match "coconut".',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: _save, child: const Text('Save')),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiChoice extends StatelessWidget {
  const _EmojiChoice({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

/// Ids only have to be unique within one device's store, so no uuid dependency.
int _idCounter = 0;
String _newId() => 'ca_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
