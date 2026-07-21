class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.xp,
    this.isComplete = false,
    this.scheduledTime,
    this.effortMinutes,
    this.kind,
  });

  final String id;
  final String title;
  final int xp;
  final bool isComplete;
  final String? scheduledTime;
  final int? effortMinutes;
  final String? kind;

  factory Habit.fromJson(
    Map<String, dynamic> json, {
    required bool isComplete,
  }) => Habit(
    id: json['id'] as String,
    title: json['title'] as String,
    xp: (json['xp_reward'] as num).toInt(),
    isComplete: isComplete,
    scheduledTime: json['scheduled_time'] as String?,
    effortMinutes: (json['effort_minutes'] as num?)?.toInt(),
    kind: json['source_key'] as String?,
  );

  Habit copyWith({bool? isComplete}) => Habit(
    id: id,
    title: title,
    xp: xp,
    isComplete: isComplete ?? this.isComplete,
    scheduledTime: scheduledTime,
    effortMinutes: effortMinutes,
    kind: kind,
  );
}
