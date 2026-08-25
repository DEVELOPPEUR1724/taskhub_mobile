import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// Valeurs brutes des enums PHP ProjectStatus/ProjectPriority telles que
// sérialisées par l'API (pas de libellé français côté backend).
({String label, Color bg, Color fg}) projectStatusStyle(BuildContext context, String? status) {
  final AppStatusColor category;
  final String label;
  switch (status) {
    case 'new':
      category = AppStatusColor.info;
      label = 'Nouveau';
      break;
    case 'in_progress':
      category = AppStatusColor.warning;
      label = 'En cours';
      break;
    case 'paused':
      category = AppStatusColor.neutral;
      label = 'En pause';
      break;
    case 'done':
      category = AppStatusColor.success;
      label = 'Terminé';
      break;
    case 'late':
      category = AppStatusColor.danger;
      label = 'En retard';
      break;
    default:
      category = AppStatusColor.neutral;
      label = status ?? '-';
  }
  final style = statusColorFor(context, category);
  return (label: label, bg: style.bg, fg: style.fg);
}

String projectPriorityLabel(String? priority) {
  switch (priority) {
    case 'low':
      return 'Faible';
    case 'medium':
      return 'Moyenne';
    case 'high':
      return 'Haute';
    case 'urgent':
      return 'Urgente';
    case 'critical':
      return 'Critique';
    default:
      return '-';
  }
}

// Palette multicolore pour les avatars de projet (un ton différent par id).
const List<Color> projectColorPalette = [
  Color(0xFF7C5CE0),
  Color(0xFF32D74B),
  Color(0xFFE0A527),
  Color(0xFF0A84FF),
  Color(0xFFE0709B),
];

Color projectColorFor(int id) => projectColorPalette[id % projectColorPalette.length];

// Couleur d'accent utilisée pour la barre de progression, distincte de la
// couleur d'avatar.
const Color projectProgressColor = Color(0xFFE57A44);
