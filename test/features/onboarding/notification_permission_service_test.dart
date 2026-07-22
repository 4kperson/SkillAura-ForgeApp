import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/onboarding/data/notification_permission_service.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('maps every accepted native status to granted', () {
    expect(
      notificationPreferenceFor(PermissionStatus.granted),
      NotificationPreference.granted,
    );
    expect(
      notificationPreferenceFor(PermissionStatus.provisional),
      NotificationPreference.granted,
    );
  });

  test('maps native refusal states to denied', () {
    for (final status in [
      PermissionStatus.denied,
      PermissionStatus.permanentlyDenied,
      PermissionStatus.restricted,
    ]) {
      expect(notificationPreferenceFor(status), NotificationPreference.denied);
    }
  });

  test('uses valid unique identifiers for Forge-owned reminders', () {
    final ids = DeviceNotificationPermissionService.reminderIds;

    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, everyElement(greaterThanOrEqualTo(0)));
  });

  test(
    'skipped recovery uses the native prompt when still available',
    () async {
      final permissions = _FakePermissionGateway(
        currentStatus: PermissionStatus.denied,
        requestedStatus: PermissionStatus.granted,
      );
      final service = DeviceNotificationPermissionService(
        platform: _FakeNotificationPlatform(),
        permissions: permissions,
      );

      final result = await service.helpEnable(NotificationPreference.skipped);

      expect(result.state, NotificationRecoveryState.granted);
      expect(permissions.requestCalls, 1);
      expect(permissions.openSettingsCalls, 0);
    },
  );

  test('iOS denial recovery opens app settings without re-prompting', () async {
    final permissions = _FakePermissionGateway(
      targetPlatform: TargetPlatform.iOS,
      currentStatus: PermissionStatus.denied,
    );
    final service = DeviceNotificationPermissionService(
      platform: _FakeNotificationPlatform(),
      permissions: permissions,
    );

    final result = await service.helpEnable(NotificationPreference.denied);

    expect(result.state, NotificationRecoveryState.settingsOpened);
    expect(permissions.requestCalls, 0);
    expect(permissions.openSettingsCalls, 1);
  });

  test('Android denial recovery uses an available native re-prompt', () async {
    final permissions = _FakePermissionGateway(
      currentStatus: PermissionStatus.denied,
      requestedStatus: PermissionStatus.granted,
    );
    final service = DeviceNotificationPermissionService(
      platform: _FakeNotificationPlatform(),
      permissions: permissions,
    );

    final result = await service.helpEnable(NotificationPreference.denied);

    expect(result.state, NotificationRecoveryState.granted);
    expect(permissions.requestCalls, 1);
    expect(permissions.openSettingsCalls, 0);
  });

  test('permanent denial recovery opens platform app settings', () async {
    final permissions = _FakePermissionGateway(
      currentStatus: PermissionStatus.permanentlyDenied,
    );
    final service = DeviceNotificationPermissionService(
      platform: _FakeNotificationPlatform(),
      permissions: permissions,
    );

    final result = await service.helpEnable(NotificationPreference.denied);

    expect(result.state, NotificationRecoveryState.settingsOpened);
    expect(permissions.requestCalls, 0);
    expect(permissions.openSettingsCalls, 1);
  });

  test(
    'resume check observes permission enabled in platform settings',
    () async {
      final permissions = _FakePermissionGateway(
        currentStatus: PermissionStatus.granted,
      );
      final service = DeviceNotificationPermissionService(
        platform: _FakeNotificationPlatform(),
        permissions: permissions,
      );

      final preference = await service.currentPermission();

      expect(preference, NotificationPreference.granted);
      expect(permissions.statusCalls, 1);
    },
  );

  test('builds one daily reminder for each personalized starter habit', () {
    const profile = OnboardingProfile(
      goals: [
        OnboardingGoal.disciplined,
        OnboardingGoal.productive,
        OnboardingGoal.betterSleep,
      ],
      disciplineLevel: DisciplineLevel.improving,
      wakeTimeMinutes: 6 * 60 + 30,
      sleepTimeMinutes: 22 * 60 + 30,
      notificationPreference: NotificationPreference.granted,
    );

    final reminders = buildDailyReminders(profile);

    expect(reminders, hasLength(3));
    expect(reminders.map((reminder) => reminder.title), [
      'Plan your three priorities',
      '35 minutes of focused work',
      'Begin a 35-minute wind-down',
    ]);
    expect(reminders.map((reminder) => (reminder.hour, reminder.minute)), [
      (7, 0),
      (8, 0),
      (21, 55),
    ]);
  });

  test('granted permission schedules every personalized reminder', () async {
    final platform = _FakeNotificationPlatform();
    final service = DeviceNotificationPermissionService(platform: platform);

    final result = await service.synchronize(_profile());

    expect(result.remindersReady, isTrue);
    expect(result.schedulingState, ReminderSchedulingState.scheduled);
    expect(
      platform.scheduledIds,
      DeviceNotificationPermissionService.reminderIds,
    );
    expect(platform.initializePluginCalls, 1);
    expect(platform.createChannelCalls, 1);
  });

  test(
    'habit plan schedules distinct weekday reminders after cleanup',
    () async {
      final platform = _FakeNotificationPlatform(
        pendingIds: {
          4100,
          DeviceNotificationPermissionService.habitReminderIdStart + 12,
        },
      );
      final service = DeviceNotificationPermissionService(platform: platform);

      final result = await service.synchronizeHabitPlan(
        timeZone: 'UTC',
        permissionState: NotificationPreference.granted,
        reminders: const [
          HabitReminder(
            id: 1000000101,
            title: 'Deep work',
            hour: 9,
            minute: 15,
            weekday: 1,
            timeZone: 'UTC',
          ),
          HabitReminder(
            id: 1000000103,
            title: 'Deep work',
            hour: 9,
            minute: 15,
            weekday: 3,
            timeZone: 'UTC',
          ),
        ],
      );

      expect(result, isTrue);
      expect(platform.cancelledIds, containsAll([4100, 1000000012]));
      expect(platform.scheduledIds, containsAll([1000000101, 1000000103]));
      expect(platform.scheduledReminders[1000000101]?.weekday, 1);
      expect(platform.scheduledReminders[1000000103]?.weekday, 3);
    },
  );

  test(
    'disabled permission clears habit reminders without rescheduling',
    () async {
      final platform = _FakeNotificationPlatform(
        pendingIds: {1000000101, 1000000103},
      );
      final service = DeviceNotificationPermissionService(platform: platform);

      final result = await service.synchronizeHabitPlan(
        timeZone: 'UTC',
        permissionState: NotificationPreference.denied,
        reminders: const [],
      );

      expect(result, isTrue);
      expect(platform.cancelledIds, containsAll([1000000101, 1000000103]));
      expect(platform.scheduledIds, isEmpty);
    },
  );

  test(
    'granted permission reports scheduling failure and rolls back',
    () async {
      final platform = _FakeNotificationPlatform(failingScheduleId: 4101);
      final service = DeviceNotificationPermissionService(platform: platform);

      final result = await service.synchronize(_profile());

      expect(result.remindersReady, isFalse);
      expect(result.schedulingState, ReminderSchedulingState.failed);
      expect(platform.cancelledIds, containsAll(<int>[4100, 4101, 4102]));
    },
  );

  test(
    'denied permission treats zero reminders as successful cleanup',
    () async {
      final platform = _FakeNotificationPlatform();
      final service = DeviceNotificationPermissionService(platform: platform);

      final result = await service.synchronize(
        _profile(preference: NotificationPreference.denied),
      );

      expect(
        result.cancellationState,
        ReminderCancellationState.nothingToCancel,
      );
      expect(result.schedulingState, ReminderSchedulingState.notRequested);
      expect(platform.cancelledIds, isEmpty);
    },
  );

  test('denied permission cancels existing Forge reminders', () async {
    final platform = _FakeNotificationPlatform(pendingIds: {4100, 4102, 99});
    final service = DeviceNotificationPermissionService(platform: platform);

    final result = await service.synchronize(
      _profile(preference: NotificationPreference.denied),
    );

    expect(result.cancellationState, ReminderCancellationState.cancelled);
    expect(platform.cancelledIds, [4100, 4102]);
  });

  test(
    'skipped permission treats zero reminders as successful cleanup',
    () async {
      final platform = _FakeNotificationPlatform();
      final service = DeviceNotificationPermissionService(platform: platform);

      final result = await service.synchronize(
        _profile(preference: NotificationPreference.skipped),
      );

      expect(
        result.cancellationState,
        ReminderCancellationState.nothingToCancel,
      );
      expect(platform.cancelledIds, isEmpty);
    },
  );

  test('skipped permission cancels existing Forge reminders', () async {
    final platform = _FakeNotificationPlatform(pendingIds: {4101});
    final service = DeviceNotificationPermissionService(platform: platform);

    final result = await service.synchronize(
      _profile(preference: NotificationPreference.skipped),
    );

    expect(result.cancellationState, ReminderCancellationState.cancelled);
    expect(platform.cancelledIds, [4101]);
  });

  test('cleanup reports failure but still attempts every owned ID', () async {
    final platform = _FakeNotificationPlatform(
      pendingIds: {4100, 4101, 4102},
      failingCancellationIds: {4101},
    );
    final service = DeviceNotificationPermissionService(platform: platform);

    final result = await service.synchronize(
      _profile(preference: NotificationPreference.denied),
    );

    expect(result.cancellationState, ReminderCancellationState.failed);
    expect(platform.cancellationAttempts, [4100, 4101, 4102]);
  });

  test('cancellation always waits for one-time initialization', () async {
    final platform = _FakeNotificationPlatform(pendingIds: {4100});
    final service = DeviceNotificationPermissionService(platform: platform);

    await service.synchronize(
      _profile(preference: NotificationPreference.denied),
    );
    await service.synchronize(
      _profile(preference: NotificationPreference.skipped),
    );

    expect(platform.operations.take(4), [
      'timezone',
      'plugin',
      'channel',
      'pending',
    ]);
    expect(platform.initializePluginCalls, 1);
    expect(platform.createChannelCalls, 1);
  });

  test('persisted notification choice survives profile reconstruction', () {
    final restored = OnboardingProfile.fromJson({
      'notification_permission_state': 'denied',
      'notifications_enabled': false,
    });

    expect(restored.notificationPreference, NotificationPreference.denied);
    expect(restored.notificationsEnabled, isFalse);
  });
}

OnboardingProfile _profile({
  NotificationPreference preference = NotificationPreference.granted,
}) => OnboardingProfile(
  goals: const [OnboardingGoal.disciplined],
  disciplineLevel: DisciplineLevel.starting,
  notificationPreference: preference,
);

class _FakeNotificationPlatform implements LocalNotificationPlatform {
  _FakeNotificationPlatform({
    Set<int>? pendingIds,
    this.failingScheduleId,
    Set<int>? failingCancellationIds,
  }) : pendingIds = pendingIds ?? <int>{},
       failingCancellationIds = failingCancellationIds ?? <int>{};

  final Set<int> pendingIds;
  final int? failingScheduleId;
  final Set<int> failingCancellationIds;
  final List<String> operations = [];
  final List<int> scheduledIds = [];
  final Map<int, DailyReminder> scheduledReminders = {};
  final List<int> cancelledIds = [];
  final List<int> cancellationAttempts = [];
  int initializePluginCalls = 0;
  int createChannelCalls = 0;

  @override
  Future<void> initializeTimeZone(String fallbackTimeZone) async {
    operations.add('timezone');
  }

  @override
  Future<void> initializePlugin() async {
    operations.add('plugin');
    initializePluginCalls++;
  }

  @override
  Future<void> createReminderChannel() async {
    operations.add('channel');
    createChannelCalls++;
  }

  @override
  Future<Set<int>> pendingNotificationIds() async {
    operations.add('pending');
    return Set<int>.of(pendingIds);
  }

  @override
  Future<void> cancel(int id) async {
    operations.add('cancel:$id');
    cancellationAttempts.add(id);
    if (failingCancellationIds.contains(id)) {
      throw StateError('cancellation failed');
    }
    cancelledIds.add(id);
    pendingIds.remove(id);
  }

  @override
  Future<void> schedule(int id, DailyReminder reminder) async {
    operations.add('schedule:$id');
    if (id == failingScheduleId) throw StateError('schedule failed');
    scheduledIds.add(id);
    scheduledReminders[id] = reminder;
    pendingIds.add(id);
  }
}

class _FakePermissionGateway implements NativeNotificationPermissionGateway {
  _FakePermissionGateway({
    this.targetPlatform = TargetPlatform.android,
    required this.currentStatus,
    this.requestedStatus = PermissionStatus.denied,
  });

  @override
  final TargetPlatform targetPlatform;
  PermissionStatus currentStatus;
  final PermissionStatus requestedStatus;
  var statusCalls = 0;
  var requestCalls = 0;
  var openSettingsCalls = 0;

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }

  @override
  Future<PermissionStatus> request() async {
    requestCalls++;
    currentStatus = requestedStatus;
    return requestedStatus;
  }

  @override
  Future<PermissionStatus> status() async {
    statusCalls++;
    return currentStatus;
  }
}
