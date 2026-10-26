import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/models/action_plan.dart';
import 'package:trace_allergy/screens/action_plan_detail_screen.dart';
import 'package:trace_allergy/screens/action_plan_edit_screen.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// FRD 1.3 — the list of airline-specific anaphylaxis action plans.
///
/// A user holds several because carriers differ in what they will do: one
/// airline buffers a row, another will not make an announcement, a third
/// carries a different emergency kit. The plan itself is the physician's,
/// never the app's — the app stores it and hands it to whoever needs it.
class ActionPlansScreen extends StatelessWidget {
  const ActionPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plans = app.actionPlans;

    return Scaffold(
      appBar: AppBar(title: const Text('Action plans')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
      ),
      body: plans.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
              children: <Widget>[_EmptyState(onCreate: () => _create(context))],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: plans.length,
              separatorBuilder: (BuildContext _, int __) =>
                  const SizedBox(height: 12),
              itemBuilder: (BuildContext _, int i) => _PlanCard(plan: plans[i]),
            ),
    );
  }

  static Future<void> _create(BuildContext context) async {
    final plan = context.read<AppState>().newActionPlan();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => ActionPlanEditScreen(plan: plan),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One plan
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final ActionPlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = plan.title.trim().isEmpty ? 'Untitled plan' : plan.title.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.airlineLabel,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _Menu(plan: plan),
                ],
              ),
              if (plan.isDefault || plan.isExpired || plan.isExpiringSoon)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (plan.isDefault)
                        _Badge(
                          label: 'Default',
                          icon: Icons.star_rounded,
                          color: scheme.onSecondaryContainer,
                          background: scheme.secondaryContainer,
                        ),
                      if (plan.isExpired)
                        _Badge(
                          label: 'Injector expired',
                          icon: Icons.error_outline,
                          color: Colors.white,
                          background: dark
                              ? TraceColors.unsafeDark
                              : TraceColors.unsafe,
                        )
                      else if (plan.isExpiringSoon)
                        _Badge(
                          label: _expiryLabel(plan),
                          icon: Icons.access_time,
                          color: Colors.white,
                          background: dark
                              ? TraceColors.cautionDark
                              : TraceColors.caution,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => ActionPlanDetailScreen(plan: plan),
      ),
    );
  }
}

/// Per-card overflow. A `PopupMenuButton` is already a 48x48 target.
class _Menu extends StatelessWidget {
  const _Menu({required this.plan});

  final ActionPlan plan;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Plan options',
      onSelected: (String value) => _run(context, value),
      itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
        if (!plan.isDefault)
          const PopupMenuItem<String>(
            value: 'default',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.star_outline),
              title: Text('Set as default'),
            ),
          ),
        const PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
          ),
        ),
      ],
    );
  }

  Future<void> _run(BuildContext context, String value) async {
    final app = context.read<AppState>();
    switch (value) {
      case 'default':
        await app.setDefaultActionPlan(plan.id);
      case 'edit':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => ActionPlanEditScreen(plan: plan),
          ),
        );
      case 'delete':
        final ok = await _confirmDelete(context, plan);
        if (!ok) return;
        await app.deleteActionPlan(plan.id);
    }
  }
}

Future<bool> _confirmDelete(BuildContext context, ActionPlan plan) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;
  final title = plan.title.trim().isEmpty ? 'this plan' : plan.title.trim();
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Delete plan'),
      content: Text('Deletes $title. This cannot be undone.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

String _expiryLabel(ActionPlan plan) {
  final on = plan.epinephrine.expiresOn;
  if (on == null) return 'Expiring';
  final now = DateTime.now();
  final days = on.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days <= 0) return 'Expires today';
  if (days == 1) return 'Expires tomorrow';
  return 'Expires in $days days';
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.assignment_outlined,
              size: 34,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text(
              'No action plans',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Your doctor’s plan, held one per airline. Carriers differ in '
              'what they will do.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onCreate,
              child: const Text('Create a plan'),
            ),
          ],
        ),
      ),
    );
  }
}
