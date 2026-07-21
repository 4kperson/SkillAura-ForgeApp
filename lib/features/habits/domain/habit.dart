class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.xp,
    this.isComplete = false,
  });

  final String id;
  final String title;
  final int xp;
  final bool isComplete;

  factory Habit.fromJson(
    Map<String, dynamic> json, {
    required bool isComplete,
  }) => Habit(
    id: json['id'] as String,
    title: json['title'] as String,
    xp: (json['xp_reward'] as num).toInt(),
    isComplete: isComplete,
  );

  Habit copyWith({bool? isComplete}) => Habit(
    id: id,
    title: title,
    xp: xp,
    isComplete: isComplete ?? this.isComplete,
  );
}
