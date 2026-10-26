import 'dart:convert';

import 'profile.dart';

/// One historical version of an allergen profile — FRD 1.2, "users must be able
/// to update their allergenic food profile over time as their medical
/// conditions change".
///
/// The requirement is easy to read as "let them edit it", which the app already
/// did. What it actually needs is an *auditable* trail: an allergy profile is a
/// medical record, and a destructive overwrite loses the fact that something
/// used to be listed as anaphylactic. Every save appends the previous state
/// here before writing the new one.
class ProfileRevision {
  const ProfileRevision({
    required this.id,
    required this.profileId,
    required this.revision,
    required this.snapshot,
    required this.changedAt,
    this.changeSummary = '',
  });

  final String id;
  final String profileId;

  /// Monotonic per profile, starting at 1.
  final int revision;

  /// The full profile as it stood *before* the edit this revision records.
  final Profile snapshot;

  final DateTime changedAt;

  /// Optional one-line note from the user, e.g. "allergist downgraded egg".
  final String changeSummary;

  Map<String, dynamic> toMap() => {
        'id': id,
        'profileId': profileId,
        'revision': revision,
        'snapshot': jsonEncode(snapshot.toMap()),
        'changedAt': changedAt.millisecondsSinceEpoch,
        'changeSummary': changeSummary,
      };

  factory ProfileRevision.fromMap(Map<String, dynamic> m) => ProfileRevision(
        id: m['id'] as String,
        profileId: (m['profileId'] as String?) ?? '',
        revision: (m['revision'] as int?) ?? 0,
        snapshot: Profile.fromMap(
          Map<String, dynamic>.from(
            jsonDecode((m['snapshot'] as String?) ?? '{}') as Map<dynamic, dynamic>,
          ),
        ),
        changedAt: DateTime.fromMillisecondsSinceEpoch(m['changedAt'] as int),
        changeSummary: (m['changeSummary'] as String?) ?? '',
      );
}

/// What changed between two consecutive revisions.
class ProfileDiff {
  const ProfileDiff({
    required this.added,
    required this.removed,
    required this.severityChanged,
    required this.notesChanged,
    this.cautionSettingChanged = false,
  });

  /// Display names of allergens present in the newer version only.
  final List<String> added;

  /// Display names present in the older version only.
  final List<String> removed;

  /// Allergens present in both, whose severity moved. Each entry is
  /// (label, from, to).
  final List<SeverityChange> severityChanged;

  final bool notesChanged;

  /// Whether the "be cautious when label data is incomplete" setting moved.
  ///
  /// Tracked because it is arguably the most safety-relevant switch in the
  /// profile: it decides whether cross-contact evidence blocks a product or
  /// merely warns. An edit that only flips it used to record no revision at
  /// all, which meant the trail silently missed it.
  final bool cautionSettingChanged;

  bool get isEmpty =>
      added.isEmpty &&
      removed.isEmpty &&
      severityChanged.isEmpty &&
      !notesChanged &&
      !cautionSettingChanged;

  /// Compares [older] against [newer]. Custom allergens participate by name,
  /// so a trigger the user defined themselves is tracked like any other.
  static ProfileDiff between(Profile older, Profile newer) {
    Map<String, String> flatten(Profile p) {
      final out = <String, String>{};
      for (final a in p.allergens.keys) {
        out[a.label] = p.allergens[a]!.label;
      }
      for (final c in p.customAllergens) {
        out[c.name] = c.severity.label;
      }
      return out;
    }

    final a = flatten(older);
    final b = flatten(newer);

    final added = b.keys.where((k) => !a.containsKey(k)).toList()..sort();
    final removed = a.keys.where((k) => !b.containsKey(k)).toList()..sort();
    final changed = <SeverityChange>[];
    for (final k in b.keys) {
      if (a.containsKey(k) && a[k] != b[k]) {
        changed.add(SeverityChange(k, a[k]!, b[k]!));
      }
    }
    changed.sort((x, y) => x.label.compareTo(y.label));

    return ProfileDiff(
      added: added,
      removed: removed,
      severityChanged: changed,
      notesChanged: older.notes.trim() != newer.notes.trim(),
      cautionSettingChanged:
          older.avoidPalWhenUnsure != newer.avoidPalWhenUnsure,
    );
  }
}

/// A single severity move between two revisions.
class SeverityChange {
  const SeverityChange(this.label, this.from, this.to);
  final String label;
  final String from;
  final String to;
}
