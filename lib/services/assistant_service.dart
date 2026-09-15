import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'client_service.dart';

class AssistantLink {
  final String label;
  final String url;
  final String? meta;

  AssistantLink({required this.label, required this.url, this.meta});

  factory AssistantLink.fromJson(Map<String, dynamic> json) {
    return AssistantLink(
      label: json['label'] ?? '',
      url: json['url'] ?? '',
      meta: json['meta'],
    );
  }
}

class AssistantReply {
  final int conversationId;
  final String reply;
  final List<AssistantLink> links;

  AssistantReply({
    required this.conversationId,
    required this.reply,
    required this.links,
  });

  factory AssistantReply.fromJson(Map<String, dynamic> json) {
    return AssistantReply(
      conversationId: json['conversation_id'],
      reply: json['reply'] ?? '',
      links: (json['links'] as List<dynamic>? ?? [])
          .map((e) => AssistantLink.fromJson(e))
          .toList(),
    );
  }
}

class AssistantService {
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

  // Contrairement au rapport IA global, l'assistant ne passe pas par un LLM
  // (réponses basées sur des requêtes en base côté serveur) : réponse rapide
  // attendue, pas besoin d'un timeout long.
  Future<AssistantReply> ask(String message, {int? conversationId}) async {
    final response = await http
        .post(
          Uri.parse("${ClientService.baseUrl}/assistant/ask"),
          headers: await _headers(),
          body: jsonEncode({
            'message': message,
            if (conversationId != null) 'conversation_id': conversationId,
          }),
        )
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw Exception(
              'L\'assistant met trop de temps à répondre. Réessayez.'),
        );

    if (response.statusCode == 200) {
      return AssistantReply.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Erreur de l\'assistant');
    }
  }
}
