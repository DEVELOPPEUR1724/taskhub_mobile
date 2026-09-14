import 'package:flutter/material.dart';

import '../screens/assistant/assistant_screen.dart';

const _adaiOrange = Color(0xFFE57A44);

// Bouton flottant persistant, présent sur tous les écrans (branché dans
// MainScaffold) — équivalent du lanceur de chat IA en bas à droite du
// dashboard web (resources/views/assistant/_floating-widget.blade.php),
// simplifié ici en simple logo rond plutôt que la pilule complète.
class AssistantLauncherButton extends StatelessWidget {
  const AssistantLauncherButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: _adaiOrange.withOpacity(0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AssistantScreen()),
          );
        },
        child: Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Le logo est conçu pour un fond clair (transparent avec traits
            // sombres) : en mode sombre, un fond noir/surface le rendrait
            // illisible — on garde donc toujours un fond clair, juste teinté
            // différemment selon le thème plutôt qu'un blanc pur figé.
            color: colors.brightness == Brightness.dark
                ? const Color(0xFFEDEDED)
                : colors.surface,
            border:
                Border.all(color: _adaiOrange.withOpacity(0.55), width: 1.5),
          ),
          child: Image.network(
            'https://dashboard-wally-process-interne.adaiexpertise.fr/logo_sans_fond.png',
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.blur_circular, color: _adaiOrange),
          ),
        ),
      ),
    );
  }
}
