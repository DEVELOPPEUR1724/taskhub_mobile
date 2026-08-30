class MessageUser {
  final int id;
  final String name;
  final String? role;

  MessageUser({
    required this.id,
    required this.name,
    this.role,
  });

  factory MessageUser.fromJson(Map<String, dynamic> json) {
    return MessageUser(
      id: json['id'],
      name: json['name'],
      role: json['role'],
    );
  }
}

class Message {
  final int id;
  // Nullable : GET /conversations/{id}/files ne sélectionne pas cette
  // colonne (get(['id','user_id','file_url','created_at'])), donc absente
  // du JSON pour cet endpoint.
  final int? conversationId;
  final int userId;
  final String? body;
  final String? fileUrl;
  // Métadonnées ajoutées côté backend pour distinguer le type de pièce
  // jointe (plus seulement des images : pdf, doc, xls, ppt, txt, csv, zip,
  // rar sont désormais acceptés par sendMessage).
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  final DateTime createdAt;
  final MessageUser? user;

  Message({
    required this.id,
    this.conversationId,
    required this.userId,
    this.body,
    this.fileUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
    required this.createdAt,
    this.user,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      body: json['body'],
      fileUrl: json['file_url'],
      fileName: json['file_name'],
      mimeType: json['mime_type'],
      fileSize: json['file_size'],
      createdAt: DateTime.parse(json['created_at']),
      user: json['user'] != null ? MessageUser.fromJson(json['user']) : null,
    );
  }

  // Pratique côté UI pour décider d'afficher une miniature image ou une
  // carte fichier générique (pdf, doc, zip, ...).
  bool get isImage {
    if (mimeType != null) return mimeType!.startsWith('image/');
    final url = fileUrl?.toLowerCase() ?? '';
    return url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.gif') ||
        url.endsWith('.webp');
  }

  String get fileExtension {
    final name = fileName ?? fileUrl ?? '';
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return '';
    return name.substring(dotIndex + 1).toLowerCase();
  }
}

// Une page de résultats de GET /conversations/{id}/messages (pagination
// Laravel). messages est trié du plus récent au plus ancien (voir
// ChatController::getMessages).
class MessagePage {
  final List<Message> messages;
  final int currentPage;
  final int lastPage;

  MessagePage({
    required this.messages,
    required this.currentPage,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;
}

// Résultat de recherche transversale (GET /messages/search) — forme
// personnalisée renvoyée par le backend (ChatController::searchAllMessages),
// pas un Message complet : pas de pièce jointe, mais on connaît la
// conversation d'origine puisque la recherche porte sur plusieurs à la fois.
class MessageSearchResult {
  final int id;
  final String? body;
  final DateTime createdAt;
  final MessageUser? user;
  final int conversationId;
  final String conversationName;

  MessageSearchResult({
    required this.id,
    this.body,
    required this.createdAt,
    this.user,
    required this.conversationId,
    required this.conversationName,
  });

  factory MessageSearchResult.fromJson(Map<String, dynamic> json) {
    return MessageSearchResult(
      id: json['id'],
      body: json['body'],
      createdAt: DateTime.parse(json['created_at']),
      user: json['user'] != null ? MessageUser.fromJson(json['user']) : null,
      conversationId: json['conversation_id'],
      conversationName: json['conversation_name'] ?? 'Conversation',
    );
  }
}

class MessageSearchPage {
  final List<MessageSearchResult> results;
  final int currentPage;
  final int lastPage;

  MessageSearchPage({
    required this.results,
    required this.currentPage,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;
}
