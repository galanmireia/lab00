enum ReminderFrequency { hourly, daily, weekly }

extension ReminderFrequencyLabel on ReminderFrequency {
  String get label {
    switch (this) {
      case ReminderFrequency.hourly:
        return 'Cada hora';
      case ReminderFrequency.daily:
        return 'Cada día';
      case ReminderFrequency.weekly:
        return 'Cada semana';
    }
  }
}

class Task {
  final int id;
  final String title;
  final ReminderFrequency frequency;
  final DateTime createdAt;
  bool active;
  DateTime? lastCompletedAt;

  Task({
    required this.id,
    required this.title,
    required this.frequency,
    required this.createdAt,
    this.active = true,
    this.lastCompletedAt,
  });

  bool get completedToday {
    final last = lastCompletedAt;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year && last.month == now.month && last.day == now.day;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'frequency': frequency.index,
        'createdAt': createdAt.toIso8601String(),
        'active': active,
        'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as int,
        title: json['title'] as String,
        frequency: ReminderFrequency.values[json['frequency'] as int],
        createdAt: DateTime.parse(json['createdAt'] as String),
        active: json['active'] as bool? ?? true,
        lastCompletedAt: json['lastCompletedAt'] != null
            ? DateTime.parse(json['lastCompletedAt'] as String)
            : null,
      );
}
