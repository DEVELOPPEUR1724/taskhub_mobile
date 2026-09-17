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

class AssistantConversationSummary {
  final int id;
  final String title;
  final DateTime updatedAt;

  AssistantConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  factory AssistantConversationSummary.fromJson(Map<String, dynamic> json) {
    return AssistantConversationSummary(
      id: json['id'],
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title']
          : 'Conversation',
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class AssistantConversationMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final List<AssistantLink> links;

  AssistantConversationMessage({
    required this.role,
    required this.content,
    required this.links,
  });

  bool get isUser => role == 'user';

  factory AssistantConversationMessage.fromJson(Map<String, dynamic> json) {
    return AssistantConversationMessage(
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? '',
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

  // POST /assistant/conversations -> crée une conversation vide côté
  // serveur (titre par défaut "Nouvelle discussion") et retourne son id,
  // pour que le bouton "Nouveau chat" démarre une conversation réelle
  // avant même le premier message plutôt que d'attendre le prochain /ask.
  Future<int> createConversation() async {
    final response = await http.post(
      Uri.parse("${ClientService.baseUrl}/assistant/conversations"),
      headers: await _headers(),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body)['id'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
          error['message'] ?? 'Erreur lors de la création de la conversation');
    }
  }

  // GET /assistant/conversations
  //   -> {"conversations": [{"id":1,"title":"...","updated_at":"..."}]}
  Future<List<AssistantConversationSummary>> listConversations() async {
    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/assistant/conversations"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final list = (json['conversations'] as List<dynamic>?) ?? [];
      return list.map((e) => AssistantConversationSummary.fromJson(e)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
          error['message'] ?? 'Erreur lors du chargement de l\'historique');
    }
  }

  // GET /assistant/conversations/{id}
  //   -> {"id":1,"title":"...","messages":[{"role":"user"|"assistant","content":"...","links":[...]}]}
  Future<List<AssistantConversationMessage>> getConversationMessages(
      int conversationId) async {
    final response = await http.get(
      Uri.parse(
          "${ClientService.baseUrl}/assistant/conversations/$conversationId"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final list = (json['messages'] as List<dynamic>?) ?? [];
      return list.map((e) => AssistantConversationMessage.fromJson(e)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
          error['message'] ?? 'Erreur lors du chargement de la conversation');
    }
  }

  // DELETE /assistant/conversations/{id} -> {"message": "..."}
  Future<void> deleteConversation(int conversationId) async {
    final response = await http.delete(
      Uri.parse(
          "${ClientService.baseUrl}/assistant/conversations/$conversationId"),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
          error['message'] ?? 'Erreur lors de la suppression de la conversation');
    }
  }
}
