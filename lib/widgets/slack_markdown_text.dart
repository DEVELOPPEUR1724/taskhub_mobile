import 'package:flutter/material.dart';

// Rendu minimal du markdown "à la Slack" (mrkdwn) : *texte* devient gras.
// Ne gère volontairement rien d'autre (pas de liens, listes, etc.) — le
// rapport IA est censé rester un texte simple structuré en paragraphes.
class SlackMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const SlackMarkdownText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*(.+?)\*');
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }
}
