import 'package:flutter/material.dart';

import '../../models/project.dart' as api;
import '../../services/project_service.dart';
import '../../utils/project_status.dart';

const _adaiOrange = Color(0xFFB5651D);
const _purple = Color(0xFF7C5CE0);

final _projectService = ProjectService();

class ProjetDetailScreen extends StatefulWidget {
  final int projectId;
  final String? initialName;

  const ProjetDetailScreen({
    super.key,
    required this.projectId,
    this.initialName,
  });

  @override
  State<ProjetDetailScreen> createState() => _ProjetDetailScreenState();
}

class _ProjetDetailScreenState extends State<ProjetDetailScreen> {
  api.Project? _project;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final project = await _projectService.getProjectById(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement du projet';
      });
    }
  }

  String get _title => _project?.name ?? widget.initialName ?? 'Projet';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'Détails du projet',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {
              // TODO: afficher plus d'options
            },
          ),
        ],
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
                          TextButton(
                            onPressed: _loadProject,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildContent(_project!),
      ),
    );
  }

  Widget _buildContent(api.Project project) {
    final statusStyle = projectStatusStyle(project.status);
    final letter = project.name.isNotEmpty ? project.name[0].toUpperCase() : '?';
    final color = projectColorFor(project.id);
    final tasks = project.tasks;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusStyle.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusStyle.label,
                            style: TextStyle(
                              color: statusStyle.fg,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (project.client != null) project.client!,
                        'Priorité ${projectPriorityLabel(project.priority)}',
                      ].join(' • '),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Avancement du projet',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
            ),
            Text(
              '${project.progress}%',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _purple),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: project.progress / 100,
            minHeight: 8,
            backgroundColor: Colors.grey.shade100,
            valueColor: const AlwaysStoppedAnimation(_purple),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Progression globale',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.timeline_outlined,
                iconBg: const Color(0xFFE3F0FB),
                iconColor: const Color(0xFF2E7CD6),
                value: '${project.sprints.length}',
                label: 'Sprints',
                caption: 'Total sprints',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                iconBg: const Color(0xFFE5F5E9),
                iconColor: const Color(0xFF3A9B54),
                value: '${tasks?.total ?? 0}',
                label: 'Tâches',
                caption: tasks != null ? '${tasks.done} terminées' : 'Total tâches',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_outline,
                iconBg: const Color(0xFFFDF0DE),
                iconColor: _adaiOrange,
                value: '${project.members.length}',
                label: 'Membres',
                caption: 'Dans le projet',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.event_outlined,
                iconBg: const Color(0xFFFCE4F1),
                iconColor: const Color(0xFFE0709B),
                value: project.deadline != null ? _formatDate(project.deadline!) : '-',
                label: 'Échéance',
                caption: 'Date limite',
                valueFontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const Text(
          'Description',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text(
          (project.description == null || project.description!.isEmpty)
              ? 'Aucune description disponible.'
              : project.description!,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 24),

        Text(
          'Membres de l\'équipe (${project.members.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
        ),
        const SizedBox(height: 8),
        if (project.members.isEmpty)
          Text('Aucun membre', style: TextStyle(color: Colors.grey.shade600))
        else
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final member in project.members)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=${member.id}'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          member.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                        Text(
                          member.role ?? '',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final String caption;
  final double valueFontSize;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.caption,
    this.valueFontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.w800, color: Colors.black),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          Text(
            caption,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
