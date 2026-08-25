import 'package:flutter/material.dart';

import 'taskComment_screen.dart';
import 'taskHistorique_screen.dart';
import '../../services/task_service.dart';
import '../../models/task.dart' as api;

const _adaiOrange = Color(0xFFB5651D);

class ChecklistItem {
  final String label;
  bool done;

  ChecklistItem({required this.label, this.done = false});
}

class TaskDetailScreen extends StatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _descriptionExpanded = true;
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  api.Task? _task;

  final taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _loadDetailsTasks();
  }

  Future<void> _loadDetailsTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final task = await taskService.getTaskById(widget.taskId.toString());
      if (!mounted) return;
      setState(() {
        _task = task;
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

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _isActionLoading = true);
    try {
      await action();
      await _loadDetailsTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  final List<ChecklistItem> _checklist = [
    ChecklistItem(label: 'Créer la vue UI', done: true),
    ChecklistItem(label: 'Intégrer les champs email & mot de passe', done: true),
    ChecklistItem(label: 'Intégrer connexion biométrique'),
    ChecklistItem(label: 'Gérer les erreurs de connexion'),
    ChecklistItem(label: 'Tests unitaires'),
  ];

  int get _doneCount => _checklist.where((item) => item.done).length;

  ({String label, Color bg, Color fg}) get _statusStyle {
    switch (_task?.status) {
      case 'todo':
        return (label: 'À faire', bg: const Color(0xFFE3F0FB), fg: const Color(0xFF2E7CD6));
      case 'in_progress':
        return (label: 'En cours', bg: const Color(0xFFE5F5E9), fg: const Color(0xFF3A9B54));
      case 'blocked':
        return (label: 'Bloqué', bg: const Color(0xFFFCE4E4), fg: const Color(0xFFE05B33));
      case 'to_test':
        return (label: 'À tester', bg: const Color(0xFFFDF0DE), fg: _adaiOrange);
      case 'done':
        return (label: 'Terminé', bg: Colors.grey.shade200, fg: Colors.grey.shade700);
      default:
        return (label: _task?.status ?? '-', bg: Colors.grey.shade200, fg: Colors.grey.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  IconButton(
                    icon: Icon(Icons.history, color: Colors.grey.shade700),
                    tooltip: 'Historique de suivi',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TaskHistoriqueScreen(taskId: widget.taskId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Expanded(
                child: Center(
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
                          onPressed: _loadDetailsTasks,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _task!.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusStyle.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusStyle.label,
                            style: TextStyle(
                              color: _statusStyle.fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.flag, size: 15, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          _task!.priority,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_task!.trackingDuration != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            _task!.trackingPaused == true ? Icons.pause_circle_outline : Icons.timer_outlined,
                            size: 15,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Temps de suivi : ${_task!.trackingDuration}'
                            '${_task!.trackingPaused == true ? ' (en pause)' : ''}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            label: 'Projet',
                            value: _task!.projectName ?? 'Projet #${_task!.projectId}',
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),
                          _InfoRow(
                            label: 'Sprint',
                            value: _task!.sprintName ??
                                (_task!.sprintId != null ? 'Sprint #${_task!.sprintId}' : 'Aucun'),
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),
                          _InfoRow(
                            label: 'Deadline',
                            value: _task!.deadline != null
                                ? '${_task!.deadline!.toLocal().day.toString().padLeft(2, '0')}/'
                                    '${_task!.deadline!.toLocal().month.toString().padLeft(2, '0')}/'
                                    '${_task!.deadline!.toLocal().year}'
                                : 'Non définie',
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),
                          _InfoRow(
                            label: 'Assigné à',
                            value: _task!.assignedToName ?? 'Utilisateur #${_task!.assignedToId}',
                          ),
                          if (_task!.createdByName != null) ...[
                            Divider(height: 1, color: Colors.grey.shade100),
                            _InfoRow(
                              label: 'Créée par',
                              value: _task!.createdByName!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    InkWell(
                      onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          Icon(
                            _descriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                    if (_descriptionExpanded) ...[
                      const SizedBox(height: 8),
                      Text(
                        _task!.description ?? 'Aucune description',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Checklist',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '$_doneCount/${_checklist.length}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final item in _checklist)
                      CheckboxListTile(
                        value: item.done,
                        onChanged: (value) {
                          setState(() => item.done = value ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: _adaiOrange,
                        title: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            color: item.done ? Colors.grey.shade500 : Colors.black,
                          ),
                        ),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isLoading || _errorMessage != null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(child: _buildPrimaryAction()),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => TaskCommentScreen(taskId: widget.taskId),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.more_horiz, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPrimaryAction() {
    final task = _task;
    if (task == null) return const SizedBox.shrink();

    ({String label, IconData icon, Color color, Future<void> Function() action})? primary;
    switch (task.status) {
      case 'todo':
      case 'blocked':
        primary = (
          label: 'Commencer',
          icon: Icons.play_arrow,
          color: const Color(0xFF2E7CD6),
          action: () => taskService.startTask(task.id),
        );
      case 'in_progress':
        primary = task.trackingPaused == true
            ? (
                label: 'Reprendre',
                icon: Icons.play_arrow,
                color: const Color(0xFF3A9B54),
                action: () => taskService.resumeTask(task.id),
              )
            : (
                label: 'Mettre en pause',
                icon: Icons.pause,
                color: _adaiOrange,
                action: () => taskService.pauseTask(task.id),
              );
      default:
        primary = null;
    }

    if (task.status == 'done') {
      return SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Tâche terminée', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Row(
      children: [
        if (primary != null)
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isActionLoading ? null : () => _runAction(primary!.action),
                icon: Icon(primary.icon, size: 20),
                label: Text(primary.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        if (primary != null) const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isActionLoading ? null : () => _runAction(() => taskService.completeTask(task.id)),
              icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF3A9B54)),
              label: const Text(
                'Terminer',
                style: TextStyle(color: Color(0xFF3A9B54), fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF3A9B54)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _InfoRow({required this.label, this.value, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          valueWidget ??
              Text(
                value ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
        ],
      ),
    );
  }
}
