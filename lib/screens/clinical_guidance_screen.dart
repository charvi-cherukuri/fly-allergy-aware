import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// Step-by-step anaphylaxis guidance for whoever ends up holding the phone —
/// FRD 5.3.
///
/// The reader is very likely not the patient and quite possibly a stranger: a
/// seatmate, a cabin crew member, a doctor who volunteered when the call went
/// out. They are reading at 35,000 feet with no signal and no time. So:
/// everything is offline, the type is large, the contrast is high, the steps
/// are numbered, and step one is on screen before anyone scrolls. No
/// accordions, no tabs, nothing to discover.
class ClinicalGuidanceScreen extends StatelessWidget {
  const ClinicalGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plan = app.actionPlan.trim();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anaphylaxis'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
        children: <Widget>[
          if (plan.isNotEmpty) _ActionPlanBanner(plan: plan),
          const _Step(
            number: 1,
            title: 'Give epinephrine now',
            emphasis: true,
            body:
                'Intramuscular, mid-anterolateral thigh — the outer mid-thigh. '
                'Through clothing if necessary. Do not wait.',
            bullets: <String>[
              'Adult auto-injector: 0.3 mg.',
              'Pediatric auto-injector: 0.15 mg, roughly 15–30 kg.',
              'From an ampoule: 0.01 mg/kg of 1 mg/mL (1:1000). Maximum '
                  '0.5 mg adult, 0.3 mg child.',
              'US airlines must carry 1:1000 epinephrine in the emergency '
                  'medical kit. Elsewhere it varies by carrier — ask the crew.',
            ],
          ),
          const _Step(
            number: 2,
            title: 'Call for help',
            body:
                'Alert cabin crew now. They reach ground-based medical advice '
                'and start a diversion decision.',
          ),
          const _Step(
            number: 3,
            title: 'Position',
            body:
                'Lie them flat, legs raised. Sitting up is acceptable if '
                'breathing is hard. Vomiting or unresponsive: recovery '
                'position, on their side, to protect the airway.',
            warning:
                'Do not stand them up or walk them. Sudden upright posture '
                'during anaphylaxis is associated with cardiovascular '
                'collapse.',
          ),
          const _Step(
            number: 4,
            title: 'Second dose',
            body:
                'No improvement after 5 to 15 minutes: give a second dose. '
                'Locate a second device or ampoule dose while you wait.',
          ),
          const _Step(
            number: 5,
            title: 'Only after epinephrine',
            demoted: true,
            body:
                'Antihistamines such as diphenhydramine may relieve itching '
                'and hives. An inhaled bronchodilator may help wheeze.',
            warning:
                'Neither treats anaphylaxis or stops it progressing. Never let '
                'them delay or replace epinephrine — delay while reaching for '
                'an antihistamine contributes to fatal outcomes.',
          ),
          const _Step(
            number: 6,
            title: 'After',
            body:
                'Emergency medical evaluation is required even if symptoms '
                'resolve completely. Biphasic reactions can recur hours later.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Reference copy of standard published anaphylaxis first-aid '
              'guidance. Not a dose calculator, and not personalised medical '
              'advice. Follow the patient\'s own action plan or medical '
              'direction where it differs.',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The patient's own plan, which outranks everything below it
// ---------------------------------------------------------------------------

class _ActionPlanBanner extends StatefulWidget {
  const _ActionPlanBanner({required this.plan});

  final String plan;

  @override
  State<_ActionPlanBanner> createState() => _ActionPlanBannerState();
}

class _ActionPlanBannerState extends State<_ActionPlanBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.assignment_outlined,
                size: 20,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This person\'s own action plan — follow it first',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.plan,
            maxLines: _expanded ? null : 5,
            overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: scheme.onPrimaryContainer,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Show less' : 'Show all'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Steps
// ---------------------------------------------------------------------------

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.bullets = const <String>[],
    this.warning,
    this.emphasis = false,
    this.demoted = false,
  });

  final int number;
  final String title;
  final String body;
  final List<String> bullets;
  final String? warning;

  /// Step one carries the treatment. It is allowed to shout.
  final bool emphasis;

  /// Step five is adjunctive. It is deliberately rendered as the quieter,
  /// visually separate block so that nobody skimming mistakes it for treatment.
  final bool demoted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;

    final Color numberBg = emphasis
        ? danger
        : demoted
        ? scheme.surfaceContainerHighest
        : scheme.secondaryContainer;
    final Color numberFg = emphasis
        ? Colors.white
        : demoted
        ? scheme.onSurfaceVariant
        : scheme.onSecondaryContainer;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: demoted
            ? Colors.transparent
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasis
              ? danger
              : demoted
              ? scheme.outline
              : Colors.transparent,
          width: emphasis ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: numberBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: numberFg,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: emphasis ? 26 : 22,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: emphasis
                        ? danger
                        : demoted
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontSize: emphasis ? 19 : 17,
              height: 1.45,
              fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
              color: demoted ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
          if (bullets.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: scheme.onSurface,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.4,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (warning != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: danger.withValues(alpha: 0.55)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, size: 22, color: danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      warning!,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
