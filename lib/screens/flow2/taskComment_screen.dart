import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'taskUploadImg_screen.dart';
import 'imageViewer_screen.dart';
import '../../services/comment_service.dart';
import '../../models/comment.dart' as api;

final commentService = CommentService();

const _adaiOrange = Color(0xFFE57A44);
class Comment {
  final String author;
  final String avatarUrl;
  final String timestamp;
  final String message;
  final String? imageUrl;
  final int likeCount;

  const Comment({
    required this.author,
    required this.avatarUrl,
    required this.timestamp,
    required this.message,
    this.imageUrl,
    this.likeCount = 0,
  });
}

class TaskCommentScreen extends StatefulWidget {
  const TaskCommentScreen({super.key, required this.taskId});
  final int taskId;

  @override
  State<TaskCommentScreen> createState() => _TaskCommentScreenState();

}

class _TaskCommentScreenState extends State<TaskCommentScreen> {
  final _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadcomments();
  }

    Future<void> _loadcomments() async {
    setState(() {
      _isLoading = true;
      // Correction : sans cette remise à zéro, un ancien message d'erreur
      // restait affiché même après un rechargement réussi.
      _errorMessage = null;
    });

    try {
      final apiComments = await commentService.getComments(widget.taskId);
      final uiComments = apiComments.map(_mapApiCommentToUiTask).toList();
      if (!mounted) return;
      setState(() {
        _comments = uiComments;
        _isLoading = false;
      });
    }catch(e){
      if (!mounted) return;
       setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des commentaires';
      });
    }
  }

  Comment _mapApiCommentToUiTask(api.Comment apiComments) {
    return Comment(
      author: apiComments.user?.name ?? 'Utilisateur inconnu',
      avatarUrl: 'https://i.pravatar.cc/100?u=${apiComments.userId}',
      timestamp: apiComments.createdAt != null
          ? '${apiComments.createdAt!.toLocal().day.toString().padLeft(2, '0')}/'
              '${apiComments.createdAt!.toLocal().month.toString().padLeft(2, '0')}/'
              '${apiComments.createdAt!.toLocal().year}'
          : 'Non définie',
      message: apiComments.body ?? 'Aucune description disponible',
      imageUrl: apiComments.imageUrl,
      likeCount: 0,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // Correction : ajout optimiste retiré du bloc principal. On ajoute le
    // commentaire localement seulement APRÈS confirmation de l'API, pour ne
    // jamais afficher un commentaire qui n'a pas réellement été envoyé.
    try {
      // Correction : "await" manquant — sans lui, le try/catch ne pouvait
      // pas intercepter les erreurs réseau/serveur (401, 422, etc.), qui
      // partaient dans un Future ignoré.
      final apiComment = await commentService.commentAjout(widget.taskId, body: text);

      if (!mounted) return;
      setState(() {
        _comments.add(_mapApiCommentToUiTask(apiComment));
      });
      // Correction : le champ est maintenant vidé en cas de SUCCÈS (avant,
      // il n'était vidé qu'en cas d'échec, ce qui était inversé).
      _commentController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
      // Le texte est volontairement conservé dans le champ en cas d'échec,
      // pour permettre à l'utilisateur de réessayer sans tout retaper.
    }
  }

  Future<void> _sendImageComment(Uint8List bytes, String fileName, String? description) async {
    try {
      final apiComment = await commentService.commentAjout(
        widget.taskId,
        body: description,
        imageBytes: bytes,
        imageFileName: fileName,
      );
      if (!mounted) return;
      setState(() {
        _comments.add(_mapApiCommentToUiTask(apiComment));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commentaires', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Correction : _errorMessage était rempli en cas d'échec mais
            // jamais affiché — la liste restait juste vide silencieusement.
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
                                  onPressed: _loadcomments,
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) => _CommentBubble(comment: _comments[index]),
                        ),
            ),
            _CommentInputBar(
              controller: _commentController,
              onSend: _sendComment,
              onImageSelected: _sendImageComment,
            ),

          ],
        ),
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final Comment comment;

  const _CommentBubble({required this.comment});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.surfaceContainerHighest,
            backgroundImage: NetworkImage(comment.avatarUrl),
            // Correction : évite l'exception plein écran (ImageCodecException /
            // ProgressEvent) quand l'avatar externe (pravatar.cc) est
            // injoignable — on garde juste le fond gris par défaut.
            onBackgroundImageError: (exception, stackTrace) {},
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        comment.author,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        comment.timestamp,
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment.message,
                    style: TextStyle(fontSize: 13.5, color: colors.onSurface, height: 1.4),
                  ),
                  if (comment.imageUrl != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (context) => ImageViewerScreen(imageUrl: comment.imageUrl!),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          comment.imageUrl!,
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          // Correction : remplace l'exception plein écran par un
                          // placeholder quand l'image (URL cassée, serveur
                          // injoignable) ne peut pas être chargée.
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 130,
                            width: double.infinity,
                            color: colors.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (comment.likeCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.thumb_up, size: 14, color: _adaiOrange),
                        const SizedBox(width: 4),
                        Text(
                          '${comment.likeCount}',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Future<void> Function(Uint8List bytes, String fileName, String? description) onImageSelected;

  const _CommentInputBar({
    required this.controller,
    required this.onSend,
    required this.onImageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Écrire un commentaire...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
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
                    child: Icon(Icons.attach_file, color: colors.onSurfaceVariant, size: 20),
                  ),
                ],
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
