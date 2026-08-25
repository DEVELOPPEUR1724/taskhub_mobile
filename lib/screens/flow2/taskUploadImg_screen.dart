import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const _adaiOrange = Color(0xFFE57A44);

class TaskUploadImgScreen extends StatefulWidget {
  const TaskUploadImgScreen({super.key});

  @override
  State<TaskUploadImgScreen> createState() => _TaskUploadImgScreenState();
}

class _TaskUploadImgScreenState extends State<TaskUploadImgScreen> {
  final _picker = ImagePicker();
  final _descriptionController = TextEditingController();

  Uint8List? _previewBytes;
  String? _fileName;
  String? _fileSize;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _fileName = file.name;
        _fileSize = '${(bytes.lengthInBytes / 1024).toStringAsFixed(0)} Ko';
      });
    } catch (e) {
      // Cas typique sur Chrome desktop sans webcam : NotFoundError lors de
      // pickImage(source: camera), ou permission refusée par le navigateur.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Caméra indisponible ou accès refusé.'
                : 'Impossible de sélectionner une image.',
          ),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
  }

  void _removeSelection() {
    setState(() {
      _previewBytes = null;
      _fileName = null;
      _fileSize = null;
    });
  }

  void _sendPhoto() {
    if (_previewBytes == null) return;
    // On ne parle pas au backend ici : on renvoie juste l'image (et la
    // description optionnelle) à l'écran appelant (TaskCommentScreen), qui
    // connaît le taskId et déclenche l'appel API via CommentService.
    final description = _descriptionController.text.trim();
    Navigator.of(context).pop({
      'bytes': _previewBytes!,
      'fileName': _fileName ?? 'comment_image.jpg',
      'description': description.isEmpty ? null : description,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colors.onSurface),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Text(
                    'Ajouter une photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    if (_previewBytes != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              _previewBytes!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: _removeSelection,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black26, blurRadius: 4),
                                  ],
                                ),
                                child: const Icon(Icons.close, size: 18, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _PickOptionCard(
                            icon: Icons.camera_alt_outlined,
                            label: 'Appareil photo',
                            onTap: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PickOptionCard(
                            icon: Icons.image_outlined,
                            label: 'Galerie',
                            onTap: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                    if (_fileName != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _fileName!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _fileSize ?? '',
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _removeSelection,
                              child: Icon(Icons.close, size: 18, color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Ajouter une description (facultatif)...',
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _previewBytes != null ? _sendPhoto : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _adaiOrange,
                    disabledBackgroundColor: colors.outlineVariant,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Envoyer la photo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickOptionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: colors.onSurface),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
