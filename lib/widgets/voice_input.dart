import 'dart:async';

import 'package:flutter/material.dart';

import '../services/speech.dart';

/// Cached for the session: whether this phone can recognise speech on-device
/// does not change while the app is open, and asking takes a platform call.
Future<SpeechAvailability>? _availability;

Future<SpeechAvailability> _checkAvailability() =>
    _availability ??= SpeechService.instance.availability();

/// A microphone that fills the form it sits on.
///
/// Hidden entirely on a phone that cannot recognise speech on the device:
/// the alternative would be sending audio to a server, which this app does
/// not do.
class VoiceButton extends StatefulWidget {
  const VoiceButton({
    super.key,
    required this.title,
    required this.hint,
    required this.onTranscript,
  });

  /// What the sheet asks, e.g. "Describe the exposure".
  final String title;

  /// An example of what to say.
  final String hint;

  final Future<void> Function(String transcript) onTranscript;

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  SpeechAvailability? _status;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability().then((SpeechAvailability s) {
      if (mounted) setState(() => _status = s);
    });
  }

  Future<void> _tap() async {
    final String? text = await showDictationSheet(
      context,
      title: widget.title,
      hint: widget.hint,
    );
    // Permission may have just been granted or refused.
    _availability = null;
    if (text == null || text.trim().isEmpty || !mounted) return;
    setState(() => _working = true);
    await widget.onTranscript(text);
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Filled in from what you said. Check it before saving.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SpeechAvailability? s = _status;
    if (s == null || s == SpeechAvailability.unavailable) {
      return const SizedBox.shrink();
    }
    if (_working) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    return IconButton(
      tooltip: 'Say it instead of typing',
      onPressed: _tap,
      icon: const Icon(Icons.mic_none_rounded),
    );
  }
}

/// Listens until the user taps Done, showing the words as they come.
/// Returns what was said, or null when cancelled or voice is not allowed.
Future<String?> showDictationSheet(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final bool ready = await SpeechService.instance.ensureReady();
  if (!context.mounted) return null;
  if (!ready) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Voice needs the microphone and speech recognition. Turn them on '
          'for this app in Settings.',
        ),
      ),
    );
    return null;
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext _) => _DictationSheet(title: title, hint: hint),
  );
}

class _DictationSheet extends StatefulWidget {
  const _DictationSheet({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  State<_DictationSheet> createState() => _DictationSheetState();
}

class _DictationSheetState extends State<_DictationSheet> {
  final List<String> _segments = <String>[];
  String _partial = '';
  bool _listening = false;
  StreamSubscription<SpeechEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SpeechService.instance.events.listen((SpeechEvent e) {
      if (!mounted) return;
      setState(() {
        if (e.isPartial) _partial = e.text;
        if (e.isSegment) {
          _segments.add(e.text);
          _partial = '';
        }
        if (e.isStopped) _listening = false;
      });
    });
    SpeechService.instance.start().then((bool ok) {
      if (mounted) setState(() => _listening = ok);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    SpeechService.instance.stop();
    super.dispose();
  }

  String get _text => <String>[
        ..._segments,
        if (_partial.isNotEmpty) _partial,
      ].join(' ');

  Future<void> _done() async {
    final NavigatorState nav = Navigator.of(context);
    final String text = _text;
    await SpeechService.instance.stop();
    nav.pop<String>(text);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String text = _text;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'For example: “${widget.hint}”',
              style: TextStyle(fontSize: 14.5, height: 1.35, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(minHeight: 110),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                text.isEmpty ? (_listening ? 'Listening…' : 'Starting…') : text,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  color: text.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  _listening ? Icons.mic_rounded : Icons.mic_off_rounded,
                  size: 16,
                  color: _listening ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'On this iPhone only — nothing you say is sent anywhere.',
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: text.isEmpty ? null : _done,
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
