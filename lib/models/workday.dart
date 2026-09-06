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

  Map<String, dynamic> toJson() => {
        'started_at': startedAt?.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
      };

  PauseEntry copyWith({DateTime? endedAt}) => PauseEntry(startedAt: startedAt, endedAt: endedAt ?? this.endedAt);
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

  Map<String, dynamic> toJson() => {
        'status': status,
        'started_at': startedAt?.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'duration_minutes': durationMinutes,
        'duration_label': durationLabel,
        'pause_count': pauseCount,
        'pause_duration': pauseDuration,
        'is_paused': isPaused,
        'pauses': pauses.map((p) => p.toJson()).toList(),
      };

  // Mutations optimistes locales : on ne recalcule pas durationMinutes/
  // durationLabel côté client (dépend du temps écoulé, non fiable hors
  // ligne) — seuls status/timestamps/pauses sont mis à jour immédiatement,
  // le reste sera rafraîchi au prochain pull en ligne.
  Workday copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? isPaused,
    List<PauseEntry>? pauses,
  }) {
    return Workday(
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMinutes: durationMinutes,
      durationLabel: durationLabel,
      pauseCount: pauses?.length ?? pauseCount,
      pauseDuration: pauseDuration,
      isPaused: isPaused ?? this.isPaused,
      pauses: pauses ?? this.pauses,
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
