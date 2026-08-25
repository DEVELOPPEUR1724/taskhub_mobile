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
