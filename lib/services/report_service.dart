import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'client_service.dart';

class ReportService {
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

  // Pas de cache côté serveur : régénéré via LLM à chaque appel, peut
  // prendre plusieurs secondes (jusqu'à 120s côté backend) — timeout client
  // aligné dessus plutôt que le timeout par défaut du reste de l'app.
  Future<String> getGlobalReport() async {
    final response = await http
        .get(
          Uri.parse("${ClientService.baseUrl}/reports/global"),
          headers: await _headers(),
        )
        .timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw Exception(
              'La génération du rapport a pris trop de temps. Réessayez.'),
        );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['report'] as String;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
          error['message'] ?? 'Erreur lors de la génération du rapport');
    }
  }
}
