import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../flow2/imageViewer_screen.dart';
import '../../models/message.dart' as msg;
import '../../utils/file_icon.dart';

class ConversationFilesScreen extends StatelessWidget {
  final List<msg.Message> files;

  const ConversationFilesScreen({super.key, required this.files});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fichiers partagés (${files.length})',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: files.isEmpty
            ? Center(
                child: Text('Aucun fichier partagé', style: TextStyle(color: colors.onSurfaceVariant)),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  final fileUrl = file.fileUrl;
                  if (fileUrl == null) return const SizedBox.shrink();

                  if (!file.isImage) {
                    return GestureDetector(
                      onTap: () => launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(fileIconForExtension(file.fileExtension), size: 26, color: colors.onSurfaceVariant),
                            const SizedBox(height: 6),
                            Text(
                              file.fileName ?? file.fileExtension.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (context) => ImageViewerScreen(imageUrl: fileUrl),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        fileUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: colors.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
