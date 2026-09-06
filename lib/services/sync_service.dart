import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/workday.dart';
import 'app_database.dart';
import 'comment_service.dart';
import 'pointage_service.dart';
import 'sync_api_service.dart';
import 'task_service.dart';

// Façade unique pour les actions synchronisables (start/pause/resume/
// complete/commentaire texte). Toute action passe par ici, en ligne comme
// hors ligne : mise à jour optimiste locale immédiate, mise en file, puis
// tentative d'envoi immédiate (non bloquante pour l'UI).
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _lastSyncKey = 'tasks_last_sync_at';

  final AppDatabase _db = AppDatabase.instance;
  final SyncApiService _api = SyncApiService();
  final TaskService _taskService = TaskService();
  final CommentService _commentService = CommentService();
  final PointageService _pointageService = PointageService();

  int pendingCount = 0;
  int failedCount = 0;
  bool isSyncing = false;
  DateTime? lastSyncAt;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_lastSyncKey);
    lastSyncAt = stored != null ? DateTime.parse(stored) : null;
    await _refreshCounts();
  }

  // ---- Points d'entrée appelés depuis l'UI ----

  Future<Task> queueStartTask(Task task) => _applyOptimisticAndQueue(
        'task.start',
        task,
        task.copyWith(status: 'in_progress', startedAt: DateTime.now(), trackingPaused: false),
      );

  Future<Task> queuePauseTask(Task task) =>
      _applyOptimisticAndQueue('task.pause', task, task.copyWith(trackingPaused: true));

  Future<Task> queueResumeTask(Task task) =>
      _applyOptimisticAndQueue('task.resume', task, task.copyWith(trackingPaused: false));

  Future<Task> queueCompleteTask(Task task) => _applyOptimisticAndQueue(
        'task.complete',
        task,
        task.copyWith(status: 'done', completedAt: DateTime.now(), trackingPaused: false),
      );

  // Lecture hors-ligne du pointage du jour : essaie le réseau d'abord (seul
  // moyen d'avoir duration_minutes/duration_label à jour, calculés côté
  // serveur), et retombe sur le cache local si hors ligne.
  Future<Workday> getTodayWorkday() async {
    try {
      final workday = await _pointageService.getToday();
      if (await _db.isAvailable()) {
        await _db.upsertTodayWorkday(workday);
      }
      return workday;
    } catch (e) {
      if (await _db.isAvailable()) {
        final cached = await _db.getCachedTodayWorkday();
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  Future<Workday> queueStartWorkday(Workday current) => _applyWorkdayOptimisticAndQueue(
        'workday.start',
        current,
        current.copyWith(status: 'in_progress', startedAt: DateTime.now(), isPaused: false),
      );

  Future<Workday> queueStartPause(Workday current) => _applyWorkdayOptimisticAndQueue(
        'workday.pause.start',
        current,
        current.copyWith(
          status: 'paused',
          isPaused: true,
          pauses: [...current.pauses, PauseEntry(startedAt: DateTime.now())],
        ),
      );

  Future<Workday> queueEndPause(Workday current) {
    final pauses = List<PauseEntry>.from(current.pauses);
    if (pauses.isNotEmpty && pauses.last.endedAt == null) {
      pauses[pauses.length - 1] = pauses.last.copyWith(endedAt: DateTime.now());
    }
    return _applyWorkdayOptimisticAndQueue(
      'workday.pause.end',
      current,
      current.copyWith(status: 'in_progress', isPaused: false, pauses: pauses),
    );
  }

  Future<Workday> queueEndWorkday(Workday current) => _applyWorkdayOptimisticAndQueue(
        'workday.end',
        current,
        current.copyWith(status: 'completed', endedAt: DateTime.now()),
      );

  Future<Workday> _applyWorkdayOptimisticAndQueue(String type, Workday original, Workday mutated) async {
    if (!await _db.isAvailable()) {
      // Mode dégradé : appel direct à l'API en ligne (cache/file indisponibles).
      await _directWorkdayCall(type);
      return mutated;
    }
    await _db.upsertTodayWorkday(mutated);
    final createdAt = DateTime.now();
    // taskId=0 : sans objet pour une action workday.* (voir PendingActions).
    final actionId = await _db.insertPendingAction(type: type, taskId: 0, createdAt: createdAt);
    await _refreshCounts();
    notifyListeners();
    // Même logique que pour les tâches : on attend la première tentative
    // pour remonter tout de suite un rejet métier (ex. "journée déjà
    // terminée") en annulant la mise à jour optimiste, sans bloquer sur une
    // vraie coupure réseau (l'action reste alors en file).
    await _attemptImmediate(
      actionId,
      {
        'type': type,
        'timestamp': createdAt.toUtc().toIso8601String(),
      },
      onReject: () => _db.upsertTodayWorkday(original),
    );
    return mutated;
  }

  Future<void> _directWorkdayCall(String type) {
    switch (type) {
      case 'workday.start':
        return _pointageService.startWorkday();
      case 'workday.pause.start':
        return _pointageService.startPause();
      case 'workday.pause.end':
        return _pointageService.endPause();
      case 'workday.end':
        return _pointageService.endWorkday();
      default:
        return Future.value();
    }
  }

  Future<void> queueTextComment(int taskId, String body) async {
    if (!await _db.isAvailable()) {
      // Mode dégradé (ex. Flutter Web, où sqflite n'existe pas) : pas de
      // file d'attente possible, on envoie directement à l'API en ligne.
      await _commentService.commentAjout(taskId, body: body);
      return;
    }
    final createdAt = DateTime.now();
    final actionId = await _db.insertPendingAction(type: 'comment.create', taskId: taskId, body: body, createdAt: createdAt);
    await _refreshCounts();
    notifyListeners();
    // Contrairement aux actions sur les tâches, un commentaire n'a pas de
    // mise à jour optimiste à annuler côté cache — mais on attend quand même
    // la première tentative pour remonter un rejet éventuel (ex. commentaire
    // vide) à l'écran plutôt que de le laisser échouer silencieusement.
    await _attemptImmediate(
      actionId,
      {
        'type': 'comment.create',
        'task_id': taskId,
        'timestamp': createdAt.toUtc().toIso8601String(),
        'body': body,
      },
    );
  }

  Future<Task> _applyOptimisticAndQueue(String type, Task original, Task mutated) async {
    final updated = mutated.copyWith(updatedAt: DateTime.now());
    if (!await _db.isAvailable()) {
      // Mode dégradé : appel direct à l'API en ligne, sans passer par le
      // cache/la file (indisponibles). L'UI reçoit quand même la tâche
      // optimiste pour rester réactive.
      await _directTaskCall(type, original.id);
      return updated;
    }
    await _db.upsertTask(updated);
    final createdAt = DateTime.now();
    final actionId = await _db.insertPendingAction(type: type, taskId: original.id, createdAt: createdAt);
    await _refreshCounts();
    notifyListeners();
    // On attend la première tentative d'envoi (pas tout flushQueue, juste
    // cette action) : si le serveur la refuse pour une vraie raison métier
    // (ex. "pas pointé", "tâche déjà terminée"), on annule la mise à jour
    // optimiste et on relance l'erreur pour que l'écran l'affiche tout de
    // suite — plutôt que de laisser l'UI mentir en silence pendant que
    // l'action échoue en arrière-plan. Une vraie coupure réseau, elle,
    // reste silencieuse : l'action attend simplement le prochain flush.
    await _attemptImmediate(
      actionId,
      {
        'type': type,
        'task_id': original.id,
        'timestamp': createdAt.toUtc().toIso8601String(),
      },
      onReject: () => _db.upsertTask(original),
    );
    return updated;
  }

  // Tente d'envoyer une action tout juste mise en file. Renvoie normalement
  // en cas de succès OU d'échec réseau/HTTP (elle reste "pending", sera
  // retentée par flushQueue) ; lève une exception uniquement sur un vrai
  // rejet du serveur (réponse {processed:0, errors:[...]} reçue avec succès,
  // action refusée pour une raison métier), après avoir annulé la mise à
  // jour optimiste correspondante via onReject si fourni.
  //
  // Le try/catch n'entoure QUE l'appel réseau lui-même : ainsi une erreur
  // réseau (pushOne qui lève une exception) et un rejet métier (pushOne qui
  // répond normalement, juste avec processed=0) ne peuvent jamais être
  // confondus l'un avec l'autre.
  Future<void> _attemptImmediate(int actionId, Map<String, dynamic> payload, {Future<void> Function()? onReject}) async {
    SyncPushResult result;
    try {
      result = await _api.pushOne(payload);
    } catch (_) {
      // Pas de réponse exploitable (hors ligne, timeout, erreur HTTP...) —
      // l'action reste 'pending', retentée par flushQueue() plus tard.
      return;
    }

    if (result.succeeded) {
      await _db.markActionSucceeded(actionId);
      await _refreshCounts();
      notifyListeners();
      return;
    }

    await _db.markActionFailed(actionId, error: result.reason ?? 'Erreur inconnue', terminal: true);
    if (onReject != null) {
      await onReject();
    }
    await _refreshCounts();
    notifyListeners();
    throw Exception(result.reason ?? 'Action refusée par le serveur');
  }

  Future<void> _directTaskCall(String type, int taskId) {
    switch (type) {
      case 'task.start':
        return _taskService.startTask(taskId);
      case 'task.pause':
        return _taskService.pauseTask(taskId);
      case 'task.resume':
        return _taskService.resumeTask(taskId);
      case 'task.complete':
        return _taskService.completeTask(taskId);
      default:
        return Future.value();
    }
  }

  // ---- Synchronisation ----

  Future<void> flushQueue() async {
    if (isSyncing) return;
    if (!await _db.isAvailable()) return; // rien à drainer en mode dégradé
    isSyncing = true;
    notifyListeners();
    try {
      final actions = await _db.getPendingActionsOrdered();
      for (final action in actions) {
        try {
          final result = await _api.pushOne(action.toActionPayload());
          if (result.succeeded) {
            await _db.markActionSucceeded(action.id);
          } else {
            // Rejet métier (ex. "tâche déjà terminée") — le serveur a
            // répondu, ça ne se réglera pas tout seul : on arrête de réessayer.
            await _db.markActionFailed(action.id, error: result.reason ?? 'Erreur inconnue', terminal: true);
          }
        } catch (e) {
          // Pas de réponse du serveur (hors ligne, timeout...) — on arrête
          // la file ici, elle sera retentée au prochain flush.
          await _db.markActionFailed(action.id, error: e.toString(), terminal: false);
          break;
        }
      }
    } finally {
      await _refreshCounts();
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> pullDelta() async {
    if (!await _db.isAvailable()) return; // pas de cache local à alimenter
    final capturedAt = DateTime.now();
    final since = lastSyncAt ?? DateTime(2000);
    try {
      final fetched = await _taskService.getTasksDelta(since);
      final skipIds = await _db.getTaskIdsWithPendingActions();
      final toUpsert = fetched.where((t) => !skipIds.contains(t.id)).toList();
      await _db.upsertTasks(toUpsert);
      lastSyncAt = capturedAt;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, capturedAt.toIso8601String());
    } catch (_) {
      // Pas de connexion / erreur réseau : le cache local reste tel quel.
    }
  }

  Future<void> syncNow() async {
    await flushQueue();
    await pullDelta();
    notifyListeners();
  }

  Future<void> retryFailed(int actionId) async {
    await _db.retryAction(actionId);
    await _refreshCounts();
    notifyListeners();
    unawaited(flushQueue());
  }

  Future<void> discardFailed(int actionId) async {
    await _db.deleteAction(actionId);
    await _refreshCounts();
    notifyListeners();
  }

  Future<void> _refreshCounts() async {
    if (!await _db.isAvailable()) {
      pendingCount = 0;
      failedCount = 0;
      return;
    }
    pendingCount = await _db.countByStatus('pending');
    failedCount = await _db.countByStatus('failed');
  }
}
