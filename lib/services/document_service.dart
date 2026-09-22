import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document.dart';
import 'client_service.dart';

// Doit rester synchronisé avec DocumentUploadService::ALLOWED_EXTENSIONS
// côté Laravel — la validation locale n'est qu'un filtre rapide avant envoi,
// le serveur reste la seule source de vérité.
const kAllowedDocumentExtensions = [
  'pdf',
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
  'txt',
  'md',
  'csv',
  'docx',
];

// Doit rester synchronisé avec la règle 'file' => ['max:20480'] (Ko) côté
// Laravel.
const kMaxDocumentSizeBytes = 20 * 1024 * 1024;

// Cf. UserRole::adminValues() côté Laravel — seuls ces rôles passent
// DocumentPolicy::create/delete (avant même de vérifier l'appartenance du
// document) : à utiliser côté UI pour cacher l'upload/la suppression aux
// autres plutôt que de laisser un 403 les surprendre au clic.
const kDocumentManagerRoles = ['super_admin', 'admin_tech', 'admin'];

class DocumentValidationException implements Exception {
  final String message;
  DocumentValidationException(this.message);
  @override
  String toString() => message;
}

class DocumentService {
  Future<String> _requireToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('Utilisateur non authentifié');
    return token;
  }

  Future<List<TaskDocument>> listForTask(int taskId) => _list('/tasks/$taskId/documents');
  Future<List<TaskDocument>> listForSprint(int sprintId) => _list('/sprints/$sprintId/documents');
  Future<List<TaskDocument>> listForProject(int projectId) => _list('/projects/$projectId/documents');

  Future<List<TaskDocument>> _list(String path) async {
    final token = await _requireToken();
    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}$path"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> data = json['data'] ?? [];
      return data.map((e) => TaskDocument.fromJson(e)).toList();
    } else {
      throw Exception(_extractError(response));
    }
  }

  Future<TaskDocument> uploadToTask(
    int taskId,
    Uint8List fileBytes,
    String fileName, {
    String? title,
    String? description,
  }) =>
      _upload('/tasks/$taskId/documents', fileBytes, fileName, title: title, description: description);

  Future<TaskDocument> uploadToSprint(
    int sprintId,
    Uint8List fileBytes,
    String fileName, {
    String? title,
    String? description,
  }) =>
      _upload('/sprints/$sprintId/documents', fileBytes, fileName, title: title, description: description);

  Future<TaskDocument> uploadToProject(
    int projectId,
    Uint8List fileBytes,
    String fileName, {
    String? title,
    String? description,
  }) =>
      _upload('/projects/$projectId/documents', fileBytes, fileName, title: title, description: description);

  Future<TaskDocument> _upload(
    String path,
    Uint8List fileBytes,
    String fileName, {
    String? title,
    String? description,
  }) async {
    validateFile(fileBytes.length, fileName);

    final token = await _requireToken();
    final uri = Uri.parse("${ClientService.baseUrl}$path");
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });

    if (title != null && title.isNotEmpty) request.fields['title'] = title;
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return TaskDocument.fromJson(jsonDecode(response.body)['data']);
    } else {
      throw Exception(_extractError(response));
    }
  }

  // Validation locale avant envoi : évite d'attendre un aller-retour réseau
  // (potentiellement long pour un gros fichier) pour découvrir que le
  // serveur va de toute façon refuser le fichier.
  void validateFile(int sizeBytes, String fileName) {
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!kAllowedDocumentExtensions.contains(extension)) {
      throw DocumentValidationException(
          'Format ".$extension" non supporté. Formats acceptés : ${kAllowedDocumentExtensions.join(', ')}.');
    }
    if (sizeBytes > kMaxDocumentSizeBytes) {
      final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
      throw DocumentValidationException('Fichier trop volumineux ($sizeMb Mo, max 20 Mo).');
    }
  }

  // Télécharge le fichier et l'enregistre dans le stockage de l'app (pas de
  // package supplémentaire pour l'ouverture automatique — cf. lib/utils/download.dart
  // qui fait le même compromis pour les fichiers de chat).
  Future<String> downloadAndSave(TaskDocument document) async {
    final token = await _requireToken();
    final response = await http.get(
      Uri.parse("${ClientService.baseUrl}/documents/${document.id}"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response));
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${document.originalName}');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  Future<void> delete(int documentId) async {
    final token = await _requireToken();
    final response = await http.delete(
      Uri.parse("${ClientService.baseUrl}/documents/$documentId"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response));
    }
  }

  String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body['errors'] != null) {
        final errors = body['errors'] as Map<String, dynamic>;
        final firstField = errors.values.first;
        if (firstField is List && firstField.isNotEmpty) {
          return firstField.first.toString();
        }
      }
      return body['message'] ?? 'Une erreur est survenue';
    } catch (_) {
      return 'Une erreur est survenue';
    }
  }
}
