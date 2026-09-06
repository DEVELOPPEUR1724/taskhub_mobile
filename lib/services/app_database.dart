import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/task.dart';
import '../models/workday.dart';
import 'db_connection_unsupported.dart' if (dart.library.io) 'db_connection_io.dart' as impl;

part 'app_database.g.dart';

// Cache local des tâches (lecture hors ligne) — une ligne par tâche, le
// JSON complet renvoyé par l'API est stocké tel quel pour ne pas dupliquer
// chaque champ du modèle en colonne SQL.
@DataClassName('CachedTaskRow')
class TasksCache extends Table {
  IntColumn get id => integer()();
  TextColumn get status => text()();
  IntColumn get projectId => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// File d'attente des actions en attente d'envoi vers POST /api/sync.
@DataClassName('PendingActionRow')
class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  // task.start | task.pause | task.resume | task.complete | comment.create |
  // workday.start | workday.pause.start | workday.pause.end | workday.end
  TextColumn get type => text()();
  // Sans objet pour les actions workday.* (le pointage est identifié par
  // l'utilisateur + le jour côté serveur, pas par un id) : on y met 0, une
  // valeur qui ne correspond à aucune vraie tâche, plutôt que de rendre la
  // colonne nullable (éviterait une migration de schéma pour un simple flag).
  IntColumn get taskId => integer()();
  TextColumn get body => text().nullable()(); // uniquement pour comment.create
  DateTimeColumn get createdAt => dateTime()(); // devient action.timestamp ET clé d'ordre FIFO
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending' | 'failed'
  TextColumn get lastError => text().nullable()();
}

extension PendingActionPayload on PendingActionRow {
  // Forme exacte attendue par POST /api/sync (un élément du tableau "actions").
  Map<String, dynamic> toActionPayload() {
    final isWorkday = type.startsWith('workday.');
    return {
      'type': type,
      if (!isWorkday) 'task_id': taskId,
      'timestamp': createdAt.toUtc().toIso8601String(),
      if (body != null) 'body': body,
    };
  }
}

// Cache local du pointage du jour (lecture hors ligne) — une ligne par jour
// (date locale au format YYYY-MM-DD), écrasée à chaque nouveau jour.
@DataClassName('CachedWorkdayRow')
class WorkdayCache extends Table {
  TextColumn get date => text()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {date};
}

@DriftDatabase(tables: [TasksCache, PendingActions, WorkdayCache])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(impl.connect());
  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(workdayCache);
          }
        },
      );

  bool? _available;

  // Mémorise si Drift a pu s'ouvrir (false sur Flutter Web, où dart:io/le
  // sqlite natif n'existent pas) — évite de retenter à chaque appel et
  // permet aux appelants de basculer en mode dégradé (voir SyncService).
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      await customSelect('SELECT 1').getSingle();
      _available = true;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  // ---- tasks_cache ----
  // _taskRow(Task task) — convertir un Task en "ligne à écrire"
  // TasksCacheCompanion est une classe générée automatiquement par Drift
  TasksCacheCompanion _taskRow(Task task) => TasksCacheCompanion.insert(
        id: Value(task.id),
        status: task.status,
        projectId: Value(task.projectId),
        updatedAt: task.updatedAt,
        json: jsonEncode(task.toJson()),
      );

// upsertTask — insérer ou remplacer
  Future<void> upsertTask(Task task) async {
    await into(tasksCache).insertOnConflictUpdate(_taskRow(task));
  }

  // upsertTasks — pareil, mais pour plusieurs tâches d'un coup
  Future<void> upsertTasks(List<Task> tasks) async {
    if (tasks.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(tasksCache, tasks.map(_taskRow));
    });
  }

// getCachedTask(id) — lire une tâche depuis le cache
  Future<Task?> getCachedTask(int id) async {
    final row = await (select(tasksCache)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return Task.fromJson(jsonDecode(row.json));
  }

// getCachedTasks({status, projectId}) — lire plusieurs tâches, avec filtres optionnels
  Future<List<Task>> getCachedTasks({String? status, int? projectId}) async {
    final query = select(tasksCache)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    if (projectId != null) {
      query.where((t) => t.projectId.equals(projectId));
    }
    final rows = await query.get();
    return rows.map((row) => Task.fromJson(jsonDecode(row.json))).toList();
  }

  // ---- pending_actions ----

  Future<int> insertPendingAction({
    required String type,
    required int taskId,
    String? body,
    required DateTime createdAt,
  }) {
    return into(pendingActions).insert(PendingActionsCompanion.insert(
      type: type,
      taskId: taskId,
      body: Value(body),
      createdAt: createdAt,
    ));
  }

  Future<List<PendingActionRow>> getPendingActionsOrdered() {
    return (select(pendingActions)
          ..where((a) => a.status.equals('pending'))
          ..orderBy([(a) => OrderingTerm.asc(a.createdAt), (a) => OrderingTerm.asc(a.id)]))
        .get();
  }

  Future<void> markActionSucceeded(int id) async {
    await (delete(pendingActions)..where((a) => a.id.equals(id))).go();
  }

  Future<void> markActionFailed(int id, {required String error, required bool terminal}) async {
    if (terminal) {
      await (update(pendingActions)..where((a) => a.id.equals(id))).write(
        PendingActionsCompanion(status: const Value('failed'), lastError: Value(error)),
      );
      return;
    }
    // Rejet non terminal (erreur réseau) : on incrémente juste le compteur
    // de tentatives, l'action reste 'pending' pour être retentée.
    final row = await (select(pendingActions)..where((a) => a.id.equals(id))).getSingleOrNull();
    await (update(pendingActions)..where((a) => a.id.equals(id))).write(
      PendingActionsCompanion(
        attemptCount: Value((row?.attemptCount ?? 0) + 1),
        lastError: Value(error),
      ),
    );
  }

  Future<int> countByStatus(String status) async {
    final count = countAll(filter: pendingActions.status.equals(status));
    final query = selectOnly(pendingActions)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<Set<int>> getTaskIdsWithPendingActions() async {
    // Les actions workday.* portent un taskId=0 factice (voir PendingActions) :
    // on les exclut explicitement pour ne pas polluer l'ensemble des vraies
    // tâches à ne pas écraser lors du prochain pull.
    final query = selectOnly(pendingActions, distinct: true)
      ..addColumns([pendingActions.taskId])
      ..where(pendingActions.type.like('task.%'));
    final rows = await query.get();
    return rows.map((row) => row.read(pendingActions.taskId)!).toSet();
  }

  Future<void> deleteAction(int id) async {
    await (delete(pendingActions)..where((a) => a.id.equals(id))).go();
  }

  Future<void> retryAction(int id) async {
    await (update(pendingActions)..where((a) => a.id.equals(id))).write(
      const PendingActionsCompanion(status: Value('pending'), lastError: Value(null)),
    );
  }

  // ---- workday_cache ----

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> upsertTodayWorkday(Workday workday) async {
    await into(workdayCache).insertOnConflictUpdate(WorkdayCacheCompanion.insert(
      date: _todayKey(),
      json: jsonEncode(workday.toJson()),
      updatedAt: DateTime.now(),
    ));
  }

  Future<Workday?> getCachedTodayWorkday() async {
    final row = await (select(workdayCache)..where((w) => w.date.equals(_todayKey()))).getSingleOrNull();
    if (row == null) return null;
    return Workday.fromJson(jsonDecode(row.json));
  }
}
