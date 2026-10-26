import 'package:flutter/material.dart';

import '../data/chef_card_translations.dart';

/// The horizontal strip of language chips used by every translated surface.
///
/// One picker, one order, one look: the chef card, the emergency phrases and a
/// scan result all choose a language the same way, so muscle memory learned in
/// a calm moment still works during a reaction.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kCardLanguages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final CardLanguage l = kCardLanguages[i];
          return ChoiceChip(
            selected: l.code == selected,
            onSelected: (_) => onSelect(l.code),
            avatar: Text(l.flag, style: const TextStyle(fontSize: 18)),
            label: Text(
              l.native,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }
}

/// The language matching [code], falling back to English so a stale stored
/// code can never leave a screen with nothing to render.
CardLanguage languageFor(String code) {
  for (final CardLanguage l in kCardLanguages) {
    if (l.code == code) return l;
  }
  return kCardLanguages.first;
}

/// True when [code] is a right-to-left script, for callers that only need the
/// direction and not the whole language.
bool languageIsRtl(String code) => languageFor(code).rtl;

/// A full list of languages as a sheet, for settings-style rows where a
/// horizontal strip would hide most of the choices.
Future<String?> showLanguageSheet(
  BuildContext context, {
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Where are you going?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Sets the language of your chef card and emergency phrases.',
                style: TextStyle(fontSize: 14.5, height: 1.35),
              ),
            ),
            for (final CardLanguage l in kCardLanguages)
              ListTile(
                leading: Text(l.flag, style: const TextStyle(fontSize: 22)),
                title: Text(l.native),
                subtitle: l.native == l.english ? null : Text(l.english),
                trailing: l.code == selected
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(l.code),
              ),
          ],
        ),
      );
    },
  );
}
