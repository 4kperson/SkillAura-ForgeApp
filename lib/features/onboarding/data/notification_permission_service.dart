import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../domain/onboarding_profile.dart';

abstract interface class NotificationPermissionService {
  Future<NotificationPreference> requestPermission();

  Future<NotificationSyncResult> synchronize(OnboardingProfile profile);
}

enum ReminderSchedulingState { notRequested, scheduled, failed }

enum ReminderCancellationState {
  notRequested,
  nothingToCancel,
  cancelled,
  failed,
}

class NotificationSyncResult {
  const NotificationSyncResult({
    required this.permissionState,
    required this.initializationSucceeded,
    required this.schedulingState,
    required this.cancellationState,
  });

  final NotificationPreference permissionState;
  final bool initializationSucceeded;
  final ReminderSchedulingState schedulingState;
  final ReminderCancellationState cancellationState;

  bool get remindersReady =>
      initializationSucceeded &&
      schedulingState == ReminderSchedulingState.scheduled;
}

abstract interface class LocalNotificationPlatform {
  Future<void> initializeTimeZone(String fallbackTimeZone);

  Future<void> initializePlugin();

  Future<void> createReminderChannel();

  Future<Set<int>> pendingNotificationIds();

  Future<void> cancel(int id);

  Future<void> schedule(int id, DailyReminder reminder);
}

class DeviceNotificationPermissionService
    implements NotificationPermissionService {
  DeviceNotificationPermissionService({LocalNotificationPlatform? platform})
    : _platform = platform ?? FlutterLocalNotificationPlatform();

  static const reminderIds = <int>[4100, 4101, 4102];

  final LocalNotificationPlatform _platform;
  Future<void>? _initialization;

  @override
  Future<NotificationPreference> requestPermission() async {
    try {
      final status = await Permission.notification.request();
      _logSuccess('permission request', status.name);
      return notificationPreferenceFor(status);
    } catch (error, stackTrace) {
      _logFailure('permission request', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<NotificationSyncResult> synchronize(OnboardingProfile profile) async {
    try {
      await _ensureInitialized(profile.timeZone);
    } catch (_) {
      return NotificationSyncResult(
        permissionState: profile.notificationPreference,
        initializationSucceeded: false,
        schedulingState:
            profile.notificationPreference == NotificationPreference.granted
            ? ReminderSchedulingState.failed
            : ReminderSchedulingState.notRequested,
        cancellationState:
            profile.notificationPreference == NotificationPreference.granted
            ? ReminderCancellationState.notRequested
            : ReminderCancellationState.failed,
      );
    }

    final cancellationState = await _cancelOwnedReminders();
    if (profile.notificationPreference != NotificationPreference.granted) {
      return NotificationSyncResult(
        permissionState: profile.notificationPreference,
        initializationSucceeded: true,
        schedulingState: ReminderSchedulingState.notRequested,
        cancellationState: cancellationState,
      );
    }

    final schedulingState = await _scheduleReminders(profile);
    return NotificationSyncResult(
      permissionState: profile.notificationPreference,
      initializationSucceeded: true,
      schedulingState: schedulingState,
      cancellationState: cancellationState,
    );
  }

  Future<void> _ensureInitialized(String fallbackTimeZone) async {
    final existing = _initialization;
    if (existing != null) {
      await existing;
      return;
    }

    final initialization = _initialize(fallbackTimeZone);
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
      rethrow;
    }
  }

  Future<void> _initialize(String fallbackTimeZone) async {
    await _runOperation(
      'timezone initialization',
      () => _platform.initializeTimeZone(fallbackTimeZone),
    );
    await _runOperation('plugin initialization', _platform.initializePlugin);
    await _runOperation(
      'notification channel creation',
      _platform.createReminderChannel,
    );
  }

  Future<ReminderCancellationState> _cancelOwnedReminders() async {
    Set<int> pendingIds;
    try {
      pendingIds = await _runOperation(
        'pending reminder lookup',
        _platform.pendingNotificationIds,
      );
    } catch (_) {
      // A lookup failure must not leave stale Forge reminders behind. Cancelling
      // a missing ID is idempotent on supported platforms, so use the known IDs.
      pendingIds = reminderIds.toSet();
    }

    final ownedIds = reminderIds.where(pendingIds.contains).toList();
    if (ownedIds.isEmpty) {
      _logSuccess('reminder cancellation', 'nothing scheduled');
      return ReminderCancellationState.nothingToCancel;
    }

    var cancellationFailed = false;
    for (final id in ownedIds) {
      try {
        await _runOperation(
          'reminder cancellation (id $id)',
          () => _platform.cancel(id),
        );
      } catch (_) {
        cancellationFailed = true;
      }
    }
    return cancellationFailed
        ? ReminderCancellationState.failed
        : ReminderCancellationState.cancelled;
  }

  Future<ReminderSchedulingState> _scheduleReminders(
    OnboardingProfile profile,
  ) async {
    final reminders = buildDailyReminders(profile);
    try {
      for (var index = 0; index < reminders.length; index++) {
        final id = reminderIds[index];
        await _runOperation(
          'reminder scheduling (id $id)',
          () => _platform.schedule(id, reminders[index]),
        );
      }
      return ReminderSchedulingState.scheduled;
    } catch (_) {
      await _rollbackPartialSchedule();
      return ReminderSchedulingState.failed;
    }
  }

  Future<void> _rollbackPartialSchedule() async {
    for (final id in reminderIds) {
      try {
        await _runOperation(
          'failed schedule cleanup (id $id)',
          () => _platform.cancel(id),
        );
      } catch (_) {
        // Each failed operation is already logged with its full stack trace.
      }
    }
  }

  Future<T> _runOperation<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      final result = await action();
      _logSuccess(operation);
      return result;
    } catch (error, stackTrace) {
      _logFailure(operation, error, stackTrace);
      rethrow;
    }
  }

  static void _logSuccess(String operation, [String? detail]) {
    if (!kDebugMode) return;
    debugPrint(
      '[notifications] $operation succeeded${detail == null ? '' : ': $detail'}',
    );
  }

  static void _logFailure(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) return;
    debugPrint('[notifications] $operation failed: $error');
    debugPrintStack(
      label: '[notifications] $operation stack trace',
      stackTrace: stackTrace,
    );
  }
}

class FlutterLocalNotificationPlatform implements LocalNotificationPlatform {
  FlutterLocalNotificationPlatform({
    FlutterLocalNotificationsPlugin? notifications,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'daily_promises';
  static const _channelName = 'Daily promises';
  static const _channelDescription =
      'Quiet reminders for the commitments in your daily plan.';
  static const _notificationIcon = 'ic_stat_forge';

  final FlutterLocalNotificationsPlugin _notifications;

  @override
  Future<void> initializeTimeZone(String fallbackTimeZone) async {
    time_zone_data.initializeTimeZones();
    try {
      final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
      time_zone.setLocalLocation(
        time_zone.getLocation(deviceTimeZone.identifier),
      );
      return;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[notifications] device timezone lookup failed: $error');
        debugPrintStack(
          label: '[notifications] device timezone lookup stack trace',
          stackTrace: stackTrace,
        );
      }
    }

    try {
      time_zone.setLocalLocation(time_zone.getLocation(fallbackTimeZone));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[notifications] saved timezone lookup failed: $error');
        debugPrintStack(
          label: '[notifications] saved timezone lookup stack trace',
          stackTrace: stackTrace,
        );
      }
      time_zone.setLocalLocation(time_zone.UTC);
    }
  }

  @override
  Future<void> initializePlugin() async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_notificationIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<void> createReminderChannel() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<Set<int>> pendingNotificationIds() async => {
    for (final request in await _notifications.pendingNotificationRequests())
      request.id,
  };

  @override
  Future<void> cancel(int id) => _notifications.cancel(id: id);

  @override
  Future<void> schedule(int id, DailyReminder reminder) =>
      _notifications.zonedSchedule(
        id: id,
        title: 'Your next promise is ready',
        body: reminder.title,
        scheduledDate: _nextOccurrence(reminder.hour, reminder.minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: _notificationIcon,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        // Daily reminders do not need exact-alarm permission. Inexact delivery
        // remains compatible with modern Android background restrictions.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '/home',
      );

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
  Future<NotificationSyncResult> synchronize(OnboardingProfile profile) async =>
      NotificationSyncResult(
        permissionState: profile.notificationPreference,
        initializationSucceeded: true,
        schedulingState:
            profile.notificationPreference == NotificationPreference.granted
            ? ReminderSchedulingState.scheduled
            : ReminderSchedulingState.notRequested,
        cancellationState: ReminderCancellationState.nothingToCancel,
      );
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
