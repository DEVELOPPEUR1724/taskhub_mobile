import 'package:flutter/material.dart';

// Valeurs brutes des enums PHP ProjectStatus/ProjectPriority telles que
// sérialisées par l'API (pas de libellé français côté backend).
({String label, Color bg, Color fg}) projectStatusStyle(String? status) {
  switch (status) {
    case 'new':
      return (label: 'Nouveau', bg: const Color(0xFFE3F0FB), fg: const Color(0xFF2E7CD6));
    case 'in_progress':
      return (label: 'En cours', bg: const Color(0xFFFDF0DE), fg: const Color(0xFFB5651D));
    case 'paused':
      return (label: 'En pause', bg: const Color(0xFFECECEC), fg: const Color(0xFF616161));
    case 'done':
      return (label: 'Terminé', bg: const Color(0xFFE5F5E9), fg: const Color(0xFF3A9B54));
    case 'late':
      return (label: 'En retard', bg: const Color(0xFFFCE4E4), fg: const Color(0xFFE05B33));
    default:
      return (label: status ?? '-', bg: const Color(0xFFECECEC), fg: const Color(0xFF616161));
  }
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
  Color(0xFF3A9B54),
  Color(0xFFE0A527),
  Color(0xFF2E7CD6),
  Color(0xFFE0709B),
];

Color projectColorFor(int id) => projectColorPalette[id % projectColorPalette.length];

// Couleur du thème (marron) utilisée pour la barre de progression, distincte
// de la couleur d'avatar.
const Color projectProgressColor = Color(0xFFB5651D);
