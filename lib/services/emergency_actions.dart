import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../data/countries.dart';
import '../models/trip.dart';
import '../theme.dart';
import 'app_state.dart';
import 'handoff.dart';

/// The number to call for an ambulance right now, and where it applies.
class LocalEmergencyNumber {
  const LocalEmergencyNumber({
    required this.number,
    required this.where,
    required this.isFallback,
  });

  final String number;

  /// The country it is for, or empty when it is a fallback.
  final String where;

  /// True when the app does not know where the phone is and is guessing.
  final bool isFallback;
}

/// Picks the emergency number from what the app knows, most specific first:
///
/// 1. a trip that is underway, when it has a destination country;
/// 2. the home country on the profile — where someone is when no trip is
///    underway;
/// 3. the phone's own region setting, for a profile with no home country;
/// 4. 911, which is what this app dialled before it knew any of this, and is
///    redirected on many networks abroad.
///
/// Pure, so the order can be tested.
LocalEmergencyNumber resolveEmergencyNumber({
  Trip? underwayTrip,
  String? homeCountry,
  String? deviceRegion,
}) {
  final Country? abroad = countryFor(underwayTrip?.destinationCountry ?? '');
  if (abroad != null) {
    return LocalEmergencyNumber(
      number: abroad.emergency,
      where: abroad.name,
      isFallback: false,
    );
  }
  final Country? home =
      countryFor(homeCountry ?? '') ?? countryFor(deviceRegion ?? '');
  if (home != null) {
    return LocalEmergencyNumber(
      number: home.emergency,
      where: home.name,
      isFallback: false,
    );
  }
  return const LocalEmergencyNumber(number: '911', where: '', isFallback: true);
}

/// [resolveEmergencyNumber] for the app as it stands now.
LocalEmergencyNumber localEmergencyNumber(AppState app) {
  final Trip? trip = app.activeTrip();
  return resolveEmergencyNumber(
    underwayTrip: trip != null && trip.isUnderway(DateTime.now()) ? trip : null,
    homeCountry: app.activeProfile.homeCountry,
    deviceRegion: PlatformDispatcher.instance.locale.countryCode,
  );
}

/// One confirmation in front of an emergency call, so it cannot fire from a
/// pocket tap — and exactly one, because anything longer is a second obstacle
/// at the worst moment. True when the call was handed to the phone.
Future<bool> callEmergency(
  BuildContext context,
  LocalEmergencyNumber n, {
  ValueChanged<LocalEmergencyNumber>? onConfirmed,
}) async {
  Country? selected;
  for (final country in kCountries) {
    if (country.name == n.where) selected = country;
  }
  LocalEmergencyNumber? confirmed;
  final bool dark = Theme.of(context).brightness == Brightness.dark;
  final Color danger = dark ? TraceColors.unsafeDark : TraceColors.unsafe;
  final bool ok =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Confirm your current country'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A trip destination or phone region may differ from where you are now. Choose your current country before calling.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Country>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Where are you now?',
                  ),
                  items: [
                    for (final c in kCountries)
                      DropdownMenuItem(value: c, child: Text(c.name)),
                  ],
                  onChanged: (value) => update(() => selected = value),
                ),
                const SizedBox(height: 12),
                Text(
                  selected == null
                      ? 'If your country is not listed, use the phone emergency dialer or ask local staff for help.'
                      : 'Call ${selected!.emergency} for an ambulance in ${selected!.name}.',
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: selected == null
                    ? null
                    : () {
                        confirmed = LocalEmergencyNumber(
                          number: selected!.emergency,
                          where: selected!.name,
                          isFallback: false,
                        );
                        Navigator.of(dialogContext).pop(true);
                      },
                child: Text(
                  selected == null ? 'Call' : 'Call ${selected!.emergency}',
                ),
              ),
            ],
          ),
        ),
      ) ??
      false;
  if (!ok || !context.mounted) return false;
  final target = confirmed;
  if (target == null) return false;
  final launched = await dialNumber(context, target.number);
  if (launched) onConfirmed?.call(target);
  return launched;
}

/// Starts a call through the phone's own dialler. True when it started.
Future<bool> dialNumber(BuildContext context, String raw) async {
  final String cleaned = dialableNumber(raw);
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (cleaned.isEmpty) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('There is no phone number to call.')),
    );
    return false;
  }
  try {
    final bool launched = await handOffToPhone(
      context,
      Uri(scheme: 'tel', path: cleaned),
    );
    if (!launched) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not start a call to $cleaned.')),
      );
    }
    return launched;
  } catch (_) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not start a call to $cleaned.')),
    );
    return false;
  }
}

/// Opens Messages with [body] ready for one recipient. The app never sends:
/// the person holding the phone presses send.
///
/// iOS wants `sms:<number>&body=<text>` — a `?` before body is ignored by
/// Messages. '#' is dropped from the number because in an sms: URL it would
/// start a fragment and take the message with it.
Future<bool> sendSms(
  BuildContext context, {
  required String phone,
  required String body,
}) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final String number = dialableNumber(phone).replaceAll('#', '');
  if (number.isEmpty) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('No usable phone number saved.')),
    );
    return false;
  }
  final Uri uri = Uri.parse(
    body.isEmpty
        ? 'sms:$number'
        : 'sms:$number&body=${Uri.encodeComponent(body)}',
  );
  try {
    final bool launched = await handOffToPhone(context, uri);
    if (!launched) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open Messages.')),
      );
    }
    return launched;
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Could not open Messages.')),
    );
    return false;
  }
}
