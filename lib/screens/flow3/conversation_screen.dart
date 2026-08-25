import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'conversationInfo_screen.dart';
import '../flow2/imageViewer_screen.dart';
import '../flow2/taskUploadImg_screen.dart';
import '../../services/chat_service.dart';
import '../../models/message.dart' as api;
import '../../models/conversation.dart' as api;
import '../../utils/file_icon.dart';

final chatService = ChatService();

const _adaiOrange = Color(0xFFE57A44);

class ChatMessage {
  final String id;
  final String sender;
  final String role;
  final bool isMe;
  final String message;
  final String? imageUrl;
  final bool isImage;
  final String? fileName;
  final int? fileSize;
  final String time;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.role,
    required this.isMe,
    required this.message,
    this.imageUrl,
    this.isImage = true,
    this.fileName,
    this.fileSize,
    required this.time,
    this.isRead = false,
  });
}

class ConversationScreen extends StatefulWidget {
  final int? conversationId;
  final String projectName;

  const ConversationScreen({
    super.key,
    this.conversationId,
    this.projectName = 'Conversation',
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _messageController = TextEditingController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentUserId;

  api.Conversation? _conversation;
  List<api.ConversationMember> _members = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');
    // Erreur silencieuse : sans la liste des membres, le chat reste
    // utilisable — juste sans le vrai titre/avatars dans l'en-tête.
    _loadConversationDetails();
    await _loadMessages();
  }

  Future<void> _loadConversationDetails() async {
    if (widget.conversationId == null) return;
    try {
      final conversation = await chatService.getConversation(widget.conversationId!);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _members = conversation.members;
      });
    } catch (_) {
      // Ignoré volontairement, voir commentaire dans _init().
    }
  }

  String get _headerTitle {
    if (_conversation?.name != null) return _conversation!.name!;
    if (_conversation != null && !_conversation!.isGroup) {
      final others = _members.where((m) => m.id != _currentUserId);
      if (others.isNotEmpty) return others.first.name;
    }
    return widget.projectName;
  }

  String get _headerSubtitle {
    if (_conversation == null) return '';
    if (_conversation!.isGroup) {
      return '${_members.length} membre${_members.length > 1 ? 's' : ''}';
    }
    final others = _members.where((m) => m.id != _currentUserId);
    return others.isNotEmpty ? (others.first.role ?? '') : '';
  }

  Future<void> _loadMessages() async {
    if (widget.conversationId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Conversation introuvable';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiMessages = await chatService.getMessages(widget.conversationId!);
      final uiMessages = apiMessages.map(_mapApiMessageToUiMessage).toList();
      if (!mounted) return;
      setState(() {
        _messages = uiMessages;
        _isLoading = false;
      });
      // Marque la conversation comme lue une fois les messages affichés.
      // Erreur silencieuse : ça ne doit pas bloquer l'affichage du chat.
      chatService.markAsRead(widget.conversationId!).catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des messages';
      });
    }
  }

  ChatMessage _mapApiMessageToUiMessage(api.Message message) {
    return ChatMessage(
      id: message.id.toString(),
      sender: message.user?.name ?? 'Utilisateur inconnu',
      role: message.user?.role ?? '',
      isMe: _currentUserId != null && message.userId == _currentUserId,
      message: message.body ?? '',
      imageUrl: message.fileUrl,
      isImage: message.isImage,
      fileName: message.fileName,
      fileSize: message.fileSize,
      time: _formatTime(message.createdAt),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.conversationId == null) return;

    try {
      final apiMessage = await chatService.sendMessages(widget.conversationId!, body: text);
      if (!mounted) return;
      setState(() {
        _messages.add(_mapApiMessageToUiMessage(apiMessage));
      });
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
  }

  Future<void> _sendImageMessage(Uint8List bytes, String fileName, String? description) async {
    if (widget.conversationId == null) return;

    try {
      final apiMessage = await chatService.sendMessages(
        widget.conversationId!,
        body: description,
        imageBytes: bytes,
        imageFileName: fileName,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_mapApiMessageToUiMessage(apiMessage));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? colors.surface : const Color(0xFFFAF7F4),
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _headerTitle,
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            if (_headerSubtitle.isNotEmpty)
              Text(
                _headerSubtitle,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
              ),
          ],
        ),
        actions: [
          if (_members.isNotEmpty)
            SizedBox(
              width: _members.take(4).length * 18.0 + 20,
              child: Stack(
                children: [
                  for (int i = 0; i < _members.take(4).length; i++)
                    Positioned(
                      left: i * 18.0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: colors.surface,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=${_members[i].id}'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(Icons.more_vert, color: colors.onSurface),
            onPressed: widget.conversationId == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ConversationInfoScreen(
                          conversationId: widget.conversationId!,
                          projectName: _headerTitle,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _loadMessages,
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _messages.isEmpty
                          ? Center(
                              child: Text(
                                'Aucun message pour l\'instant',
                                style: TextStyle(color: colors.onSurfaceVariant),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
                            ),
            ),
            _MessageInputBar(
              controller: _messageController,
              onSend: _sendMessage,
              onImageSelected: _sendImageMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMe = message.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=${message.sender}'),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: message.sender,
                            style: const TextStyle(
                              color: _adaiOrange,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          if (message.role.isNotEmpty)
                            TextSpan(
                              text: '  •  ${message.role}',
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFDCF3DC) : colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: isMe ? null : Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.message.isNotEmpty)
                        Text(
                          message.message,
                          style: TextStyle(fontSize: 13.5, color: isMe ? Colors.black87 : colors.onSurface, height: 1.4),
                        ),
                      if (message.imageUrl != null) ...[
                        const SizedBox(height: 8),
                        if (message.isImage)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (context) => ImageViewerScreen(imageUrl: message.imageUrl!),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                message.imageUrl!,
                                height: 120,
                                width: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 120,
                                  width: 220,
                                  color: colors.surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
                                ),
                              ),
                            ),
                          )
                        else
                          _FileAttachmentCard(
                            url: message.imageUrl!,
                            fileName: message.fileName ?? 'Fichier',
                            fileSize: message.fileSize,
                          ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.time,
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10.5),
                      ),
                      if (isMe && message.isRead) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all, size: 13, color: Color(0xFF32D74B)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileAttachmentCard extends StatelessWidget {
  final String url;
  final String fileName;
  final int? fileSize;

  const _FileAttachmentCard({
    required this.url,
    required this.fileName,
    this.fileSize,
  });

  Future<void> _openFile(BuildContext context) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir ce fichier.'), backgroundColor: Color(0xFFFF453A)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return InkWell(
      onTap: () => _openFile(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(fileIconForExtension(extension), size: 18, color: _adaiOrange),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.onSurface),
                  ),
                  if (fileSize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      formatFileSize(fileSize),
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Future<void> Function(Uint8List bytes, String fileName, String? description) onImageSelected;

  const _MessageInputBar({
    required this.controller,
    required this.onSend,
    required this.onImageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: colors.surface,
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final result = await Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(
                  builder: (context) => const TaskUploadImgScreen(),
                ),
              );
              if (result != null) {
                await onImageSelected(
                  result['bytes'] as Uint8List,
                  result['fileName'] as String,
                  result['description'] as String?,
                );
              }
            },
            child: Icon(Icons.image_outlined, color: colors.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              // Sélection d'un fichier quelconque (pas seulement une image) :
              // image_picker ne gère que la caméra/galerie, il faut file_picker
              // pour pdf/doc/xls/ppt/txt/csv/zip/rar — mêmes extensions que
              // celles validées côté Laravel (sendMessage).
              try {
                final result = await FilePicker.platform.pickFiles(
                  withData: true,
                  type: FileType.custom,
                  allowedExtensions: const [
                    'jpg', 'jpeg', 'png', 'gif', 'webp',
                    'pdf', 'doc', 'docx', 'xls', 'xlsx',
                    'ppt', 'pptx', 'txt', 'csv', 'zip', 'rar',
                  ],
                );
                final file = result?.files.single;
                if (file?.bytes != null) {
                  await onImageSelected(file!.bytes!, file.name, null);
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sélection de fichier impossible : $e'),
                    backgroundColor: const Color(0xFFFF453A),
                  ),
                );
              }
            },
            child: Icon(Icons.attach_file, color: colors.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: _adaiOrange,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
