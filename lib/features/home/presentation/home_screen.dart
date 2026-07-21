import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../habits/domain/habit.dart';
import '../data/morning_repository.dart';
import '../domain/morning_snapshot.dart';
import 'morning_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.onSignOut,
  });

  final MorningRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MorningController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MorningController(widget.repository)
      ..addListener(_onChanged)
      ..initialize();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
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
            SafeArea(child: _buildState()),
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
    );
  }
}

class _MorningExperience extends StatelessWidget {
  const _MorningExperience({
    required this.snapshot,
    required this.controller,
    required this.onSignOut,
    required this.onRefresh,
  });

  final MorningSnapshot snapshot;
  final MorningController controller;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 14),
          _ProgressHero(snapshot: snapshot),
          const SizedBox(height: 30),
          _MissionHeader(snapshot: snapshot),
          const SizedBox(height: 13),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: snapshot.remainingHabits.isEmpty
                ? _DayCompleteCard(key: const ValueKey('complete'))
                : Column(
                    key: ValueKey(snapshot.remainingHabits.length),
                    children: [
                      for (
                        var index = 0;
                        index < snapshot.remainingHabits.length;
                        index++
                      ) ...[
                        _MissionCard(
                          habit: snapshot.remainingHabits[index],
                          isNext: index == 0,
                          isSaving: controller.isUpdating(
                            snapshot.remainingHabits[index].id,
                          ),
                          onComplete: () => controller.toggleHabit(
                            snapshot.remainingHabits[index].id,
                          ),
                        ),
                        if (index < snapshot.remainingHabits.length - 1)
                          const SizedBox(height: 11),
                      ],
                    ],
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
  const _MissionHeader({required this.snapshot});

  final MorningSnapshot snapshot;

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
        Text(
          '${snapshot.completedCount}/${snapshot.totalCount} kept',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
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
      label: 'Complete ${habit.title} for ${habit.xp} XP',
      child: Material(
        color: isNext
            ? AppColors.primary.withValues(alpha: .11)
            : Colors.white.withValues(alpha: .042),
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          onTap: isSaving ? null : onComplete,
          borderRadius: BorderRadius.circular(23),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: isNext
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
                    _habitIcon(habit.kind),
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
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 17,
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

IconData _habitIcon(String? kind) => switch (kind) {
  'discipline' => Icons.bolt_rounded,
  'health' => Icons.favorite_rounded,
  'focus' => Icons.center_focus_strong_rounded,
  'study' => Icons.school_rounded,
  'sleep' => Icons.bedtime_rounded,
  'screenTime' => Icons.phone_android_rounded,
  _ => Icons.task_alt_rounded,
};

String _habitDetails(Habit habit) {
  final details = <String>[];
  if (habit.scheduledTime case final time?) {
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
