import 'package:flutter/material.dart';

import '../models/document.dart';
import '../utils/file_icon.dart';

const _adaiOrange = Color(0xFFE57A44);

class DocumentListTile extends StatelessWidget {
  final TaskDocument document;
  final VoidCallback onTap;
  final bool downloading;
  final bool canDelete;
  final VoidCallback? onDelete;

  const DocumentListTile({
    super.key,
    required this.document,
    required this.onTap,
    this.downloading = false,
    this.canDelete = false,
    this.onDelete,
  });

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: downloading ? null : onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(fileIconForExtension(document.extension), color: colors.onSurfaceVariant, size: 20),
      ),
      title: Text(
        document.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface),
      ),
      subtitle: Text(
        '${formatFileSize(document.size)} • Utilisateur #${document.uploadedById} • ${_formatDate(document.createdAt)}',
        style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
      ),
      trailing: downloading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : canDelete
              ? IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFFF453A)),
                  onPressed: onDelete,
                )
              : const Icon(Icons.download_outlined, color: _adaiOrange, size: 20),
    );
  }
}

class DocumentEmptyState extends StatelessWidget {
  const DocumentEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'Aucun document pour l\'instant.',
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
      ),
    );
  }
}
