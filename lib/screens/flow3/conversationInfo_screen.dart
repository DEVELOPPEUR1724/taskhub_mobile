import 'package:flutter/material.dart';

import 'conversationFiles_screen.dart';
import '../../services/chat_service.dart';
import '../../models/conversation.dart' as api;
import '../../models/message.dart' as msg;
import '../../utils/file_icon.dart';

const _adaiOrange = Color(0xFFE57A44);

final _chatServiceForInfo = ChatService();

class ConversationInfoScreen extends StatefulWidget {
  final int conversationId;
  final String projectName;

  const ConversationInfoScreen({
    super.key,
    required this.conversationId,
    required this.projectName,
  });

  @override
  State<ConversationInfoScreen> createState() => _ConversationInfoScreenState();
}

class _ConversationInfoScreenState extends State<ConversationInfoScreen> {
  api.Conversation? _conversation;
  bool _isLoadingConversation = true;

  List<msg.Message> _files = [];
  bool _isLoadingFiles = true;

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _loadFiles();
  }

  Future<void> _loadConversation() async {
    try {
      final conversation = await _chatServiceForInfo.getConversation(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _isLoadingConversation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingConversation = false);
    }
  }

  Future<void> _loadFiles() async {
    try {
      final files = await _chatServiceForInfo.getFiles(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _files = files;
        _isLoadingFiles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFiles = false);
    }
  }

  String get _title => _conversation?.name ?? widget.projectName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isGroup = _conversation?.isGroup ?? true;
    final members = _conversation?.members ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'À propos de la conversation',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _adaiOrange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isGroup ? Icons.groups_outlined : Icons.person_outline,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Fichiers partagés',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
            ),
            const SizedBox(height: 12),
            _buildFilesSection(),
            const SizedBox(height: 24),

            Text(
              'Membres (${members.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
            ),
            const SizedBox(height: 12),
            if (_isLoadingConversation)
              const Center(child: CircularProgressIndicator())
            else if (members.isEmpty)
              Text('Aucun membre', style: TextStyle(color: colors.onSurfaceVariant))
            else
              for (final member in members) _MemberTile(member: member),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesSection() {
    final colors = Theme.of(context).colorScheme;
    if (_isLoadingFiles) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_files.isEmpty) {
      return Text('Aucun fichier partagé', style: TextStyle(color: colors.onSurfaceVariant));
    }

    final previewFiles = _files.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 140,
            child: Row(
              children: [
                for (int i = 0; i < previewFiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(child: _buildPreviewThumbnail(previewFiles[i])),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ConversationFilesScreen(files: _files),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0DE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.perm_media_outlined, size: 18, color: _adaiOrange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fichiers partagés',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_files.length} fichier${_files.length > 1 ? 's' : ''}',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewThumbnail(msg.Message file) {
    final colors = Theme.of(context).colorScheme;
    if (file.fileUrl == null) {
      return Container(color: colors.surfaceContainerHighest);
    }
    if (!file.isImage) {
      return Container(
        color: colors.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(fileIconForExtension(file.fileExtension), size: 28, color: colors.onSurfaceVariant),
      );
    }
    return Image.network(
      file.fileUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: colors.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final api.ConversationMember member;

  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=${member.id}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.onSurface),
                ),
                if (member.role != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.role!,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
