// Basic smoke test: the app boots and shows the empty-state home screen.
//
// Notifications and shared_preferences talk to native platform channels
// that don't exist in the widget-test VM, so both are mocked here.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:study_reminder/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
      switch (call.method) {
        case 'getNotificationAppLaunchDetails':
          return {'notificationLaunchedApp': false};
        default:
          return true;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  testWidgets('App boots and shows the task list screen', (tester) async {
    await tester.pumpWidget(const StudyReminderApp());
    await tester.pumpAndSettle();

    expect(find.text('Recordatorios de estudio'), findsOneWidget);
    expect(find.text('Nueva tarea'), findsOneWidget);
  });
}
