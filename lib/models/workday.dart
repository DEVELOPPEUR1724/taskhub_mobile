class PauseEntry {
  final DateTime? startedAt;
  final DateTime? endedAt;

  PauseEntry({this.startedAt, this.endedAt});

  factory PauseEntry.fromJson(Map<String, dynamic> json) {
    return PauseEntry(
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
    );
  }
}

class Workday {
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationMinutes;
  final String? durationLabel;
  final int pauseCount;
  final String? pauseDuration;
  final bool isPaused;
  final List<PauseEntry> pauses;

  Workday({
    required this.status,
    this.startedAt,
    this.endedAt,
    required this.durationMinutes,
    this.durationLabel,
    required this.pauseCount,
    this.pauseDuration,
    required this.isPaused,
    this.pauses = const [],
  });

  factory Workday.fromJson(Map<String, dynamic> json) {
    return Workday(
      status: json['status'],
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      durationMinutes: json['duration_minutes'] ?? 0,
      durationLabel: json['duration_label'],
      pauseCount: json['pause_count'] ?? 0,
      pauseDuration: json['pause_duration'],
      isPaused: json['is_paused'] ?? false,
      pauses: json['pauses'] != null
          ? (json['pauses'] as List).map((e) => PauseEntry.fromJson(e)).toList()
          : const [],
    );
  }
}

class WorkdayHistoryEntry {
  final DateTime workDate;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationMinutes;
  final String durationLabel;
  final int pauseCount;
  final String pauseDuration;
  final bool isComplete;

  WorkdayHistoryEntry({
    required this.workDate,
    this.startedAt,
    this.endedAt,
    required this.durationMinutes,
    required this.durationLabel,
    required this.pauseCount,
    required this.pauseDuration,
    required this.isComplete,
  });

  factory WorkdayHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WorkdayHistoryEntry(
      workDate: DateTime.parse(json['work_date']),
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      durationMinutes: json['duration_minutes'] ?? 0,
      durationLabel: json['duration_label'] ?? '00h00',
      pauseCount: json['pause_count'] ?? 0,
      pauseDuration: json['pause_duration'] ?? '00h00',
      isComplete: json['is_complete'] ?? false,
    );
  }
}
