import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/habit_repository.dart';
import '../domain/habit.dart';
import 'habit_engine_controller.dart';

enum _HabitSection { active, paused, archived }

enum _HabitAction { edit, history, pause, resume, archive, restore, delete }

class HabitManagementScreen extends StatefulWidget {
  const HabitManagementScreen({super.key, required this.repository});

  final HabitRepository repository;

  @override
  State<HabitManagementScreen> createState() => _HabitManagementScreenState();
}

class _HabitManagementScreenState extends State<HabitManagementScreen> {
  late final HabitEngineController _controller;
  _HabitSection _section = _HabitSection.active;

  @override
  void initState() {
    super.initState();
    _controller = HabitEngineController(widget.repository)
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
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF171126),
              AppColors.background,
              Color(0xFF07070C),
            ],
            stops: [0, .43, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(onBack: Navigator.of(context).pop, onAdd: _openCreate),
              if (_controller.library case final library?) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _PlanSummary(library: library),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionPicker(
                    selected: _section,
                    library: library,
                    onSelected: (section) => setState(() => _section = section),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_controller.errorMessage case final message?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: _ErrorBanner(
                    message: message,
                    onDismiss: _controller.clearMessage,
                  ),
                ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final library = _controller.library;
    if (library == null && _controller.status == HabitEngineStatus.loading) {
      return const _HabitLoadingState();
    }
    if (library == null && _controller.status == HabitEngineStatus.failed) {
      return _HabitLoadError(onRetry: _controller.initialize);
    }
    final habits = switch (_section) {
      _HabitSection.active => library!.active,
      _HabitSection.paused => library!.paused,
      _HabitSection.archived => library!.archived,
    };
    if (habits.isEmpty) {
      return _HabitEmptyState(section: _section, onAdd: _openCreate);
    }
    if (_section == _HabitSection.active) {
      return ReorderableListView.builder(
        key: const ValueKey('active-habit-list'),
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 36),
        itemCount: habits.length,
        onReorderItem: _controller.reorderActive,
        proxyDecorator: (child, _, animation) => AnimatedBuilder(
          animation: animation,
          builder: (_, _) => Transform.scale(
            scale: 1 + animation.value * .025,
            child: Material(
              color: Colors.transparent,
              elevation: animation.value * 12,
              borderRadius: BorderRadius.circular(24),
              child: child,
            ),
          ),
        ),
        itemBuilder: (_, index) => Padding(
          key: ValueKey(habits[index].id),
          padding: const EdgeInsets.only(bottom: 11),
          child: _HabitCard(
            habit: habits[index],
            isBusy: _controller.isBusy(habits[index].id),
            dragIndex: index,
            onTap: () => _openEdit(habits[index]),
            onAction: (action) => _handleAction(habits[index], action),
          ),
        ),
      );
    }
    return ListView.separated(
      key: ValueKey(_section),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 36),
      itemCount: habits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 11),
      itemBuilder: (_, index) => _HabitCard(
        habit: habits[index],
        isBusy: _controller.isBusy(habits[index].id),
        onTap: () => habits[index].isArchived
            ? _openHistory(habits[index])
            : _openEdit(habits[index]),
        onAction: (action) => _handleAction(habits[index], action),
      ),
    );
  }

  Future<void> _openCreate() async {
    final library = _controller.library;
    if (library == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HabitEditorSheet(
        timeZone: library.timeZone,
        isSaving: () => _controller.isCreating,
        onSave: _controller.create,
      ),
    );
    if (saved == true) _showMessage('Habit added to your plan.');
  }

  Future<void> _openEdit(Habit habit) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HabitEditorSheet(
        habit: habit,
        timeZone: habit.timeZone,
        isSaving: () => _controller.isBusy(habit.id),
        onSave: (draft) => _controller.update(habit.id, draft),
      ),
    );
    if (saved == true) _showMessage('Changes saved.');
  }

  Future<void> _handleAction(Habit habit, _HabitAction action) async {
    switch (action) {
      case _HabitAction.edit:
        await _openEdit(habit);
      case _HabitAction.history:
        await _openHistory(habit);
      case _HabitAction.pause:
        if (await _controller.setPaused(habit.id, paused: true)) {
          _showMessage('${habit.title} is paused.');
        }
      case _HabitAction.resume:
        if (await _controller.setPaused(habit.id, paused: false)) {
          _showMessage('${habit.title} is back in your plan.');
        }
      case _HabitAction.archive:
        if (await _controller.setArchived(habit.id, archived: true)) {
          _showMessage('${habit.title} moved to Archive.');
        }
      case _HabitAction.restore:
        if (await _controller.setArchived(habit.id, archived: false)) {
          _showMessage('${habit.title} restored to your active plan.');
        }
      case _HabitAction.delete:
        await _confirmDelete(habit);
    }
  }

  Future<void> _confirmDelete(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('Delete this habit?'),
        content: Text(
          '“${habit.title}” and its completion history will be permanently '
          'removed. XP earned from it will be reversed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep habit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC4964),
            ),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await _controller.delete(habit.id)) _showMessage('Habit deleted.');
  }

  Future<void> _openHistory(Habit habit) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _HistorySheet(habit: habit, history: _controller.loadHistory(habit.id)),
  );

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onAdd});

  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Back to Home',
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR SYSTEM',
                style: TextStyle(
                  color: AppColors.primaryBright,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Shape your habits.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Create a new habit',
          child: FilledButton.tonalIcon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: AppColors.primary.withValues(alpha: .18),
              foregroundColor: AppColors.primaryBright,
            ),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text(
              'Add',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.library});

  final HabitLibrary library;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF29223F), Color(0xFF171521)],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white.withValues(alpha: .09)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x44000000),
          blurRadius: 28,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.tune_rounded, color: AppColors.primaryBright),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A plan you own',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${library.active.length} active · ${library.paused.length} paused · '
                '${library.archived.length} archived',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionPicker extends StatelessWidget {
  const _SectionPicker({
    required this.selected,
    required this.library,
    required this.onSelected,
  });

  final _HabitSection selected;
  final HabitLibrary library;
  final ValueChanged<_HabitSection> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    child: Row(
      children: [
        _item(_HabitSection.active, 'Active', library.active.length),
        _item(_HabitSection.paused, 'Paused', library.paused.length),
        _item(_HabitSection.archived, 'Archive', library.archived.length),
      ],
    ),
  );

  Widget _item(_HabitSection section, String label, int count) {
    final isSelected = selected == section;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$label habits, $count',
        child: InkWell(
          onTap: () => onSelected(section),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: .2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$label  $count',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.isBusy,
    required this.onTap,
    required this.onAction,
    this.dragIndex,
  });

  final Habit habit;
  final bool isBusy;
  final VoidCallback onTap;
  final ValueChanged<_HabitAction> onAction;
  final int? dragIndex;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${habit.title}. ${_habitSchedule(habit)}. '
        '${habit.isArchived ? 'Tap to view history.' : 'Tap to edit.'}',
    child: Material(
      color: habit.isArchived
          ? Colors.white.withValues(alpha: .025)
          : habit.isPaused
          ? const Color(0xFF171722)
          : Colors.white.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.fromLTRB(15, 15, 8, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: .075)),
          ),
          child: Row(
            children: [
              _SymbolTile(symbol: habit.symbol, muted: habit.isArchived),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            habit.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: habit.isArchived
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (habit.source == 'onboarding') ...[
                          const SizedBox(width: 7),
                          const _StarterBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _habitSchedule(habit),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                PopupMenuButton<_HabitAction>(
                  tooltip: 'Habit actions',
                  onSelected: onAction,
                  color: AppColors.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  itemBuilder: (_) => _habitActions(habit),
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
                if (dragIndex case final index?)
                  ReorderableDragStartListener(
                    index: index,
                    child: const SizedBox(
                      width: 42,
                      height: 48,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  static List<PopupMenuEntry<_HabitAction>> _habitActions(Habit habit) => [
    if (!habit.isArchived)
      const PopupMenuItem(
        value: _HabitAction.edit,
        child: _MenuLabel(icon: Icons.edit_rounded, label: 'Edit habit'),
      ),
    const PopupMenuItem(
      value: _HabitAction.history,
      child: _MenuLabel(icon: Icons.history_rounded, label: 'View history'),
    ),
    if (!habit.isArchived && !habit.isPaused)
      const PopupMenuItem(
        value: _HabitAction.pause,
        child: _MenuLabel(icon: Icons.pause_rounded, label: 'Pause'),
      ),
    if (!habit.isArchived && habit.isPaused)
      const PopupMenuItem(
        value: _HabitAction.resume,
        child: _MenuLabel(icon: Icons.play_arrow_rounded, label: 'Resume'),
      ),
    if (!habit.isArchived)
      const PopupMenuItem(
        value: _HabitAction.archive,
        child: _MenuLabel(icon: Icons.archive_outlined, label: 'Archive'),
      ),
    if (habit.isArchived)
      const PopupMenuItem(
        value: _HabitAction.restore,
        child: _MenuLabel(icon: Icons.unarchive_outlined, label: 'Restore'),
      ),
    const PopupMenuDivider(),
    const PopupMenuItem(
      value: _HabitAction.delete,
      child: _MenuLabel(
        icon: Icons.delete_outline_rounded,
        label: 'Delete permanently',
        destructive: true,
      ),
    ),
  ];
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 19, color: destructive ? const Color(0xFFFF7B91) : null),
      const SizedBox(width: 11),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: destructive ? const Color(0xFFFF9AAC) : null,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _StarterBadge extends StatelessWidget {
  const _StarterBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'STARTER',
      style: TextStyle(
        color: AppColors.primaryBright,
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    ),
  );
}

class _SymbolTile extends StatelessWidget {
  const _SymbolTile({required this.symbol, this.muted = false});

  final HabitSymbol symbol;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: muted
          ? Colors.white.withValues(alpha: .04)
          : AppColors.primary.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Icon(
      habitSymbolIcon(symbol),
      color: muted ? AppColors.textSecondary : AppColors.primaryBright,
      size: 22,
    ),
  );
}

class _HabitEditorSheet extends StatefulWidget {
  const _HabitEditorSheet({
    required this.timeZone,
    required this.isSaving,
    required this.onSave,
    this.habit,
  });

  final Habit? habit;
  final String timeZone;
  final bool Function() isSaving;
  final Future<bool> Function(HabitDraft draft) onSave;

  @override
  State<_HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<_HabitEditorSheet> {
  late final TextEditingController _title;
  late HabitCategory _category;
  late HabitSymbol _symbol;
  late Set<int> _weekdays;
  int? _reminderMinutes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _title = TextEditingController(text: habit?.title ?? '');
    _category = habit?.category ?? HabitCategory.discipline;
    _symbol = habit?.symbol ?? HabitSymbol.shield;
    _weekdays = {...?habit?.activeWeekdays};
    if (_weekdays.isEmpty) _weekdays = {1, 2, 3, 4, 5, 6, 7};
    _reminderMinutes = habit?.reminderMinutes;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.sizeOf(context).height * .94,
        decoration: const BoxDecoration(
          color: Color(0xFF11111A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                children: [
                  Text(
                    widget.habit == null
                        ? 'Create a promise'
                        : 'Refine your habit',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.habit == null
                        ? 'Make it clear enough to act on, small enough to repeat.'
                        : 'Your plan can evolve without losing the progress behind it.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _FieldLabel('WHAT WILL YOU DO?'),
                  const SizedBox(height: 9),
                  TextField(
                    key: const ValueKey('habit-title-field'),
                    controller: _title,
                    autofocus: widget.habit == null,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      hintText: 'Read for 20 minutes',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('CATEGORY'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in HabitCategory.values)
                        _ChoiceChip(
                          label: category.label,
                          selected: _category == category,
                          onTap: () => setState(() {
                            _category = category;
                            _symbol = _defaultSymbol(category);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _FieldLabel('SYMBOL'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final symbol in HabitSymbol.values)
                        _SymbolChoice(
                          symbol: symbol,
                          selected: _symbol == symbol,
                          onTap: () => setState(() => _symbol = symbol),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(child: _FieldLabel('ACTIVE DAYS')),
                      TextButton(
                        onPressed: () =>
                            setState(() => _weekdays = {1, 2, 3, 4, 5, 6, 7}),
                        child: const Text('Every day'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        _WeekdayButton(
                          day: day,
                          selected: _weekdays.contains(day),
                          onTap: () => setState(() {
                            if (_weekdays.contains(day)) {
                              _weekdays.remove(day);
                            } else {
                              _weekdays.add(day);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _FieldLabel('REMINDER'),
                  const SizedBox(height: 9),
                  _ReminderPicker(
                    minutes: _reminderMinutes,
                    onPick: _pickTime,
                    onClear: () => setState(() => _reminderMinutes = null),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(message: error),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('save-habit-button'),
                    onPressed: _saving || widget.isSaving() ? null : _save,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: _saving
                          ? const SizedBox.square(
                              key: ValueKey('saving-habit'),
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.habit == null
                                  ? 'Add to my plan'
                                  : 'Save changes',
                              key: const ValueKey('save-habit-label'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Times follow ${widget.timeZone}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final initial = _reminderMinutes ?? 8 * 60;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      helpText: 'WHEN SHOULD FORGE NUDGE YOU?',
    );
    if (selected != null && mounted) {
      setState(() => _reminderMinutes = selected.hour * 60 + selected.minute);
    }
  }

  Future<void> _save() async {
    final draft = HabitDraft(
      title: _title.text,
      category: _category,
      symbol: _symbol,
      reminderMinutes: _reminderMinutes,
      activeWeekdays: _weekdays,
      timeZone: widget.timeZone,
    );
    final validation = draft.validationMessage;
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSave(draft);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = 'That change did not reach Forge. Your edits are still here.';
      });
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: AppColors.primaryBright,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.25,
    ),
  );
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: .2)
              : Colors.white.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primaryBright.withValues(alpha: .38)
                : Colors.white.withValues(alpha: .07),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _SymbolChoice extends StatelessWidget {
  const _SymbolChoice({
    required this.symbol,
    required this.selected,
    required this.onTap,
  });

  final HabitSymbol symbol;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${symbol.name} symbol',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 47,
        height: 47,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: .25)
              : Colors.white.withValues(alpha: .045),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppColors.primaryBright
                : Colors.white.withValues(alpha: .08),
          ),
        ),
        child: Icon(
          habitSymbolIcon(symbol),
          color: selected ? AppColors.primaryBright : AppColors.textSecondary,
          size: 21,
        ),
      ),
    ),
  );
}

class _WeekdayButton extends StatelessWidget {
  const _WeekdayButton({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  static const _short = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _full = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: _full[day - 1],
    child: InkWell(
      key: ValueKey('weekday-$day'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.white.withValues(alpha: .045),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppColors.primaryBright
                : Colors.white.withValues(alpha: .08),
          ),
        ),
        child: Text(
          _short[day - 1],
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _ReminderPicker extends StatelessWidget {
  const _ReminderPicker({
    required this.minutes,
    required this.onPick,
    required this.onClear,
  });

  final int? minutes;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .045),
    borderRadius: BorderRadius.circular(19),
    child: InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white.withValues(alpha: .075)),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    minutes == null ? 'No reminder' : formatHabitTime(minutes!),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    minutes == null
                        ? 'Tap to choose a gentle cue'
                        : 'Tap to change time',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (minutes != null)
              IconButton(
                onPressed: onClear,
                tooltip: 'Remove reminder',
                icon: const Icon(Icons.close_rounded, size: 19),
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.habit, required this.history});

  final Habit habit;
  final Future<List<HabitCompletion>> history;

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.sizeOf(context).height * .78,
    decoration: const BoxDecoration(
      color: Color(0xFF11111A),
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _SymbolTile(symbol: habit.symbol),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'COMPLETION HISTORY',
                    style: TextStyle(
                      color: AppColors.primaryBright,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    habit.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<List<HabitCompletion>>(
            future: history,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (snapshot.hasError) {
                return const _CenteredMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'History is temporarily unavailable',
                  body:
                      'Your completions are safe. Close this sheet and try again.',
                );
              }
              final completions = snapshot.data ?? const [];
              if (completions.isEmpty) {
                return const _CenteredMessage(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'A clean beginning',
                  body: 'Your first confirmed completion will appear here.',
                );
              }
              return ListView.separated(
                itemCount: completions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (_, index) =>
                    _HistoryRow(completion: completions[index]),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.completion});

  final HabitCompletion completion;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .065)),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: .14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.success,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatHistoryDate(completion.completionDate),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Confirmed at ${TimeOfDay.fromDateTime(completion.completedAt).format(context)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          '+${completion.xpAwarded} XP',
          style: const TextStyle(
            color: AppColors.primaryBright,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _HabitEmptyState extends StatelessWidget {
  const _HabitEmptyState({required this.section, required this.onAdd});

  final _HabitSection section;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final content = switch (section) {
      _HabitSection.active => (
        Icons.add_task_rounded,
        'Your plan is ready for a first move.',
        'Create one habit you can keep even on a difficult day.',
      ),
      _HabitSection.paused => (
        Icons.pause_circle_outline_rounded,
        'Nothing is paused.',
        'Habits you pause temporarily will wait here without losing history.',
      ),
      _HabitSection.archived => (
        Icons.inventory_2_outlined,
        'Your archive is empty.',
        'Retired habits stay recoverable here until you choose to delete them.',
      ),
    };
    return _CenteredMessage(
      icon: content.$1,
      title: content.$2,
      body: content.$3,
      actionLabel: section == _HabitSection.active ? 'Create a habit' : null,
      onAction: section == _HabitSection.active ? onAdd : null,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: AppColors.primaryBright, size: 29),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 12,
            ),
          ),
          if (actionLabel case final label?) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(label)),
          ],
        ],
      ),
    ),
  );
}

class _HabitLoadingState extends StatelessWidget {
  const _HabitLoadingState();

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
    itemCount: 4,
    separatorBuilder: (_, _) => const SizedBox(height: 11),
    itemBuilder: (_, index) => Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(24),
      ),
    ),
  );
}

class _HabitLoadError extends StatelessWidget {
  const _HabitLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _CenteredMessage(
    icon: Icons.cloud_off_rounded,
    title: 'Your plan could not be reached.',
    body: 'Nothing was changed. Reconnect and Forge will try again.',
    actionLabel: 'Try again',
    onAction: onRetry,
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(13, 11, 7, 11),
    decoration: BoxDecoration(
      color: const Color(0xFF5C2631).withValues(alpha: .5),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFFF7B91).withValues(alpha: .28)),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFFFF9AAC)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Color(0xFFFFCED6),
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onDismiss != null)
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
      ],
    ),
  );
}

IconData habitSymbolIcon(HabitSymbol symbol) => switch (symbol) {
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

HabitSymbol _defaultSymbol(HabitCategory category) => switch (category) {
  HabitCategory.discipline => HabitSymbol.shield,
  HabitCategory.health => HabitSymbol.heart,
  HabitCategory.focus => HabitSymbol.target,
  HabitCategory.learning => HabitSymbol.book,
  HabitCategory.sleep => HabitSymbol.moon,
  HabitCategory.digital => HabitSymbol.phone,
  HabitCategory.wellbeing => HabitSymbol.leaf,
  HabitCategory.personal => HabitSymbol.spark,
};

String _habitSchedule(Habit habit) {
  final days = _formatWeekdays(habit.activeWeekdays);
  final time = habit.reminderMinutes == null
      ? 'No reminder'
      : formatHabitTime(habit.reminderMinutes!);
  return '${habit.category.label} · $days · $time';
}

String _formatWeekdays(Set<int> days) {
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && {1, 2, 3, 4, 5}.every(days.contains)) {
    return 'Weekdays';
  }
  if (days.length == 2 && days.contains(6) && days.contains(7)) {
    return 'Weekends';
  }
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return [for (final day in days.toList()..sort()) labels[day - 1]].join(', ');
}

String formatHabitTime(int minutes) {
  var hour = minutes ~/ 60;
  final minute = minutes % 60;
  final period = hour < 12 ? 'AM' : 'PM';
  if (hour == 0) hour = 12;
  if (hour > 12) hour -= 12;
  return '$hour:${minute.toString().padLeft(2, '0')} $period';
}

String _formatHistoryDate(DateTime date) {
  const months = [
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
