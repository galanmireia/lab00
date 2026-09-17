import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const StudyReminderApp());
}

class StudyReminderApp extends StatelessWidget {
  const StudyReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recordatorios de estudio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
