import 'dart:async';
import '../data/countries.dart';
import '../widgets/country_picker.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/models/verdict.dart';
import 'package:trace_allergy/screens/custom_allergens_screen.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// The household screen.
///
/// The allergic person is often not the one holding the phone. The app keeps a
/// profile per person and switches between them, so the parent shopping for a
/// child is checking the child's list, not their own.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _notesController = TextEditingController();
  String? _notesProfileId;
  Timer? _notesDebounce;

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Profile _copyOf(
    Profile p, {
    String? name,
    Map<Allergen, Severity>? allergens,
    bool? avoidPalWhenUnsure,
    String? notes,
    bool? isChild,
    String? homeCountry,
  }) {
    return Profile(
      id: p.id,
      name: name ?? p.name,
      allergens: allergens ?? Map<Allergen, Severity>.from(p.allergens),
      // Carried through explicitly: Profile's constructor defaults this to an
      // empty list, so omitting it here silently wipes every custom allergen
      // on the next rename, severity change or notes keystroke.
      customAllergens: p.customAllergens.toList(),
      avoidPalWhenUnsure: avoidPalWhenUnsure ?? p.avoidPalWhenUnsure,
      notes: notes ?? p.notes,
      isChild: isChild ?? p.isChild,
      homeCountry: homeCountry ?? p.homeCountry,
    );
  }

  void _confirm(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _toggleAllergen(Profile p, Allergen a) async {
    final next = Map<Allergen, Severity>.from(p.allergens);
    final removing = next.containsKey(a);
    if (removing) {
      next.remove(a);
    } else {
      next[a] = Severity.severe;
    }
    await context.read<AppState>().saveProfile(
          _copyOf(p, allergens: next),
        );
    if (!mounted) return;
    _confirm(
      removing
          ? '${a.label} removed from ${p.name}'
          : '${a.label} added for ${p.name}',
    );
  }

  Future<void> _setSeverity(Profile p, Allergen a, Severity s) async {
    final next = Map<Allergen, Severity>.from(p.allergens);
    next[a] = s;
    await context.read<AppState>().saveProfile(
          _copyOf(p, allergens: next),
        );
    if (!mounted) return;
    _confirm('${a.label} set to ${s.label}');
  }

  Future<void> _setAvoidPal(Profile p, bool value) async {
    await context.read<AppState>().saveProfile(
          _copyOf(p, avoidPalWhenUnsure: value),
        );
  }

  Future<void> _pickHomeCountry(Profile p) async {
    final String? code = await showCountryPicker(context, selected: p.homeCountry);
    if (code == null || !mounted) return;
    await context.read<AppState>().saveProfile(
          _copyOf(p, homeCountry: code),
          recordHistory: false,
        );
    if (!mounted) return;
    final Country? c = countryFor(code);
    _confirm(c == null ? 'Home country cleared' : 'Home country set to ${c.name}');
  }

  Future<void> _setIsChild(Profile p, bool value) async {
    await context.read<AppState>().saveProfile(_copyOf(p, isChild: value));
  }

  void _onNotesChanged(Profile p, String value) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      context.read<AppState>().saveProfile(_copyOf(p, notes: value));
    });
  }

  Future<String?> _askForName({
    required String title,
    required String actionLabel,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Sam',
            ),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 40),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addPerson() async {
    final name = await _askForName(
      title: 'Add a person',
      actionLabel: 'Add',
    );
    if (!mounted) return;
    if (name == null || name.isEmpty) return;

    final appState = context.read<AppState>();
    final created = await appState.createProfile(name);
    if (!mounted) return;
    await appState.setActiveProfile(created.id);
    if (!mounted) return;
    _confirm('$name added');
  }

  Future<void> _rename(Profile p) async {
    final name = await _askForName(
      title: 'Rename profile',
      actionLabel: 'Save',
      initial: p.name,
    );
    if (!mounted) return;
    if (name == null || name.isEmpty) return;
    await context.read<AppState>().saveProfile(_copyOf(p, name: name));
  }

  Future<void> _delete(Profile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text(
          'Allergen list and notes removed. Scan history kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    await context.read<AppState>().deleteProfile(p.id);
    if (!mounted) return;
    _confirm('${p.name} deleted');
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.activeProfile;
    final profiles = appState.profiles;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_notesProfileId != profile.id) {
      _notesProfileId = profile.id;
      _notesDebounce?.cancel();
      _notesController.value = TextEditingValue(
        text: profile.notes,
        selection: TextSelection.collapsed(offset: profile.notes.length),
      );
    }

    final chosen = profile.sorted;
    final major = Allergen.values.where((a) => a.isUsMajor).toList();
    final euOnly = Allergen.values.where((a) => !a.isUsMajor).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            onPressed: _addPerson,
            icon: const Icon(Icons.person_add_alt_rounded),
            tooltip: 'Add person',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ActiveProfileCard(
            profile: profile,
            onRename: () => _rename(profile),
            onDelete: profiles.length > 1 ? () => _delete(profile) : null,
          ),
          const SectionTitle('Household'),
          _ProfileSwitcher(
            profiles: profiles,
            activeId: profile.id,
            onSelect: (id) => context.read<AppState>().setActiveProfile(id),
            onAdd: _addPerson,
          ),
          const SectionTitle('Allergens'),
          Text(
            'Saved as you go.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _AllergenWrap(
            allergens: major,
            selected: profile.allergens.keys.toSet(),
            onToggle: (a) => _toggleAllergen(profile, a),
          ),
          const SizedBox(height: 14),
          Text(
            'Also regulated in the EU',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _AllergenWrap(
            allergens: euOnly,
            selected: profile.allergens.keys.toSet(),
            onToggle: (a) => _toggleAllergen(profile, a),
          ),
          const SizedBox(height: 10),
          Text(
            'Not required on a US label; molluscs often go undeclared.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SectionTitle('Beyond the fourteen'),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                child: const Icon(Icons.playlist_add_rounded),
              ),
              title: const Text(
                'Custom allergens',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  profile.customAllergens.isEmpty
                      ? 'Alpha-gal, corn, nightshades — triggers no label '
                          'declares'
                      : '${profile.customAllergens.length} set: '
                          '${profile.customAllergens.map((c) => c.name).join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CustomAllergensScreen(),
                ),
              ),
            ),
          ),
          const SectionTitle('How strict'),
          if (chosen.isEmpty)
            _EmptyState(
              icon: Icons.rule_rounded,
              message: 'No allergens for ${profile.name} yet. '
                  'Choose one above.',
            )
          else ...[
            for (final a in chosen)
              _SeverityRow(
                allergen: a,
                severity: profile.severityOf(a),
                onChanged: (s) => _setSeverity(profile, a, s),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'At Severe, "may contain" and shared-equipment warnings '
                  'block the product. Lower settings show them as a caution.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
          const SectionTitle('This person'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Text(
                    countryFor(profile.homeCountry)?.flag ?? '🌐',
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: const Text('Home country'),
                  subtitle: Text(
                    countryFor(profile.homeCountry)?.name ??
                        'Not set — trips cannot be told domestic or international',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickHomeCountry(profile),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                SwitchListTile(
                  value: profile.isChild,
                  onChanged: (v) => _setIsChild(profile, v),
                  title: const Text('This profile is for a child'),
                  subtitle: const Text('Shown on the chef card.'),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                SwitchListTile(
                  value: profile.avoidPalWhenUnsure,
                  onChanged: (v) => _setAvoidPal(profile, v),
                  title: const Text(
                    'Be cautious when label data is incomplete',
                  ),
                  subtitle: const Text(
                    'Partial data is reported as unverified, not clear.',
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Notes'),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => _onNotesChanged(profile, v),
            decoration: const InputDecoration(
              hintText: 'e.g. shared oil is fine',
              helperText: 'Shown on the chef card.',
              helperMaxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveProfileCard extends StatelessWidget {
  const _ActiveProfileCard({
    required this.profile,
    required this.onRename,
    required this.onDelete,
  });

  final Profile profile;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    profile.isChild
                        ? Icons.child_care_rounded
                        : Icons.person_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Profile options',
                  onSelected: (value) {
                    if (value == 'rename') {
                      onRename();
                    } else if (value == 'delete') {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      enabled: onDelete != null,
                      child: Text(
                        onDelete == null ? 'Delete (last profile)' : 'Delete',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (profile.hasSevere) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: TraceColors.forLevel(
                    VerdictLevel.unsafe,
                    theme.brightness,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: TraceColors.forLevel(
                        VerdictLevel.unsafe,
                        theme.brightness,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Severe set — cross-contact warnings block a product.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileSwitcher extends StatelessWidget {
  const _ProfileSwitcher({
    required this.profiles,
    required this.activeId,
    required this.onSelect,
    required this.onAdd,
  });

  final List<Profile> profiles;
  final String activeId;
  final void Function(String id) onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final p in profiles) ...[
            ChoiceChip(
              selected: p.id == activeId,
              onSelected: (_) => onSelect(p.id),
              avatar: Icon(
                p.isChild ? Icons.child_care_rounded : Icons.person_rounded,
                size: 18,
              ),
              label: Text(p.name),
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            onPressed: onAdd,
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add person'),
          ),
        ],
      ),
    );
  }
}

class _AllergenWrap extends StatelessWidget {
  const _AllergenWrap({
    required this.allergens,
    required this.selected,
    required this.onToggle,
  });

  final List<Allergen> allergens;
  final Set<Allergen> selected;
  final void Function(Allergen) onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final a in allergens)
              SizedBox(
                width: width,
                child: _AllergenCard(
                  allergen: a,
                  selected: selected.contains(a),
                  onTap: () => onToggle(a),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AllergenCard extends StatelessWidget {
  const _AllergenCard({
    required this.allergen,
    required this.selected,
    required this.onTap,
  });

  final Allergen allergen;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(allergen.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  allergen.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityRow extends StatelessWidget {
  const _SeverityRow({
    required this.allergen,
    required this.severity,
    required this.onChanged,
  });

  final Allergen allergen;
  final Severity severity;
  final ValueChanged<Severity> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(allergen.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      allergen.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<Severity>(
                  segments: [
                    for (final s in Severity.values)
                      ButtonSegment<Severity>(
                        value: s,
                        label: Text(s.label),
                      ),
                  ],
                  selected: {severity},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (set) => onChanged(set.first),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                severity.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
