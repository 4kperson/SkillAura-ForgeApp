import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../habits/domain/habit.dart';
import '../../onboarding/data/notification_permission_service.dart';
import '../../onboarding/domain/onboarding_profile.dart';
import '../data/morning_repository.dart';
import '../domain/morning_snapshot.dart';
import 'morning_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.onSignOut,
    this.onManageHabits = _unavailableHabitManager,
    this.onEnableReminders = _unavailableReminderRecovery,
    this.onRefreshReminderPermission = _unavailablePermissionRefresh,
  });

  final MorningRepository repository;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onManageHabits;
  final Future<NotificationRecoveryResult> Function() onEnableReminders;
  final Future<bool> Function() onRefreshReminderPermission;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

Future<NotificationRecoveryResult> _unavailableReminderRecovery() async =>
    const NotificationRecoveryResult(
      state: NotificationRecoveryState.failed,
      preference: NotificationPreference.denied,
    );

Future<bool> _unavailablePermissionRefresh() async => false;

Future<void> _unavailableHabitManager() async {}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final MorningController _controller;
  var _reminderActionInProgress = false;
  var _awaitingNotificationSettings = false;
  String? _reminderActionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MorningController(widget.repository)
      ..addListener(_onChanged)
      ..initialize();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_awaitingNotificationSettings ||
        _reminderActionInProgress) {
      return;
    }
    _awaitingNotificationSettings = false;
    unawaited(_restoreReminderPermission());
  }

  Future<void> _enableReminders() async {
    if (_reminderActionInProgress) return;
    setState(() {
      _reminderActionInProgress = true;
      _reminderActionError = null;
    });
    try {
      final recovery = await widget.onEnableReminders();
      if (!mounted) return;
      switch (recovery.state) {
        case NotificationRecoveryState.granted:
          await _controller.initialize();
          break;
        case NotificationRecoveryState.settingsOpened:
          _awaitingNotificationSettings = true;
          break;
        case NotificationRecoveryState.denied:
          break;
        case NotificationRecoveryState.failed:
          setState(() {
            _reminderActionError =
                'Forge could not open notification settings. Please try again.';
          });
          break;
      }
    } finally {
      if (mounted) setState(() => _reminderActionInProgress = false);
    }
  }

  Future<void> _restoreReminderPermission() async {
    if (!mounted || _reminderActionInProgress) return;
    setState(() {
      _reminderActionInProgress = true;
      _reminderActionError = null;
    });
    try {
      if (await widget.onRefreshReminderPermission()) {
        await _controller.initialize();
      }
    } finally {
      if (mounted) setState(() => _reminderActionInProgress = false);
    }
  }

  Future<void> _openHabitManager() async {
    await widget.onManageHabits();
    if (mounted) await _controller.initialize();
  }

  Future<void> _completeHabit(Habit habit) async {
    final saved = await _controller.toggleHabit(habit.id);
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${habit.title} completed. +${habit.xp} XP'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          backgroundColor: AppColors.surfaceElevated,
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primaryBright,
            onPressed: () => unawaited(_controller.undoHabit(habit.id)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF110D20),
              AppColors.background,
              Color(0xFF07070C),
            ],
            stops: [0, .42, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(top: -170, right: -130, child: _HomeGlow()),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey(_controller.status),
                  child: _buildState(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildState() {
    final snapshot = _controller.snapshot;
    if (_controller.status == MorningStatus.loading && snapshot == null) {
      return const _MorningLoadingState();
    }
    if (_controller.status == MorningStatus.failed && snapshot == null) {
      return _MorningErrorState(
        message:
            _controller.errorMessage ?? 'Your morning could not be loaded.',
        onRetry: _controller.initialize,
      );
    }
    return _MorningExperience(
      snapshot: snapshot!,
      controller: _controller,
      onSignOut: widget.onSignOut,
      onRefresh: _controller.initialize,
      onManageHabits: _openHabitManager,
      onCompleteHabit: _completeHabit,
      onEnableReminders: _enableReminders,
      reminderActionInProgress: _reminderActionInProgress,
      reminderActionError: _reminderActionError,
    );
  }
}

class _MorningExperience extends StatelessWidget {
  const _MorningExperience({
    required this.snapshot,
    required this.controller,
    required this.onSignOut,
    required this.onRefresh,
    required this.onManageHabits,
    required this.onCompleteHabit,
    required this.onEnableReminders,
    required this.reminderActionInProgress,
    required this.reminderActionError,
  });

  final MorningSnapshot snapshot;
  final MorningController controller;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onRefresh;
  final VoidCallback onManageHabits;
  final ValueChanged<Habit> onCompleteHabit;
  final VoidCallback onEnableReminders;
  final bool reminderActionInProgress;
  final String? reminderActionError;

  @override
  Widget build(BuildContext context) {
    final missionHabits = snapshot.habits
        .where(
          (habit) =>
              !habit.isComplete || controller.isRecentlyCompleted(habit.id),
        )
        .toList(growable: false);
    return RefreshIndicator(
      color: AppColors.primaryBright,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _MorningHeader(name: snapshot.displayName, onSignOut: onSignOut),
          const SizedBox(height: 24),
          _IdentityBanner(identity: snapshot.identityLabel),
          if (!snapshot.notificationsEnabled) ...[
            const SizedBox(height: 10),
            _ReminderStatus(
              isBusy: reminderActionInProgress,
              message: reminderActionError,
              onTap: onEnableReminders,
            ),
          ],
          const SizedBox(height: 14),
          _ProgressHero(snapshot: snapshot),
          const SizedBox(height: 30),
          _MissionHeader(snapshot: snapshot, onManageHabits: onManageHabits),
          const SizedBox(height: 13),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: snapshot.habits.isEmpty
                  ? const _NoMissionsCard(key: ValueKey('empty'))
                  : missionHabits.isEmpty
                  ? _DayCompleteCard(key: const ValueKey('complete'))
                  : Column(
                      key: ValueKey(missionHabits.length),
                      children: [
                        for (
                          var index = 0;
                          index < missionHabits.length;
                          index++
                        ) ...[
                          _MissionCard(
                            habit: missionHabits[index],
                            isNext:
                                index == 0 && !missionHabits[index].isComplete,
                            isSaving: controller.isUpdating(
                              missionHabits[index].id,
                            ),
                            onComplete: () =>
                                onCompleteHabit(missionHabits[index]),
                          ),
                          if (index < missionHabits.length - 1)
                            const SizedBox(height: 11),
                        ],
                      ],
                    ),
            ),
          ),
          if (controller.errorMessage case final message?) ...[
            const SizedBox(height: 12),
            _InlineMessage(message: message),
          ],
          const SizedBox(height: 30),
          _MomentumCard(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _MorningHeader extends StatelessWidget {
  const _MorningHeader({required this.name, required this.onSignOut});

  final String name;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Make today count.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Sign out',
          child: IconButton(
            onPressed: onSignOut,
            tooltip: 'Sign out',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .055),
              side: BorderSide(color: Colors.white.withValues(alpha: .08)),
              fixedSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
          ),
        ),
      ],
    );
  }
}

class _IdentityBanner extends StatelessWidget {
  const _IdentityBanner({required this.identity});

  final String identity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryBright.withValues(alpha: .18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.north_east_rounded,
            color: AppColors.primaryBright,
            size: 18,
          ),
          const SizedBox(width: 10),
          const Text(
            'BECOMING',
            style: TextStyle(
              color: AppColors.primaryBright,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              identity,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderStatus extends StatelessWidget {
  const _ReminderStatus({
    required this.isBusy,
    required this.message,
    required this.onTap,
  });

  final bool isBusy;
  final String? message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isBusy,
      label: 'Reminders are off. Tap to enable reminders.',
      child: Material(
        color: AppColors.primary.withValues(alpha: .075),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.primaryBright.withValues(alpha: .18),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isBusy ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.notifications_off_outlined,
                    color: AppColors.primaryBright,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reminders are off',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message ?? 'Tap to enable your daily cues',
                        style: TextStyle(
                          color: message == null
                              ? AppColors.textSecondary
                              : const Color(0xFFFFC2CD),
                          fontSize: 11,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isBusy
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          key: ValueKey('arrow'),
                          color: AppColors.primaryBright,
                          size: 20,
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

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.snapshot});

  final MorningSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final level = snapshot.levelProgress;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF242039), Color(0xFF151421)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 36,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(
                label: 'DAY ${snapshot.dayNumber.toString().padLeft(2, '0')}',
              ),
              const Spacer(),
              _Pill(
                label: '${snapshot.currentStreak} DAY STREAK',
                icon: Icons.local_fire_department_rounded,
                warm: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            snapshot.dayIdentity,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.12,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _LevelHalo(progress: level.fraction, level: level.level),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snapshot.totalXp} TOTAL XP',
                      style: const TextStyle(
                        color: AppColors.primaryBright,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${level.xpRemaining} XP until Level ${level.level + 1}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _XpTrail(progress: level.fraction),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flag_rounded,
                  color: AppColors.primaryBright,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Next milestone · ${snapshot.nextAchievement}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({required this.snapshot, required this.onManageHabits});

  final MorningSnapshot snapshot;
  final VoidCallback onManageHabits;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TODAY'S MISSION",
                style: TextStyle(
                  color: AppColors.primaryBright,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Keep the next promise.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${snapshot.completedCount}/${snapshot.totalCount} kept',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Semantics(
              button: true,
              label: 'Manage habits',
              child: InkWell(
                onTap: onManageHabits,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 15,
                        color: AppColors.primaryBright,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Manage',
                        style: TextStyle(
                          color: AppColors.primaryBright,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.habit,
    required this.isNext,
    required this.isSaving,
    required this.onComplete,
  });

  final Habit habit;
  final bool isNext;
  final bool isSaving;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: habit.isComplete,
      label: habit.isComplete
          ? '${habit.title} completed for ${habit.xp} XP'
          : 'Complete ${habit.title} for ${habit.xp} XP',
      child: Material(
        color: habit.isComplete
            ? AppColors.success.withValues(alpha: .09)
            : isNext
            ? AppColors.primary.withValues(alpha: .11)
            : Colors.white.withValues(alpha: .042),
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          onTap: isSaving || habit.isComplete ? null : onComplete,
          borderRadius: BorderRadius.circular(23),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: habit.isComplete
                    ? AppColors.success.withValues(alpha: .24)
                    : isNext
                    ? AppColors.primaryBright.withValues(alpha: .25)
                    : Colors.white.withValues(alpha: .075),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _habitIcon(habit),
                    color: AppColors.primaryBright,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNext) ...[
                        const Text(
                          'NEXT PROMISE',
                          style: TextStyle(
                            color: AppColors.primaryBright,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        habit.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _habitDetails(habit),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Text(
                      '+${habit.xp} XP',
                      style: const TextStyle(
                        color: AppColors.primaryBright,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox.square(
                      dimension: 30,
                      child: isSaving
                          ? const Padding(
                              key: ValueKey('promise-loading'),
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : habit.isComplete
                          ? const DecoratedBox(
                              key: ValueKey('promise-completed'),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            )
                          : DecoratedBox(
                              key: const ValueKey('promise-incomplete'),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .025),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryBright.withValues(
                                    alpha: .5,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBright.withValues(
                                      alpha: .16,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MomentumCard extends StatelessWidget {
  const _MomentumCard({required this.snapshot});

  final MorningSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .075)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MOMENTUM',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _MomentumMetric(
                  icon: Icons.local_fire_department_rounded,
                  value: '${snapshot.currentStreak}',
                  label: 'current streak',
                  accent: const Color(0xFFFFB867),
                ),
              ),
              Container(
                width: 1,
                height: 54,
                color: Colors.white.withValues(alpha: .08),
              ),
              Expanded(
                child: _MomentumMetric(
                  icon: Icons.emoji_events_rounded,
                  value: '${snapshot.longestStreak}',
                  label: 'personal best',
                  accent: AppColors.primaryBright,
                ),
              ),
              Container(
                width: 1,
                height: 54,
                color: Colors.white.withValues(alpha: .08),
              ),
              Expanded(
                child: _MomentumMetric(
                  icon: Icons.bolt_rounded,
                  value: '${snapshot.todayXp}',
                  label: 'XP today',
                  accent: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelHalo extends StatelessWidget {
  const _LevelHalo({required this.progress, required this.level});

  final double progress;
  final int level;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 88,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0, 1)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                color: AppColors.primaryBright,
                backgroundColor: Colors.white.withValues(alpha: .07),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LEVEL',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                '$level',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _XpTrail extends StatelessWidget {
  const _XpTrail({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(99),
        ),
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          width: constraints.maxWidth * progress.clamp(0, 1),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryBright],
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .45),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.icon, this.warm = false});

  final String label;
  final IconData? icon;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final color = warm ? const Color(0xFFFFB867) : AppColors.primaryBright;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final value?) ...[
            Icon(value, color: color, size: 13),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentumMetric extends StatelessWidget {
  const _MomentumMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: accent, size: 19),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DayCompleteCard extends StatelessWidget {
  const _DayCompleteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: .14),
            AppColors.primary.withValues(alpha: .09),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.success.withValues(alpha: .24)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.success, size: 30),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Every promise kept.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You finished today. Tomorrow begins with momentum.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

class _NoMissionsCard extends StatelessWidget {
  const _NoMissionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: .075)),
      ),
      child: const Row(
        children: [
          Icon(Icons.sync_rounded, color: AppColors.primaryBright, size: 28),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your plan is catching up.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pull to refresh while Forge restores today’s mission.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
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

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.warning,
          size: 18,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MorningLoadingState extends StatelessWidget {
  const _MorningLoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        SizedBox(height: 16),
        Text(
          'Preparing your day…',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _MorningErrorState extends StatelessWidget {
  const _MorningErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.primaryBright,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your progress is still safe.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Load my day')),
        ],
      ),
    ),
  );
}

class _HomeGlow extends StatelessWidget {
  const _HomeGlow();

  @override
  Widget build(BuildContext context) => Container(
    width: 370,
    height: 370,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [AppColors.primary.withValues(alpha: .2), Colors.transparent],
      ),
    ),
  );
}

IconData _habitIcon(Habit habit) => switch (habit.symbol) {
  HabitSymbol.shield => Icons.shield_rounded,
  HabitSymbol.heart => Icons.favorite_rounded,
  HabitSymbol.target => Icons.center_focus_strong_rounded,
  HabitSymbol.book => Icons.menu_book_rounded,
  HabitSymbol.moon => Icons.bedtime_rounded,
  HabitSymbol.phone => Icons.phone_android_rounded,
  HabitSymbol.spark => Icons.auto_awesome_rounded,
  HabitSymbol.bolt => Icons.bolt_rounded,
  HabitSymbol.leaf => Icons.eco_rounded,
};

String _habitDetails(Habit habit) {
  final details = <String>[];
  if (habit.reminderMinutes case final minutes?) {
    var hour = minutes ~/ 60;
    final minute = (minutes % 60).toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    if (hour == 0) hour = 12;
    if (hour > 12) hour -= 12;
    details.add('$hour:$minute $period');
  } else if (habit.scheduledTime case final time?) {
    final parts = time.split(':');
    if (parts.length >= 2) {
      var hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1];
      final period = hour < 12 ? 'AM' : 'PM';
      if (hour == 0) hour = 12;
      if (hour > 12) hour -= 12;
      details.add('$hour:$minute $period');
    }
  }
  if (habit.effortMinutes case final minutes?) details.add('$minutes min');
  return details.isEmpty ? 'Ready when you are' : details.join('  ·  ');
}
