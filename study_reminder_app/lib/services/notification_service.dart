import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

/// Wraps local (device-only) notifications used as dismissible reminders.
///
/// Notifications reappear on a schedule the person configured for that
/// task and can always be swiped away — nothing here blocks the device or
/// re-shows itself faster than the chosen interval.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(settings);
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static const _nightHour = 22;
  static const _nightMinute = 0;

  /// The night reminder of a [ReminderFrequency.morningAndNight] task uses
  /// this derived id so it can be scheduled/cancelled independently from
  /// the morning one.
  int _nightIdFor(int taskId) => taskId + 1;

  Future<void> scheduleReminder(Task task) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'study_reminders',
        'Recordatorios de tareas',
        channelDescription: 'Recordatorios periódicos para tus tareas',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ongoing: false,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(),
    );
    const body =
        'Recordatorio: tienes pendiente esta tarea. Puedes descartar este aviso.';

    if (task.frequency == ReminderFrequency.morningAndNight) {
      await _scheduleDailyAt(
        task.id,
        task.title,
        body,
        details,
        task.morningHour,
        task.morningMinute,
      );
      await _scheduleDailyAt(
        _nightIdFor(task.id),
        task.title,
        body,
        details,
        _nightHour,
        _nightMinute,
      );
      return;
    }

    final repeatInterval = switch (task.frequency) {
      ReminderFrequency.hourly => RepeatInterval.hourly,
      ReminderFrequency.daily => RepeatInterval.daily,
      ReminderFrequency.weekly => RepeatInterval.weekly,
      ReminderFrequency.morningAndNight =>
        throw StateError('handled above'),
    };

    await _plugin.periodicallyShow(
      task.id,
      task.title,
      body,
      repeatInterval,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Schedules a notification that repeats every day at [hour]:[minute],
  /// identically on Android and iOS. Neither platform offers a reliable
  /// way for a background app to detect a real screen-unlock event
  /// without an always-on foreground service, so a fixed clock time is
  /// used on both instead.
  Future<void> _scheduleDailyAt(
    int id,
    String title,
    String body,
    NotificationDetails details,
    int hour,
    int minute,
  ) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelReminder(int taskId) async {
    await _plugin.cancel(taskId);
    await _plugin.cancel(_nightIdFor(taskId));
  }
}
