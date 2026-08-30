import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'client_service.dart';

// Résultat de l'envoi d'une action unique à POST /api/sync — voir
// SyncController::sync côté backend, réponse {processed, errors: [...]}.
class SyncPushResult {
  final int processed;
  final List<Map<String, dynamic>> errors;

  SyncPushResult({required this.processed, required this.errors});

  bool get succeeded => processed == 1 && errors.isEmpty;
  String? get reason => errors.isEmpty ? null : errors.first['reason'] as String?;
}

class SyncApiService {
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

  // On envoie une seule action par appel (pas de batch) : le backend ne
  // renvoie pas d'identifiant d'action dans "errors", donc en batch on ne
  // pourrait pas faire correspondre une erreur précise à une ligne précise
  // de la file locale en cas de doublon (type, task_id).
  Future<SyncPushResult> pushOne(Map<String, dynamic> actionPayload) async {
    final response = await http.post(
      Uri.parse("${ClientService.baseUrl}/sync"),
      headers: await _headers(),
      body: jsonEncode({
        'actions': [actionPayload],
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return SyncPushResult(
        processed: json['processed'] ?? 0,
        errors: List<Map<String, dynamic>>.from(json['errors'] ?? []),
      );
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }
}
