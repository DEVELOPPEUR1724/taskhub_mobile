import 'package:flutter/material.dart';

import '../flow4/notificationListe_screen.dart';
import 'projetDetail_screen.dart';
import '../../services/notification_service.dart';
import '../../services/project_service.dart';
import '../../models/project.dart' as api;
import '../../utils/project_status.dart';

final _notificationService = NotificationService();
final _projectService = ProjectService();

const _adaiOrange = Color(0xFFB5651D);
const _purple = Color(0xFF7C5CE0);

class ProjetListScreen extends StatefulWidget {
  const ProjetListScreen({super.key});

  @override
  State<ProjetListScreen> createState() => _ProjetListScreenState();
}

class _ProjetListScreenState extends State<ProjetListScreen> {
  int _unreadNotifications = 0;

  List<api.Project> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUnreadNotifications();
    _loadProjects();
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadNotifications = count);
    } catch (_) {
      // Erreur silencieuse : le badge reste juste absent, pas bloquant.
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final projects = await _projectService.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des projets';
      });
    }
  }

  int get _avgProgress {
    if (_projects.isEmpty) return 0;
    final sum = _projects.fold<int>(0, (acc, p) => acc + p.progress);
    return (sum / _projects.length).round();
  }

  int get _totalTasks => _projects.fold<int>(0, (acc, p) => acc + (p.tasksCount ?? 0));

  int get _inProgressCount => _projects.where((p) => p.status == 'in_progress').length;

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationListeScreen(),
      ),
    );
    // Recharge au retour : l'utilisateur a pu marquer des notifications
    // comme lues (une par une ou "Tout marqué comme lu") pendant l'écran.
    _loadUnreadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Stack(
        children: [
          _buildBody(context),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              backgroundColor: _purple,
              onPressed: () {
                // TODO: créer un nouveau projet
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.menu, color: Colors.grey.shade800),
              const Text(
                'Projets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.search, color: Colors.grey.shade800),
                    onPressed: () {
                      // TODO: afficher la recherche de projets
                    },
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_none, color: Colors.grey.shade800),
                        onPressed: _openNotifications,
                      ),
                      if (_unreadNotifications > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$_unreadNotifications',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
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
                              onPressed: _loadProjects,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.work_outline,
                                  iconBg: const Color(0xFFEDE7FB),
                                  iconColor: _purple,
                                  value: '${_projects.length}',
                                  label: 'Total projets',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.show_chart,
                                  iconBg: const Color(0xFFE5F5E9),
                                  iconColor: const Color(0xFF3A9B54),
                                  value: '$_avgProgress%',
                                  label: 'Avancement moyen',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.trending_up,
                                  iconBg: const Color(0xFFE3F0FB),
                                  iconColor: const Color(0xFF2E7CD6),
                                  value: '$_inProgressCount',
                                  label: 'Projets en cours',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.check_circle_outline,
                                  iconBg: const Color(0xFFFDF0DE),
                                  iconColor: _adaiOrange,
                                  value: '$_totalTasks',
                                  label: 'Tâches totales',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Liste des projets',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          if (_projects.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text('Aucun projet', style: TextStyle(color: Colors.grey.shade600)),
                            )
                          else
                            for (final project in _projects) _ProjectCard(project: project),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final api.Project project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final color = projectColorFor(project.id);
    final letter = project.name.isNotEmpty ? project.name[0].toUpperCase() : '?';
    final statusStyle = projectStatusStyle(project.status);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProjetDetailScreen(projectId: project.id, initialName: project.name),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    letter,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        project.client ?? '',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusStyle.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusStyle.label,
                    style: TextStyle(color: statusStyle.fg, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (project.tasksCount != null)
                  Text(
                    '${project.tasksCount} tâche${project.tasksCount! > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                const Spacer(),
                Text(
                  '${project.progress}%',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: project.progress / 100,
                minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
