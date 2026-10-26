import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:trace_allergy/data/chef_card_translations.dart';
import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/models/verdict.dart';
import 'package:trace_allergy/screens/profile_screen.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';
import 'package:trace_allergy/widgets/language_picker.dart';

/// A chef card in twelve languages, generated on the device.
///
/// The top scanner apps are English-only, and the one serious translation-card
/// product puts its languages behind a subscription and is reported to fail with
/// no connection — the exact condition travel imposes. Every string here ships
/// in the binary, so the card renders on a plane, on a dead SIM, in a basement
/// restaurant abroad.
class ChefCardScreen extends StatefulWidget {
  const ChefCardScreen({super.key});

  @override
  State<ChefCardScreen> createState() => _ChefCardScreenState();
}

class _ChefCardScreenState extends State<ChefCardScreen> {
  /// The language comes from [AppState.travelLanguage], shared with the
  /// emergency phrases and the allergen names on a scan result. Someone flying
  /// to Tokyo sets it once, on any of those screens, and the whole app follows.
  String get _code => context.read<AppState>().travelLanguage;

  void _select(String code) {
    context.read<AppState>().setTravelLanguage(code);
  }

  Future<void> _share(Profile profile) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await Share.share(
      _buildChefCardText(profile, _code),
      subject: 'Allergy card — ${profile.name}',
      sharePositionOrigin: origin,
    );
  }

  void _openFullScreen(Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenCardPage(profile: profile, code: _code),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().activeProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chef card'),
        actions: [
          if (!profile.isEmpty)
            IconButton(
              tooltip: 'Share',
              onPressed: () => _share(profile),
              icon: const Icon(Icons.ios_share_rounded),
            ),
        ],
      ),
      body: profile.isEmpty
          ? _NoAllergensState(name: profile.name)
          : _buildCardView(profile),
    );
  }

  Widget _buildCardView(Profile profile) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        _OfflineCaption(name: profile.name),
        const SizedBox(height: 12),
        LanguagePicker(selected: _code, onSelect: _select),
        const SizedBox(height: 18),
        _ChefCardBody(profile: profile, code: _code),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openFullScreen(profile),
                icon: const Icon(Icons.fullscreen_rounded),
                label: const Text('Full screen'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _share(profile),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
        if (_code != 'en') ...[
          const SectionTitle('What it says'),
          Text(
            'The same card in English, so you can check what you are handing over.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _EnglishTranscript(profile: profile),
        ],
      ],
    );
  }
}

/// The card itself. The full-screen page renders this same widget at a larger
/// scale rather than keeping a second, drifting copy of the layout.
class _ChefCardBody extends StatelessWidget {
  const _ChefCardBody({
    required this.profile,
    required this.code,
    this.scale = 1.0,
  });

  final Profile profile;
  final String code;

  /// Multiplier on every type size. The full-screen page pushes this up.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = cardStringsFor(code);
    final language = cardLanguageFor(code);
    final allergens = profile.sorted;
    final severities = profile.allergens.values.toSet();
    final showSeverityPerRow = severities.length > 1;
    final severe = TraceColors.forLevel(VerdictLevel.unsafe, theme.brightness);

    return Directionality(
      textDirection: language.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: 0.32),
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (profile.hasSevere)
              Container(
                color: severe.withValues(alpha: 0.16),
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale,
                  vertical: 12 * scale,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: severe,
                      size: 26 * scale,
                    ),
                    SizedBox(width: 10 * scale),
                    Expanded(
                      child: Text(
                        strings.severityLabels[Severity.severe] ?? '',
                        style: TextStyle(
                          color: severe,
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.all(18 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.heading,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 27 * scale,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 14 * scale),
                  Text(
                    strings.leadIn,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  for (final a in allergens) ...[
                    _AllergenRow(
                      allergen: a,
                      code: code,
                      severity: profile.severityOf(a),
                      showSeverity: showSeverityPerRow,
                      scale: scale,
                    ),
                    SizedBox(height: 8 * scale),
                  ],
                  SizedBox(height: 6 * scale),
                  Text(
                    strings.crossContact,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16.5 * scale,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  Container(
                    padding: EdgeInsets.all(12 * scale),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      strings.consequence,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 17 * scale,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                  SizedBox(height: 14 * scale),
                  Text(
                    strings.thanks,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 16 * scale,
                      height: 1.35,
                    ),
                  ),
                  if (profile.notes.trim().isNotEmpty) ...[
                    SizedBox(height: 16 * scale),
                    Divider(color: scheme.outlineVariant, height: 1),
                    SizedBox(height: 14 * scale),
                    Text(
                      strings.noteLabel,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14.5 * scale,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    // The note is the user's own words, so it stays in English.
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        profile.notes.trim(),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16 * scale,
                          height: 1.35,
                        ),
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Text(
                      'This note is in English only.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14 * scale,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllergenRow extends StatelessWidget {
  const _AllergenRow({
    required this.allergen,
    required this.code,
    required this.severity,
    required this.showSeverity,
    required this.scale,
  });

  final Allergen allergen;
  final String code;
  final Severity severity;
  final bool showSeverity;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = cardStringsFor(code);
    final isSevere = severity == Severity.severe;
    final accent = isSevere
        ? TraceColors.forLevel(VerdictLevel.unsafe, theme.brightness)
        : scheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: isSevere ? 0.5 : 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(allergen.emoji, style: TextStyle(fontSize: 26 * scale)),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allergenNameIn(code, allergen),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 21 * scale,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (showSeverity) ...[
                  SizedBox(height: 3 * scale),
                  Text(
                    strings.severityLabels[severity] ?? '',
                    style: TextStyle(
                      color: accent,
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineCaption extends StatelessWidget {
  const _OfflineCaption({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "$name's card. Built on this device — works with no connection.",
            style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// The English rendering shown under the card, so the user can read back what
/// the stranger is being asked to do.
class _EnglishTranscript extends StatelessWidget {
  const _EnglishTranscript({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = cardStringsFor('en');
    final mixed = profile.allergens.values.toSet().length > 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile.hasSevere)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  strings.severityLabels[Severity.severe] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TraceColors.forLevel(
                      VerdictLevel.unsafe,
                      Theme.of(context).brightness,
                    ),
                  ),
                ),
              ),
            Text(
              strings.heading,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(strings.leadIn, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 6),
            for (final a in profile.sorted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  mixed
                      ? '${a.emoji}  ${allergenNameIn('en', a)} — '
                            '${strings.severityLabels[profile.severityOf(a)] ?? ''}'
                      : '${a.emoji}  ${allergenNameIn('en', a)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 10),
            Text(strings.crossContact, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 8),
            Text(
              strings.consequence,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              strings.thanks,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (profile.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                strings.noteLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(profile.notes.trim(), style: const TextStyle(height: 1.35)),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoAllergensState extends StatelessWidget {
  const _NoAllergensState({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate_rounded, size: 52, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'Nothing to put on the card',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$name has no allergens set, so there is nothing to translate yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileScreen(),
                ),
              ),
              child: const Text('Set up allergens'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card alone, as large as the screen allows, with the system chrome out of
/// the way. Screen brightness is left alone — overriding it is a battery
/// decision that belongs to the person holding the phone.
class _FullScreenCardPage extends StatefulWidget {
  const _FullScreenCardPage({required this.profile, required this.code});

  final Profile profile;
  final String code;

  @override
  State<_FullScreenCardPage> createState() => _FullScreenCardPageState();
}

class _FullScreenCardPageState extends State<_FullScreenCardPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = (constraints.maxWidth / 360).clamp(1.0, 1.7);
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                      child: _ChefCardBody(
                        profile: widget.profile,
                        code: widget.code,
                        scale: scale,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(
                      'Tap anywhere to close',
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The card as plain text, for sharing. The target language first, then the
/// English rendering underneath so the recipient of a forwarded card can read
/// both halves.
String _buildChefCardText(Profile profile, String code) {
  final buffer = StringBuffer();
  _writeCardText(buffer, profile, code);
  if (code != 'en') {
    buffer.writeln();
    buffer.writeln('— — —');
    buffer.writeln();
    _writeCardText(buffer, profile, 'en');
  }
  return buffer.toString().trimRight();
}

void _writeCardText(StringBuffer buffer, Profile profile, String code) {
  final strings = cardStringsFor(code);
  final mixed = profile.allergens.values.toSet().length > 1;

  if (profile.hasSevere) {
    buffer.writeln(strings.severityLabels[Severity.severe] ?? '');
  }
  buffer.writeln(strings.heading);
  buffer.writeln();
  buffer.writeln(strings.leadIn);
  for (final a in profile.sorted) {
    final name = allergenNameIn(code, a);
    if (mixed) {
      buffer.writeln(
        '• $name — ${strings.severityLabels[profile.severityOf(a)] ?? ''}',
      );
    } else {
      buffer.writeln('• $name');
    }
  }
  buffer.writeln();
  buffer.writeln(strings.crossContact);
  buffer.writeln(strings.consequence);
  buffer.writeln();
  buffer.writeln(strings.thanks);
  if (profile.notes.trim().isNotEmpty) {
    buffer.writeln();
    buffer.writeln('${strings.noteLabel}: ${profile.notes.trim()}');
  }
}
