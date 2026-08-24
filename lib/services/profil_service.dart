import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import 'client_service.dart';

class ProfilService {
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

  Future<Profile> getProfil() async {
    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/profil"),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return Profile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_extractError(response));
    }
  }

  Future<Profile> updateProfil({String? name, String? email}) async {
    final response = await http.patch(
      Uri.parse("${ClientService.baseUrl}/profil"),
      headers: await _headers(),
      body: jsonEncode({
        if (name != null) "name": name,
        if (email != null) "email": email,
      }),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Profile.fromJson(json['user']);
    } else {
      throw Exception(_extractError(response));
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.patch(
      Uri.parse("${ClientService.baseUrl}/profil/password"),
      headers: await _headers(),
      body: jsonEncode({
        "current_password": currentPassword,
        "password": password,
        "password_confirmation": passwordConfirmation,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractError(response));
    }
  }

  // Laravel renvoie {"message": "..."} pour nos checks manuels, ou
  // {"message": "...", "errors": {"champ": ["détail"]}} pour la validation
  // automatique — on préfère le détail le plus précis quand il existe.
  String _extractError(http.Response response) {
    final body = jsonDecode(response.body);
    if (body['errors'] != null) {
      final errors = body['errors'] as Map<String, dynamic>;
      final firstField = errors.values.first;
      if (firstField is List && firstField.isNotEmpty) {
        return firstField.first.toString();
      }
    }
    return body['message'] ?? 'Une erreur est survenue';
  }
}
