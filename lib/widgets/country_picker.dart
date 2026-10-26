import 'package:flutter/material.dart';

import '../data/countries.dart';

/// A searchable sheet over [kCountries]. Returns the picked ISO code, an empty
/// string for "Somewhere else", or null when dismissed.
///
/// "Somewhere else" is a real answer, not a cancel: the trip still saves, and
/// the emergency screen falls back to 112 and says that it is a fallback.
Future<String?> showCountryPicker(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _CountrySheet(selected: selected),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({this.selected});

  final String? selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String q = _query.trim().toLowerCase();
    final List<Country> matches = q.isEmpty
        ? kCountries
        : kCountries
            .where((Country c) =>
                c.name.toLowerCase().contains(q) ||
                c.code.toLowerCase() == q)
            .toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (String v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search countries',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final Country c in matches)
                    ListTile(
                      leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                      title: Text(c.name),
                      trailing: c.code == widget.selected
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(context).pop(c.code),
                    ),
                  ListTile(
                    leading: const Icon(Icons.public_rounded),
                    title: const Text('Somewhere else'),
                    subtitle: const Text(
                      'Not in the list. The emergency screen will offer 112, '
                      'which works on mobile networks in many countries.',
                    ),
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
