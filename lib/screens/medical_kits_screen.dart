import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/safety_copy.dart';
import '../theme.dart';

/// What a plane's medical kit is likely to hold, and which airlines are
/// reported to carry epinephrine auto-injectors — with a source for each.
class MedicalKitsScreen extends StatelessWidget {
  const MedicalKitsScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final bool ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger?.showSnackBar(const SnackBar(content: Text('Could not open the source.')));
      }
    } catch (_) {
      messenger?.showSnackBar(const SnackBar(content: Text('Could not open the source.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Medical kits on planes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          for (final String fact in kMedicalKitFacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(Icons.circle, size: 8, color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(fact, style: const TextStyle(fontSize: 16, height: 1.45)),
                  ),
                ],
              ),
            ),
          const SectionTitle('Airlines that carry auto-injectors'),
          Text(
            'Reported by news sources and checked in $kAirlineEpinephrineChecked. '
            'Kits can differ from plane to plane, so ask the crew. Other '
            'airlines may carry only a vial and syringe.',
            style: TextStyle(fontSize: 14.5, height: 1.4, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final AirlineEpinephrine a in kAirlineEpinephrine)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(a.airline, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      a.status.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: a.status == EpiStatus.carries ? scheme.primary : scheme.tertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(a.detail, style: const TextStyle(fontSize: 15, height: 1.4)),
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => _open(context, a.url),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text('Source: ${a.source}'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            kMedicalNoteShort,
            style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
