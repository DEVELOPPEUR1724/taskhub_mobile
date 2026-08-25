import 'package:flutter/material.dart';

import 'conversation_screen.dart';
import 'createConversation_screen.dart';
import '../../services/chat_service.dart';
import '../../models/conversation.dart' as api;

final chatService = ChatService();

const _adaiOrange = Color(0xFFE57A44);

// Palette utilisée pour donner une icône/couleur déterministe à chaque
// conversation, faute d'un tel champ renvoyé par l'API.
const _iconPalette = [
  (Icons.phone_iphone, Color(0xFF32D74B)),
  (Icons.terminal, Color(0xFF8B5CF6)),
  (Icons.dashboard_outlined, Color(0xFFE0A527)),
  (Icons.bug_report_outlined, Color(0xFF0A84FF)),
  (Icons.campaign_outlined, Color(0xFFE0709B)),
];

class ConversationPreview {
  final int id;
  final String projectName;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String lastSender;
  final String lastMessage;
  final String time;
  final int unreadCount;

  const ConversationPreview({
    required this.id,
    required this.projectName,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.lastSender,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
  });
}

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  List<ConversationPreview> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiConversations = await chatService.getConversations();
      final previews = apiConversations.map(_mapApiConversationToPreview).toList();
      if (!mounted) return;
      setState(() {
        _conversations = previews;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des conversations';
      });
    }
  }

  ConversationPreview _mapApiConversationToPreview(api.Conversation conversation) {
    final palette = _iconPalette[conversation.id % _iconPalette.length];
    final lastMessage = conversation.lastMessage;

    return ConversationPreview(
      id: conversation.id,
      projectName: conversation.name ?? (conversation.isGroup ? 'Groupe' : 'Conversation'),
      icon: palette.$1,
      iconBg: palette.$2,
      iconColor: Colors.white,
      lastSender: lastMessage?.user?.name ?? '',
      // '📎 Fichier' générique : la liste des conversations ne reçoit pas le
      // mime_type du dernier message, impossible de savoir ici s'il s'agit
      // d'une image ou d'un autre type de pièce jointe (pdf, doc, ...).
      lastMessage: lastMessage?.body ??
          (lastMessage?.fileUrl != null ? '📎 Fichier' : 'Aucun message pour l\'instant'),
      time: _formatRelativeTime(conversation.lastMessageAt),
      unreadCount: conversation.unreadCount,
    );
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);

    if (date == today) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    if (date == today.subtract(const Duration(days: 1))) {
      return 'Hier';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Conversations',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: _adaiOrange, size: 28),
                      tooltip: 'Nouvelle conversation',
                      onPressed: () async {
                        final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (context) => const CreateConversationScreen(),
                          ),
                        );
                        if (created == true) {
                          _loadConversations();
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    const CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(
                        'https://dashboard-wally-process-interne.adaiexpertise.fr/logo_sans_fond.png',
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Discussions par projet',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
          ),
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
                                onPressed: _loadConversations,
                                child: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _conversations.isEmpty
                        ? Center(
                            child: Text(
                              'Aucune conversation pour l\'instant',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _conversations.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: colors.outlineVariant),
                            itemBuilder: (context, index) {
                              return _ConversationTile(conversation: _conversations[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationPreview conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ConversationScreen(
              conversationId: conversation.id,
              projectName: conversation.projectName,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: conversation.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(conversation.icon, color: conversation.iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.projectName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastSender.isEmpty
                        ? conversation.lastMessage
                        : '${conversation.lastSender}: ${conversation.lastMessage}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  conversation.time,
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
                if (conversation.unreadCount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _adaiOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
