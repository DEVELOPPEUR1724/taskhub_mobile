import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/assistant_service.dart';

const _adaiOrange = Color(0xFFE57A44);
const _liveGreen = Color(0xFF32D74B);

// Écran de chat de l'assistant IA, relié à POST /api/assistant/ask (réponses
// basées sur des requêtes en base côté serveur, pas de LLM — pas de
// streaming, réponse synchrone). Voir le lanceur flottant dans
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
  final List<AssistantLink> links;
  final bool isError;

  const _ChatMessage(
    this.text, {
    required this.isUser,
    this.links = const [],
    this.isError = false,
  });
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _assistantService = AssistantService();
  final _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];
  int? _conversationId;
  bool _isSending = false;

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

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;
    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(trimmed, isUser: true));
      _isSending = true;
    });

    try {
      final reply = await _assistantService.ask(
        trimmed,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = reply.conversationId;
        _messages
            .add(_ChatMessage(reply.reply, isUser: false, links: reply.links));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          e.toString().replaceFirst('Exception: ', ''),
          isUser: false,
          isError: true,
        ));
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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
                  const _AssistantBubble(
                    text:
                        'Bonjour ! Je suis Copilot, ton assistant Friday. Pose-moi une question sur tes projets, tes tâches ou ta charge de travail.',
                  ),
                  const SizedBox(height: 16),
                  ..._messages.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: m.isUser
                            ? _UserBubble(text: m.text)
                            : _AssistantBubble(
                                text: m.text,
                                links: m.links,
                                isError: m.isError,
                              ),
                      )),
                  if (_isSending)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _AssistantBubble(text: '...', isLoading: true),
                    ),
                  if (_messages.isEmpty && !_isSending) ...[
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
                        enabled: !_isSending,
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
                      onPressed:
                          _isSending ? null : () => _send(_controller.text),
                      style: IconButton.styleFrom(backgroundColor: _adaiOrange),
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send,
                              size: 18, color: Colors.white),
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
  final List<AssistantLink> links;
  final bool isError;
  final bool isLoading;

  const _AssistantBubble({
    required this.text,
    this.links = const [],
    this.isError = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
              color: isError ? const Color(0xFFFF453A) : colors.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colors.onSurfaceVariant),
              )
            else
              Text(text,
                  style: TextStyle(
                      color:
                          isError ? const Color(0xFFFF453A) : colors.onSurface,
                      fontSize: 13.5,
                      height: 1.4)),
            if (links.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...links.map((link) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => launchUrl(Uri.parse(link.url),
                          mode: LaunchMode.externalApplication),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: _adaiOrange.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(link.label,
                                style: const TextStyle(
                                    color: _adaiOrange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            if (link.meta != null)
                              Text(link.meta!,
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
          ],
        ),
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
