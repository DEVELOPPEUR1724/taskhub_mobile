class ProjectMember {
  final int id;
  final String name;
  final String? role;

  ProjectMember({
    required this.id,
    required this.name,
    this.role,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      id: json['id'],
      name: json['name'],
      role: json['role'],
    );
  }
}

class ProjectSprint {
  final int id;
  final String name;
  final String? status;
  final DateTime? startsAt;
  final DateTime? endsAt;

  ProjectSprint({
    required this.id,
    required this.name,
    this.status,
    this.startsAt,
    this.endsAt,
  });

  factory ProjectSprint.fromJson(Map<String, dynamic> json) {
    return ProjectSprint(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      startsAt: json['starts_at'] != null ? DateTime.tryParse(json['starts_at']) : null,
      endsAt: json['ends_at'] != null ? DateTime.tryParse(json['ends_at']) : null,
    );
  }
}

class ProjectTaskCounts {
  final int total;
  final int todo;
  final int inProgress;
  final int toTest;
  final int blocked;
  final int done;

  ProjectTaskCounts({
    required this.total,
    required this.todo,
    required this.inProgress,
    required this.toTest,
    required this.blocked,
    required this.done,
  });

  factory ProjectTaskCounts.fromJson(Map<String, dynamic> json) {
    return ProjectTaskCounts(
      total: json['total'] ?? 0,
      todo: json['todo'] ?? 0,
      inProgress: json['in_progress'] ?? 0,
      toTest: json['to_test'] ?? 0,
      blocked: json['blocked'] ?? 0,
      done: json['done'] ?? 0,
    );
  }
}

class Project {
  final int id;
  final String name;
  final String? client;
  // Valeurs brutes des enums PHP (ProjectStatus/ProjectPriority) telles que
  // sérialisées par json_encode : "new"/"in_progress"/"paused"/"done"/"late"
  // et "low"/"medium"/"high"/"urgent"/"critical" — pas de libellé français,
  // à mapper côté UI.
  final String? status;
  final String? priority;
  final DateTime? deadline;
  // 0-100 (Project::progressPercentage() renvoie un pourcentage entier, pas
  // une fraction 0-1).
  final int progress;
  // Présent seulement sur GET /projects (liste).
  final int? tasksCount;
  // Champs suivants présents seulement sur GET /projects/{id} (détail).
  final String? description;
  final ProjectTaskCounts? tasks;
  final List<ProjectMember> members;
  final List<ProjectSprint> sprints;

  Project({
    required this.id,
    required this.name,
    this.client,
    this.status,
    this.priority,
    this.deadline,
    required this.progress,
    this.tasksCount,
    this.description,
    this.tasks,
    this.members = const [],
    this.sprints = const [],
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      client: json['client'],
      status: json['status'],
      priority: json['priority'],
      deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline']) : null,
      progress: json['progress'] ?? 0,
      tasksCount: json['tasks_count'],
      description: json['description'],
      tasks: json['tasks'] != null ? ProjectTaskCounts.fromJson(json['tasks']) : null,
      members: json['members'] != null
          ? (json['members'] as List).map((e) => ProjectMember.fromJson(e)).toList()
          : const [],
      sprints: json['sprints'] != null
          ? (json['sprints'] as List).map((e) => ProjectSprint.fromJson(e)).toList()
          : const [],
    );
  }
}
