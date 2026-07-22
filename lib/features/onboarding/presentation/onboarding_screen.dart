import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../data/notification_permission_service.dart';
import '../data/onboarding_repository.dart';
import '../domain/onboarding_profile.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.repository,
    this.notificationPermissionService =
        const DisabledNotificationPermissionService(),
    this.onCompleted,
  });

  final OnboardingRepository? repository;
  final NotificationPermissionService notificationPermissionService;
  final ValueChanged<OnboardingProfile>? onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  late final OnboardingController _controller;
  late final PageController _pages;
  var _pageReady = false;
  var _notificationActionInProgress = false;
  var _awaitingNotificationSettings = false;
  String? _notificationActionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final repository =
        widget.repository ??
        SupabaseOnboardingRepository(Supabase.instance.client);
    _controller = OnboardingController(repository)..addListener(_onChanged);
    _pages = PageController();
    _controller.initialize();
  }

  void _onChanged() {
    if (!mounted) return;
    if (!_pageReady && _controller.status == OnboardingStatus.ready) {
      _pageReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients) {
          _pages.jumpToPage(_controller.profile.currentStep);
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_awaitingNotificationSettings ||
        _notificationActionInProgress) {
      return;
    }
    _awaitingNotificationSettings = false;
    unawaited(_restoreNotificationPermission());
  }

  Future<void> _goTo(int step) async {
    final saved = await _controller.moveTo(step);
    if (!saved || !mounted) return;
    await _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _requestNotifications() async {
    if (_notificationActionInProgress) return;
    setState(() {
      _notificationActionInProgress = true;
      _notificationActionError = null;
    });
    try {
      final preference = await widget.notificationPermissionService
          .requestPermission();
      if (preference == NotificationPreference.granted) {
        await _activateNotifications();
      } else {
        final saved = await _controller.setNotificationPreference(preference);
        if (saved) {
          await widget.notificationPermissionService.synchronize(
            _controller.profile,
          );
        }
      }
    } catch (error, stackTrace) {
      assert(() {
        debugPrint('[notifications] onboarding permission flow failed: $error');
        debugPrintStack(
          label: '[notifications] onboarding permission flow stack trace',
          stackTrace: stackTrace,
        );
        return true;
      }());
      if (mounted) {
        setState(() {
          _notificationActionError =
              'Your choice was saved, but reminders could not be prepared. Please try once more.';
        });
      }
    } finally {
      if (mounted) setState(() => _notificationActionInProgress = false);
    }
  }

  Future<void> _skipNotifications() async {
    if (_notificationActionInProgress) return;
    setState(() {
      _notificationActionInProgress = true;
      _notificationActionError = null;
    });
    final saved = await _controller.setNotificationPreference(
      NotificationPreference.skipped,
    );
    if (saved) {
      try {
        await widget.notificationPermissionService.synchronize(
          _controller.profile,
        );
      } catch (error, stackTrace) {
        assert(() {
          debugPrint('[notifications] skipped reminder cleanup failed: $error');
          debugPrintStack(
            label: '[notifications] skipped reminder cleanup stack trace',
            stackTrace: stackTrace,
          );
          return true;
        }());
      }
    }
    if (mounted) setState(() => _notificationActionInProgress = false);
  }

  Future<void> _helpEnableNotifications() async {
    if (_notificationActionInProgress) return;
    setState(() {
      _notificationActionInProgress = true;
      _notificationActionError = null;
    });
    try {
      final recovery = await widget.notificationPermissionService.helpEnable(
        _controller.profile.notificationPreference,
      );
      if (!mounted) return;
      switch (recovery.state) {
        case NotificationRecoveryState.granted:
          await _activateNotifications();
          break;
        case NotificationRecoveryState.settingsOpened:
          _awaitingNotificationSettings = true;
          break;
        case NotificationRecoveryState.denied:
          if (_controller.profile.notificationPreference !=
              recovery.preference) {
            await _controller.setNotificationPreference(recovery.preference);
          }
          break;
        case NotificationRecoveryState.failed:
          setState(() {
            _notificationActionError =
                'Forge could not open notification settings. Please try again.';
          });
          break;
      }
    } finally {
      if (mounted) setState(() => _notificationActionInProgress = false);
    }
  }

  Future<void> _restoreNotificationPermission() async {
    if (!mounted || _notificationActionInProgress) return;
    setState(() {
      _notificationActionInProgress = true;
      _notificationActionError = null;
    });
    try {
      final preference = await widget.notificationPermissionService
          .currentPermission();
      if (preference == NotificationPreference.granted) {
        await _activateNotifications();
      }
    } finally {
      if (mounted) setState(() => _notificationActionInProgress = false);
    }
  }

  Future<void> _activateNotifications() async {
    final candidate = _controller.profile.copyWith(
      notificationPreference: NotificationPreference.granted,
    );
    final result = await widget.notificationPermissionService.synchronize(
      candidate,
    );
    if (!mounted) return;
    if (!result.remindersReady) {
      setState(() {
        _notificationActionError =
            'Notifications are enabled, but reminders could not be prepared. Please try again.';
      });
      return;
    }
    final saved = await _controller.setNotificationPreference(
      NotificationPreference.granted,
    );
    if (saved && mounted) await _goTo(6);
  }

  Future<void> _finish() async {
    if (!await _controller.complete() || !mounted) return;
    if (widget.onCompleted case final callback?) {
      callback(_controller.profile);
    } else {
      context.go('/home');
    }
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
              Color(0xFF0F0B1B),
              AppColors.background,
              Color(0xFF08080D),
            ],
            stops: [0, .46, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -150,
              right: -120,
              child: _AmbientGlow(size: 360),
            ),
            SafeArea(child: _buildState()),
          ],
        ),
      ),
    );
  }

  Widget _buildState() {
    return switch (_controller.status) {
      OnboardingStatus.loading => const _LoadingState(),
      OnboardingStatus.failed when !_pageReady => _ErrorState(
        message: _controller.errorMessage!,
        onRetry: _controller.initialize,
      ),
      OnboardingStatus.completed when !_pageReady => _LoadingState(
        onReady: () {
          if (widget.onCompleted case final callback?) {
            callback(_controller.profile);
          } else {
            context.go('/home');
          }
        },
      ),
      _ => _Journey(
        controller: _controller,
        pages: _pages,
        onNext: _goTo,
        onRequestNotifications: _requestNotifications,
        onSkipNotifications: _skipNotifications,
        onEnableNotifications: _helpEnableNotifications,
        onFinish: _finish,
        notificationActionInProgress: _notificationActionInProgress,
        notificationActionError: _notificationActionError,
      ),
    };
  }
}

class _Journey extends StatelessWidget {
  const _Journey({
    required this.controller,
    required this.pages,
    required this.onNext,
    required this.onRequestNotifications,
    required this.onSkipNotifications,
    required this.onEnableNotifications,
    required this.onFinish,
    required this.notificationActionInProgress,
    required this.notificationActionError,
  });

  final OnboardingController controller;
  final PageController pages;
  final Future<void> Function(int) onNext;
  final VoidCallback onRequestNotifications;
  final VoidCallback onSkipNotifications;
  final VoidCallback onEnableNotifications;
  final VoidCallback onFinish;
  final bool notificationActionInProgress;
  final String? notificationActionError;

  @override
  Widget build(BuildContext context) {
    final step = controller.profile.currentStep;
    return Column(
      children: [
        _ProgressHeader(
          step: step,
          onBack: step > 0 && step < 6 ? () => onNext(step - 1) : null,
        ),
        Expanded(
          child: PageView(
            controller: pages,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _WelcomeStep(onContinue: () => onNext(1)),
              _GoalStep(controller: controller, onContinue: () => onNext(2)),
              _DisciplineStep(
                controller: controller,
                onContinue: () => onNext(3),
              ),
              _RoutineStep(controller: controller, onContinue: () => onNext(4)),
              _PlanStep(
                profile: controller.profile,
                onContinue: () => onNext(5),
              ),
              _NotificationStep(
                preference: controller.profile.notificationPreference,
                isBusy: notificationActionInProgress,
                onAllow: onRequestNotifications,
                onSkip: onSkipNotifications,
                onEnable: onEnableNotifications,
                onContinueDenied: onFinish,
              ),
              _CompletionStep(profile: controller.profile, onFinish: onFinish),
            ],
          ),
        ),
        if (controller.errorMessage case final message?)
          _SaveError(message: message),
        if (notificationActionError case final message?)
          _SaveError(message: message),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.onBack});

  final int step;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: onBack == null
                ? const Center(child: _ForgeMark(size: 34))
                : IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Semantics(
              label: 'Onboarding progress, step ${step + 1} of 7',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (step + 1) / 7),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, child) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: .08),
                    color: AppColors.primaryBright,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${step + 1}/7',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.content,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
    this.secondary,
    this.onSecondary,
    this.centered = false,
    this.secondaryEnabled = true,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget content;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryEnabled;
  final String? secondary;
  final VoidCallback? onSecondary;
  final bool centered;
  final bool secondaryEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 92,
                  ),
                  child: Column(
                    mainAxisAlignment: centered
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    crossAxisAlignment: centered
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      _Entrance(
                        child: Text(
                          eyebrow.toUpperCase(),
                          textAlign: centered
                              ? TextAlign.center
                              : TextAlign.start,
                          style: const TextStyle(
                            color: AppColors.primaryBright,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Entrance(
                        delay: .08,
                        child: Text(
                          title,
                          textAlign: centered
                              ? TextAlign.center
                              : TextAlign.start,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 34,
                            height: 1.08,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Entrance(
                        delay: .14,
                        child: Text(
                          body,
                          textAlign: centered
                              ? TextAlign.center
                              : TextAlign.start,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                            height: 1.55,
                            letterSpacing: -.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _Entrance(delay: .2, child: content),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            _PrimaryButton(
              label: primaryLabel,
              onPressed: primaryEnabled ? onPrimary : null,
            ),
            if (secondary != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: secondaryEnabled ? onSecondary : null,
                child: Text(secondary!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      eyebrow: 'Your next chapter',
      title: 'You already took\nthe hardest step.',
      body:
          "You chose to begin. Now let's build the life you actually want—one promise kept at a time.",
      primaryLabel: 'Make the commitment',
      onPrimary: onContinue,
      centered: true,
      content: const SizedBox(
        height: 214,
        child: Center(child: _CommitmentOrb()),
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.controller, required this.onContinue});
  final OnboardingController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    const options = [
      (OnboardingGoal.disciplined, 'Build discipline', Icons.bolt_rounded),
      (OnboardingGoal.healthier, 'Improve health', Icons.favorite_rounded),
      (
        OnboardingGoal.productive,
        'Increase productivity',
        Icons.rocket_launch_rounded,
      ),
      (OnboardingGoal.student, 'Study better', Icons.school_rounded),
      (OnboardingGoal.betterSleep, 'Sleep better', Icons.bedtime_rounded),
      (
        OnboardingGoal.reduceScreenTime,
        'Reduce screen time',
        Icons.phone_android_rounded,
      ),
    ];
    return _StepFrame(
      eyebrow: 'The life you are building',
      title: 'What deserves more\nof your attention?',
      body:
          'Choose up to three. The right plan should reflect the life you want—not a generic checklist.',
      primaryLabel: 'Shape my path',
      primaryEnabled: controller.profile.goals.isNotEmpty,
      onPrimary: onContinue,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${controller.profile.goals.length} of ${OnboardingProfile.maxGoals} selected',
            style: const TextStyle(
              color: AppColors.primaryBright,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final option in options)
                  SizedBox(
                    width: math.max(150, (constraints.maxWidth - 12) / 2),
                    child: _ChoiceCard(
                      label: option.$2,
                      icon: option.$3,
                      selected: controller.profile.goals.contains(option.$1),
                      onTap: () => controller.toggleGoal(option.$1),
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

class _DisciplineStep extends StatelessWidget {
  const _DisciplineStep({required this.controller, required this.onContinue});
  final OnboardingController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    const options = [
      (
        DisciplineLevel.starting,
        'Beginner',
        'Short habits · lower XP targets · gentle momentum',
        Icons.wb_sunny_outlined,
      ),
      (
        DisciplineLevel.improving,
        'Intermediate',
        'Balanced effort · steady XP · stronger consistency',
        Icons.stairs_rounded,
      ),
      (
        DisciplineLevel.consistent,
        'Advanced',
        'Larger missions · higher XP · ambitious standards',
        Icons.workspace_premium_rounded,
      ),
    ];
    return _StepFrame(
      eyebrow: 'Set the right difficulty',
      title: 'What challenge will\nyou respect?',
      body:
          'We ask so your first week feels achievable—not trivial, not punishing. You can change this later.',
      primaryLabel: 'Set my starting standard',
      primaryEnabled: controller.profile.disciplineLevel != null,
      onPrimary: onContinue,
      content: Column(
        children: [
          for (final option in options) ...[
            _DetailedChoiceCard(
              title: option.$2,
              subtitle: option.$3,
              icon: option.$4,
              selected: controller.profile.disciplineLevel == option.$1,
              onTap: () => controller.selectDisciplineLevel(option.$1),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RoutineStep extends StatelessWidget {
  const _RoutineStep({required this.controller, required this.onContinue});
  final OnboardingController controller;
  final VoidCallback onContinue;

  Future<void> _pick(BuildContext context, {required bool wake}) async {
    final value = wake
        ? controller.profile.wakeTimeMinutes
        : controller.profile.sleepTimeMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
      helpText: wake ? 'WHEN DOES YOUR DAY BEGIN?' : 'WHEN DO YOU WIND DOWN?',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null) return;
    controller.setRoutine(
      wakeMinutes: wake
          ? selected.hour * 60 + selected.minute
          : controller.profile.wakeTimeMinutes,
      sleepMinutes: wake
          ? controller.profile.sleepTimeMinutes
          : selected.hour * 60 + selected.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      eyebrow: 'Protect your rhythm',
      title: 'When does your day\nbelong to you?',
      body:
          'Your wake and sleep times help us place each commitment where your energy can actually support it.',
      primaryLabel: 'Build around my rhythm',
      onPrimary: onContinue,
      content: Column(
        children: [
          _TimeCard(
            icon: Icons.wb_sunny_rounded,
            label: 'Wake-up time',
            value: _formatMinutes(context, controller.profile.wakeTimeMinutes),
            accent: const Color(0xFFFFC76B),
            onTap: () => _pick(context, wake: true),
          ),
          const SizedBox(height: 14),
          _TimeCard(
            icon: Icons.nightlight_round,
            label: 'Sleep time',
            value: _formatMinutes(context, controller.profile.sleepTimeMinutes),
            accent: const Color(0xFF9F8CFF),
            onTap: () => _pick(context, wake: false),
          ),
          const SizedBox(height: 22),
          const _InsightStrip(
            icon: Icons.auto_awesome_rounded,
            text: 'These moments will shape your plan—not just fill a profile.',
          ),
        ],
      ),
    );
  }
}

class _PlanStep extends StatelessWidget {
  const _PlanStep({required this.profile, required this.onContinue});
  final OnboardingProfile profile;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final habits = profile.recommendedHabits;
    return _StepFrame(
      eyebrow: 'Your personal Day One',
      title: 'This plan was built\naround you.',
      body:
          'Your goals chose the direction. Your level set the challenge. Your routine found the right moments.',
      primaryLabel: 'Commit to this Day One',
      onPrimary: onContinue,
      content: Column(
        children: [
          _InsightStrip(
            icon: Icons.tune_rounded,
            text: profile.personalizationSummary,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .045),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 32,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var index = 0; index < habits.length; index++) ...[
                  _PlanHabit(habit: habits[index]),
                  if (index < habits.length - 1)
                    Divider(
                      height: 25,
                      color: Colors.white.withValues(alpha: .07),
                    ),
                ],
                Divider(height: 25, color: Colors.white.withValues(alpha: .07)),
                Row(
                  children: [
                    const Text(
                      'DAY ONE PROGRESSION',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${profile.startingXpTarget} XP',
                      style: const TextStyle(
                        color: AppColors.primaryBright,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationStep extends StatelessWidget {
  const _NotificationStep({
    required this.preference,
    required this.isBusy,
    required this.onAllow,
    required this.onSkip,
    required this.onEnable,
    required this.onContinueDenied,
  });
  final NotificationPreference preference;
  final bool isBusy;
  final VoidCallback onAllow;
  final VoidCallback onSkip;
  final VoidCallback onEnable;
  final VoidCallback onContinueDenied;

  @override
  Widget build(BuildContext context) {
    if (preference == NotificationPreference.denied ||
        preference == NotificationPreference.skipped) {
      return _StepFrame(
        eyebrow: 'Reminders are off',
        title: 'Notifications are\ncurrently turned off.',
        body:
            "Forge will still work perfectly, but it won't be able to remind you when it's time to build your habits.",
        primaryLabel: isBusy ? 'Checking reminders...' : 'Enable reminders',
        primaryEnabled: !isBusy,
        onPrimary: onEnable,
        secondary: 'Continue without reminders',
        secondaryEnabled: !isBusy,
        onSecondary: onContinueDenied,
        content: const _NotificationTradeoff(),
      );
    }
    return _StepFrame(
      eyebrow: 'A quiet nudge',
      title: 'Support when\nintention gets busy.',
      body:
          "Forge can remind you at the moments you chose—never noise, never guilt, always in your control.",
      primaryLabel: isBusy ? 'Preparing reminders…' : 'Keep me on track',
      primaryEnabled: !isBusy,
      onPrimary: onAllow,
      secondary: 'Not now',
      secondaryEnabled: !isBusy,
      onSecondary: onSkip,
      content: Column(
        children: [
          const SizedBox(height: 8),
          const _NotificationPreview(),
          const SizedBox(height: 24),
          Row(
            children: const [
              Expanded(
                child: _Benefit(icon: Icons.tune_rounded, label: 'Your timing'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _Benefit(
                  icon: Icons.volume_off_rounded,
                  label: 'No noise',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _Benefit(
                  icon: Icons.lock_outline_rounded,
                  label: 'Private',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationTradeoff extends StatelessWidget {
  const _NotificationTradeoff();

  @override
  Widget build(BuildContext context) {
    const moments = [
      (
        Icons.wb_sunny_outlined,
        'Morning cue',
        'Your first commitment will wait until you open Forge.',
      ),
      (
        Icons.shield_moon_outlined,
        'Evening reset',
        'Your wind-down prompt will remain silent.',
      ),
      (
        Icons.local_fire_department_outlined,
        'Streak support',
        'Forge cannot nudge you before a day closes.',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < moments.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    moments[index].$1,
                    color: AppColors.primaryBright,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moments[index].$2,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        moments[index].$3,
                        style: const TextStyle(
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
            if (index < moments.length - 1)
              Divider(height: 25, color: Colors.white.withValues(alpha: .07)),
          ],
        ],
      ),
    );
  }
}

class _CompletionStep extends StatelessWidget {
  const _CompletionStep({required this.profile, required this.onFinish});
  final OnboardingProfile profile;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final firstHabit = profile.recommendedHabits.first;
    return _StepFrame(
      eyebrow: 'Your journey is ready',
      title: 'Your first promise\nis waiting.',
      body:
          'You built a plan for your ambition and your real life. Day One is not a test—it is proof that you started.',
      primaryLabel: 'Start Day One',
      onPrimary: onFinish,
      centered: true,
      content: Column(
        children: [
          const _CompletionSeal(),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primaryBright.withValues(alpha: .25),
              ),
            ),
            child: Row(
              children: [
                const _NumberBadge(value: '01'),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TODAY'S MISSION",
                        style: TextStyle(
                          color: AppColors.primaryBright,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        firstHabit.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${firstHabit.cue}  ·  +${firstHabit.xp} XP',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: .17)
              : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primaryBright.withValues(alpha: .72)
                : Colors.white.withValues(alpha: .08),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: selected
                      ? AppColors.primaryBright
                      : AppColors.textSecondary,
                ),
                const SizedBox(height: 18),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
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

class _DetailedChoiceCard extends StatelessWidget {
  const _DetailedChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: .15)
              : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.primaryBright.withValues(alpha: .65)
                : Colors.white.withValues(alpha: .08),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: .22)
                        : Colors.white.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: selected
                        ? AppColors.primaryBright
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.primaryBright : Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanHabit extends StatelessWidget {
  const _PlanHabit({required this.habit});
  final StarterHabit habit;

  @override
  Widget build(BuildContext context) {
    final icon = switch (habit.kind) {
      StarterHabitKind.discipline => Icons.bolt_rounded,
      StarterHabitKind.health => Icons.favorite_rounded,
      StarterHabitKind.focus => Icons.center_focus_strong_rounded,
      StarterHabitKind.study => Icons.school_rounded,
      StarterHabitKind.sleep => Icons.bedtime_rounded,
      StarterHabitKind.screenTime => Icons.phone_android_rounded,
    };
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primaryBright, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                habit.cue,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '+${habit.xp} XP',
          style: const TextStyle(
            color: AppColors.primaryBright,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: Colors.white.withValues(alpha: .07),
          disabledForegroundColor: Colors.white30,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, size: 19),
          ],
        ),
      ),
    );
  }
}

class _CommitmentOrb extends StatefulWidget {
  const _CommitmentOrb();
  @override
  State<_CommitmentOrb> createState() => _CommitmentOrbState();
}

class _CommitmentOrbState extends State<_CommitmentOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();
  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) =>
          Transform.rotate(angle: _animation.value * math.pi * 2, child: child),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryBright.withValues(alpha: .2),
              ),
            ),
          ),
          const Positioned(top: 7, child: _Spark(size: 9)),
          const Positioned(bottom: 18, left: 22, child: _Spark(size: 6)),
          Transform.rotate(
            angle: -math.pi / 4,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: const LinearGradient(
                  colors: [Color(0xFF9A72FF), Color(0xFF5C2EE7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .38),
                    blurRadius: 54,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: math.pi / 4,
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionSeal extends StatelessWidget {
  const _CompletionSeal();
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .65, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.elasticOut,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFAD8BFF), Color(0xFF6A37EA)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .35),
              blurRadius: 48,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 62),
      ),
    );
  }
}

class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF20202B).withValues(alpha: .92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          const _ForgeMark(size: 44),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FORGE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Your next promise is ready.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'One focused hour. Start when you are ready.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'now',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryBright, size: 21),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InsightStrip extends StatelessWidget {
  const _InsightStrip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.primaryBright, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Text(
      value,
      style: const TextStyle(
        color: AppColors.primaryBright,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _ForgeMark extends StatelessWidget {
  const _ForgeMark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primaryBright, AppColors.primary],
      ),
      borderRadius: BorderRadius.circular(size * .31),
    ),
    child: Icon(
      Icons.arrow_upward_rounded,
      size: size * .55,
      color: Colors.white,
    ),
  );
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [AppColors.primary.withValues(alpha: .15), Colors.transparent],
      ),
    ),
  );
}

class _Spark extends StatelessWidget {
  const _Spark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.primaryBright,
      shape: BoxShape.circle,
    ),
  );
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, this.delay = 0});
  final Widget child;
  final double delay;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 540 + (delay * 500).round()),
    curve: Interval(delay.clamp(0, .4), 1, curve: Curves.easeOutCubic),
    builder: (_, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}

class _SaveError extends StatelessWidget {
  const _SaveError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFF3A1720),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFFFFC2CD), fontSize: 12),
    ),
  );
}

class _LoadingState extends StatefulWidget {
  const _LoadingState({this.onReady});
  final VoidCallback? onReady;
  @override
  State<_LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<_LoadingState> {
  @override
  void initState() {
    super.initState();
    if (widget.onReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady!());
    }
  }

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ForgeMark(size: 54),
        SizedBox(height: 22),
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.primaryBright,
            size: 44,
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _formatMinutes(BuildContext context, int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
