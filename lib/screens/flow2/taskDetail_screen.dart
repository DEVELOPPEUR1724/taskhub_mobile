import 'package:flutter/material.dart';

import 'taskComment_screen.dart';
import 'taskHistorique_screen.dart';
import '../../services/task_service.dart';
import '../../services/app_database.dart';
import '../../services/sync_service.dart';
import '../../services/document_service.dart';
import '../../services/profil_service.dart';
import '../../models/task.dart' as api;
import '../../models/document.dart';
import '../../theme/app_colors.dart';
import '../../widgets/document_list_tile.dart';
import '../../widgets/document_upload_sheet.dart';

const _adaiOrange = Color(0xFFE57A44);

// Cf. UserRole::adminValues() côté Laravel — seuls ces rôles passent
// DocumentPolicy::create/delete (avant même de vérifier l'appartenance du
// document), donc on cache l'upload/la suppression pour les autres plutôt
// que de laisser un 403 surprendre l'utilisateur au clic.
const _documentManagerRoles = ['super_admin', 'admin_tech', 'admin'];

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

  List<api.TaskChecklist> _checklist = [];
  bool _isChecklistLoading = true;
  bool _isAddingChecklistItem = false;

  final taskService = TaskService();

  final _documentService = DocumentService();
  List<TaskDocument> _documents = [];
  bool _isDocumentsLoading = true;
  bool _canManageDocuments = false;
  int? _downloadingDocumentId;

  @override
  void initState() {
    super.initState();
    _loadDetailsTasks();
    _loadChecklist();
    _loadDocuments();
    _loadDocumentPermission();
  }

  Future<void> _loadChecklist() async {
    setState(() => _isChecklistLoading = true);
    try {
      final checklist = await taskService.getChecklists(widget.taskId);
      if (!mounted) return;
      setState(() => _checklist = checklist);
    } catch (_) {
      // Silencieux : la checklist est secondaire, la tâche reste consultable
      // même si son chargement échoue (ex. hors ligne, non géré par la
      // synchro pour cette ressource).
    } finally {
      if (mounted) setState(() => _isChecklistLoading = false);
    }
  }

  Future<void> _toggleChecklistItem(api.TaskChecklist item, bool value) async {
    final index = _checklist.indexWhere((c) => c.id == item.id);
    if (index == -1) return;
    setState(() => _checklist[index] = item.copyWith(isDone: value));
    try {
      final updated =
          await taskService.setChecklistItemDone(widget.taskId, item.id, value);
      if (!mounted) return;
      setState(() => _checklist[index] = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checklist[index] = item);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
  }

  Future<void> _addChecklistItem(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() => _isAddingChecklistItem = true);
    try {
      final item = await taskService.addChecklistItem(widget.taskId, trimmed);
      if (!mounted) return;
      setState(() => _checklist = [..._checklist, item]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAddingChecklistItem = false);
    }
  }

  Future<void> _deleteChecklistItem(api.TaskChecklist item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet élément ?'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer',
                style: TextStyle(color: Color(0xFFFF453A))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _checklist = _checklist.where((c) => c.id != item.id).toList());
    try {
      await taskService.deleteChecklistItem(widget.taskId, item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checklist = [..._checklist, item]
        ..sort((a, b) => a.id.compareTo(b.id)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
  }

  Future<void> _promptAddChecklistItem() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvel élément'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex : Tests unitaires'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (title != null) _addChecklistItem(title);
  }

  Future<void> _loadDocumentPermission() async {
    try {
      final profile = await ProfilService().getProfil();
      if (!mounted) return;
      setState(() => _canManageDocuments = _documentManagerRoles.contains(profile.role));
    } catch (_) {
      // Reste à false : mieux vaut cacher l'upload que risquer un 403.
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isDocumentsLoading = true);
    try {
      final documents = await _documentService.listForTask(widget.taskId);
      if (!mounted) return;
      setState(() => _documents = documents);
    } catch (_) {
      // Silencieux, comme la checklist : section secondaire, ne bloque pas
      // la consultation de la tâche.
    } finally {
      if (mounted) setState(() => _isDocumentsLoading = false);
    }
  }

  Future<void> _uploadDocument() async {
    final document = await showDocumentUploadSheet(
      context,
      onUpload: (bytes, fileName, {title, description}) => _documentService.uploadToTask(
        widget.taskId,
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
      // Hors ligne / erreur réseau : on retombe sur le cache local avant
      // d'afficher une vraie erreur (indisponible sur Flutter Web, où
      // sqflite n'existe pas).
      api.Task? cached;
      try {
        cached = await AppDatabase.instance.getCachedTask(widget.taskId);
      } catch (_) {}
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _task = cached;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runAction(Future<api.Task> Function() action) async {
    setState(() => _isActionLoading = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _task = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  int get _doneCount => _checklist.where((item) => item.isDone).length;

  ({String label, AppStatusColor color}) get _statusInfo {
    switch (_task?.status) {
      case 'todo':
        return (label: 'À faire', color: AppStatusColor.info);
      case 'in_progress':
        return (label: 'En cours', color: AppStatusColor.success);
      case 'blocked':
        return (label: 'Bloqué', color: AppStatusColor.danger);
      case 'to_test':
        return (label: 'À tester', color: AppStatusColor.warning);
      case 'done':
        return (label: 'Terminé', color: AppStatusColor.neutral);
      default:
        return (label: _task?.status ?? '-', color: AppStatusColor.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colors.onSurface),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  IconButton(
                    icon: Icon(Icons.history, color: colors.onSurfaceVariant),
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
                          style: TextStyle(color: colors.onSurfaceVariant),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColorFor(context, _statusInfo.color).bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusInfo.label,
                            style: TextStyle(
                              color: statusColorFor(context, _statusInfo.color).fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.flag, size: 15, color: Color(0xFFFF453A)),
                        const SizedBox(width: 4),
                        Text(
                          _task!.priority,
                          style: const TextStyle(
                            color: Color(0xFFFF453A),
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
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Temps de suivi : ${_task!.trackingDuration}'
                            '${_task!.trackingPaused == true ? ' (en pause)' : ''}',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outlineVariant, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            label: 'Projet',
                            value: _task!.projectName ?? 'Projet #${_task!.projectId}',
                          ),
                          Divider(height: 1, color: colors.outlineVariant),
                          _InfoRow(
                            label: 'Sprint',
                            value: _task!.sprintName ??
                                (_task!.sprintId != null ? 'Sprint #${_task!.sprintId}' : 'Aucun'),
                          ),
                          Divider(height: 1, color: colors.outlineVariant),
                          _InfoRow(
                            label: 'Deadline',
                            value: _task!.deadline != null
                                ? '${_task!.deadline!.toLocal().day.toString().padLeft(2, '0')}/'
                                    '${_task!.deadline!.toLocal().month.toString().padLeft(2, '0')}/'
                                    '${_task!.deadline!.toLocal().year}'
                                : 'Non définie',
                          ),
                          Divider(height: 1, color: colors.outlineVariant),
                          _InfoRow(
                            label: 'Assigné à',
                            value: _task!.assignedToName ?? 'Utilisateur #${_task!.assignedToId}',
                          ),
                          if (_task!.createdByName != null) ...[
                            Divider(height: 1, color: colors.outlineVariant),
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
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          Icon(
                            _descriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    if (_descriptionExpanded) ...[
                      const SizedBox(height: 8),
                      Text(
                        _task!.description ?? 'Aucune description',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Checklist',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            if (!_isChecklistLoading)
                              Text(
                                '$_doneCount/${_checklist.length}',
                                style: TextStyle(
                                    color: colors.onSurfaceVariant, fontSize: 13),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Ajouter un élément',
                              icon: _isAddingChecklistItem
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.add, color: _adaiOrange),
                              onPressed: _isAddingChecklistItem
                                  ? null
                                  : _promptAddChecklistItem,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_isChecklistLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_checklist.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Aucun élément pour l\'instant.',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                        ),
                      )
                    else
                      for (final item in _checklist)
                        CheckboxListTile(
                          value: item.isDone,
                          onChanged: (value) =>
                              _toggleChecklistItem(item, value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: _adaiOrange,
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              color: item.isDone
                                  ? colors.onSurfaceVariant
                                  : colors.onSurface,
                            ),
                          ),
                          secondary: IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Supprimer',
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Color(0xFFFF453A)),
                            onPressed: () => _deleteChecklistItem(item),
                          ),
                        ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Documents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
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
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
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
                        side: BorderSide(color: colors.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Icon(Icons.more_horiz, color: colors.onSurface),
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

    ({String label, IconData icon, Color color, Future<api.Task> Function() action})? primary;
    switch (task.status) {
      case 'todo':
      case 'blocked':
        primary = (
          label: 'Commencer',
          icon: Icons.play_arrow,
          color: const Color(0xFF0A84FF),
          action: () => SyncService.instance.queueStartTask(task),
        );
      case 'in_progress':
        primary = task.trackingPaused == true
            ? (
                label: 'Reprendre',
                icon: Icons.play_arrow,
                color: const Color(0xFF32D74B),
                action: () => SyncService.instance.queueResumeTask(task),
              )
            : (
                label: 'Mettre en pause',
                icon: Icons.pause,
                color: _adaiOrange,
                action: () => SyncService.instance.queuePauseTask(task),
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
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
              onPressed: _isActionLoading ? null : () => _runAction(() => SyncService.instance.queueCompleteTask(task)),
              icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF32D74B)),
              label: const Text(
                'Terminer',
                style: TextStyle(color: Color(0xFF32D74B), fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF32D74B)),
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
          valueWidget ??
              Text(
                value ?? '',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
        ],
      ),
    );
  }
}
