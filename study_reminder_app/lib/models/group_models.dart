class GroupMember {
  final int id;
  final int groupId;
  final String displayName;
  final bool isOwner;
  final int totalPoints;
  final int currentStreak;

  GroupMember({
    required this.id,
    required this.groupId,
    required this.displayName,
    required this.isOwner,
    required this.totalPoints,
    required this.currentStreak,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id'] as int,
        groupId: json['groupId'] as int,
        displayName: json['displayName'] as String,
        isOwner: json['isOwner'] as bool,
        totalPoints: json['totalPoints'] as int,
        currentStreak: json['currentStreak'] as int,
      );
}

class GroupInfo {
  final int id;
  final String name;
  final String joinCode;

  GroupInfo({required this.id, required this.name, required this.joinCode});

  factory GroupInfo.fromJson(Map<String, dynamic> json) => GroupInfo(
        id: json['id'] as int,
        name: json['name'] as String,
        joinCode: json['joinCode'] as String,
      );
}

class GroupTask {
  final int id;
  final int groupId;
  final int assigneeMemberId;
  final int createdByMemberId;
  final String title;
  final String frequency;
  final int morningHour;
  final int morningMinute;
  final bool hasConfirmationCode;
  final bool active;
  final DateTime? lastCompletedAt;

  GroupTask({
    required this.id,
    required this.groupId,
    required this.assigneeMemberId,
    required this.createdByMemberId,
    required this.title,
    required this.frequency,
    required this.morningHour,
    required this.morningMinute,
    required this.hasConfirmationCode,
    required this.active,
    required this.lastCompletedAt,
  });

  bool get completedToday {
    final last = lastCompletedAt;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  factory GroupTask.fromJson(Map<String, dynamic> json) => GroupTask(
        id: json['id'] as int,
        groupId: json['groupId'] as int,
        assigneeMemberId: json['assigneeMemberId'] as int,
        createdByMemberId: json['createdByMemberId'] as int,
        title: json['title'] as String,
        frequency: json['frequency'] as String,
        morningHour: json['morningHour'] as int,
        morningMinute: json['morningMinute'] as int,
        hasConfirmationCode: json['hasConfirmationCode'] as bool,
        active: json['active'] as bool,
        lastCompletedAt: json['lastCompletedAt'] != null
            ? DateTime.parse(json['lastCompletedAt'] as String)
            : null,
      );
}
