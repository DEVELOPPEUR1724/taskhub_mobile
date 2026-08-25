import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';

const _adaiOrange = Color(0xFFB5651D);

final _taskService = TaskService();

class TaskHistoriqueScreen extends StatefulWidget {
  final int taskId;

  const TaskHistoriqueScreen({super.key, required this.taskId});

  @override
  State<TaskHistoriqueScreen> createState() => _TaskHistoriqueScreenState();
}

class _TaskHistoriqueScreenState extends State<TaskHistoriqueScreen> {
  TaskHistory? _history;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final history = await _taskService.getTaskHistory(widget.taskId);
      if (!mounted) return;
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '--';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Historique de suivi',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: SafeArea(
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
                          TextButton(onPressed: _loadHistory, child: const Text('Réessayer')),
                        ],
                      ),
                    ),
                  )
                : _buildContent(_history!),
      ),
    );
  }

  Widget _buildContent(TaskHistory history) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temps total', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text(
                      history.trackingDuration ?? '--',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _adaiOrange),
                    ),
                  ],
                ),
              ),
              if (history.trackingPaused)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0DE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'En pause',
                    style: TextStyle(color: _adaiOrange, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Sessions (${history.sessions.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
        ),
        const SizedBox(height: 12),
        if (history.sessions.isEmpty)
          Text('Aucune session enregistrée', style: TextStyle(color: Colors.grey.shade600))
        else
          for (final session in history.sessions) _SessionTile(session: session, formatDateTime: _formatDateTime),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final TaskTrackingSession session;
  final String Function(DateTime?) formatDateTime;

  const _SessionTile({required this.session, required this.formatDateTime});

  @override
  Widget build(BuildContext context) {
    final isOngoing = session.endedAt == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isOngoing ? const Color(0xFFFDF0DE) : const Color(0xFFE5F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOngoing ? Icons.timelapse : Icons.check,
              size: 18,
              color: isOngoing ? _adaiOrange : const Color(0xFF3A9B54),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatDateTime(session.startedAt)} → ${isOngoing ? 'en cours' : formatDateTime(session.endedAt)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
          Text(
            session.duration,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
