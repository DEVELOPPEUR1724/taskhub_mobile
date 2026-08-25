import 'package:flutter/material.dart';

// Palette sémantique unique pour les badges de statut (bleu/vert/orange/
// rouge/violet/rose/neutre), remplaçant les paires (bg, fg) dupliquées
// inline dans une dizaine d'écrans. Chaque variante a un rendu clair et un
// rendu sombre — l'appelant n'a qu'à passer le BuildContext courant.
enum AppStatusColor { info, success, warning, danger, purple, pink, neutral }

const Color _infoColor = Color(0xFF0A84FF);
const Color _successColor = Color(0xFF32D74B);
const Color _warningColor = Color(0xFFFF9F0A);
const Color _dangerColor = Color(0xFFFF453A);

({Color bg, Color fg}) statusColorFor(BuildContext context, AppStatusColor status) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (status) {
    case AppStatusColor.info:
      return (bg: _infoColor.withOpacity(isDark ? 0.18 : 0.12), fg: _infoColor);
    case AppStatusColor.success:
      return (bg: _successColor.withOpacity(isDark ? 0.18 : 0.12), fg: _successColor);
    case AppStatusColor.warning:
      return (bg: _warningColor.withOpacity(isDark ? 0.18 : 0.12), fg: _warningColor);
    case AppStatusColor.danger:
      return (bg: _dangerColor.withOpacity(isDark ? 0.18 : 0.12), fg: _dangerColor);
    case AppStatusColor.purple:
      return isDark
          ? (bg: const Color(0xFF29223D), fg: const Color(0xFFA48CF0))
          : (bg: const Color(0xFFEDE7FB), fg: const Color(0xFF7C5CE0));
    case AppStatusColor.pink:
      return isDark
          ? (bg: const Color(0xFF3A2230), fg: const Color(0xFFEF93B8))
          : (bg: const Color(0xFFFCE4F1), fg: const Color(0xFFE0709B));
    case AppStatusColor.neutral:
      return isDark
          ? (bg: const Color(0xFF2A2A2E), fg: const Color(0xFFB0B0B5))
          : (bg: const Color(0xFFECECEC), fg: const Color(0xFF616161));
  }
}
