import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import 'client_service.dart';

class TaskService {
  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('Utilisateur non authentifié');
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // Correction : le filtre status/project_id existe côté API mais n'était
  // jamais transmis — la liste chargeait toujours tout puis filtrait côté
  // client.
  Future<List<Task>> getAllTasks({String? status, int? projectId}) async {
    final uri = Uri.parse("${ClientService.baseUrl}/tasks").replace(
      queryParameters: {
        if (status != null) 'status': status,
        if (projectId != null) 'project_id': projectId.toString(),
      },
    );

    final response = await http.get(uri, headers: await _headers());

    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(response.body);
      return json.map((e) => Task.fromJson(e)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  Future<Task> getTaskById(String id) async {
    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/tasks/$id"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return Task.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  Future<void> startTask(int taskId) => _patch('/tasks/$taskId/start');
  Future<void> pauseTask(int taskId) => _patch('/tasks/$taskId/pause');
  Future<void> resumeTask(int taskId) => _patch('/tasks/$taskId/resume');
  Future<void> completeTask(int taskId) => _patch('/tasks/$taskId/complete');

  Future<void> _patch(String path) async {
    final response = await http.patch(
      Uri.parse("${ClientService.baseUrl}$path"),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  Future<TaskHistory> getTaskHistory(int taskId) async {
    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/tasks/$taskId/history"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return TaskHistory.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  Future<List<TaskChecklist>> getChecklists(int taskId) async {
    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/tasks/$taskId/checklists"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> data = json['data'] ?? [];
      return data.map((e) => TaskChecklist.fromJson(e)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Erreur lors du chargement de la checklist');
    }
  }

  Future<TaskChecklist> addChecklistItem(int taskId, String title) async {
    final response = await http.post(
      Uri.parse("${ClientService.baseUrl}/tasks/$taskId/checklists"),
      headers: await _headers(),
      body: jsonEncode({'title': title}),
    );

    if (response.statusCode == 201) {
      return TaskChecklist.fromJson(jsonDecode(response.body)['data']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Erreur lors de l\'ajout de l\'élément');
    }
  }

  Future<TaskChecklist> setChecklistItemDone(
      int taskId, int checklistId, bool isDone) async {
    final response = await http.patch(
      Uri.parse("${ClientService.baseUrl}/tasks/$taskId/checklists/$checklistId"),
      headers: await _headers(),
      body: jsonEncode({'is_done': isDone}),
    );

    if (response.statusCode == 200) {
      return TaskChecklist.fromJson(jsonDecode(response.body)['data']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Erreur lors de la mise à jour');
    }
  }

  Future<void> deleteChecklistItem(int taskId, int checklistId) async {
    final response = await http.delete(
      Uri.parse("${ClientService.baseUrl}/tasks/$taskId/checklists/$checklistId"),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Erreur lors de la suppression');
    }
  }

  // Synchronisation hors-ligne : renvoie les tâches modifiées depuis `since`.
  // Note : l'app n'a pas de stockage local de tâches pour l'instant, donc ça
  // reste une brique isolée — rien ne consomme le résultat pour fusionner
  // avec un cache local tant que cette couche n'existe pas.
  Future<List<Task>> getTasksDelta(DateTime since) async {
    final uri = Uri.parse("${ClientService.baseUrl}/tasks/delta").replace(
      queryParameters: {'since': since.toUtc().toIso8601String()},
    );

    final response = await http.get(uri, headers: await _headers());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> tasks = json['tasks'];
      return tasks.map((e) => Task.fromJson(e)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }
}
