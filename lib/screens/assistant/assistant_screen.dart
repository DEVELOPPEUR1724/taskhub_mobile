import 'package:flutter/material.dart';

const _adaiOrange = Color(0xFFE57A44);
const _liveGreen = Color(0xFF32D74B);

// Écran de chat de l'assistant IA — interface prête (bulles, composer,
// suggestions), mais pas encore reliée à l'API réelle de streaming
// (/api/assistant/chat côté backend). Voir le lanceur flottant dans
// MainScaffold, équivalent du widget web
// resources/views/assistant/widget.blade.php.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage(this.text, {required this.isUser});
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];

  static const _suggestions = [
    'Quelles tâches sont bloquées aujourd\'hui ?',
    'Résume l\'avancement du sprint en cours.',
    'Qui est le plus chargé cette semaine ?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(trimmed, isUser: true));
      // TODO: brancher /api/assistant/chat (réponse en streaming) — pour
      // l'instant l'interface reste fonctionnelle mais non connectée.
      _messages.add(const _ChatMessage(
        'Cette fonctionnalité arrive bientôt — je ne suis pas encore connecté à l\'assistant réel.',
        isUser: false,
      ));
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _adaiOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _adaiOrange.withOpacity(0.4)),
              ),
              child:
                  const Icon(Icons.blur_circular, color: _adaiOrange, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Copilot',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: _liveGreen, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text('Friday · En direct',
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AssistantBubble(
                    text:
                        'Bonjour ! Je suis Copilot, ton assistant Friday. Pose-moi une question sur tes projets, tes tâches ou ta charge de travail.',
                  ),
                  const SizedBox(height: 16),
                  ..._messages.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: m.isUser
                            ? _UserBubble(text: m.text)
                            : _AssistantBubble(text: m.text),
                      )),
                  if (_messages.isEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions
                          .map((s) => OutlinedButton(
                                onPressed: () => _send(s),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: _adaiOrange.withOpacity(0.4)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(s,
                                    style: const TextStyle(fontSize: 12.5)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: _send,
                        decoration: InputDecoration(
                          hintText: 'Écris ta question...',
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _send(_controller.text),
                      style: IconButton.styleFrom(backgroundColor: _adaiOrange),
                      icon:
                          const Icon(Icons.send, size: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String text;

  const _AssistantBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style: TextStyle(
                color: colors.onSurface, fontSize: 13.5, height: 1.4)),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;

  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _adaiOrange.withOpacity(0.14),
          border: Border.all(color: _adaiOrange.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style: TextStyle(
                color: colors.onSurface, fontSize: 13.5, height: 1.4)),
      ),
    );
  }
}
