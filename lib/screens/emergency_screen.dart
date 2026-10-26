import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/emergency_actions.dart';
import 'emergency_mode_screen.dart';

import 'package:trace_allergy/data/emergency_phrases.dart';
import 'package:trace_allergy/data/emk_locations.dart';
import 'package:trace_allergy/models/emergency.dart';
import 'package:trace_allergy/models/flight.dart';
import 'package:trace_allergy/screens/action_plans_screen.dart';
import 'package:trace_allergy/screens/clinical_guidance_screen.dart';
import 'package:trace_allergy/screens/emergency_phrases_screen.dart';
import 'package:trace_allergy/screens/reaction_log_screen.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/services/notifications.dart';
import 'package:trace_allergy/theme.dart';
import 'package:trace_allergy/widgets/language_picker.dart';

/// The emergency layer.
///
/// No food scanner in the category ships any of this. The one app that ever
/// did has not been updated since 2021. Everything here is ordered by how
/// quickly it might be needed: the call buttons sit above the fold and never
/// scroll out of reach of a thumb, because someone may open this screen during
/// a reaction rather than before one.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pens = app.epiPens;
    final contacts = app.contacts;
    final reactions = app.reactions;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          const _StartEmergencyMode(),
          const SizedBox(height: 12),
          _CallActions(contacts: contacts, senderName: app.activeProfile.name),
          const SizedBox(height: 16),
          const _GuidanceButton(),
          const SizedBox(height: 10),
          const _PhrasesButton(),
          const SectionTitle('Emergency medical kit on board'),
          _EmkCard(flight: app.activeFlight),
          SectionTitle(
            'Auto-injectors',
            trailing: pens.isEmpty
                ? null
                : _AddButton(onPressed: () => _editPen(context, null)),
          ),
          if (pens.isEmpty)
            _EmptyState(
              icon: Icons.medication_liquid_outlined,
              title: 'No auto-injectors added',
              body:
                  'Expiry is silent, and an expired device can lose potency. '
                  'You get a reminder first.',
              actionLabel: 'Add an auto-injector',
              onAction: () => _editPen(context, null),
            )
          else
            _CardList(
              children: <Widget>[
                for (final pen in pens)
                  _EpiPenTile(
                    pen: pen,
                    onEdit: () => _editPen(context, pen),
                    onDelete: () => _deletePen(context, pen),
                  ),
              ],
            ),
          SectionTitle(
            'Emergency contacts',
            trailing: contacts.isEmpty
                ? null
                : _AddButton(onPressed: () => _editContact(context, null)),
          ),
          if (contacts.isEmpty)
            _EmptyState(
              icon: Icons.contact_phone_outlined,
              title: 'No contacts added',
              body:
                  'Parent, partner, school office, allergist. They become call '
                  'and message buttons at the top of this screen.',
              actionLabel: 'Add a contact',
              onAction: () => _editContact(context, null),
            )
          else
            _CardList(
              children: <Widget>[
                for (final c in contacts)
                  _ContactTile(
                    contact: c,
                    senderName: app.activeProfile.name,
                    onEdit: () => _editContact(context, c),
                    onDelete: () => _deleteContact(context, c),
                  ),
              ],
            ),
          const SectionTitle('Action plan'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.medical_information_outlined),
              title: const Text('Anaphylaxis action plans'),
              subtitle: const Text('One per airline, with dose and expiry'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) => const ActionPlansScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _ActionPlanCard(),
          SectionTitle(
            'Recent reactions',
            trailing: reactions.isEmpty
                ? null
                : TextButton(
                    onPressed: () => _openLog(context),
                    child: const Text('See all'),
                  ),
          ),
          if (reactions.isEmpty)
            _EmptyState(
              icon: Icons.event_note_outlined,
              title: 'Nothing logged',
              body:
                  'What was eaten and what happened — the record an allergist '
                  'asks for.',
              actionLabel: 'Log a reaction',
              onAction: () => _openLog(context),
            )
          else ...<Widget>[
            _CardList(
              children: <Widget>[
                for (final r in reactions.take(3))
                  _ReactionSummaryTile(
                    reaction: r,
                    onTap: () => _openLog(context),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openLog(context),
              icon: const Icon(Icons.add),
              label: const Text('Log a reaction'),
            ),
          ],
        ],
      ),
    );
  }

  static void _openLog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => const ReactionLogScreen(),
      ),
    );
  }

  static Future<void> _editPen(BuildContext context, EpiPen? existing) async {
    final app = context.read<AppState>();
    final result = await showModalBottomSheet<EpiPen>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => _EpiPenSheet(existing: existing),
    );
    if (result == null) return;

    await app.saveEpiPen(result);
    // Ask only when there is something to remind about, and only once the
    // user has actually opted in by saving a pen.
    await NotificationService.requestPermissions();
    await NotificationService.scheduleEpiExpiry(result);
  }

  static Future<void> _deletePen(BuildContext context, EpiPen pen) async {
    final app = context.read<AppState>();
    final label = pen.label.trim().isEmpty ? 'this auto-injector' : pen.label;
    final ok = await _confirm(
      context,
      title: 'Remove auto-injector',
      body: 'Remove $label and its expiry reminder.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    await NotificationService.cancelEpiExpiry(pen.id);
    await app.deleteEpiPen(pen.id);
  }

  static Future<void> _editContact(
    BuildContext context,
    EmergencyContact? existing,
  ) async {
    final app = context.read<AppState>();
    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => _ContactSheet(existing: existing),
    );
    if (result == null) return;
    await app.saveContact(result);
  }

  static Future<void> _deleteContact(
    BuildContext context,
    EmergencyContact contact,
  ) async {
    final app = context.read<AppState>();
    final name = contact.name.trim().isEmpty ? 'this contact' : contact.name;
    final ok = await _confirm(
      context,
      title: 'Remove contact',
      body: 'Remove $name from the emergency buttons.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    await app.deleteContact(contact.id);
  }
}

// ---------------------------------------------------------------------------
// Call actions — the part of the screen that has to work first time, in a
// hurry, possibly one-handed.
// ---------------------------------------------------------------------------

class _CallActions extends StatelessWidget {
  const _CallActions({required this.contacts, required this.senderName});

  final List<EmergencyContact> contacts;

  /// Whose reaction it is, used to open the prefilled message with a name on it.
  final String senderName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;
    final number = localEmergencyNumber(context.watch<AppState>());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(76),
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: () => callEmergency(context, number),
          icon: const Icon(Icons.phone_in_talk, size: 30),
          label: Text('Call ${number.number}'),
        ),
        const SizedBox(height: 8),
        Text(
          'Epinephrine first, then ${number.number}'
          '${number.where.isEmpty ? '' : ' (suggested for ${number.where})'}. Confirm your current country before calling. Call even if '
          'symptoms start to settle.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
        ),
        if (contacts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          // Calling is not always the right move: a parent in a meeting, a
          // partner asleep in another time zone, a school office that never
          // picks up. A text gets through those and leaves a record of when it
          // was sent.
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => _openMessageSheet(
              context,
              contacts: contacts,
              senderName: senderName,
            ),
            icon: const Icon(Icons.sms_outlined, size: 20),
            label: Text(
              contacts.length == 1
                  ? 'Text ${_shortName(contacts.first)}'
                  : 'Text a contact',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: contacts.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int i) {
                final c = contacts[i];
                final name = c.name.trim().isEmpty ? c.phone : c.name.trim();
                return OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _dial(context, c.phone),
                  icon: const Icon(Icons.call, size: 18),
                  label: Text(name),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> _dial(BuildContext context, String number) =>
    dialNumber(context, number);

/// Opens Messages with the text ready and the recipient filled in.
///
/// The app never sends it. A message announcing a reaction that did not happen
/// is its own kind of harm, and the person holding the phone is the only one who
/// knows which it is — so the last tap is always theirs, in Messages.
///
/// One recipient, deliberately. The iOS `sms:` scheme addresses a single
/// number; a comma-separated list is not its group form and Messages will not
/// read it as one, so offering "text everyone" here would be offering
/// something that does not arrive.
Future<void> _sendSms(
  BuildContext context,
  EmergencyContact recipient,
  String body,
) => sendSms(context, phone: recipient.phone, body: body);

String _shortName(EmergencyContact c) {
  final name = c.name.trim();
  if (name.isEmpty) return c.phone.trim();
  return name.split(RegExp(r'\s+')).first;
}

Future<void> _openMessageSheet(
  BuildContext context, {
  required List<EmergencyContact> contacts,
  required String senderName,
  EmergencyContact? only,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext _) => _MessageSheet(
      contacts: only == null ? contacts : <EmergencyContact>[only],
      senderName: senderName,
    ),
  );
}

/// Pick who, pick what, hand it to Messages.
///
/// One recipient at a time, because that is all the iOS `sms:` scheme can
/// actually address. The first contact is preselected, so the common case is
/// still one tap.
class _MessageSheet extends StatefulWidget {
  const _MessageSheet({required this.contacts, required this.senderName});

  final List<EmergencyContact> contacts;
  final String senderName;

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  late String _selectedId = widget.contacts.first.id;

  EmergencyContact? get _recipient {
    for (final EmergencyContact c in widget.contacts) {
      if (c.id == _selectedId) return c;
    }
    return widget.contacts.isEmpty ? null : widget.contacts.first;
  }

  Future<void> _send(String body) async {
    final recipient = _recipient;
    if (recipient == null) return;
    final navigator = Navigator.of(context);
    await _sendSms(context, recipient, body);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: <Widget>[
        const Text(
          'Send a message',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          widget.contacts.length > 1
              ? 'Opens Messages with the text ready. You press send. One '
                    'person at a time.'
              : 'Opens Messages with the text ready. You press send.',
          style: TextStyle(
            fontSize: 14.5,
            height: 1.35,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (widget.contacts.length > 1) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final EmergencyContact c in widget.contacts)
                ChoiceChip(
                  selected: c.id == _selectedId,
                  label: Text(_shortName(c)),
                  onSelected: (_) => setState(() => _selectedId = c.id),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        for (final ContactMessageTemplate t in kContactMessages)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TemplateTile(
              template: t,
              body: fillContactMessage(t.body, widget.senderName),
              accent: t.severe ? danger : scheme.onSurfaceVariant,
              enabled: _recipient != null,
              onTap: () => _send(fillContactMessage(t.body, widget.senderName)),
            ),
          ),
        TextButton.icon(
          onPressed: _recipient == null ? null : () => _send(''),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Write my own'),
        ),
      ],
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.body,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final ContactMessageTemplate template;
  final String body;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      template.severe
                          ? Icons.warning_amber_rounded
                          : Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        template.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: template.severe ? accent : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ---------------------------------------------------------------------------
// Auto-injectors
// ---------------------------------------------------------------------------

class _EpiPenTile extends StatelessWidget {
  const _EpiPenTile({
    required this.pen,
    required this.onEdit,
    required this.onDelete,
  });

  final EpiPen pen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Color? stateColor = pen.isExpired
        ? (dark ? TraceColors.unsafeDark : TraceColors.unsafe)
        : pen.isExpiringSoon
        ? (dark ? TraceColors.cautionDark : TraceColors.caution)
        : null;

    final subtitleParts = <String>[
      if (pen.location.trim().isNotEmpty) pen.location.trim(),
      if (pen.brand.trim().isNotEmpty) pen.brand.trim(),
    ];

    return ListTile(
      onTap: onEdit,
      leading: Icon(
        pen.isExpired
            ? Icons.error_outline
            : pen.isExpiringSoon
            ? Icons.access_time
            : Icons.medication_liquid,
        color: stateColor ?? scheme.onSurfaceVariant,
      ),
      title: Text(
        pen.label.trim().isEmpty ? 'Auto-injector' : pen.label.trim(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (subtitleParts.isNotEmpty)
            Text(
              subtitleParts.join(' · '),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 2),
          Text(
            _expiryLine(pen),
            style: TextStyle(
              color: stateColor ?? scheme.onSurfaceVariant,
              fontWeight: stateColor == null
                  ? FontWeight.w400
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
      isThreeLine: subtitleParts.isNotEmpty,
      trailing: IconButton(
        tooltip: 'Remove',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

String _expiryLine(EpiPen pen) {
  final days = pen.daysUntilExpiry;
  if (days < 0) {
    final ago = -days;
    if (ago == 1) return 'Expired yesterday';
    return 'Expired $ago days ago';
  }
  if (pen.isExpiringSoon) {
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }
  return 'Expires ${_formatDate(pen.expiresOn)}';
}

class _EpiPenSheet extends StatefulWidget {
  const _EpiPenSheet({required this.existing});

  final EpiPen? existing;

  @override
  State<_EpiPenSheet> createState() => _EpiPenSheetState();
}

class _EpiPenSheetState extends State<_EpiPenSheet> {
  static const List<int> _leadOptions = <int>[7, 30, 60, 90];

  late final TextEditingController _label;
  late final TextEditingController _location;
  late final TextEditingController _brand;
  late DateTime _expiresOn;
  late int _remindDaysBefore;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _brand = TextEditingController(text: e?.brand ?? '');
    _expiresOn = e?.expiresOn ?? DateTime.now().add(const Duration(days: 365));
    final lead = e?.remindDaysBefore ?? 30;
    _remindDaysBefore = _leadOptions.contains(lead) ? lead : 30;
  }

  @override
  void dispose() {
    _label.dispose();
    _location.dispose();
    _brand.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresOn,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'Expiry date on the device',
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _expiresOn = picked);
  }

  void _save() {
    final existing = widget.existing;
    final pen = EpiPen(
      id: existing?.id ?? _newId(),
      label: _label.text.trim().isEmpty ? 'Auto-injector' : _label.text.trim(),
      expiresOn: DateTime(_expiresOn.year, _expiresOn.month, _expiresOn.day),
      brand: _brand.text.trim(),
      location: _location.text.trim(),
      remindDaysBefore: _remindDaysBefore,
    );
    Navigator.of(context).pop(pen);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SheetScaffold(
      title: widget.existing == null
          ? 'Add auto-injector'
          : 'Edit auto-injector',
      onSave: _save,
      children: <Widget>[
        TextField(
          controller: _label,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'EpiPen 1',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _location,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Where it is kept',
            hintText: 'School bag, kitchen drawer, car',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _brand,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Brand',
            hintText: 'EpiPen, Jext, Auvi-Q, Emerade',
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Expiry date'),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(_formatDate(_expiresOn))),
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Remind me before it expires',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final days in _leadOptions)
              ChoiceChip(
                label: Text('$days days'),
                selected: _remindDaysBefore == days,
                onSelected: (bool _) =>
                    setState(() => _remindDaysBefore = days),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Reminder at 9am. A replacement needs a prescription, so allow time.',
          style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contacts
// ---------------------------------------------------------------------------

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.senderName,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final String senderName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = <String>[
      if (contact.relationship.trim().isNotEmpty) contact.relationship.trim(),
      if (contact.phone.trim().isNotEmpty) contact.phone.trim(),
    ].join(' · ');

    return ListTile(
      onTap: onEdit,
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: const Icon(Icons.person_outline),
      ),
      title: Text(
        contact.name.trim().isEmpty ? 'Contact' : contact.name.trim(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: detail.isEmpty
          ? null
          : Text(detail, style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Call',
            onPressed: () => _dial(context, contact.phone),
            icon: const Icon(Icons.call),
          ),
          IconButton(
            tooltip: 'Message',
            onPressed: () => _openMessageSheet(
              context,
              contacts: <EmergencyContact>[contact],
              senderName: senderName,
              only: contact,
            ),
            icon: const Icon(Icons.sms_outlined),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.existing});

  final EmergencyContact? existing;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _relationship;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _relationship = TextEditingController(text: e?.relationship ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  void _save() {
    if (_phone.text.trim().isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('A phone number is needed for the call button.'),
        ),
      );
      return;
    }
    final existing = widget.existing;
    Navigator.of(context).pop(
      EmergencyContact(
        id: existing?.id ?? _newId(),
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        relationship: _relationship.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: widget.existing == null ? 'Add contact' : 'Edit contact',
      onSave: _save,
      children: <Widget>[
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _relationship,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Relationship',
            hintText: 'Mom, partner, school office, allergist',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action plan
// ---------------------------------------------------------------------------

class _ActionPlanCard extends StatefulWidget {
  const _ActionPlanCard();

  @override
  State<_ActionPlanCard> createState() => _ActionPlanCardState();
}

class _ActionPlanCardState extends State<_ActionPlanCard> {
  static const String _placeholder =
      'From the prescribing doctor. For example:\n\n'
      'Trouble breathing, throat tightness, repeated vomiting, faintness — '
      'epinephrine, then call emergency services.\n\n'
      'Mild only, such as a few hives or an itchy mouth — antihistamine, '
      'watch closely for 30 minutes.\n\n'
      'Epinephrine: which device, which dose.\n'
      'Antihistamine: which one, how much.\n'
      'Asthma inhaler, if prescribed.\n'
      'Doctor and pharmacy phone numbers.';

  final TextEditingController _controller = TextEditingController();
  String _saved = '';
  bool _initialisedFromState = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    // Seed once from persisted state; after that the field is the source of
    // truth so typing is never clobbered by a rebuild.
    if (!_initialisedFromState) {
      _initialisedFromState = true;
      _saved = app.actionPlan;
      _controller.text = _saved;
    }

    final dirty = _controller.text != _saved;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 20,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (String _) => setState(() {}),
              decoration: const InputDecoration(
                hintText: _placeholder,
                hintMaxLines: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Free-text notes. For dose, expiry and airline, use the plans above.',
              style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
            ),
            if (dirty) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final text = _controller.text;
                  await app.setActionPlan(text);
                  if (!mounted) return;
                  setState(() => _saved = text);
                },
                child: const Text('Save notes'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clinical guidance — FRD 5.3
//
// Deliberately the largest control on the screen after 911. The person who
// needs it may not be the person who installed the app: a seatmate, a crew
// member, a doctor who answered the call. It has to be obvious to someone who
// has never seen this screen before.
// ---------------------------------------------------------------------------

class _GuidanceButton extends StatelessWidget {
  const _GuidanceButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        minimumSize: const Size.fromHeight(72),
        textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => const ClinicalGuidanceScreen(),
        ),
      ),
      icon: const Icon(Icons.medical_information_outlined, size: 28),
      label: const Text('Step-by-step: suspected anaphylaxis'),
    );
  }
}

/// The way into the translated phrases, on the screen you would already be on.
///
/// A reaction abroad has two problems at once: the reaction, and the fact that
/// nobody around you reads English. This is the second one, one tap deep.
class _PhrasesButton extends StatelessWidget {
  const _PhrasesButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = languageFor(context.watch<AppState>().travelLanguage);

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        foregroundColor: scheme.onSurface,
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => const EmergencyPhrasesScreen(),
        ),
      ),
      icon: Text(language.flag, style: const TextStyle(fontSize: 20)),
      label: Text(
        language.code == 'en'
            ? 'Emergency phrases · 12 languages'
            : 'Emergency phrases · ${language.native}',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Emergency medical kit — FRD 5.2
//
// Curated per-aircraft-family guidance. There is no public database mapping a
// kit to a tail number, and pretending otherwise would be worse than saying
// nothing: someone would go to the wrong galley. The definitive answer is a
// flight attendant, and the card says so louder than it says anything else.
// ---------------------------------------------------------------------------

class _EmkCard extends StatelessWidget {
  const _EmkCard({required this.flight});

  final Flight? flight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = flight;
    final aircraft = active?.aircraftType.trim() ?? '';

    // `emkFor` never returns null — an unrecognized or empty type resolves to
    // the generic entry, which is exactly what should be shown when there is
    // no active flight either.
    final EmkLocation emk = emkFor(aircraft);
    final String aircraftLine;
    if (active == null) {
      aircraftLine = 'No active flight. General guidance for any airliner.';
    } else if (aircraft.isEmpty) {
      aircraftLine =
          'No aircraft type on ${active.label}. General guidance for any '
          'airliner.';
    } else {
      aircraftLine = '$aircraft — ${emk.aircraftFamily}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.support_agent_outlined,
                    size: 24,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ask a flight attendant. They are the only definitive '
                      'answer.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _EmkRow(
              icon: Icons.flight_outlined,
              label: 'Aircraft',
              value: aircraftLine,
            ),
            _EmkRow(
              icon: Icons.place_outlined,
              label: 'Usually stowed',
              value: emk.stowage,
            ),
            _EmkRow(
              icon: Icons.inventory_2_outlined,
              label: 'Kits carried',
              value: emk.kitCount == 1
                  ? '1 emergency medical kit'
                  : '${emk.kitCount} emergency medical kits',
            ),
            if (emk.notes.trim().isNotEmpty)
              _EmkRow(
                icon: Icons.notes_outlined,
                label: 'Note',
                value: emk.notes.trim(),
              ),
            _EmkRow(
              icon: Icons.medication_liquid_outlined,
              label: 'Epinephrine',
              value:
                  'US airlines must carry it, usually as a vial and syringe. A few '
                  'also carry auto-injectors. Other airlines vary. Only the crew '
                  'can open the kit.',
            ),
            const SizedBox(height: 6),
            Text(
              'Curated guidance by aircraft family, not a location for this '
              'aircraft.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmkRow extends StatelessWidget {
  const _EmkRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reactions
// ---------------------------------------------------------------------------

class _ReactionSummaryTile extends StatelessWidget {
  const _ReactionSummaryTile({required this.reaction, required this.onTap});

  final ReactionLog reaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = <String>[
      if (reaction.suspectedFood.trim().isNotEmpty)
        reaction.suspectedFood.trim(),
      if (reaction.symptoms.isNotEmpty) reaction.symptoms.join(', '),
    ].join(' — ');

    return ListTile(
      onTap: onTap,
      leading: _SeverityDot(rating: reaction.severityRating),
      title: Text(
        _formatDate(reaction.occurredAt),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: detail.isEmpty
          ? null
          : Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// The severity dot, shared in spirit with the reaction log screen.
class _SeverityDot extends StatelessWidget {
  const _SeverityDot({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color color = rating >= 5
        ? (dark ? TraceColors.unsafeDark : TraceColors.unsafe)
        : rating >= 3
        ? (dark ? TraceColors.cautionDark : TraceColors.caution)
        : (dark ? TraceColors.clearDark : TraceColors.clear);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

class _CardList extends StatelessWidget {
  const _CardList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(icon, size: 34, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

/// The frame every add/edit sheet on this screen shares.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.onSave,
    required this.children,
  });

  final String title;
  final VoidCallback onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            ...children,
            const SizedBox(height: 22),
            FilledButton(onPressed: onSave, child: const Text('Save')),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

const List<String> _months = <String>[
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

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// No uuid dependency on the list, and none needed: these ids only have to be
/// unique within one device's store.
int _idCounter = 0;
String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

/// The way into emergency mode: the epinephrine timer, the right number for
/// where you are, the crew card on a plane, and a record kept as you go.
class _StartEmergencyMode extends StatelessWidget {
  const _StartEmergencyMode();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;
    final app = context.watch<AppState>();
    final trip = app.activeTrip();
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: danger,
        side: BorderSide(color: danger, width: 2),
        minimumSize: const Size.fromHeight(64),
        textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => EmergencyModeScreen(
            tripId: trip != null && trip.isUnderway(DateTime.now())
                ? trip.id
                : null,
          ),
        ),
      ),
      icon: const Icon(Icons.emergency_rounded, size: 26),
      label: const Text('Start emergency mode'),
    );
  }
}
