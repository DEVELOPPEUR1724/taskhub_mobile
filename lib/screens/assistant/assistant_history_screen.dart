import 'package:flutter/material.dart';

import '../../services/assistant_service.dart';

const _adaiOrange = Color(0xFFE57A44);

class AssistantHistoryScreen extends StatefulWidget {
  const AssistantHistoryScreen({super.key});

  @override
  State<AssistantHistoryScreen> createState() => _AssistantHistoryScreenState();
}

class _AssistantHistoryScreenState extends State<AssistantHistoryScreen> {
  final _assistantService = AssistantService();
  List<AssistantConversationSummary>? _conversations;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final conversations = await _assistantService.listConversations();
      if (!mounted) return;
      setState(() => _conversations = conversations);
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la conversation ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer',
                style: TextStyle(color: Color(0xFFFF453A))),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  // Le retrait visuel se fait dès le swipe confirmé (comportement attendu
  // d'un Dismissible) ; en cas d'échec réseau on recharge la vraie liste
  // depuis le serveur plutôt que de tenter de réinsérer l'élément à la main.
  Future<void> _delete(AssistantConversationSummary conversation) async {
    setState(() => _conversations?.removeWhere((c) => c.id == conversation.id));
    try {
      await _assistantService.deleteConversation(conversation.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
      _load();
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return '${diff.inDays} j';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          TextButton(
                              onPressed: _load, child: const Text('Réessayer')),
                        ],
                      ),
                    ),
                  )
                : (_conversations == null || _conversations!.isEmpty)
                    ? Center(
                        child: Text('Aucune conversation pour l\'instant.',
                            style: TextStyle(color: colors.onSurfaceVariant)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _conversations!.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final conversation = _conversations![index];
                          return Dismissible(
                            key: ValueKey(conversation.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(),
                            onDismissed: (_) => _delete(conversation),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF453A).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFFF453A).withOpacity(0.4)),
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: Color(0xFFFF453A)),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: colors.outlineVariant),
                              ),
                              leading: const Icon(Icons.chat_bubble_outline,
                                  color: _adaiOrange),
                              title: Text(conversation.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatDate(conversation.updatedAt),
                                    style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20, color: Color(0xFFFF453A)),
                                    onPressed: () async {
                                      if (await _confirmDelete()) {
                                        _delete(conversation);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  Navigator.of(context).pop(conversation.id),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
