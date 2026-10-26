import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/chef_card_translations.dart';
import '../data/emergency_phrases.dart';
import '../models/allergen.dart';
import '../models/profile.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/language_picker.dart';

/// What to say when a reaction starts somewhere you do not speak the language.
///
/// The chef card is for the calm minute before you eat. This is for the minute
/// after: short imperative sentences, largest first, in an order that puts the
/// ambulance before the explanation. Everything is `const` in the binary, so it
/// renders on a plane, on a dead SIM, in a country you landed in an hour ago.
class EmergencyPhrasesScreen extends StatelessWidget {
  const EmergencyPhrasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final String code = app.travelLanguage;
    final CardLanguage language = languageFor(code);
    final PhraseScreenStrings strings =
        kPhraseScreenStrings[code] ?? kPhraseScreenStrings['en']!;
    final Profile profile = app.activeProfile;

    final List<EmergencyPhrase> urgent =
        kEmergencyPhrases.where((EmergencyPhrase p) => p.urgent).toList();
    // `allergic_to` is the heading on the allergen card below, so it would
    // otherwise appear twice on the same screen.
    final List<EmergencyPhrase> rest = kEmergencyPhrases
        .where((EmergencyPhrase p) => !p.urgent && p.id != 'allergic_to')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency phrases'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share',
            onPressed: () => _share(context, profile, code),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          LanguagePicker(
            selected: code,
            onSelect: (String c) => app.setTravelLanguage(c),
          ),
          const SizedBox(height: 14),
          _ShowInstruction(text: strings.showToLabel, language: language),
          SectionTitle(strings.urgentLabel),
          for (final EmergencyPhrase p in urgent)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PhraseCard(
                phrase: p,
                language: language,
                emphasis: true,
              ),
            ),
          if (!profile.isEmpty) ...<Widget>[
            const SizedBox(height: 4),
            _AllergenCard(profile: profile, language: language),
          ],
          SectionTitle(strings.otherLabel),
          for (final EmergencyPhrase p in rest)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PhraseCard(phrase: p, language: language),
            ),
          const SizedBox(height: 16),
          Text(
            'Translations ship with the app and are fixed. Tap a phrase to '
            'fill the screen with it.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    Profile profile,
    String code,
  ) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    await Share.share(
      _phraseSheetText(profile, code),
      subject: 'Emergency phrases — ${profile.name}',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }
}

/// The line that tells the user what to do with this screen, in the language of
/// the person they are about to hand it to as well as their own.
class _ShowInstruction extends StatelessWidget {
  const _ShowInstruction({required this.text, required this.language});

  final String text;
  final CardLanguage language;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(
          Icons.record_voice_over_outlined,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            textDirection: language.rtl ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _PhraseCard extends StatelessWidget {
  const _PhraseCard({
    required this.phrase,
    required this.language,
    this.emphasis = false,
  });

  final EmergencyPhrase phrase;
  final CardLanguage language;

  /// The phrases that get someone moving are set larger than the rest.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool translated = language.code != 'en';
    final String text = phrase.inLanguage(language.code);

    return Card(
      margin: EdgeInsets.zero,
      color: emphasis ? scheme.errorContainer.withValues(alpha: 0.35) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showFullScreen(context, text, phrase.english, language),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      text,
                      textDirection: language.rtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: TextStyle(
                        fontSize: emphasis ? 19 : 17,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    // The English is kept underneath so the user can check they
                    // are about to show the sentence they meant to show.
                    if (translated) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        phrase.english,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                },
                icon: Icon(
                  Icons.copy_rounded,
                  size: 18,
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

/// The allergen list in the local language, under the "I am allergic to"
/// sentence. Custom allergens have no translation and are shown as typed,
/// labeled so nobody reads them as translated text.
class _AllergenCard extends StatelessWidget {
  const _AllergenCard({required this.profile, required this.language});

  final Profile profile;
  final CardLanguage language;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final EmergencyPhrase lead = kEmergencyPhrases.firstWhere(
      (EmergencyPhrase p) => p.id == 'allergic_to',
    );
    final Map<Allergen, String> names =
        kAllergenTranslations[language.code] ?? kAllergenTranslations['en']!;
    final List<String> lines = <String>[
      for (final Allergen a in profile.sorted) names[a] ?? a.label,
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              lead.inLanguage(language.code),
              textDirection:
                  language.rtl ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            for (final String line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $line',
                  textDirection:
                      language.rtl ? TextDirection.rtl : TextDirection.ltr,
                  style: const TextStyle(fontSize: 16, height: 1.35),
                ),
              ),
            if (profile.customAllergens.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Also, as you typed them: '
                '${profile.customAllergens.map((c) => c.name).join(', ')}',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One sentence, filling the screen, for handing the phone across a counter.
void _showFullScreen(
  BuildContext context,
  String text,
  String english,
  CardLanguage language,
) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext routeContext) {
        final ColorScheme scheme = Theme.of(routeContext).colorScheme;
        return Scaffold(
          backgroundColor: scheme.surface,
          body: SafeArea(
            child: GestureDetector(
              onTap: () => Navigator.of(routeContext).pop(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      text,
                      textDirection: language.rtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (language.code != 'en') ...<Widget>[
                      const SizedBox(height: 20),
                      Text(
                        english,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      'Tap anywhere to close',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// The whole sheet as plain text, for sharing into a notes app or printing —
/// a phone can be lost or flat at the worst possible moment.
String _phraseSheetText(Profile profile, String code) {
  final CardLanguage language = languageFor(code);
  final Map<Allergen, String> names =
      kAllergenTranslations[code] ?? kAllergenTranslations['en']!;
  final StringBuffer out = StringBuffer();

  for (final EmergencyPhrase p in kEmergencyPhrases) {
    if (p.id == 'allergic_to') continue;
    out.writeln(p.inLanguage(code));
    if (language.code != 'en') out.writeln('(${p.english})');
    out.writeln();
  }

  if (!profile.isEmpty) {
    final EmergencyPhrase lead = kEmergencyPhrases.firstWhere(
      (EmergencyPhrase p) => p.id == 'allergic_to',
    );
    out.writeln(lead.inLanguage(code));
    for (final Allergen a in profile.sorted) {
      out.writeln('- ${names[a] ?? a.label}');
    }
    for (final custom in profile.customAllergens) {
      out.writeln('- ${custom.name}');
    }
  }

  return out.toString().trimRight();
}
