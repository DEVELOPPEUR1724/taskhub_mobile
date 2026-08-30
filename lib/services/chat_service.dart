import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/project.dart';
import 'client_service.dart';

class ChatService {
  Future<String> _requireToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('Utilisateur non authentifié');
    return token;
  }

  // Annuaire des collègues avec qui démarrer une conversation (direct ou
  // groupe), indépendamment de tout projet. Réutilise ProjectMember : même
  // forme exacte {id, name, role}.
  Future<List<ProjectMember>> getUsers() async {
    final token = await _requireToken();

    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/users"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(response.body);
      return json.map((e) => ProjectMember.fromJson(e)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  // Détail d'une conversation existante (nom, is_group, membres) — utile à
  // l'ouverture d'une conversation, contrairement à getConversations (liste)
  // qui ne renvoie pas les membres.
  Future<Conversation> getConversation(int conversationId) async {
    final token = await _requireToken();

    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/conversations/$conversationId"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Conversation.fromJson(json);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  Future<List<Conversation>> getConversations() async {
    final token = await _requireToken();

    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/conversations"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(response.body);
      return json.map((e) => Conversation.fromJson(e)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  // Correction : le backend n'a plus une seule route de création "générique"
  // (type + project_id) — il expose désormais deux routes distinctes :
  // /conversations/direct (retrouve ou crée la conversation 1-à-1 avec cet
  // utilisateur, jamais de doublon) et /conversations/group (toujours un
  // nouveau groupe). Plus aucune notion de projet dans la création.
  Future<Conversation> createDirect(int userId) async {
    final token = await _requireToken();

    final response = await http.post(
      Uri.parse("${ClientService.baseUrl}/conversations/direct"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"user_id": userId}),
    );

    // 201 si la conversation vient d'être créée, 200 si elle existait déjà
    // (le backend déduplique les conversations directes entre deux mêmes
    // personnes).
    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Conversation.fromJson(json);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    final token = await _requireToken();

    final response = await http.post(
      Uri.parse("${ClientService.baseUrl}/conversations/group"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name": name,
        "member_ids": memberIds,
      }),
    );

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Conversation.fromJson(json);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  // page 1 = messages les plus récents (le backend trie désormais par
  // created_at décroissant) ; pages suivantes = messages plus anciens, au
  // fil du défilement vers le haut de l'écran de conversation.
  Future<MessagePage> getMessages(int conversationId, {int page = 1}) async {
    final token = await _requireToken();

    final uri = Uri.parse("${ClientService.baseUrl}/conversations/$conversationId/messages").replace(
      queryParameters: {'page': page.toString()},
    );
    final response = await http.get(
      uri,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      final List<dynamic> data = json['data'];
      return MessagePage(
        messages: data.map((e) => Message.fromJson(e)).toList(),
        currentPage: json['current_page'],
        lastPage: json['last_page'],
      );
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  // Recherche de messages dans une conversation précise (même forme de
  // réponse que getMessages, juste filtrée par "q").
  Future<MessagePage> searchMessages(int conversationId, String query, {int page = 1}) async {
    final token = await _requireToken();

    final uri = Uri.parse("${ClientService.baseUrl}/conversations/$conversationId/messages/search").replace(
      queryParameters: {'q': query, 'page': page.toString()},
    );
    final response = await http.get(
      uri,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      final List<dynamic> data = json['data'];
      return MessagePage(
        messages: data.map((e) => Message.fromJson(e)).toList(),
        currentPage: json['current_page'],
        lastPage: json['last_page'],
      );
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  // Recherche transversale, dans toutes les conversations dont l'utilisateur
  // est membre.
  Future<MessageSearchPage> searchAllMessages(String query, {int page = 1}) async {
    final token = await _requireToken();

    final uri = Uri.parse("${ClientService.baseUrl}/messages/search").replace(
      queryParameters: {'q': query, 'page': page.toString()},
    );
    final response = await http.get(
      uri,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      final List<dynamic> data = json['data'];
      return MessageSearchPage(
        results: data.map((e) => MessageSearchResult.fromJson(e)).toList(),
        currentPage: json['current_page'],
        lastPage: json['last_page'],
      );
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  // Correction : le backend attend maintenant le champ multipart "file" (pas
  // "image") — sendMessage accepte désormais n'importe quelle pièce jointe
  // (pdf, doc, xls, ppt, txt, csv, zip, rar...), pas seulement des images.
  // Envoyer "image" comme avant ne matchait plus aucune règle de validation
  // côté Laravel, donc le fichier n'était jamais reçu.
  Future<Message> sendMessages(
    int conversationId, {
    String? body,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final token = await _requireToken();

    final uri = Uri.parse("${ClientService.baseUrl}/conversations/$conversationId/messages");
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });

    if (body != null && body.isNotEmpty) {
      request.fields['body'] = body;
    }
    if (imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: imageFileName ?? 'chat_image.jpg',
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Message.fromJson(json);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  // Liste des messages contenant un fichier (image) dans la conversation.
  // Contrairement à getMessages, la réponse est un tableau JSON brut (pas de
  // pagination Laravel ici : le contrôleur utilise get(), pas paginate()).
  Future<List<Message>> getFiles(int conversationId) async {
    final token = await _requireToken();

    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/conversations/$conversationId/files"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(response.body);
      return json.map((e) => Message.fromJson(e)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    }
  }

  Future<void> markAsRead(int conversationId) async {
    final token = await _requireToken();

    final response = await http.post(
      Uri.parse("${ClientService.baseUrl}/conversations/$conversationId/read"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message']);
    } 
  }
}
