enum HabitCategory {
  discipline,
  health,
  focus,
  learning,
  sleep,
  digital,
  wellbeing,
  personal;

  String get label => switch (this) {
    HabitCategory.discipline => 'Discipline',
    HabitCategory.health => 'Health',
    HabitCategory.focus => 'Focus',
    HabitCategory.learning => 'Learning',
    HabitCategory.sleep => 'Sleep',
    HabitCategory.digital => 'Digital balance',
    HabitCategory.wellbeing => 'Wellbeing',
    HabitCategory.personal => 'Personal',
  };

  static HabitCategory fromJson(String? value) {
    for (final category in values) {
      if (category.name == value) return category;
    }
    return HabitCategory.personal;
  }
}

enum HabitSymbol {
  shield,
  heart,
  target,
  book,
  moon,
  phone,
  spark,
  bolt,
  leaf;

  static HabitSymbol fromJson(String? value) {
    for (final symbol in values) {
      if (symbol.name == value) return symbol;
    }
    return HabitSymbol.spark;
  }
}

class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.xp,
    this.userId = '',
    this.category = HabitCategory.personal,
    this.symbol = HabitSymbol.spark,
    this.reminderMinutes,
    this.activeWeekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.timeZone = 'America/New_York',
    this.position = 0,
    this.isPaused = false,
    this.isArchived = false,
    this.isComplete = false,
    this.scheduledTime,
    this.effortMinutes,
    this.kind,
    this.source = 'user',
    this.effectiveDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final HabitCategory category;
  final HabitSymbol symbol;
  final int? reminderMinutes;
  final Set<int> activeWeekdays;
  final String timeZone;
  final int position;
  final bool isPaused;
  final bool isArchived;
  final int xp;
  final bool isComplete;
  final String? scheduledTime;
  final int? effortMinutes;
  final String? kind;
  final String source;
  final DateTime? effectiveDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isEveryDay => activeWeekdays.length == 7;
  bool get canComplete => !isPaused && !isArchived;

  bool isActiveOn(DateTime localDate) =>
      canComplete && activeWeekdays.contains(localDate.weekday);

  factory Habit.fromJson(Map<String, dynamic> json, {bool? isComplete}) {
    final reminder = json['reminder_time'] as String?;
    final legacyReminder = json['scheduled_time'] as String?;
    final sourceKey = json['source_key'] as String?;
    final category = HabitCategory.fromJson(
      json['category'] as String? ?? _legacyCategory(sourceKey),
    );
    final symbol = HabitSymbol.fromJson(
      json['symbol'] as String? ?? _legacySymbol(sourceKey),
    );

    return Habit(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String,
      category: category,
      symbol: symbol,
      reminderMinutes: _timeToMinutes(reminder ?? legacyReminder),
      activeWeekdays:
          (json['active_weekdays'] as List?)
              ?.whereType<num>()
              .map((day) => day.toInt())
              .where((day) => day >= 1 && day <= 7)
              .toSet() ??
          const {1, 2, 3, 4, 5, 6, 7},
      timeZone: json['timezone'] as String? ?? 'America/New_York',
      position: (json['position'] as num?)?.toInt() ?? 0,
      isPaused: json['paused'] as bool? ?? false,
      isArchived: json['archived'] as bool? ?? false,
      xp: (json['xp_reward'] as num?)?.toInt() ?? 10,
      isComplete: isComplete ?? json['is_completed'] as bool? ?? false,
      scheduledTime: reminder ?? legacyReminder,
      effortMinutes: (json['effort_minutes'] as num?)?.toInt(),
      kind: sourceKey,
      source: json['source'] as String? ?? 'user',
      effectiveDate: _parseDate(json['local_date'] as String?),
      createdAt: _parseDate(json['created_at'] as String?),
      updatedAt: _parseDate(json['updated_at'] as String?),
    );
  }

  Habit copyWith({
    String? title,
    HabitCategory? category,
    HabitSymbol? symbol,
    int? reminderMinutes,
    bool clearReminder = false,
    Set<int>? activeWeekdays,
    String? timeZone,
    int? position,
    bool? isPaused,
    bool? isArchived,
    int? xp,
    bool? isComplete,
    String? scheduledTime,
    int? effortMinutes,
    String? kind,
    String? source,
    DateTime? effectiveDate,
    DateTime? updatedAt,
  }) => Habit(
    id: id,
    userId: userId,
    title: title ?? this.title,
    category: category ?? this.category,
    symbol: symbol ?? this.symbol,
    reminderMinutes: clearReminder
        ? null
        : reminderMinutes ?? this.reminderMinutes,
    activeWeekdays: activeWeekdays ?? this.activeWeekdays,
    timeZone: timeZone ?? this.timeZone,
    position: position ?? this.position,
    isPaused: isPaused ?? this.isPaused,
    isArchived: isArchived ?? this.isArchived,
    xp: xp ?? this.xp,
    isComplete: isComplete ?? this.isComplete,
    scheduledTime: clearReminder ? null : scheduledTime ?? this.scheduledTime,
    effortMinutes: effortMinutes ?? this.effortMinutes,
    kind: kind ?? this.kind,
    source: source ?? this.source,
    effectiveDate: effectiveDate ?? this.effectiveDate,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static int? _timeToMinutes(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  static DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toLocal();

  static String? _legacyCategory(String? key) => switch (key) {
    'discipline' => 'discipline',
    'health' => 'health',
    'focus' => 'focus',
    'study' => 'learning',
    'sleep' => 'sleep',
    'screenTime' => 'digital',
    _ => null,
  };

  static String? _legacySymbol(String? key) => switch (key) {
    'discipline' => 'shield',
    'health' => 'heart',
    'focus' => 'target',
    'study' => 'book',
    'sleep' => 'moon',
    'screenTime' => 'phone',
    _ => null,
  };
}

class HabitDraft {
  const HabitDraft({
    required this.title,
    required this.category,
    required this.symbol,
    required this.activeWeekdays,
    required this.timeZone,
    this.reminderMinutes,
  });

  final String title;
  final HabitCategory category;
  final HabitSymbol symbol;
  final int? reminderMinutes;
  final Set<int> activeWeekdays;
  final String timeZone;

  factory HabitDraft.fromHabit(Habit habit) => HabitDraft(
    title: habit.title,
    category: habit.category,
    symbol: habit.symbol,
    reminderMinutes: habit.reminderMinutes,
    activeWeekdays: habit.activeWeekdays,
    timeZone: habit.timeZone,
  );

  String? get validationMessage {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 'Give this habit a clear name.';
    if (trimmed.length > 80) return 'Keep the habit name under 80 characters.';
    if (activeWeekdays.isEmpty) return 'Choose at least one active day.';
    if (timeZone.trim().isEmpty) return 'A timezone is required.';
    return null;
  }

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'category': category.name,
    'symbol': symbol.name,
    'reminder_time': _minutesToTime(reminderMinutes),
    'scheduled_time': _minutesToTime(reminderMinutes),
    'active_weekdays': activeWeekdays.toList()..sort(),
    'timezone': timeZone,
  };

  static String? _minutesToTime(int? minutes) {
    if (minutes == null) return null;
    final normalized = minutes.clamp(0, 1439);
    return '${(normalized ~/ 60).toString().padLeft(2, '0')}:'
        '${(normalized % 60).toString().padLeft(2, '0')}:00';
  }
}

class HabitCompletion {
  const HabitCompletion({
    required this.habitId,
    required this.userId,
    required this.completionDate,
    required this.completedAt,
    required this.xpAwarded,
    required this.source,
    required this.createdAt,
    this.id = '',
  });

  final String id;
  final String habitId;
  final String userId;
  final DateTime completionDate;
  final DateTime completedAt;
  final int xpAwarded;
  final String source;
  final DateTime createdAt;

  factory HabitCompletion.fromJson(Map<String, dynamic> json) =>
      HabitCompletion(
        id: json['id'] as String? ?? '',
        habitId: json['habit_id'] as String,
        userId: json['user_id'] as String? ?? '',
        completionDate: DateTime.parse(json['completion_date'] as String),
        completedAt: DateTime.parse(json['completed_at'] as String).toLocal(),
        xpAwarded: (json['xp_awarded'] as num).toInt(),
        source: json['source'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

class HabitCompletionResult {
  const HabitCompletionResult({
    required this.completionDate,
    required this.changed,
    required this.totalXp,
  });

  final DateTime completionDate;
  final bool changed;
  final int totalXp;

  factory HabitCompletionResult.fromJson(Map<String, dynamic> json) =>
      HabitCompletionResult(
        completionDate: DateTime.parse(json['completion_date'] as String),
        changed: json['changed'] as bool? ?? false,
        totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      );
}
