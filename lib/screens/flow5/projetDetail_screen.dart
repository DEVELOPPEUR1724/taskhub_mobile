import 'package:flutter/material.dart';

import '../../models/project.dart' as api;
import '../../models/document.dart';
import '../../services/project_service.dart';
import '../../services/document_service.dart';
import '../../services/profil_service.dart';
import '../../utils/project_status.dart';
import '../../widgets/document_list_tile.dart';
import '../../widgets/document_upload_sheet.dart';

const _adaiOrange = Color(0xFFE57A44);

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

  final _documentService = DocumentService();
  List<TaskDocument> _documents = [];
  bool _isDocumentsLoading = true;
  bool _canManageDocuments = false;
  int? _downloadingDocumentId;

  @override
  void initState() {
    super.initState();
    _loadProject();
    _loadDocuments();
    _loadDocumentPermission();
  }

  Future<void> _loadDocumentPermission() async {
    try {
      final profile = await ProfilService().getProfil();
      if (!mounted) return;
      setState(() => _canManageDocuments = kDocumentManagerRoles.contains(profile.role));
    } catch (_) {
      // Reste à false : mieux vaut cacher l'upload que risquer un 403.
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isDocumentsLoading = true);
    try {
      final documents = await _documentService.listForProject(widget.projectId);
      if (!mounted) return;
      setState(() => _documents = documents);
    } catch (_) {
      // Silencieux : section secondaire, ne bloque pas la consultation du projet.
    } finally {
      if (mounted) setState(() => _isDocumentsLoading = false);
    }
  }

  Future<void> _uploadDocument() async {
    final document = await showDocumentUploadSheet(
      context,
      onUpload: (bytes, fileName, {title, description}) => _documentService.uploadToProject(
        widget.projectId,
        bytes,
        fileName,
        title: title,
        description: description,
      ),
    );
    if (document != null && mounted) {
      setState(() => _documents = [document, ..._documents]);
    }
  }

  Future<void> _downloadDocument(TaskDocument document) async {
    setState(() => _downloadingDocumentId = document.id);
    try {
      final path = await _documentService.downloadAndSave(document);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistré : $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingDocumentId = null);
    }
  }

  Future<void> _deleteDocument(TaskDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text(document.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF453A))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _documents = _documents.where((d) => d.id != document.id).toList());
    try {
      await _documentService.delete(document.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _documents = [..._documents, document]..sort((a, b) => a.id.compareTo(b.id)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Détails du projet',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
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
                            style: TextStyle(color: colors.onSurfaceVariant),
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
                : _buildContent(context, _project!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, api.Project project) {
    final colors = Theme.of(context).colorScheme;
    final statusStyle = projectStatusStyle(context, project.status);
    final letter = project.name.isNotEmpty ? project.name[0].toUpperCase() : '?';
    final color = projectColorFor(project.id);
    final tasks = project.tasks;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
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
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5, height: 1.3),
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
            Text(
              'Avancement du projet',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.onSurface),
            ),
            Text(
              '${project.progress}%',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: projectProgressColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: project.progress / 100,
            minHeight: 8,
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation(projectProgressColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Progression globale',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.timeline_outlined,
                iconBg: const Color(0xFFE3F0FB),
                iconColor: const Color(0xFF0A84FF),
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
                iconColor: const Color(0xFF32D74B),
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

        Text(
          'Description',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          (project.description == null || project.description!.isEmpty)
              ? 'Aucune description disponible.'
              : project.description!,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 24),

        Text(
          'Membres de l\'équipe (${project.members.length})',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        const SizedBox(height: 8),
        if (project.members.isEmpty)
          Text('Aucun membre', style: TextStyle(color: colors.onSurfaceVariant))
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface),
                        ),
                        Text(
                          member.role ?? '',
                          style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Documents',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
            ),
            if (_canManageDocuments)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Ajouter un document',
                icon: const Icon(Icons.add, color: _adaiOrange),
                onPressed: _uploadDocument,
              ),
          ],
        ),
        if (_isDocumentsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else if (_documents.isEmpty)
          const DocumentEmptyState()
        else
          for (final document in _documents)
            DocumentListTile(
              document: document,
              downloading: _downloadingDocumentId == document.id,
              canDelete: _canManageDocuments,
              onTap: () => _downloadDocument(document),
              onDelete: () => _deleteDocument(document),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
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
            style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.w800, color: colors.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.onSurface),
          ),
          Text(
            caption,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
