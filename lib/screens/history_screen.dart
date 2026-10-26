import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/models/scan_record.dart';
import 'package:trace_allergy/models/verdict.dart';
import 'package:trace_allergy/screens/result_screen.dart';
import 'package:trace_allergy/screens/scanner_screen.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// Everything scanned, and everything pinned.
///
/// Both lists are local. A product scanned once resolves forever after with no
/// signal, which is the whole point of the cache — on a plane, in a basement
/// supermarket, abroad.
///
/// Tapping a row does not replay the stored verdict. It re-runs the match
/// against whoever is active now, because the verdict on the row was computed
/// for whoever was active at the time, and in a household that is often a
/// different person with a different list.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  List<ScanRecord> _filter(List<ScanRecord> records) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return records;
    return records.where((r) {
      final name = r.product.displayName.toLowerCase();
      final brand = (r.product.brand ?? '').toLowerCase();
      return name.contains(q) || brand.contains(q);
    }).toList();
  }

  void _open(ScanRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          product: record.product,
          status: ScanStatus.foundCached,
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear history'),
        content: const Text(
          'This removes every past scan from this device. Saved items are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<AppState>().clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history;
    final saved = state.savedItems;
    final activeId = state.activeProfile.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Recent'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by product or brand',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _RecordList(
                  records: _filter(history),
                  activeProfileId: activeId,
                  onOpen: _open,
                  caption: null,
                  empty: history.isEmpty
                      ? _EmptyState(
                          icon: Icons.history_rounded,
                          title: 'No scans yet',
                          message:
                              'Every product you check is kept here and works '
                              'again with no connection.',
                          actionLabel: 'Scan a product',
                          onAction: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ScannerScreen(),
                            ),
                          ),
                        )
                      : _NoMatchesState(
                          query: _query,
                          onClear: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                _RecordList(
                  records: _filter(saved),
                  activeProfileId: activeId,
                  onOpen: _open,
                  caption:
                      'Saved items live on this device and work with no '
                      'connection.',
                  empty: saved.isEmpty
                      ? _EmptyState(
                          icon: Icons.star_border_rounded,
                          title: 'Nothing saved',
                          message:
                              'Star a scan to keep it here — the products you '
                              'buy again, ready offline.',
                          actionLabel: 'Browse recent scans',
                          onAction: () => _tabs.animateTo(0),
                        )
                      : _NoMatchesState(
                          query: _query,
                          onClear: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
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

class _RecordList extends StatelessWidget {
  const _RecordList({
    required this.records,
    required this.activeProfileId,
    required this.onOpen,
    required this.empty,
    required this.caption,
  });

  final List<ScanRecord> records;
  final String activeProfileId;
  final ValueChanged<ScanRecord> onOpen;
  final Widget empty;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return empty;
    final scheme = Theme.of(context).colorScheme;
    final head = caption;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: records.length + (head == null ? 0 : 1),
      separatorBuilder: (_, index) => head != null && index == 0
          ? const SizedBox.shrink()
          : const Divider(indent: 84, height: 1),
      itemBuilder: (context, index) {
        if (head != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    head,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final record = records[index - (head == null ? 0 : 1)];
        return _ScanTile(
          record: record,
          forAnotherProfile: record.profileId != activeProfileId,
          onTap: () => onOpen(record),
        );
      },
    );
  }
}

class _ScanTile extends StatelessWidget {
  const _ScanTile({
    required this.record,
    required this.forAnotherProfile,
    required this.onTap,
  });

  final ScanRecord record;
  final bool forAnotherProfile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final product = record.product;
    final brand = product.brand?.trim() ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(url: product.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        relativeTime(record.scannedAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (brand.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _VerdictPill(level: record.level),
                  const SizedBox(height: 6),
                  Text(
                    record.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      color: scheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  if (forAnotherProfile) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Checked under another profile — open to re-check.',
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: record.saved ? 'Remove from saved' : 'Save',
              onPressed: () =>
                  context.read<AppState>().toggleSaved(product.barcode),
              icon: Icon(
                record.saved ? Icons.star_rounded : Icons.star_border_rounded,
                color: record.saved ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 24,
        color: scheme.onSurfaceVariant,
      ),
    );
    final source = url?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: source.isEmpty
            ? fallback
            : Image.network(
                source,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}

class _VerdictPill extends StatelessWidget {
  const _VerdictPill({required this.level});

  final VerdictLevel level;

  @override
  Widget build(BuildContext context) {
    final color = TraceColors.forLevel(level, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TraceColors.iconForLevel(level), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            TraceColors.titleForLevel(level),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 22),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: scheme.outline),
            const SizedBox(height: 14),
            Text(
              'Nothing matches "${query.trim()}"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onClear, child: const Text('Clear search')),
          ],
        ),
      ),
    );
  }
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Just now" / "12m ago" / "2h ago" / "Yesterday" / "4d ago" / "3 Mar" /
/// "3 Mar 2025".
///
/// Written by hand because the app does not depend on `intl`; the day
/// boundaries are calendar days, not multiples of 24 hours, so a scan at 23:50
/// reads "Yesterday" at 00:10 rather than "0h ago".
String relativeTime(DateTime when, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = when.toLocal();
  final elapsed = current.difference(local);

  if (elapsed.isNegative) return 'Just now';
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';

  final today = DateTime(current.year, current.month, current.day);
  final thatDay = DateTime(local.year, local.month, local.day);
  final days = today.difference(thatDay).inDays;

  if (days == 0) return '${elapsed.inHours}h ago';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '${days}d ago';

  final month = _months[local.month - 1];
  if (local.year == current.year) return '${local.day} $month';
  return '${local.day} $month ${local.year}';
}
