import 'package:flutter/material.dart';

import '../models/group_models.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../services/group_service.dart';
import '../services/notification_service.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _api = ApiService();
  final _groupService = GroupService();
  final _notifications = NotificationService();

  String? _token;
  bool _loading = true;
  String? _error;

  GroupInfo? _group;
  GroupMember? _me;
  List<GroupMember> _members = [];
  List<GroupTask> _myTasks = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _groupService.loadToken();
    if (token == null) {
      setState(() {
        _token = null;
        _loading = false;
      });
      return;
    }
    _token = token;
    await _refresh();
  }

  Future<void> _refresh() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groupJson = await _api.fetchGroup(token);
      final tasks = await _api.fetchMyTasks(token);
      await _syncNotifications(tasks);
      setState(() {
        _group = GroupInfo.fromJson(groupJson['group'] as Map<String, dynamic>);
        _me = GroupMember.fromJson(groupJson['me'] as Map<String, dynamic>);
        _members = (groupJson['members'] as List)
            .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
            .toList();
        _myTasks = tasks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _syncNotifications(List<GroupTask> tasks) async {
    await _notifications.init();
    await _notifications.requestPermissions();
    for (final t in tasks) {
      if (!t.active) {
        await _notifications.cancelReminder(t.id);
        continue;
      }
      await _notifications.scheduleReminder(Task(
        id: t.id,
        title: t.title,
        frequency: ReminderFrequency.values.byName(t.frequency),
        createdAt: DateTime.now(),
        morningHour: t.morningHour,
        morningMinute: t.morningMinute,
      ));
    }
  }

  Future<void> _leaveGroup() async {
    await _groupService.leaveGroup();
    for (final t in _myTasks) {
      await _notifications.cancelReminder(t.id);
    }
    setState(() {
      _token = null;
      _group = null;
      _me = null;
      _members = [];
      _myTasks = [];
    });
  }

  Future<void> _onGroupJoined(String token) async {
    await _groupService.saveToken(token);
    _token = token;
    await _refresh();
  }

  Future<void> _completeTask(GroupTask task) async {
    final token = _token;
    if (token == null) return;

    if (!task.hasConfirmationCode) {
      await _submitComplete(token, task.id, null);
      return;
    }

    final controller = TextEditingController();
    String? error;
    final code = await showDialog<String>(
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
                decoration: InputDecoration(labelText: 'Código', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final token = _token;
                if (token == null) return;
                try {
                  await _api.completeTask(
                    token: token,
                    taskId: task.id,
                    code: controller.text,
                  );
                  if (context.mounted) Navigator.pop(context, controller.text);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (code != null) {
      await _notifications.cancelReminder(task.id);
      await _refresh();
    }
  }

  Future<void> _submitComplete(String token, int taskId, String? code) async {
    try {
      await _api.completeTask(token: token, taskId: taskId, code: code);
      await _notifications.cancelReminder(taskId);
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _showAssignTaskDialog() async {
    final assignable = _members.where((m) => m.id != _me?.id).toList();
    if (assignable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nadie más se ha unido al grupo todavía.'),
      ));
      return;
    }

    final controller = TextEditingController();
    final codeController = TextEditingController();
    GroupMember assignee = assignable.first;
    ReminderFrequency frequency = ReminderFrequency.daily;
    TimeOfDay morningTime = const TimeOfDay(hour: 8, minute: 0);

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Asignar tarea'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<GroupMember>(
                  value: assignee,
                  isExpanded: true,
                  items: assignable
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m.displayName),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => assignee = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ej: Sacar la basura',
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
                    if (value != null) setDialogState(() => frequency = value);
                  },
                ),
                if (frequency == ReminderFrequency.morningAndNight) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hora de mañana'),
                    subtitle: Text(morningTime.format(context)),
                    trailing: const Icon(Icons.edit),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: morningTime,
                      );
                      if (picked != null) {
                        setDialogState(() => morningTime = picked);
                      }
                    },
                  ),
                ],
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
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    final token = _token;
    if (created == true && token != null && controller.text.trim().isNotEmpty) {
      try {
        await _api.createTask(
          token: token,
          assigneeMemberId: assignee.id,
          title: controller.text.trim(),
          frequency: frequency.name,
          morningHour: morningTime.hour,
          morningMinute: morningTime.minute,
          confirmationCode: codeController.text.trim(),
        );
        await _refresh();
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return _JoinOrCreateForm(api: _api, onJoined: _onGroupJoined);
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final me = _me!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _group?.name ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(onPressed: _leaveGroup, child: const Text('Salir')),
            ],
          ),
          Text('Código para invitar: ${_group?.joinCode}'),
          const SizedBox(height: 8),
          Text('${me.totalPoints} pts · racha ${me.currentStreak} día(s)'),
          const Divider(height: 32),
          Text('Mis tareas', style: Theme.of(context).textTheme.titleMedium),
          if (_myTasks.isEmpty) const Text('No tienes tareas asignadas.'),
          ..._myTasks.map((t) => Card(
                child: ListTile(
                  title: Text(t.title),
                  subtitle: Text(
                    '${t.active ? "Activa" : t.completedToday ? "Completada hoy" : "Pausada"}'
                    '${t.hasConfirmationCode ? " · pide código" : ""}',
                  ),
                  trailing: t.active
                      ? IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () => _completeTask(t),
                        )
                      : const Icon(Icons.check, color: Colors.green),
                ),
              )),
          if (me.isOwner) ...[
            const Divider(height: 32),
            Text('Miembros del grupo', style: Theme.of(context).textTheme.titleMedium),
            ..._members.map((m) => ListTile(
                  title: Text(m.displayName + (m.isOwner ? ' (tú)' : '')),
                  trailing: Text('${m.totalPoints} pts'),
                )),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showAssignTaskDialog,
              icon: const Icon(Icons.add_task),
              label: const Text('Asignar tarea'),
            ),
          ],
        ],
      ),
    );
  }
}

class _JoinOrCreateForm extends StatefulWidget {
  final ApiService api;
  final void Function(String token) onJoined;

  const _JoinOrCreateForm({required this.api, required this.onJoined});

  @override
  State<_JoinOrCreateForm> createState() => _JoinOrCreateFormState();
}

class _JoinOrCreateFormState extends State<_JoinOrCreateForm> {
  final _nameController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _createGroup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final json = await widget.api.createGroup(
        name: _groupNameController.text.trim(),
        displayName: _nameController.text.trim(),
      );
      widget.onJoined(json['token'] as String);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinGroup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final json = await widget.api.joinGroup(
        joinCode: _joinCodeController.text.trim(),
        displayName: _nameController.text.trim(),
      );
      widget.onJoined(json['token'] as String);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_busy && _nameController.text.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Únete o crea un grupo para compartir tareas con otras personas. '
            'Cualquiera puede salir del grupo cuando quiera desde aquí.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Tu nombre'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          Text('Crear grupo nuevo', style: Theme.of(context).textTheme.titleMedium),
          TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(labelText: 'Nombre del grupo'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: canSubmit && _groupNameController.text.trim().isNotEmpty
                ? _createGroup
                : null,
            child: const Text('Crear grupo'),
          ),
          const Divider(height: 40),
          Text('Unirse a un grupo', style: Theme.of(context).textTheme.titleMedium),
          TextField(
            controller: _joinCodeController,
            decoration: const InputDecoration(labelText: 'Código de invitación'),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: canSubmit && _joinCodeController.text.trim().isNotEmpty
                ? _joinGroup
                : null,
            child: const Text('Unirse'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
