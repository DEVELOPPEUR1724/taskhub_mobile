import 'package:flutter/material.dart';

import 'pointageHistorique_screen.dart';
import '../../models/workday.dart';
import '../../services/pointage_service.dart';
import '../../utils/french_date.dart';

final _pointageService = PointageService();

const _adaiOrange = Color(0xFFE57A44);
const _adaiGreen = Color(0xFF32D74B);
const _adaiGrey = Color(0xFF9E9E9E);

class TimelineStep {
  final String time;
  final String label;
  final bool isDone;
  final bool isActive;

  const TimelineStep({
    required this.time,
    required this.label,
    this.isDone = false,
    this.isActive = false,
  });
}

class PointageScreen extends StatefulWidget {
  const PointageScreen({super.key});

  @override
  State<PointageScreen> createState() => _PointageScreenState();
}

class _PointageScreenState extends State<PointageScreen> {
  Workday? _workday;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final workday = await _pointageService.getToday();
      if (!mounted) return;
      setState(() {
        _workday = workday;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement du pointage';
      });
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _isActionLoading = true);
    try {
      await action();
      await _loadToday();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '--:--';
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}h${local.minute.toString().padLeft(2, '0')}';
  }

  ({String label, Color color}) get _statusStyle {
    switch (_workday?.status) {
      case 'in_progress':
        return (label: 'EN POSTE', color: _adaiGreen);
      case 'paused':
        return (label: 'EN PAUSE', color: _adaiOrange);
      case 'completed':
        return (label: 'JOURNÉE TERMINÉE', color: _adaiGrey);
      default:
        return (label: 'PAS ENCORE COMMENCÉE', color: _adaiGrey);
    }
  }

  List<TimelineStep> get _timeline {
    final w = _workday;
    if (w == null || w.startedAt == null) return const [];

    final steps = <TimelineStep>[
      TimelineStep(time: _formatTime(w.startedAt), label: 'Arrivée', isDone: true),
    ];
    for (final pause in w.pauses) {
      steps.add(TimelineStep(
        time: _formatTime(pause.startedAt),
        label: 'Pause',
        isDone: true,
        isActive: pause.endedAt == null,
      ));
      if (pause.endedAt != null) {
        steps.add(TimelineStep(time: _formatTime(pause.endedAt), label: 'Reprise', isDone: true));
      }
    }
    steps.add(TimelineStep(
      time: w.endedAt != null ? _formatTime(w.endedAt) : '--:--',
      label: 'Départ',
      isDone: w.endedAt != null,
    ));
    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadToday, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final w = _workday!;
    final status = _statusStyle;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(
                  'https://dashboard-wally-process-interne.adaiexpertise.fr/logo_sans_fond.png',
                ),
                backgroundColor: Colors.transparent,
              ),
              Text(
                'Mon Pointage',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.onSurface),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.history, color: colors.onSurfaceVariant),
                    tooltip: 'Historique des pointages',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const PointageHistoriqueScreen()),
                      );
                    },
                  ),
                  Icon(Icons.notifications_none, color: colors.onSurfaceVariant),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(formatFrenchDate(DateTime.now()), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'STATUT DE LA JOURNÉE',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: status.color),
                      const SizedBox(width: 6),
                      Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Début de journée', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5)),
                          const SizedBox(height: 6),
                          Text(
                            _formatTime(w.startedAt),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.onSurface),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 42, child: VerticalDivider(color: colors.outlineVariant, width: 1)),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Temps effectif', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5)),
                          const SizedBox(height: 6),
                          Text(
                            w.durationLabel ?? '00h00',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _adaiOrange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (w.pauseCount > 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pause_circle_outline, size: 15, color: colors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '${w.pauseDuration ?? '00h00'} en pause',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'ACTION DISPONIBLE',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ..._buildActions(w.status),

          const SizedBox(height: 28),
          if (_timeline.isNotEmpty) ...[
            Text(
              'TIMELINE DU JOUR',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            const SizedBox(height: 16),
            _Timeline(steps: _timeline),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(String status) {
    switch (status) {
      case 'not_started':
        return [
          _ActionButton(
            label: 'COMMENCER MA JOURNÉE',
            icon: Icons.play_circle_outline,
            color: _adaiGreen,
            onPressed: _isActionLoading ? null : () => _runAction(_pointageService.startWorkday),
          ),
        ];
      case 'in_progress':
        return [
          _ActionButton(
            label: 'PRENDRE UNE PAUSE',
            icon: Icons.pause_circle_outline,
            color: _adaiOrange,
            onPressed: _isActionLoading ? null : () => _runAction(_pointageService.startPause),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            label: 'TERMINER MA JOURNÉE',
            icon: Icons.stop_circle_outlined,
            color: const Color(0xFFFF453A),
            onPressed: _isActionLoading ? null : () => _runAction(_pointageService.endWorkday),
          ),
        ];
      case 'paused':
        return [
          _ActionButton(
            label: 'REPRENDRE',
            icon: Icons.play_circle_outline,
            color: _adaiGreen,
            onPressed: _isActionLoading ? null : () => _runAction(_pointageService.endPause),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            label: 'TERMINER MA JOURNÉE',
            icon: Icons.stop_circle_outlined,
            color: const Color(0xFFFF453A),
            onPressed: _isActionLoading ? null : () => _runAction(_pointageService.endWorkday),
          ),
        ];
      default:
        return [
          Center(
            child: Text(
              'Journée déjà terminée pour aujourd\'hui.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ];
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 18),
        label: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<TimelineStep> steps;

  const _Timeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox()
                          : Container(
                              height: 2,
                              color: steps[i - 1].isDone ? _stepColor(steps[i - 1]) : colors.outlineVariant,
                            ),
                    ),
                    _StepDot(step: steps[i]),
                    Expanded(
                      child: i == steps.length - 1
                          ? const SizedBox()
                          : Container(
                              height: 2,
                              color: steps[i].isDone ? _stepColor(steps[i]) : colors.outlineVariant,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(steps[i].time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(steps[i].label, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _stepColor(TimelineStep step) => step.isActive ? _adaiOrange : _adaiGreen;
}

class _StepDot extends StatelessWidget {
  final TimelineStep step;

  const _StepDot({required this.step});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!step.isDone) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.outlineVariant, width: 2)),
      );
    }
    final color = step.isActive ? _adaiOrange : _adaiGreen;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: step.isActive ? colors.surface : color,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}
