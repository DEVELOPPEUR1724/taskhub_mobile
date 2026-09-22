import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/document.dart';
import '../services/document_service.dart';

const _adaiOrange = Color(0xFFE57A44);

typedef DocumentUploader = Future<TaskDocument> Function(
  Uint8List fileBytes,
  String fileName, {
  String? title,
  String? description,
});

// Bottom sheet de sélection + upload d'un document. Retourne le document créé
// si l'upload a réussi, ou null si l'utilisateur a annulé.
Future<TaskDocument?> showDocumentUploadSheet(
  BuildContext context, {
  required DocumentUploader onUpload,
}) {
  return showModalBottomSheet<TaskDocument>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DocumentUploadSheet(onUpload: onUpload),
  );
}

class _DocumentUploadSheet extends StatefulWidget {
  final DocumentUploader onUpload;
  const _DocumentUploadSheet({required this.onUpload});

  @override
  State<_DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<_DocumentUploadSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _documentService = DocumentService();

  PlatformFile? _selectedFile;
  String? _fileError;
  bool _isUploading = false;
  String? _uploadError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAllowedDocumentExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    setState(() {
      _selectedFile = file;
      _uploadError = null;
      try {
        _documentService.validateFile(file.size, file.name);
        _fileError = null;
      } on DocumentValidationException catch (e) {
        _fileError = e.message;
      }
    });
  }

  Future<void> _submit() async {
    final file = _selectedFile;
    if (file == null || file.bytes == null || _fileError != null) return;

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });
    try {
      final document = await widget.onUpload(
        file.bytes!,
        file.name,
        title: _titleController.text,
        description: _descriptionController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(document);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ajouter un document',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickFile,
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(_selectedFile?.name ?? 'Choisir un fichier', overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _fileError != null ? const Color(0xFFFF453A) : colors.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_fileError != null) ...[
              const SizedBox(height: 6),
              Text(_fileError!, style: const TextStyle(color: Color(0xFFFF453A), fontSize: 12)),
            ] else if (_selectedFile != null) ...[
              const SizedBox(height: 6),
              Text(
                'Formats acceptés : ${kAllowedDocumentExtensions.join(', ')} · max 20 Mo',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              enabled: !_isUploading,
              decoration: const InputDecoration(labelText: 'Titre (optionnel)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              enabled: !_isUploading,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description (optionnel)'),
            ),
            if (_uploadError != null) ...[
              const SizedBox(height: 10),
              Text(_uploadError!, style: const TextStyle(color: Color(0xFFFF453A), fontSize: 12.5)),
            ],
            const SizedBox(height: 18),
            if (_isUploading) const LinearProgressIndicator(),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: (_selectedFile == null || _fileError != null || _isUploading) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _adaiOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_isUploading ? 'Envoi en cours...' : 'Envoyer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
