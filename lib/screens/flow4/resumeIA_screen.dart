import 'package:flutter/material.dart';

const _adaiOrange = Color(0xFFE57A44);

class ResumeIAScreen extends StatefulWidget {
  const ResumeIAScreen({super.key});

  @override
  State<ResumeIAScreen> createState() => _ResumeIAScreenState();
}

class _ResumeIAScreenState extends State<ResumeIAScreen> {
  bool _isRefreshing = false;

  final String _projectName = 'Mobile App';
  final String _projectDescription = 'Développement de l\'application mobile pour nos utilisateurs.';
  final double _progress = 0.68;

  final String _iaSummary =
      'Le projet avance bien. L\'équipe a complété les fonctionnalités clés de l\'authentification et du tableau de bord. L\'intégration de l\'écran de connexion est en cours et devrait être terminée d\'ici demain. Attention à la tâche "Design écran tableau de bord" qui est en retard par rapport au planning initial.';
  final String _generatedAgo = 'il y a 30 min';

  final int _totalTasks = 24;
  final int _inProgressTasks = 14;
  final int _lateTasks = 3;

  Future<void> _refreshSummary() async {
    setState(() => _isRefreshing = true);
    // TODO: appeler le vrai service de génération de résumé IA
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: _adaiOrange),
        centerTitle: true,
        title: const Text(
          'Résumé IA projet',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: afficher plus d'options
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF32D74B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.phone_iphone, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _projectName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _projectDescription,
                                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: CircularProgressIndicator(
                              value: _progress,
                              strokeWidth: 10,
                              backgroundColor: colors.surfaceContainerHighest,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF32D74B)),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(_progress * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                              Text(
                                'Avancement',
                                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6F0),
                  border: Border.all(color: const Color(0xFFF0E4D4)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, size: 16, color: _adaiOrange),
                        SizedBox(width: 6),
                        Text(
                          'Résumé IA',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.auto_awesome, size: 16, color: _adaiOrange),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _iaSummary,
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 13.5, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Généré $_generatedAgo • Basé sur les données du projet',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.format_list_bulleted,
                      iconBg: const Color(0xFFE3F0FB),
                      iconColor: const Color(0xFF0A84FF),
                      value: '$_totalTasks',
                      label: 'Tâches totales',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.autorenew,
                      iconBg: const Color(0xFFFDF0DE),
                      iconColor: _adaiOrange,
                      value: '$_inProgressTasks',
                      label: 'En cours',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.access_time,
                      iconBg: const Color(0xFFFCE4E4),
                      iconColor: const Color(0xFFE05B33),
                      value: '$_lateTasks',
                      label: 'En retard',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isRefreshing ? null : _refreshSummary,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(
                    _isRefreshing ? 'Génération en cours...' : 'Actualiser le résumé',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _adaiOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Dernière mise à jour : $_generatedAgo',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
