import 'package:flutter/material.dart';

import '../../models/task.dart' as api;
import '../../services/task_service.dart';
import 'taskDetail_screen.dart';

final taskService = TaskService();

const _adaiOrange = Color(0xFFB5651D);
const _adaiBrown = Color(0xFF3E2B1F);

// Valeurs exactes de App\Enums\TaskStatus (backend) : todo, in_progress,
// blocked, done, to_test.
enum TaskStatus { aFaire, enCours, bloque, aTester, termine }

String _statusToApiValue(TaskStatus status) {
  switch (status) {
    case TaskStatus.aFaire:
      return 'todo';
    case TaskStatus.enCours:
      return 'in_progress';
    case TaskStatus.bloque:
      return 'blocked';
    case TaskStatus.aTester:
      return 'to_test';
    case TaskStatus.termine:
      return 'done';
  }
}

TaskStatus _mapApiStatus(String status) {
  switch (status) {
    case 'todo':
      return TaskStatus.aFaire;
    case 'in_progress':
      return TaskStatus.enCours;
    case 'blocked':
      return TaskStatus.bloque;
    case 'to_test':
      return TaskStatus.aTester;
    case 'done':
      return TaskStatus.termine;
    default:
      return TaskStatus.aFaire;
  }
}

class Task {
  final int id;
  final String title;
  final String project;
  final String deadline;
  final TaskStatus status;
  final String avatarUrl;

  const Task({
    required this.id,
    required this.title,
    required this.project,
    required this.deadline,
    required this.status,
    required this.avatarUrl,
  });
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  TaskStatus? _selectedFilter; // null = "Toutes"

  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiTasks = await taskService.getAllTasks(
        status: _selectedFilter != null ? _statusToApiValue(_selectedFilter!) : null,
      );
      final uiTasks = apiTasks.map(_mapApiTaskToUiTask).toList();

      if (!mounted) return;
      setState(() {
        _tasks = uiTasks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onFilterChanged(TaskStatus? filter) {
    setState(() => _selectedFilter = filter);
    _loadTasks();
  }

  Task _mapApiTaskToUiTask(api.Task apiTask) {
    return Task(
      id: apiTask.id,
      title: apiTask.title,
      project: apiTask.projectName ?? 'Projet #${apiTask.projectId}',
      deadline: apiTask.deadline != null
          ? '${apiTask.deadline!.toLocal().day.toString().padLeft(2, '0')}/'
              '${apiTask.deadline!.toLocal().month.toString().padLeft(2, '0')}/'
              '${apiTask.deadline!.toLocal().year}'
          : 'Non définie',
      status: _mapApiStatus(apiTask.status),
      avatarUrl: 'https://i.pravatar.cc/100?u=${apiTask.assignedToId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mes tâches',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _adaiBrown,
                  ),
                ),
                const CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    'https://dashboard-wally-process-interne.adaiexpertise.fr/logo_sans_fond.png',
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Toutes',
                  selected: _selectedFilter == null,
                  onTap: () => _onFilterChanged(null),
                ),
                _FilterChip(
                  label: 'À faire',
                  selected: _selectedFilter == TaskStatus.aFaire,
                  onTap: () => _onFilterChanged(TaskStatus.aFaire),
                ),
                _FilterChip(
                  label: 'En cours',
                  selected: _selectedFilter == TaskStatus.enCours,
                  onTap: () => _onFilterChanged(TaskStatus.enCours),
                ),
                _FilterChip(
                  label: 'Bloqué',
                  selected: _selectedFilter == TaskStatus.bloque,
                  onTap: () => _onFilterChanged(TaskStatus.bloque),
                ),
                _FilterChip(
                  label: 'À tester',
                  selected: _selectedFilter == TaskStatus.aTester,
                  onTap: () => _onFilterChanged(TaskStatus.aTester),
                ),
                _FilterChip(
                  label: 'Terminé',
                  selected: _selectedFilter == TaskStatus.termine,
                  onTap: () => _onFilterChanged(TaskStatus.termine),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _loadTasks,
                                child: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _tasks.isEmpty
                        ? Center(
                            child: Text('Aucune tâche', style: TextStyle(color: Colors.grey.shade600)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _tasks.length,
                            itemBuilder: (context, index) {
                              return _TaskCard(task: _tasks[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: _adaiOrange,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? _adaiOrange : Colors.grey.shade300),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;

  const _TaskCard({required this.task});

  ({String label, Color bg, Color fg}) get _statusStyle {
    switch (task.status) {
      case TaskStatus.aFaire:
        return (label: 'À faire', bg: const Color(0xFFE3F0FB), fg: const Color(0xFF2E7CD6));
      case TaskStatus.enCours:
        return (label: 'En cours', bg: const Color(0xFFE5F5E9), fg: const Color(0xFF3A9B54));
      case TaskStatus.bloque:
        return (label: 'Bloqué', bg: const Color(0xFFFCE4E4), fg: const Color(0xFFE05B33));
      case TaskStatus.aTester:
        return (label: 'À tester', bg: const Color(0xFFFDF0DE), fg: _adaiOrange);
      case TaskStatus.termine:
        return (label: 'Terminé', bg: Colors.grey.shade200, fg: Colors.grey.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(taskId: task.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        task.project,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'Deadline: ${task.deadline}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(task.avatarUrl),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
