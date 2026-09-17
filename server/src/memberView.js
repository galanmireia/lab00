export function memberView(member) {
  return {
    id: member.id,
    groupId: member.group_id,
    displayName: member.display_name,
    isOwner: member.is_owner,
    totalPoints: member.total_points,
    currentStreak: member.current_streak,
  };
}

export function taskView(task) {
  return {
    id: task.id,
    groupId: task.group_id,
    assigneeMemberId: task.assignee_member_id,
    createdByMemberId: task.created_by_member_id,
    title: task.title,
    frequency: task.frequency,
    morningHour: task.morning_hour,
    morningMinute: task.morning_minute,
    hasConfirmationCode: Boolean(task.confirmation_code),
    active: task.active,
    lastCompletedAt: task.last_completed_at,
  };
}
