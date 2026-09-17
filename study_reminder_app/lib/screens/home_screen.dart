import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/user_stats.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _notifications = NotificationService();

  List<Task> _tasks = [];
  UserStats _stats = UserStats();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _notifications.init();
    await _notifications.requestPermissions();
    final tasks = await _storage.loadTasks();
    final stats = await _storage.loadStats();
    setState(() {
      _tasks = tasks;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _persistTasks() => _storage.saveTasks(_tasks);
  Future<void> _persistStats() => _storage.saveStats(_stats);

  Future<void> _addTask(
    String title,
    ReminderFrequency frequency,
    String? confirmationCode,
  ) async {
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      frequency: frequency,
      createdAt: DateTime.now(),
      confirmationCode:
          (confirmationCode != null && confirmationCode.isNotEmpty)
              ? confirmationCode
              : null,
    );
    await _notifications.scheduleReminder(task);
    setState(() => _tasks = [..._tasks, task]);
    await _persistTasks();
  }

  /// Entry point for the "mark as completed" button. If the task has a
  /// confirmation code, it's asked here; the reminder notification itself
  /// is never affected by this and can always be dismissed on its own.
  Future<void> _onCompletePressed(Task task) async {
    final code = task.confirmationCode;
    if (code == null || code.isEmpty) {
      await _completeTask(task);
      return;
    }

    final confirmed = await _askConfirmationCode(code);
    if (confirmed) {
      await _completeTask(task);
    }
  }

  Future<bool> _askConfirmationCode(String expectedCode) async {
    final controller = TextEditingController();
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirmar tarea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Introduce el código para confirmar que la tarea '
                  'está hecha.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Código',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text == expectedCode) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => error = 'Código incorrecto');
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _completeTask(Task task) async {
    await _notifications.cancelReminder(task.id);
    setState(() {
      task.active = false;
      task.lastCompletedAt = DateTime.now();
      _stats.registerCompletion(DateTime.now());
    });
    await _persistTasks();
    await _persistStats();
  }

  Future<void> _reactivateTask(Task task) async {
    await _notifications.scheduleReminder(task);
    setState(() => task.active = true);
    await _persistTasks();
  }

  Future<void> _deleteTask(Task task) async {
    await _notifications.cancelReminder(task.id);
    setState(() => _tasks = _tasks.where((t) => t.id != task.id).toList());
    await _persistTasks();
  }

  Future<void> _showAddTaskDialog() async {
    final controller = TextEditingController();
    final codeController = TextEditingController();
    ReminderFrequency frequency = ReminderFrequency.daily;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva tarea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Ej: Repasar apuntes de matemáticas',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButton<ReminderFrequency>(
                value: frequency,
                isExpanded: true,
                items: ReminderFrequency.values
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => frequency = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Código de confirmación (opcional)',
                  helperText: 'Se pedirá solo al marcar la tarea como '
                      'completada. El aviso siempre se puede cerrar.',
                  helperMaxLines: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      await _addTask(
        controller.text.trim(),
        frequency,
        codeController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios de estudio'),
      ),
      body: Column(
        children: [
          _StatsBanner(stats: _stats),
          Expanded(
            child: _tasks.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return _TaskTile(
                        task: task,
                        onComplete: () => _onCompletePressed(task),
                        onReactivate: () => _reactivateTask(task),
                        onDelete: () => _deleteTask(task),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}

class _StatsBanner extends StatelessWidget {
  final UserStats stats;

  const _StatsBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatBadge(
            icon: Icons.star,
            label: '${stats.totalPoints} pts',
          ),
          _StatBadge(
            icon: Icons.local_fire_department,
            label: 'Racha: ${stats.currentStreak} día(s)',
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Aún no tienes tareas. Toca "Nueva tarea" para crear tu primer '
          'recordatorio de estudio o trabajo.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onComplete;
  final VoidCallback onReactivate;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onComplete,
    required this.onReactivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final doneToday = task.completedToday;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(task.title),
        subtitle: Text(
          '${task.frequency.label} · '
          '${task.active ? "Activo" : doneToday ? "Completada hoy" : "Pausado"}'
          '${task.confirmationCode != null ? " · pide código al completar" : ""}',
        ),
        leading: CircleAvatar(
          backgroundColor: doneToday
              ? Colors.green
              : Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            doneToday ? Icons.check : Icons.notifications_active,
            color: doneToday ? Colors.white : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.active)
              IconButton(
                tooltip: 'Marcar como completada',
                icon: const Icon(Icons.check_circle_outline),
                onPressed: onComplete,
              )
            else
              IconButton(
                tooltip: 'Reactivar recordatorio',
                icon: const Icon(Icons.replay),
                onPressed: onReactivate,
              ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
