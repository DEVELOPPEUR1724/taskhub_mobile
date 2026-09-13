import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../widgets/slack_markdown_text.dart';

const _adaiOrange = Color(0xFFE57A44);

class ResumeIAScreen extends StatefulWidget {
  const ResumeIAScreen({super.key});

  @override
  State<ResumeIAScreen> createState() => _ResumeIAScreenState();
}

class _ResumeIAScreenState extends State<ResumeIAScreen> {
  final _reportService = ReportService();
  String? _globalReport;
  bool _isLoadingGlobalReport = false;
  String? _globalReportError;

  final String _projectName = 'Tous les projets';
  final String _projectDescription =
      'Vue d\'ensemble de l\'avancement du portefeuille.';

  final int _totalTasks = 24;
  final int _inProgressTasks = 14;
  final int _lateTasks = 3;

  // Données de portefeuille (tous projets confondus), à l'image de la barre
  // récapitulative en haut du dashboard web.
  final int _totalProjects = 15;
  final double _averageProgress = 0.76;
  final int _teamMembers = 37;

  int get _completedTasks => _totalTasks - _inProgressTasks - _lateTasks;

  int _percentOf(int value) =>
      _totalTasks == 0 ? 0 : (value / _totalTasks * 100).round();

  Future<void> _loadGlobalReport() async {
    setState(() {
      _isLoadingGlobalReport = true;
      _globalReportError = null;
    });
    try {
      final report = await _reportService.getGlobalReport();
      if (!mounted) return;
      setState(() => _globalReport = report);
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _globalReportError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingGlobalReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: _adaiOrange),
        centerTitle: true,
        title: const Text(
          'Avancement',
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
                            color: const Color(0xFF7C5CE0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.dashboard_outlined,
                              color: Colors.white, size: 22),
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
                                style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _adaiOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(_averageProgress * 100).round()}%',
                                style: const TextStyle(
                                    color: _adaiOrange,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14),
                              ),
                              Text(
                                'Avancement moyen',
                                style: TextStyle(
                                    color: _adaiOrange.withOpacity(0.85),
                                    fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: _adaiOrange),
                        SizedBox(width: 6),
                        Text(
                          'Rapport global',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.auto_awesome, size: 16, color: _adaiOrange),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_globalReportError != null)
                      Text(_globalReportError!,
                          style: const TextStyle(
                              color: Color(0xFFFF453A), fontSize: 13))
                    else if (_globalReport != null)
                      SlackMarkdownText(
                        _globalReport!,
                        style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 13.5,
                            height: 1.5),
                      )
                    else
                      Text(
                        'Pas encore généré — tous projets confondus.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isLoadingGlobalReport ? null : _loadGlobalReport,
                        icon: _isLoadingGlobalReport
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(_isLoadingGlobalReport
                            ? 'Génération... (peut prendre du temps)'
                            : 'Générer le rapport global'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _adaiOrange,
                          side: const BorderSide(color: _adaiOrange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Répartition des Tâches',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: colors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Taux de complétion global',
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        width: 130,
                        height: 130,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 130,
                              height: 130,
                              child: CustomPaint(
                                painter: _SegmentedRingPainter(
                                  backgroundColor:
                                      colors.surfaceContainerHighest,
                                  segments: [
                                    MapEntry(const Color(0xFF32D74B),
                                        _percentOf(_completedTasks).toDouble()),
                                    MapEntry(
                                        const Color(0xFF0A84FF),
                                        _percentOf(_inProgressTasks)
                                            .toDouble()),
                                    MapEntry(const Color(0xFFFF453A),
                                        _percentOf(_lateTasks).toDouble()),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_percentOf(_completedTasks)}%',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: colors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Terminées',
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _BreakdownRow(
                      color: const Color(0xFF32D74B),
                      label: 'Terminées',
                      percent: _percentOf(_completedTasks),
                      count: _completedTasks,
                    ),
                    const SizedBox(height: 10),
                    _BreakdownRow(
                      color: const Color(0xFF0A84FF),
                      label: 'En cours',
                      percent: _percentOf(_inProgressTasks),
                      count: _inProgressTasks,
                    ),
                    const SizedBox(height: 10),
                    _BreakdownRow(
                      color: const Color(0xFFFF453A),
                      label: 'En retard',
                      percent: _percentOf(_lateTasks),
                      count: _lateTasks,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.folder_outlined,
                            iconBg: const Color(0xFFEDE7FF),
                            iconColor: const Color(0xFF7C5CE0),
                            value: '$_totalProjects',
                            label: 'Total projets',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.trending_up,
                            iconBg: const Color(0xFFFDF0DE),
                            iconColor: _adaiOrange,
                            value: '${(_averageProgress * 100).round()}%',
                            label: 'Avancement moyen',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.groups_outlined,
                            iconBg: const Color(0xFFE3F0FB),
                            iconColor: const Color(0xFF0A84FF),
                            value: '$_teamMembers',
                            label: 'Membres équipe',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dessine un anneau découpé en arcs colorés (un par segment, dans l'ordre
// donné), façon donut de la maquette web — Canvas.drawArc ne gère qu'un
// pourcentage à la fois, contrairement au CircularProgressIndicator standard
// qui ne sait afficher qu'une seule couleur.
class _SegmentedRingPainter extends CustomPainter {
  final List<MapEntry<Color, double>> segments;
  final Color backgroundColor;
  final double strokeWidth;

  const _SegmentedRingPainter({
    required this.segments,
    required this.backgroundColor,
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      final sweepAngle = (segment.value.clamp(0, 100) / 100) * 2 * math.pi;
      if (sweepAngle <= 0) continue;
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = segment.key
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedRingPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.backgroundColor != backgroundColor;
}

class _BreakdownRow extends StatelessWidget {
  final Color color;
  final String label;
  final int percent;
  final int count;

  const _BreakdownRow({
    required this.color,
    required this.label,
    required this.percent,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
          ],
        ),
        Row(
          children: [
            Text(
              '$percent%',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colors.onSurface),
            ),
            const SizedBox(width: 6),
            Text(
              '· $count tâches',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ],
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
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.onSurface),
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
