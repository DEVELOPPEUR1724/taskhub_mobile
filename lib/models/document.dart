// GET|POST /tasks|sprints|projects/{id}/documents, GET|DELETE /documents/{id}
class TaskDocument {
  final int id;
  final int? projectId;
  final int? sprintId;
  final int? taskId;
  final int uploadedById;
  final String title;
  final String? description;
  final String originalName;
  final String? mimeType;
  final int size;
  final DateTime createdAt;

  TaskDocument({
    required this.id,
    this.projectId,
    this.sprintId,
    this.taskId,
    required this.uploadedById,
    required this.title,
    this.description,
    required this.originalName,
    this.mimeType,
    required this.size,
    required this.createdAt,
  });

  factory TaskDocument.fromJson(Map<String, dynamic> json) {
    return TaskDocument(
      id: json['id'],
      projectId: json['project_id'],
      sprintId: json['sprint_id'],
      taskId: json['task_id'],
      uploadedById: json['uploaded_by_id'],
      title: json['title'] ?? '',
      description: json['description'],
      originalName: json['original_name'] ?? '',
      mimeType: json['mime_type'],
      size: json['size'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get extension {
    final parts = originalName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}
