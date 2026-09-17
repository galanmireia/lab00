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

    final repeatInterval = switch (task.frequency) {
      ReminderFrequency.hourly => RepeatInterval.hourly,
      ReminderFrequency.daily => RepeatInterval.daily,
      ReminderFrequency.weekly => RepeatInterval.weekly,
    };

    await _plugin.periodicallyShow(
      task.id,
      task.title,
      'Recordatorio: tienes pendiente esta tarea. Puedes descartar este aviso.',
      repeatInterval,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelReminder(int taskId) async {
    await _plugin.cancel(taskId);
  }

  // Kept for completeness in case a future feature needs exact one-off
  // scheduling (e.g. "remind me once at 6pm").
  tz.TZDateTime nextInstanceOf(DateTime dateTime) =>
      tz.TZDateTime.from(dateTime, tz.local);
}
