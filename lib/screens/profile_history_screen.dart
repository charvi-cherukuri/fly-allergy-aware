import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/models/profile_revision.dart';
import 'package:trace_allergy/screens/history_screen.dart' show relativeTime;
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// The audit trail for the active profile — FRD 1.2.
///
/// A revision holds the profile as it stood *before* the edit that created it,
/// so the change a revision records is the step from its own snapshot to the
/// snapshot of the revision above it — and, for the newest revision, to the
/// live profile. Pairing rows with their own snapshot instead of the next one
/// would show every change one entry too early.
class ProfileHistoryScreen extends StatefulWidget {
  const ProfileHistoryScreen({super.key});

  @override
  State<ProfileHistoryScreen> createState() => _ProfileHistoryScreenState();
}

class _ProfileHistoryScreenState extends State<ProfileHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<AppState>().refreshRevisions();
    });
  }

  Future<void> _confirmRestore(ProfileRevision revision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Restore version ${revision.revision}'),
        content: const Text(
          'Your current profile is kept as a new entry first. '
          'Nothing is erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    await context.read<AppState>().restoreRevision(revision);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restored version ${revision.revision}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final current = app.activeProfile;

    // Newest first. The database already orders by revision descending, but
    // the pairing below is only correct on that ordering, so it is enforced
    // here rather than assumed. Revisions carried over from another profile
    // are dropped: diffing them against this profile would invent changes.
    final entries = app.revisions
        .where((r) => r.profileId == current.id)
        .toList()
      ..sort((a, b) => b.revision.compareTo(a.revision));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile history')),
      body: entries.isEmpty
          ? _EmptyHistory(onBack: () => Navigator.of(context).maybePop())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: entries.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return const _Preamble();
                final i = index - 1;
                final revision = entries[i];
                // The version that followed this one: the next revision up,
                // or the live profile when this is the newest entry.
                final Profile newer =
                    i == 0 ? current : entries[i - 1].snapshot;
                return _RevisionCard(
                  revision: revision,
                  diff: ProfileDiff.between(revision.snapshot, newer),
                  onRestore: () => _confirmRestore(revision),
                );
              },
            ),
    );
  }
}

class _Preamble extends StatelessWidget {
  const _Preamble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Every edit is kept. Nothing is overwritten.',
              style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    required this.revision,
    required this.diff,
    required this.onRestore,
  });

  final ProfileRevision revision;
  final ProfileDiff diff;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final added = dark ? TraceColors.clearDark : TraceColors.clear;
    final changed = dark ? TraceColors.cautionDark : TraceColors.caution;
    final removed = scheme.onSurfaceVariant;
    final when = revision.changedAt.toLocal();
    final summary = revision.changeSummary.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${revision.revision}',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${relativeTime(revision.changedAt)} · '
              '${MaterialLocalizations.of(context).formatShortDate(when)}',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  color: scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (diff.isEmpty)
              Text(
                'No allergen changes recorded.',
                style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
              )
            else ...[
              for (final label in diff.added)
                _DiffRow(
                  marker: '+',
                  color: added,
                  text: label,
                  semanticLabel: 'Added $label',
                ),
              for (final label in diff.removed)
                _DiffRow(
                  marker: '−',
                  color: removed,
                  text: label,
                  semanticLabel: 'Removed $label',
                ),
              for (final change in diff.severityChanged)
                _DiffRow(
                  marker: '±',
                  color: changed,
                  text: '${change.label}: ${change.from} → ${change.to}',
                  semanticLabel: '${change.label} severity changed from '
                      '${change.from} to ${change.to}',
                ),
              if (diff.notesChanged)
                _DiffRow(
                  marker: '·',
                  color: removed,
                  text: 'Notes edited',
                  semanticLabel: 'Notes edited',
                ),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onRestore,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Restore this version'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of a diff. The marker glyph carries the meaning alongside the
/// colour, and the spoken label replaces both for screen readers.
class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.marker,
    required this.color,
    required this.text,
    required this.semanticLabel,
  });

  final String marker;
  final Color color;
  final String text;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              child: Text(
                marker,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 14, height: 1.3, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 52,
                color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'No edits yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'History starts at the first change to this profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 22),
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}
