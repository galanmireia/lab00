class UserStats {
  int totalPoints;
  int currentStreak;
  DateTime? lastCompletionDate;

  UserStats({
    this.totalPoints = 0,
    this.currentStreak = 0,
    this.lastCompletionDate,
  });

  /// Registers a completion for [day] and returns the updated streak.
  void registerCompletion(DateTime day) {
    totalPoints += 10;

    final last = lastCompletionDate;
    if (last == null) {
      currentStreak = 1;
    } else {
      final lastDay = DateTime(last.year, last.month, last.day);
      final today = DateTime(day.year, day.month, day.day);
      final diff = today.difference(lastDay).inDays;
      if (diff == 0) {
        // Already completed something today, streak unchanged.
      } else if (diff == 1) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }
    }
    lastCompletionDate = day;
  }

  Map<String, dynamic> toJson() => {
        'totalPoints': totalPoints,
        'currentStreak': currentStreak,
        'lastCompletionDate': lastCompletionDate?.toIso8601String(),
      };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalPoints: json['totalPoints'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        lastCompletionDate: json['lastCompletionDate'] != null
            ? DateTime.parse(json['lastCompletionDate'] as String)
            : null,
      );
}
