import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';
import 'client_service.dart';

class ProjectService {
  Future<String> _requireToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('Utilisateur non authentifié');
    return token;
  }

  Future<List<Project>> getProjects() async {
    final token = await _requireToken();

    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/projects"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(response.body);
      return json.map((e) => Project.fromJson(e)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  Future<Project> getProjectById(int id) async {
    final token = await _requireToken();

    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/projects/$id"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Project.fromJson(json);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }
}
