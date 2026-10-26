import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:trace_allergy/data/airline_policies.dart';
import 'package:trace_allergy/data/request_guides.dart';
import 'package:trace_allergy/models/flight.dart';
import 'package:trace_allergy/models/request_guide.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/theme.dart';

/// How to actually ask this carrier for an accommodation.
///
/// Knowing that an airline offers a buffer zone gets a passenger nowhere if
/// the request has to go through a phone line that takes it no earlier than 48
/// hours out, while the web form that looks official routes to sales. Every
/// carrier is different, none of them explain it in one place, and the result
/// is passengers arriving at the gate certain they asked, with no record and
/// no accommodation.
///
/// So the order here is deliberate: the channel that works, then the window to
/// use it in, then the steps, then the words. The carrier-agnostic teaching
/// content sits at the bottom, collapsed, because someone opening this screen
/// has a specific airline in mind.
///
/// Nothing on this screen is a live lookup. It is a shipped record with a
/// review date, and it says so.
class HowToRequestScreen extends StatelessWidget {
  const HowToRequestScreen({super.key, this.iata, this.flightId});

  /// The carrier to explain. When null, the active flight's carrier is used.
  final String? iata;

  /// Only used to show which trip this is about. The screen never writes.
  final String? flightId;

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    final String resolved =
        (iata ?? app.activeFlight?.airlineIata ?? '').trim().toUpperCase();
    final RequestGuide? specific =
        resolved.isEmpty ? null : guideFor(resolved);
    final RequestGuide guide = specific ?? kGenericRequestGuide;

    final AirlinePolicy? policy =
        resolved.isEmpty ? null : policyFor(resolved);
    final String carrierName = (policy?.name ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: const Text('How to request')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          _Header(
            carrierName: carrierName,
            iata: resolved,
            flight: _flightFor(app),
            isSpecific: specific != null,
          ),

          // 1 -----------------------------------------------------------------
          const SectionTitle('Which way works'),
          _MethodSection(guide: guide),

          // 2 -----------------------------------------------------------------
          const SectionTitle('When to ask'),
          _LeadTimeCard(leadTime: guide.leadTime),

          // 3 -----------------------------------------------------------------
          const SectionTitle('Do this'),
          _StepsSection(steps: guide.steps),

          // 4 -----------------------------------------------------------------
          const SectionTitle('What to say'),
          _ScriptSection(script: guide.script, profileSummary: _profileLine(app)),

          // 5 -----------------------------------------------------------------
          const SectionTitle('Contact'),
          _ContactSection(guide: guide, carrierName: carrierName, iata: resolved),

          // 6 -----------------------------------------------------------------
          const SectionTitle('Watch out for'),
          _GotchaSection(gotchas: guide.gotchas),

          // 7 -----------------------------------------------------------------
          const SectionTitle('How to ask anyone'),
          const _TutorialSection(),

          // 8 -----------------------------------------------------------------
          const SizedBox(height: 22),
          _FooterNote(lastReviewed: guide.lastReviewed),
        ],
      ),
      bottomNavigationBar: const _LogTheRequestBar(),
    );
  }

  /// The trip this advice is being read for, when one is identifiable. Shown
  /// for orientation only — nothing on this screen depends on it.
  Flight? _flightFor(AppState app) {
    final String? id = flightId;
    if (id != null) {
      for (final Flight f in app.flights) {
        if (f.id == id) return f;
      }
    }
    if (iata == null) return app.activeFlight;
    return null;
  }

  /// What the user's own profile says they avoid, so the script can be
  /// adapted rather than read out verbatim with the wrong allergen in it.
  String _profileLine(AppState app) {
    final profile = app.activeProfile;
    if (profile.isEmpty) return '';
    return profile.summary;
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.carrierName,
    required this.iata,
    required this.flight,
    required this.isSpecific,
  });

  final String carrierName;
  final String iata;
  final Flight? flight;
  final bool isSpecific;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Flight? f = flight;

    final String title = carrierName.isNotEmpty
        ? carrierName
        : (iata.isNotEmpty ? iata : 'Requesting an accommodation');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (carrierName.isNotEmpty && iata.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    iata,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (f != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.flight_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${f.label} · ${f.origin} to ${f.destination}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
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
        ),
        if (!isSpecific) ...<Widget>[
          const SizedBox(height: 12),
          _UnknownCarrierCard(iata: iata),
        ],
      ],
    );
  }
}

/// Shown when no per-carrier record exists. The advice below is still real —
/// it is the general procedure — but the user has to know it is not this
/// airline's own published one.
class _UnknownCarrierCard extends StatelessWidget {
  const _UnknownCarrierCard({required this.iata});

  final String iata;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color color = dark ? TraceColors.unknownDark : TraceColors.unknown;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.help_outline_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  iata.isEmpty
                      ? 'No airline selected'
                      : 'No request procedure for $iata',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            iata.isEmpty
                ? 'No carrier identified, so what follows is the general '
                    'procedure.'
                : 'No record of how this carrier takes these requests, so '
                    'what follows is the general procedure.',
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Confirm the channel and the window with the airline.',
            style: TextStyle(height: 1.4, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Which way works
// ---------------------------------------------------------------------------

class _MethodSection extends StatelessWidget {
  const _MethodSection({required this.guide});

  final RequestGuide guide;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PrimaryMethodCard(method: guide.primary),
        if (guide.alsoAccepted.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            'Also accepted',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ContactMethod m in guide.alsoAccepted)
                Chip(
                  avatar: Icon(
                    _methodIcon(m),
                    size: 17,
                    color: scheme.onSurfaceVariant,
                  ),
                  label: Text(m.label),
                  labelStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
            ],
          ),
        ],
        if (guide.notAccepted.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _NotAcceptedGroup(methods: guide.notAccepted),
        ],
        const SizedBox(height: 10),
        _Caption(
          guide.primary.leavesARecord
              ? 'Leaves a written record. Keep it.'
              : 'No written record — ask for a reference number and a name.',
        ),
      ],
    );
  }
}

class _PrimaryMethodCard extends StatelessWidget {
  const _PrimaryMethodCard({required this.method});

  final ContactMethod method;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_methodIcon(method), size: 26, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Use this: ${method.label}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  method.description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The channels that look official and go nowhere. Naming them saves more
/// time than naming the ones that work.
class _NotAcceptedGroup extends StatelessWidget {
  const _NotAcceptedGroup({required this.methods});

  final List<ContactMethod> methods;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.do_not_disturb_alt_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Do not bother with',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < methods.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == methods.length - 1 ? 0 : 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(_methodIcon(methods[i]), size: 15, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${methods[i].label} — ${methods[i].description}',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: color,
                      ),
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

// ---------------------------------------------------------------------------
// 2. When to ask
// ---------------------------------------------------------------------------

class _LeadTimeCard extends StatelessWidget {
  const _LeadTimeCard({required this.leadTime});

  final String leadTime;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color color = dark ? TraceColors.cautionDark : TraceColors.caution;
    final String text = leadTime.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.schedule_rounded, size: 24, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text.isEmpty ? 'No window recorded' : text,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text.isEmpty
                      ? 'No lead time recorded for this carrier. Ask as soon '
                          'as you book, and again 48 hours out.'
                      : 'Missing the window is the most common way a request '
                          'fails.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: scheme.onSurface.withValues(alpha: 0.85),
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

// ---------------------------------------------------------------------------
// 3. Do this
// ---------------------------------------------------------------------------

class _StepsSection extends StatelessWidget {
  const _StepsSection({required this.steps});

  final List<RequestStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const _Note(
        icon: Icons.info_outline_rounded,
        text: 'No steps recorded for this carrier. Use the general procedure '
            'below.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < steps.length; i++)
              _StepRow(
                index: i + 1,
                step: steps[i],
                last: i == steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.last,
  });

  final int index;
  final RequestStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String detail = (step.detail ?? '').trim();

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 3),
                Text(
                  step.text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. What to say
// ---------------------------------------------------------------------------

/// The wording, in a box the user can select from and copy.
///
/// People freeze on the phone. Being handed the sentences — specific about the
/// allergen and the accommodation, in the carrier's own vocabulary — gets a
/// materially better result than "I have allergies".
class _ScriptSection extends StatelessWidget {
  const _ScriptSection({required this.script, required this.profileSummary});

  final String script;
  final String profileSummary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String text = script.trim();

    if (text.isEmpty) {
      return const _Note(
        icon: Icons.info_outline_rounded,
        text: 'No wording recorded. Give the flight number and date, the '
            'allergen by name, and the one thing you are asking for. Then ask '
            'for a reference number.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _copyScript(context, text),
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy this wording'),
        ),
        const SizedBox(height: 10),
        _Caption(
          profileSummary.isEmpty
              ? 'Name your own allergens in the wording before you use it.'
              : 'Substitute your own: $profileSummary.',
        ),
      ],
    );
  }
}

Future<void> _copyScript(BuildContext context, String text) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger?.showSnackBar(
    const SnackBar(content: Text('Wording copied to the clipboard')),
  );
}

// ---------------------------------------------------------------------------
// 5. Contact
// ---------------------------------------------------------------------------

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.guide,
    required this.carrierName,
    required this.iata,
  });

  final RequestGuide guide;
  final String carrierName;
  final String iata;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final String? phone = _clean(guide.phone);
    final String? formUrl = _clean(guide.formUrl);
    final String? email = _clean(guide.email);
    final String? appPath = _clean(guide.appPath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!guide.hasDirectContact)
          _NoContactCard(carrierName: carrierName, iata: iata)
        else ...<Widget>[
          if (phone != null) ...<Widget>[
            FilledButton.icon(
              onPressed: () => _open(
                context,
                Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
                'Could not start the call. The number is $phone.',
              ),
              icon: const Icon(Icons.phone_rounded),
              label: Text(
                (guide.phoneLabel ?? '').trim().isEmpty
                    ? 'Call $phone'
                    : '${guide.phoneLabel!.trim()} · $phone',
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (formUrl != null) ...<Widget>[
            OutlinedButton.icon(
              onPressed: () => _open(
                context,
                Uri.parse(formUrl),
                'Could not open the form.',
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open the request form'),
            ),
            const SizedBox(height: 10),
          ],
          if (email != null) ...<Widget>[
            OutlinedButton.icon(
              onPressed: () => _open(
                context,
                Uri(scheme: 'mailto', path: email),
                'Could not open your mail app. The address is $email.',
              ),
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: Text('Email $email'),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (appPath != null) ...<Widget>[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.smartphone_rounded,
                      size: 17,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'In the airline app',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  appPath,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The path inside the airline’s own app.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (guide.hasDirectContact) ...<Widget>[
          const SizedBox(height: 12),
          _Caption(
            'Shipped with the app, not looked up live. Airlines change them.',
          ),
        ],
      ],
    );
  }

  static String? _clean(String? value) {
    final String v = (value ?? '').trim();
    return v.isEmpty ? null : v;
  }
}

/// No verified contact details. The app says so rather than guessing, because
/// a wrong number in a safety context is worse than no number.
class _NoContactCard extends StatelessWidget {
  const _NoContactCard({required this.carrierName, required this.iata});

  final String carrierName;
  final String iata;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color color = dark ? TraceColors.unknownDark : TraceColors.unknown;
    final String who = carrierName.isNotEmpty
        ? carrierName
        : (iata.isNotEmpty ? iata : 'this carrier');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.phone_disabled_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No verified contact details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'No verified phone number, form or address for $who.',
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the number on your boarding pass, or the airline’s own '
            'contact page.',
            style: TextStyle(height: 1.4, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

Future<void> _open(BuildContext context, Uri uri, String failure) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final bool opened = await launchUrl(
      uri,
      mode: uri.scheme == 'https' || uri.scheme == 'http'
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );
    if (!opened) {
      messenger?.showSnackBar(SnackBar(content: Text(failure)));
    }
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(failure)));
  }
}

// ---------------------------------------------------------------------------
// 6. Watch out for
// ---------------------------------------------------------------------------

class _GotchaSection extends StatelessWidget {
  const _GotchaSection({required this.gotchas});

  final List<String> gotchas;

  @override
  Widget build(BuildContext context) {
    final List<String> items =
        gotchas.map((String g) => g.trim()).where((String g) => g.isNotEmpty).toList();

    if (items.isEmpty) {
      return const _Note(
        icon: Icons.info_outline_rounded,
        text: 'None recorded — none were found at review, not that there are '
            'none.',
      );
    }

    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color color = dark ? TraceColors.cautionDark : TraceColors.caution;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, size: 19, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
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

// ---------------------------------------------------------------------------
// 7. How to ask anyone
// ---------------------------------------------------------------------------

/// Collapsed by default, deliberately. Someone who opened this screen came
/// with an airline in mind, and the carrier-specific advice above answers them
/// faster. This is the version that still works when the carrier is not in the
/// data at all.
class _TutorialSection extends StatelessWidget {
  const _TutorialSection();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.school_outlined, color: scheme.primary),
          title: const Text(
            'Asking any airline',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Works with any carrier',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          children: <Widget>[
            if (kGeneralRequestTutorial.isEmpty)
              const _Note(
                icon: Icons.info_outline_rounded,
                text: 'No general procedure is recorded.',
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < kGeneralRequestTutorial.length; i++)
                    _StepRow(
                      index: i + 1,
                      step: kGeneralRequestTutorial[i],
                      last: i == kGeneralRequestTutorial.length - 1,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Footer
// ---------------------------------------------------------------------------

class _FooterNote extends StatelessWidget {
  const _FooterNote({required this.lastReviewed});

  final String lastReviewed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String reviewed = lastReviewed.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.event_available_outlined,
              size: 15,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                reviewed.isEmpty
                    ? 'No review date recorded for this procedure'
                    : 'Procedure last reviewed $reviewed',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Caption(
          'Airlines change these without notice. Confirm with the carrier.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Close the loop
// ---------------------------------------------------------------------------

/// The point of the whole screen. Knowing how to ask is half of it; the other
/// half is that a request nobody wrote down did not happen.
class _LogTheRequestBar extends StatelessWidget {
  const _LogTheRequestBar();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'An unrecorded request did not happen.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Log this request'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A Material icon for each way of reaching an airline.
IconData _methodIcon(ContactMethod method) {
  switch (method) {
    case ContactMethod.phone:
      return Icons.phone_rounded;
    case ContactMethod.webForm:
      return Icons.assignment_outlined;
    case ContactMethod.app:
      return Icons.smartphone_rounded;
    case ContactMethod.email:
      return Icons.mail_outline_rounded;
    case ContactMethod.chat:
      return Icons.chat_bubble_outline_rounded;
    case ContactMethod.socialDm:
      return Icons.alternate_email_rounded;
    case ContactMethod.airportDesk:
      return Icons.support_agent_rounded;
    case ContactMethod.gate:
      return Icons.flight_takeoff_rounded;
    case ContactMethod.onboard:
      return Icons.airline_seat_recline_normal_rounded;
  }
}
