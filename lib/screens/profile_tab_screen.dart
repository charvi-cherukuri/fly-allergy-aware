import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/language_picker.dart';
import 'action_plans_screen.dart';
import 'chef_card_screen.dart';
import 'custom_allergens_screen.dart';
import 'emergency_phrases_screen.dart';
import 'language_packs_screen.dart';
import 'history_screen.dart';
import 'profile_history_screen.dart';
import 'profile_screen.dart';
import 'translate_screen.dart';
import 'settings_screen.dart';

/// The Profile tab: who is flying, and everything that belongs to them.
///
/// Four tabs is the practical ceiling on a phone, and the three that earned one
/// are what you reach for under time pressure: your travel, the scanner, the
/// emergency screen. This tab is the fourth because the profile is what every
/// other screen reads from — a wrong allergen list here makes every verdict in
/// the app wrong — so it deserves a fixed place rather than hiding behind
/// "More".
class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.activeProfile;
    final language = languageFor(app.travelLanguage);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SizedBox(height: 8),
          _ProfileHeader(
            name: profile.name,
            summary: profile.summary,
            onTap: () => _push(context, const ProfileScreen()),
          ),

          const SectionTitle('Who is flying'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.people_rounded),
                  title: const Text('Profiles'),
                  subtitle: Text(
                    app.profiles.length == 1
                        ? 'Allergens, strictness, notes'
                        : '${app.profiles.length} people on this device',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const ProfileScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Custom allergens'),
                  subtitle: Text(
                    profile.customAllergens.isEmpty
                        ? 'Alpha-gal, corn, seeds — anything outside the fourteen'
                        : profile.customAllergens.map((c) => c.name).join(', '),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const CustomAllergensScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.history_edu_outlined),
                  title: const Text('Profile history'),
                  subtitle: Text(
                    app.revisions.isEmpty
                        ? 'Every edit is kept, so nothing is lost'
                        : '${app.revisions.length} earlier '
                            '${app.revisions.length == 1 ? "version" : "versions"}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const ProfileHistoryScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.medical_information_outlined),
                  title: const Text('Anaphylaxis action plans'),
                  subtitle: Text(_planSubtitle(app)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const ActionPlansScreen()),
                ),
              ],
            ),
          ),

          // One language setting drives the chef card, the emergency phrases
          // and the allergen names on a scan result. Set once per trip.
          const SectionTitle('Language'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Text(
                    language.flag,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: const Text('Where you are going'),
                  subtitle: Text(
                    language.code == 'en'
                        ? 'English — set this before you land'
                        : '${language.native} · ${language.english}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickLanguage(context, app),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: const Text('Chef card'),
                  subtitle: const Text('12 languages, offline'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const ChefCardScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: const Text('Emergency phrases'),
                  subtitle: const Text('What to say if a reaction starts'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const EmergencyPhrasesScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.g_translate_rounded),
                  title: const Text('Translate'),
                  subtitle: const Text('A menu, a label, or what someone said'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const TranslateScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: const Text('Language packs'),
                  subtitle: const Text(
                    'Download before you fly — then it works offline',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const LanguagePacksScreen()),
                ),
              ],
            ),
          ),

          const SectionTitle('Food'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Scan history and saved items'),
              subtitle: const Text('Works with no connection'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _push(context, const HistoryScreen()),
            ),
          ),

          const SectionTitle('App'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings and about'),
              subtitle: Text(
                app.lockIsEnabled ? 'Lock, theme, data' : 'Theme, data, app lock',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _push(context, const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  static String _planSubtitle(AppState app) {
    final plans = app.actionPlans;
    if (plans.isEmpty) return 'One per airline, from your doctor';
    final expiring = app.expiringActionPlans.length;
    final n = '${plans.length} ${plans.length == 1 ? "plan" : "plans"}';
    return expiring == 0 ? n : '$n · $expiring expiring';
  }

  Future<void> _pickLanguage(BuildContext context, AppState app) async {
    final code = await showLanguageSheet(context, selected: app.travelLanguage);
    if (code == null) return;
    await app.setTravelLanguage(code);
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

/// The active profile, at the top, because every verdict in the app is computed
/// from it and a wrong list here is a wrong answer everywhere else.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.summary,
    required this.onTap,
  });

  final String name;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
