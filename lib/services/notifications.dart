import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:trace_allergy/models/emergency.dart';

/// Local notifications for auto-injector expiry.
///
/// This is the only part of Trace that speaks without being opened, and it
/// exists because expiry is silent — nothing tells you but the label, and a
/// device past its date can lose potency. Every call is wrapped: a failed or
/// denied notification must never crash the app or block the UI, because the
/// screen it sits behind is one someone may open during a reaction.
///
/// All members are static. Call sites read `NotificationService.init()`,
/// `NotificationService.scheduleEpiExpiry(pen)` and so on.
class NotificationService {
  const NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'epi_expiry';
  static const String _channelName = 'Auto-injector expiry';
  static const String _channelDescription =
      'Reminders that an epinephrine auto-injector is approaching its expiry '
      'date.';

  /// The hour, in device-local wall-clock time, that reminders fire at.
  static const int _reminderHour = 9;

  static bool _initialised = false;

  /// Prepares the plugin and the time zone database.
  ///
  /// Safe to call more than once; only the first call does work. On iOS this
  /// deliberately does **not** request permissions — the Darwin settings ask
  /// for nothing at init so the system prompt appears when the user actually
  /// schedules a reminder, not on first launch. Use [requestPermissions] for
  /// that.
  static Future<void> init() async {
    if (_initialised) return;
    try {
      tzdata.initializeTimeZones();

      // Limitation, deliberate: resolving the device's IANA zone name (e.g.
      // "Europe/London") needs a platform plugin that is not on this project's
      // dependency list, so `tz.local` stays at the database default rather
      // than the real local zone. Reminder times are therefore always built as
      // a plain device-local `DateTime` first and only then converted with
      // `TZDateTime.from`, which preserves the absolute instant regardless of
      // what `tz.local` resolves to. The plugin sends a full ISO-8601 string
      // with offset to the platform, so the notification still lands at 9am by
      // the device's own clock. What is lost is only the zone *name*, which
      // matters if the user changes time zone between scheduling and firing.
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      _initialised = true;
    } catch (e) {
      debugPrint('NotificationService.init failed: $e');
    }
  }

  /// Asks the platform for permission to post notifications.
  ///
  /// Returns false if permission was refused, unavailable, or the request
  /// itself failed. Callers should treat false as "reminders will not fire"
  /// and never as an error worth interrupting the user for.
  static Future<bool> requestPermissions() async {
    try {
      await init();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) {
        final granted = await macos.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }

      return false;
    } catch (e) {
      debugPrint('NotificationService.requestPermissions failed: $e');
      return false;
    }
  }

  /// Schedules the expiry reminder for [pen].
  ///
  /// Fires `pen.remindDaysBefore` days before `pen.expiresOn`, at 9am by the
  /// device clock. Any reminder already scheduled for this pen is replaced. If
  /// that moment has already passed the call is a silent no-op — a reminder
  /// for a date in the past is noise, and the expiry state is already visible
  /// on the auto-injector list.
  static Future<void> scheduleEpiExpiry(EpiPen pen) async {
    try {
      await init();
      if (!_initialised) return;

      // Replace rather than stack: saving an edited pen must not leave the old
      // reminder behind.
      await _plugin.cancel(notificationIdFor(pen.id));

      final due = pen.expiresOn.subtract(Duration(days: pen.remindDaysBefore));
      final localWallClock = DateTime(
        due.year,
        due.month,
        due.day,
        _reminderHour,
      );
      if (!localWallClock.isAfter(DateTime.now())) return;

      final scheduled = tz.TZDateTime.from(localWallClock, tz.local);
      if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;

      final label = pen.label.trim().isEmpty ? 'Auto-injector' : pen.label.trim();
      final where = pen.location.trim();

      await _plugin.zonedSchedule(
        notificationIdFor(pen.id),
        'Auto-injector expiring',
        where.isEmpty
            ? '$label expires on ${_formatDate(pen.expiresOn)}. Arrange a '
                  'replacement prescription.'
            : '$label ($where) expires on ${_formatDate(pen.expiresOn)}. '
                  'Arrange a replacement prescription.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        // Inexact is the right trade here: an expiry reminder that arrives
        // within the hour is as useful as one to the second, and exact alarms
        // need a permission Google Play restricts to alarm and calling apps.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: pen.id,
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleEpiExpiry failed: $e');
    }
  }

  /// Cancels the expiry reminder for the pen with this [id].
  static Future<void> cancelEpiExpiry(String id) async {
    try {
      await init();
      if (!_initialised) return;
      await _plugin.cancel(notificationIdFor(id));
    } catch (e) {
      debugPrint('NotificationService.cancelEpiExpiry failed: $e');
    }
  }

  /// Cancels every reminder this app has scheduled.
  static Future<void> cancelAll() async {
    try {
      await init();
      if (!_initialised) return;
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService.cancelAll failed: $e');
    }
  }

  /// The pending reminders the platform currently holds, for diagnostics.
  static Future<List<PendingNotificationRequest>> pending() async {
    try {
      await init();
      if (!_initialised) return const <PendingNotificationRequest>[];
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('NotificationService.pending failed: $e');
      return const <PendingNotificationRequest>[];
    }
  }

  /// A stable notification id derived from a pen id.
  ///
  /// Stable is the point: it lets a later save or delete find and replace the
  /// reminder without storing a second identifier alongside the pen.
  static int notificationIdFor(String penId) => penId.hashCode.abs() % 100000;

  static const List<String> _months = <String>[
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

  static String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';
}
