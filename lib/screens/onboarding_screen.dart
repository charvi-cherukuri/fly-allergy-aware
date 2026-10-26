import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/safety_copy.dart';

import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// First run. Three pages: what the app is, which allergens, how strict.
///
/// No account, no paywall, no email. The only thing collected is the profile
/// the app needs in order to answer anything at all.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  final Map<Allergen, Severity> _selected = <Allergen, Severity>{};

  bool _avoidPalWhenUnsure = true;
  int _page = 0;
  bool _saving = false;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    if (_saving) return false;
    if (_page == 1) return _selected.isNotEmpty;
    return true;
  }

  void _toggle(Allergen a) {
    setState(() {
      if (_selected.containsKey(a)) {
        _selected.remove(a);
      } else {
        _selected[a] = Severity.severe;
      }
    });
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final appState = context.read<AppState>();
    final current = appState.activeProfile;
    final profile = Profile(
      id: current.id,
      name: current.name,
      allergens: Map<Allergen, Severity>.from(_selected),
      customAllergens: current.customAllergens.toList(),
      avoidPalWhenUnsure: _avoidPalWhenUnsure,
      notes: current.notes,
      isChild: current.isChild,
      homeCountry: current.homeCountry,
    );

    await appState.saveProfile(profile);
    if (!mounted) return;
    await appState.completeOnboarding();
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_page + 1) / _pageCount,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Step ${_page + 1} of $_pageCount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _IntroPage(),
                  _AllergenPickerPage(
                    selected: _selected,
                    onToggle: _toggle,
                  ),
                  _SeverityPage(
                    selected: _selected,
                    avoidPalWhenUnsure: _avoidPalWhenUnsure,
                    onSeverityChanged: (a, s) =>
                        setState(() => _selected[a] = s),
                    onAvoidPalChanged: (v) =>
                        setState(() => _avoidPalWhenUnsure = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_page > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _back,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _canAdvance ? _next : null,
                      child: Text(isLast ? 'Done' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
            if (_page == 1 && _selected.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Pick at least one allergen to continue.',
                  style: TextStyle(
                    fontSize: 14.5,
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

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.qr_code_scanner_rounded,
            size: 32,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Fly Allergy Aware',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Checks a food label against your allergens and shows what matched.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        const _Bullet(
          icon: Icons.checklist_rounded,
          title: 'You set the list',
          body: 'Cross-contact warnings included.',
        ),
        const _Bullet(
          icon: Icons.cloud_off_rounded,
          title: 'Works offline once scanned',
          body: 'Scanned products resolve again with no signal.',
        ),
        const _Bullet(
          icon: Icons.lock_open_rounded,
          title: 'Free, and stays on this phone',
          body: 'Your profiles and scans stay on this device. If your iPhone '
              'has a passcode, the app locks with it once you are set up. You '
              'can turn that off in Settings.',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This app helps you read labels. It does not replace '
                    'reading them.\n\n$kMedicalNoteLong',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
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
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllergenPickerPage extends StatelessWidget {
  const _AllergenPickerPage({required this.selected, required this.onToggle});

  final Map<Allergen, Severity> selected;
  final void Function(Allergen) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final major = Allergen.values.where((a) => a.isUsMajor).toList();
    final euOnly = Allergen.values.where((a) => !a.isUsMajor).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text(
          'Which allergens?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick as many as you need. You can change this later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SectionTitle('Most common'),
        _AllergenWrap(
          allergens: major,
          selected: selected.keys.toSet(),
          onToggle: onToggle,
        ),
        const SectionTitle('Also regulated in the EU'),
        _AllergenWrap(
          allergens: euOnly,
          selected: selected.keys.toSet(),
          onToggle: onToggle,
        ),
        const SizedBox(height: 12),
        Text(
          'Not required on a US label — molluscs can sit undeclared inside '
          '"natural flavor".',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
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
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
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

class _SeverityPage extends StatelessWidget {
  const _SeverityPage({
    required this.selected,
    required this.avoidPalWhenUnsure,
    required this.onSeverityChanged,
    required this.onAvoidPalChanged,
  });

  final Map<Allergen, Severity> selected;
  final bool avoidPalWhenUnsure;
  final void Function(Allergen, Severity) onSeverityChanged;
  final ValueChanged<bool> onAvoidPalChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = selected.keys.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text(
          'How strict is each one?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Go back and choose at least one allergen.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final a in entries)
            _SeverityRow(
              allergen: a,
              severity: selected[a] ?? Severity.severe,
              onChanged: (s) => onSeverityChanged(a, s),
            ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'At Severe, "may contain" and shared-equipment warnings block '
              'the product. Lower settings show them as a caution you weigh '
              'yourself.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SectionTitle('When data is missing'),
        Card(
          child: SwitchListTile(
            value: avoidPalWhenUnsure,
            onChanged: onAvoidPalChanged,
            title: const Text('Be cautious when label data is incomplete'),
            subtitle: const Text(
              'Partial data is reported as unverified, not clear.',
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
          ),
        ),
      ],
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
