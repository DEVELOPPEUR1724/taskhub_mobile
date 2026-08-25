class Task {
  final int id;
  final int? projectId;
  final int? sprintId;
  final int? assignedToId;
  final int? createdById;

  final String? projectName;
  final String? sprintName;
  final String? assignedToName;
  final String? createdByName;

  final String title;
  final String? description;

  final String priority;
  final String status;

  final DateTime? deadline;

  final int? estimatedDurationMinutes;

  final DateTime? completedAt;

  final DateTime? recurrencePausedAt;

  final DateTime? recurrenceResumedAt;

  final DateTime? startedAt;

  final int? estimatedHours;

  final DateTime? timeExceededNotifiedAt;

  final DateTime? createdAt;

  final DateTime updatedAt;

  final DateTime? deletedAt;

  // Renvoyés uniquement par GET /tasks/{id} (getTaskById) — absents de la
  // liste GET /tasks.
  final bool? trackingPaused;
  final String? trackingDuration;

  Task({
    required this.id,
    this.projectId,
    this.sprintId,
    this.assignedToId,
    this.createdById,
    this.projectName,
    this.sprintName,
    this.assignedToName,
    this.createdByName,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.deadline,
    this.estimatedDurationMinutes,
    this.completedAt,
    this.recurrencePausedAt,
    this.recurrenceResumedAt,
    this.startedAt,
    this.estimatedHours,
    this.timeExceededNotifiedAt,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.trackingPaused,
    this.trackingDuration,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      projectId: json['project_id'] ?? json['project']?['id'],
      sprintId: json['sprint_id'] ?? json['sprint']?['id'],
      assignedToId: json['assigned_to_id'] ?? json['assigned_to']?['id'],
      createdById: json['created_by_id'] ?? json['created_by']?['id'],
      projectName: json['project']?['name'],
      sprintName: json['sprint']?['name'],
      assignedToName: json['assigned_to']?['name'],
      createdByName: json['created_by']?['name'],
      title: json['title'],
      description: json['description'],
      priority: json['priority'],
      status: json['status'],
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      estimatedDurationMinutes: json['estimated_duration_minutes'],
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      recurrencePausedAt: json['recurrence_paused_at'] != null
          ? DateTime.parse(json['recurrence_paused_at'])
          : null,
      recurrenceResumedAt: json['recurrence_resumed_at'] != null
          ? DateTime.parse(json['recurrence_resumed_at'])
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      estimatedHours: json['estimated_hours'],
      timeExceededNotifiedAt: json['time_exceeded_notified_at'] != null
          ? DateTime.parse(json['time_exceeded_notified_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: DateTime.parse(json['updated_at']),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      trackingPaused: json['tracking_paused'],
      trackingDuration: json['tracking_duration'],
    );
  }
}

// GET /tasks/{id}/history
class TaskTrackingSession {
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String duration;

  TaskTrackingSession({
    this.startedAt,
    this.endedAt,
    required this.duration,
  });

  factory TaskTrackingSession.fromJson(Map<String, dynamic> json) {
    return TaskTrackingSession(
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      duration: json['duration'] ?? 'en cours',
    );
  }
}

class TaskHistory {
  final int taskId;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? trackingDuration;
  final bool trackingPaused;
  final List<TaskTrackingSession> sessions;

  TaskHistory({
    required this.taskId,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.trackingDuration,
    required this.trackingPaused,
    this.sessions = const [],
  });

  factory TaskHistory.fromJson(Map<String, dynamic> json) {
    return TaskHistory(
      taskId: json['task_id'],
      status: json['status'],
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      trackingDuration: json['tracking_duration'],
      trackingPaused: json['tracking_paused'] ?? false,
      sessions: json['sessions'] != null
          ? (json['sessions'] as List).map((e) => TaskTrackingSession.fromJson(e)).toList()
          : const [],
    );
  }
}