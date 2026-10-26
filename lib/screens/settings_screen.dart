import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/safety_copy.dart';

import 'package:trace_allergy/models/verdict.dart';
import 'package:trace_allergy/services/app_lock.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

const String _kAppVersion = '1.0.0';
const String _kOpenFoodFactsUrl = 'https://world.openfoodfacts.org';
const String _kFdcUrl = 'https://fdc.nal.usda.gov';

/// Settings, attribution and the explanation of how a verdict is reached.
///
/// This is also where the cross-screen disclaimers live — read the label,
/// confirm with the airline, no database is authoritative — said once here so
/// no other screen has to repeat them.
///
/// The data credits are a license obligation. Open Food Facts is ODbL and the
/// attribution has to be visible in the app, not buried in a store listing.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not open $url'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearHistory(BuildContext context) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear scan history?'),
        content: const Text(
          'Past scans are removed from this device. Saved items and profiles '
          'are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await appState.clearHistory();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Scan history cleared.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const SectionTitle('App lock'),
          const _LockCard(),

          const SectionTitle('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {appState.themeMode},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (set) =>
                      context.read<AppState>().setThemeMode(set.first),
                ),
              ),
            ),
          ),
          const SectionTitle('How the check works'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Every scan lands on one of four answers.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _VerdictLine(
                    level: VerdictLevel.unsafe,
                    body: 'An allergen on your list is declared in the '
                        'product data.',
                  ),
                  const _VerdictLine(
                    level: VerdictLevel.caution,
                    body: 'A "may contain" or shared-equipment warning. '
                        'Blocks the product at Severe; otherwise yours to '
                        'weigh.',
                  ),
                  const _VerdictLine(
                    level: VerdictLevel.unknown,
                    body: 'The record has no ingredient text, or the data is '
                        'incomplete.',
                  ),
                  const _VerdictLine(
                    level: VerdictLevel.clear,
                    body: 'Nothing on your list appeared in the data held for '
                        'this product.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Two matchers, run independently',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'One reads the database’s allergen tags, the other scans '
                    'the raw ingredient text, so whey with no milk tag is '
                    'still caught. Either is enough to raise a result.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Clear means no match was found in the data available. It '
                    'does not mean the food is safe.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Limits'),
          const Card(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Limit(
                    'The app lock keeps the app shut, not the file it keeps.',
                  ),
                  _Limit('Read the label yourself. Every time.'),
                  _Limit('Confirm catering and policy with the airline.'),
                  _Limit(
                    'No database is authoritative. Recipes change and '
                    'packaging is regional.',
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Scan history'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Clear scan history'),
              subtitle: const Text('Saved items are kept.'),
              onTap: () => _clearHistory(context),
            ),
          ),
          const SectionTitle('About the data'),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Product data comes from two public sources, credited as '
                    'their licenses require.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.public_rounded),
                  title: const Text('Open Food Facts'),
                  subtitle: const Text(
                    'Open Database License (ODbL). world.openfoodfacts.org',
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openUrl(context, _kOpenFoodFactsUrl),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                ListTile(
                  leading: const Icon(Icons.account_balance_rounded),
                  title: const Text('USDA FoodData Central'),
                  subtitle: const Text(
                    'Public domain. fdc.nal.usda.gov',
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openUrl(context, _kFdcUrl),
                ),
              ],
            ),
          ),
          const SectionTitle('About'),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('Fly Allergy Aware'),
                  subtitle: Text(
                    'Version $_kAppVersion\nBuilt by student developers to raise '
                    'food allergy awareness.',
                  ),
                  isThreeLine: true,
                ),
                Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.health_and_safety_outlined),
                  title: Text('A note on safety'),
                  subtitle: Text(kMedicalNoteLong),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Free, no account, no ads. Your profiles and scans stay on this '
            'device.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// The app lock control.
///
/// One switch. The lock is the iPhone's own — Face ID with the system passcode
/// sheet behind it — so there is nothing here to set, change or forget, and no
/// second secret for the user to keep.
///
/// Kept honest: the lock stops the next person who picks up the phone from
/// reading a medical profile. It is not encryption, and the copy never implies
/// that it is.
class _LockCard extends StatefulWidget {
  const _LockCard();

  @override
  State<_LockCard> createState() => _LockCardState();
}

class _LockCardState extends State<_LockCard> {
  bool _available = true;
  bool _busy = false;
  // Neutral until the device says which it is: a Touch ID or passcode-only
  // iPhone must not be told to use Face ID, even for one frame.
  String _method = 'Face ID or your passcode';

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    final app = context.read<AppState>();
    final available = await app.lockAvailable();
    final method = await app.lockMethodLabel();
    if (!mounted) return;
    setState(() {
      _available = available;
      _method = method;
    });
  }

  Future<void> _toggle(bool on) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final outcome = on ? await app.enableLock() : await app.disableLock();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case LockOutcome.unlocked:
        messenger.showSnackBar(
          SnackBar(content: Text(on ? 'Lock turned on' : 'Lock turned off')),
        );
      case LockOutcome.failed:
        messenger.showSnackBar(
          const SnackBar(content: Text('Not confirmed, so nothing changed.')),
        );
      case LockOutcome.unavailable:
        await _loadDevice();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('This iPhone has no passcode set, so there is '
                'nothing to lock the app with.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        children: <Widget>[
          SwitchListTile(
            secondary: Icon(
              app.lockIsEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
            ),
            title: Text('Require $_method to open'),
            subtitle: Text(
              _available
                  ? 'Asked for when the app opens and whenever you come back '
                      'to it.'
                  : 'Set a passcode on this iPhone first, in Settings › Face ID '
                      '& Passcode.',
            ),
            value: app.lockIsEnabled,
            onChanged: _available && !_busy ? _toggle : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'Uses the iPhone’s own unlock — this app never sees your '
              'passcode. It keeps the app shut, not the file it keeps. For 30 '
              'minutes after an emergency call or text it will not ask again, '
              'unless iOS closes the app in that time.\n\n'
              'With the lock on, someone helping you cannot open the app. Add '
              'your allergies to Medical ID in the Health app too — it can be '
              'read from the iPhone lock screen.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the consolidated limits block. The cross-screen disclaimers live
/// here and nowhere else, so each screen can carry at most a short local line.
class _Limit extends StatelessWidget {
  const _Limit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictLine extends StatelessWidget {
  const _VerdictLine({required this.level, required this.body});

  final VerdictLevel level;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = TraceColors.forLevel(level, theme.brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(TraceColors.iconForLevel(level), size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TraceColors.titleForLevel(level),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
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
