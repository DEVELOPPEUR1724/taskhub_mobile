import 'package:flutter/material.dart';

import '../../models/workday.dart';
import '../../services/pointage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/french_date.dart';

final _pointageService = PointageService();

const _adaiOrange = Color(0xFFE57A44);

class PointageHistoriqueScreen extends StatefulWidget {
  const PointageHistoriqueScreen({super.key});

  @override
  State<PointageHistoriqueScreen> createState() => _PointageHistoriqueScreenState();
}

class _PointageHistoriqueScreenState extends State<PointageHistoriqueScreen> {
  List<WorkdayHistoryEntry> _history = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final history = await _pointageService.getHistory();
      if (!mounted) return;
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement de l\'historique';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Historique Pointage',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: afficher les filtres (période, statut, etc.)
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _loadHistory, child: const Text('Réessayer')),
                        ],
                      ),
                    ),
                  )
                : _history.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun pointage enregistré',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) => _PointageDayTile(day: _history[index]),
                      ),
      ),
    );
  }
}

class _PointageDayTile extends StatelessWidget {
  final WorkdayHistoryEntry day;

  const _PointageDayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completionStyle = statusColorFor(
      context,
      day.isComplete ? AppStatusColor.success : AppStatusColor.warning,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0DE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_today_outlined, size: 18, color: _adaiOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatFrenchDate(day.workDate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13, color: colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      day.pauseCount == 0
                          ? '0 pause'
                          : '${day.pauseCount} pause${day.pauseCount > 1 ? 's' : ''} (${day.pauseDuration})',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                day.durationLabel,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.onSurface),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: completionStyle.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  day.isComplete ? 'Complet' : 'Incomplet',
                  style: TextStyle(
                    color: completionStyle.fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
