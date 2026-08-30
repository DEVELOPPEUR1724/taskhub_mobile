import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import 'app_database.dart';
import 'comment_service.dart';
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

  Future<void> queueTextComment(int taskId, String body) async {
    if (!await _db.isAvailable()) {
      // Mode dégradé (ex. Flutter Web, où sqflite n'existe pas) : pas de
      // file d'attente possible, on envoie directement à l'API en ligne.
      await _commentService.commentAjout(taskId, body: body);
      return;
    }
    await _db.insertPendingAction(type: 'comment.create', taskId: taskId, body: body, createdAt: DateTime.now());
    await _refreshCounts();
    notifyListeners();
    unawaited(flushQueue());
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
    await _db.insertPendingAction(type: type, taskId: original.id, createdAt: DateTime.now());
    await _refreshCounts();
    notifyListeners();
    unawaited(flushQueue());
    return updated;
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
