import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../domain/onboarding_profile.dart';

abstract interface class NotificationPermissionService {
  Future<NotificationPreference> requestPermission();

  Future<void> synchronize(OnboardingProfile profile);
}

class DeviceNotificationPermissionService
    implements NotificationPermissionService {
  DeviceNotificationPermissionService({
    FlutterLocalNotificationsPlugin? notifications,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _firstReminderId = 4100;
  static const _reminderSlots = 3;
  static const _channelId = 'daily_promises';
  static const _channelName = 'Daily promises';
  static const _channelDescription =
      'Quiet reminders for the commitments in your daily plan.';

  final FlutterLocalNotificationsPlugin _notifications;
  Future<void>? _initialization;

  @override
  Future<NotificationPreference> requestPermission() async {
    final status = await Permission.notification.request();
    return notificationPreferenceFor(status);
  }

  @override
  Future<void> synchronize(OnboardingProfile profile) async {
    await (_initialization ??= _initialize(profile.timeZone));
    await Future.wait([
      for (var index = 0; index < _reminderSlots; index++)
        _notifications.cancel(id: _firstReminderId + index),
    ]);

    if (profile.notificationPreference != NotificationPreference.granted) {
      return;
    }

    final reminders = buildDailyReminders(profile);
    for (var index = 0; index < reminders.length; index++) {
      final reminder = reminders[index];
      await _notifications.zonedSchedule(
        id: _firstReminderId + index,
        title: 'Your next promise is ready',
        body: reminder.title,
        scheduledDate: _nextOccurrence(reminder.hour, reminder.minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '/home',
      );
    }
  }

  Future<void> _initialize(String fallbackTimeZone) async {
    time_zone_data.initializeTimeZones();
    await _setLocalTimeZone(fallbackTimeZone);
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<void> _setLocalTimeZone(String fallback) async {
    try {
      final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
      time_zone.setLocalLocation(
        time_zone.getLocation(deviceTimeZone.identifier),
      );
      return;
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('Could not read the device time zone: $error');
        debugPrintStack(stackTrace: stack);
      }
    }

    try {
      time_zone.setLocalLocation(time_zone.getLocation(fallback));
    } catch (_) {
      time_zone.setLocalLocation(time_zone.UTC);
    }
  }

  static time_zone.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = time_zone.TZDateTime.now(time_zone.local);
    var scheduled = time_zone.TZDateTime(
      time_zone.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = time_zone.TZDateTime(
        time_zone.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }
    return scheduled;
  }
}

class DisabledNotificationPermissionService
    implements NotificationPermissionService {
  const DisabledNotificationPermissionService();

  @override
  Future<NotificationPreference> requestPermission() async =>
      NotificationPreference.denied;

  @override
  Future<void> synchronize(OnboardingProfile profile) async {}
}

NotificationPreference notificationPreferenceFor(PermissionStatus status) {
  if (status == PermissionStatus.granted ||
      status == PermissionStatus.provisional) {
    return NotificationPreference.granted;
  }
  return NotificationPreference.denied;
}

List<DailyReminder> buildDailyReminders(OnboardingProfile profile) => [
  for (final habit in profile.recommendedHabits)
    DailyReminder(
      title: habit.title,
      hour: habit.scheduledMinutes ~/ 60,
      minute: habit.scheduledMinutes % 60,
    ),
];

class DailyReminder {
  const DailyReminder({
    required this.title,
    required this.hour,
    required this.minute,
  });

  final String title;
  final int hour;
  final int minute;
}
