import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/countries.dart';
import '../data/safety_copy.dart';
import '../data/translator_languages.dart';
import '../models/trip.dart';
import '../services/app_state.dart';
import '../services/translator.dart';

/// "Please don't give my child food" — a message a parent can show to other
/// passengers, relatives or airline staff.
///
/// Full-screen, black on white, readable at arm's length. Long and short
/// versions, both editable. When a trip abroad has the language pack, a
/// machine translation is shown underneath and labelled as one.
class ChildCardScreen extends StatefulWidget {
  const ChildCardScreen({super.key});

  @override
  State<ChildCardScreen> createState() => _ChildCardScreenState();
}

class _ChildCardScreenState extends State<ChildCardScreen> {
  bool _short = false;
  String? _translation;
  String? _translatedKey;

  /// The language to translate into: the current trip's destination, when it
  /// is not the phone's own language.
  String? _language(AppState app) {
    final Trip? trip = app.activeTrip();
    final List<String> langs =
        countryFor(trip?.destinationCountry ?? '')?.languages ?? const <String>[];
    for (final String l in langs) {
      if (l != app.deviceLanguage && l != 'en') return l;
    }
    return null;
  }

  Future<void> _translate(String text, String to) async {
    final TranslatorService t = context.read<AppState>().translator;
    final TranslationResult r = await t.translate(text: text, from: 'en', to: to);
    if (!mounted) return;
    setState(() => _translation = r.ok ? r.text : null);
  }

  Future<void> _edit(AppState app) async {
    final TextEditingController full = TextEditingController(text: app.childCardText);
    final TextEditingController short = TextEditingController(text: app.childCardShort);
    final bool? save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Edit the message', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: full,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Full message'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: short,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Short version'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  full.text = kChildCardDefault;
                  short.text = kChildCardShortDefault;
                },
                child: const Text('Use the original wording'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save == true) {
      await app.setChildCard(full: full.text, short: short.text);
    }
    full.dispose();
    short.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final String text = _short ? app.childCardShort : app.childCardText;
    final String? lang = _language(app);
    final TranslatorLanguage? langInfo = lang == null ? null : translatorLanguageFor(lang);

    if (lang != null && _translatedKey != '$lang|$text') {
      _translatedKey = '$lang|$text';
      _translation = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _translate(text, lang);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Please don’t feed my child'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _edit(app),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: <Widget>[
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: false, label: Text('Full')),
              ButtonSegment<bool>(value: true, label: Text('Short')),
            ],
            selected: <bool>{_short},
            onSelectionChanged: (Set<bool> v) => setState(() => _short = v.first),
          ),
          const SizedBox(height: 24),
          Text(
            text,
            style: TextStyle(
              color: Colors.black,
              fontSize: _short ? 34 : 25,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_translation != null) ...<Widget>[
            const SizedBox(height: 24),
            const Divider(color: Colors.black26),
            const SizedBox(height: 10),
            Text(
              'MACHINE TRANSLATION · ${langInfo?.native ?? lang}',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _translation!,
              textDirection: (langInfo?.rtl ?? false) ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(color: Colors.black, fontSize: _short ? 28 : 22, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
