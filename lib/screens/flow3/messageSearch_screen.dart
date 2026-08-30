import 'dart:async';

import 'package:flutter/material.dart';

import 'conversation_screen.dart';
import '../../services/chat_service.dart';

final chatService = ChatService();

const _adaiOrange = Color(0xFFE57A44);

// Résultat unifié, que la recherche soit globale (toutes les conversations)
// ou limitée à une conversation précise — évite de dupliquer l'UI de la
// liste pour les deux formes de réponse renvoyées par le backend.
class _SearchHit {
  final int id;
  final String body;
  final DateTime createdAt;
  final String senderName;
  final int conversationId;
  final String? conversationName; // null si déjà dans une conversation précise

  const _SearchHit({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.senderName,
    required this.conversationId,
    this.conversationName,
  });
}

class MessageSearchScreen extends StatefulWidget {
  // Recherche globale si null, sinon recherche limitée à cette conversation.
  final int? conversationId;
  final String? conversationName;

  const MessageSearchScreen({super.key, this.conversationId, this.conversationName});

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  String _query = '';
  List<_SearchHit> _hits = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  bool get _hasMore => _currentPage < _lastPage;

  bool get _isGlobal => widget.conversationId == null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    setState(() => _query = trimmed);

    if (trimmed.length < 2) {
      setState(() {
        _hits = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    // Recherche "en direct" au fil de la frappe, sans attendre un Entrée —
    // même logique que la barre de recherche Messenger.
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(trimmed));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final hits = _isGlobal
          ? await _searchGlobal(query, page: 1)
          : await _searchInConversation(query, page: 1);
      // La requête a pu changer pendant l'attente réseau (frappe rapide) :
      // on ignore une réponse qui ne correspond plus au champ actuel.
      if (!mounted || query != _query) return;
      setState(() {
        _hits = hits.$1;
        _currentPage = hits.$2;
        _lastPage = hits.$3;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || query != _query) return;
      setState(() {
        _isSearching = false;
        _errorMessage = 'Erreur lors de la recherche';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _query.length < 2) return;
    setState(() => _isLoadingMore = true);
    try {
      final hits = _isGlobal
          ? await _searchGlobal(_query, page: _currentPage + 1)
          : await _searchInConversation(_query, page: _currentPage + 1);
      if (!mounted) return;
      setState(() {
        _hits = [..._hits, ...hits.$1];
        _currentPage = hits.$2;
        _lastPage = hits.$3;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<(List<_SearchHit>, int, int)> _searchGlobal(String query, {required int page}) async {
    final result = await chatService.searchAllMessages(query, page: page);
    final hits = result.results
        .map((r) => _SearchHit(
              id: r.id,
              body: r.body ?? '',
              createdAt: r.createdAt,
              senderName: r.user?.name ?? 'Utilisateur inconnu',
              conversationId: r.conversationId,
              conversationName: r.conversationName,
            ))
        .toList();
    return (hits, result.currentPage, result.lastPage);
  }

  Future<(List<_SearchHit>, int, int)> _searchInConversation(String query, {required int page}) async {
    final result = await chatService.searchMessages(widget.conversationId!, query, page: page);
    final hits = result.messages
        .map((m) => _SearchHit(
              id: m.id,
              body: m.body ?? '',
              createdAt: m.createdAt,
              senderName: m.user?.name ?? 'Utilisateur inconnu',
              conversationId: widget.conversationId!,
            ))
        .toList();
    return (hits, result.currentPage, result.lastPage);
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);

    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (date == today) return time;
    if (date == today.subtract(const Duration(days: 1))) return 'Hier · $time';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} · $time';
  }

  void _onHitTap(_SearchHit hit) {
    if (_isGlobal) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ConversationScreen(
            conversationId: hit.conversationId,
            projectName: hit.conversationName ?? 'Conversation',
          ),
        ),
      );
    } else {
      // Déjà dans la bonne conversation : on referme simplement la recherche.
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colors.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 20, color: colors.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _queryController,
                              autofocus: true,
                              onChanged: _onQueryChanged,
                              style: TextStyle(color: colors.onSurface, fontSize: 14.5),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: _isGlobal
                                    ? 'Rechercher dans les messages'
                                    : 'Rechercher dans "${widget.conversationName}"',
                                hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 14.5),
                              ),
                            ),
                          ),
                          if (_queryController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _queryController.clear();
                                _onQueryChanged('');
                              },
                              child: Icon(Icons.close, size: 18, color: colors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    if (_query.length < 2) {
      return _CenteredHint(
        icon: Icons.search,
        text: 'Recherchez un mot dans vos messages',
        colors: colors,
      );
    }
    if (_isSearching && _hits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextButton(onPressed: () => _runSearch(_query), child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (_hits.isEmpty) {
      return _CenteredHint(
        icon: Icons.search_off,
        text: 'Aucun résultat pour "$_query"',
        colors: colors,
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _hits.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => Divider(height: 1, color: colors.outlineVariant, indent: 72),
      itemBuilder: (context, index) {
        if (index >= _hits.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        return _SearchHitTile(hit: _hits[index], query: _query, onTap: () => _onHitTap(_hits[index]), formatDate: _formatDate);
      },
    );
  }
}

class _CenteredHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colors;

  const _CenteredHint({required this.icon, required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}

class _SearchHitTile extends StatelessWidget {
  final _SearchHit hit;
  final String query;
  final VoidCallback onTap;
  final String Function(DateTime) formatDate;

  const _SearchHitTile({
    required this.hit,
    required this.query,
    required this.onTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colors.surfaceContainerHighest,
              backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=${hit.senderName}'),
              onBackgroundImageError: (exception, stackTrace) {},
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hit.conversationName != null ? hit.conversationName! : hit.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatDate(hit.createdAt),
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (hit.conversationName != null)
                    Text(
                      hit.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                    ),
                  const SizedBox(height: 2),
                  _HighlightedSnippet(text: hit.body, query: query, colors: colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Met en évidence la première occurrence du terme recherché dans l'extrait
// du message — même principe que la recherche Messenger, qui surligne le
// mot trouvé plutôt que d'afficher juste un extrait brut.
class _HighlightedSnippet extends StatelessWidget {
  final String text;
  final String query;
  final ColorScheme colors;

  const _HighlightedSnippet({required this.text, required this.query, required this.colors});

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(color: colors.onSurfaceVariant, fontSize: 13, height: 1.3);
    final matchStyle = TextStyle(color: _adaiOrange, fontWeight: FontWeight.w700, fontSize: 13, height: 1.3);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerQuery.isEmpty ? -1 : lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: baseStyle);
    }

    // Recadre l'extrait autour du terme trouvé plutôt que de toujours partir
    // du début du message, pour ne pas couper le mot recherché hors-champ
    // sur un message long.
    const contextChars = 40;
    final start = (matchIndex - contextChars).clamp(0, text.length);
    final end = (matchIndex + lowerQuery.length + contextChars).clamp(0, text.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';

    final before = text.substring(start, matchIndex);
    final match = text.substring(matchIndex, matchIndex + lowerQuery.length);
    final after = text.substring(matchIndex + lowerQuery.length, end);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$prefix$before'),
          TextSpan(text: match, style: matchStyle),
          TextSpan(text: '$after$suffix'),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }
}
