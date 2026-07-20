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

  Habit copyWith({bool? isComplete}) => Habit(
        id: id,
        title: title,
        xp: xp,
        isComplete: isComplete ?? this.isComplete,
      );
}
