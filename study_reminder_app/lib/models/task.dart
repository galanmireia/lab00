enum ReminderFrequency { hourly, daily, weekly, morningAndNight }

extension ReminderFrequencyLabel on ReminderFrequency {
  String get label {
    switch (this) {
      case ReminderFrequency.hourly:
        return 'Cada hora';
      case ReminderFrequency.daily:
        return 'Cada día';
      case ReminderFrequency.weekly:
        return 'Cada semana';
      case ReminderFrequency.morningAndNight:
        return 'Mañana y noche';
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

  /// Optional code the person enters to confirm the task is actually done.
  /// It only gates the "mark as completed" action — it never affects
  /// whether the reminder notification itself can be dismissed.
  final String? confirmationCode;

  /// Only used when [frequency] is [ReminderFrequency.morningAndNight]:
  /// the hour/minute of the morning reminder. The night reminder is
  /// fixed at 22:00 on both Android and iOS (both scheduled at a fixed
  /// clock time — neither platform lets an app detect a real unlock
  /// event reliably in the background without a persistent, always-on
  /// service, which this app intentionally avoids).
  final int morningHour;
  final int morningMinute;

  Task({
    required this.id,
    required this.title,
    required this.frequency,
    required this.createdAt,
    this.active = true,
    this.lastCompletedAt,
    this.confirmationCode,
    this.morningHour = 8,
    this.morningMinute = 0,
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
        'confirmationCode': confirmationCode,
        'morningHour': morningHour,
        'morningMinute': morningMinute,
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
        confirmationCode: json['confirmationCode'] as String?,
        morningHour: json['morningHour'] as int? ?? 8,
        morningMinute: json['morningMinute'] as int? ?? 0,
      );
}
