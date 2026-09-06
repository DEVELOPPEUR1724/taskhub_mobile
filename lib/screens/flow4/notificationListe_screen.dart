import 'package:flutter/material.dart';

import '../flow2/taskDetail_screen.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';

final _notificationService = NotificationService();

const _adaiOrange = Color(0xFFE57A44);

enum NotificationFilter { toutes, nonLues }

class NotificationListeScreen extends StatefulWidget {
  const NotificationListeScreen({super.key});

  @override
  State<NotificationListeScreen> createState() =>
      _NotificationListeScreenState();
}

class _NotificationListeScreenState extends State<NotificationListeScreen> {
  NotificationFilter _filter = NotificationFilter.toutes;

  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifications = await _notificationService.getNotifications(
        unreadOnly: _filter == NotificationFilter.nonLues,
      );
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des notifications';
      });
    }
  }

  void _onFilterChanged(NotificationFilter filter) {
    setState(() => _filter = filter);
    _loadNotifications();
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    // Optimiste : on met à jour tout de suite, on annule si l'appel échoue.
    setState(() => notification.readAt = DateTime.now());
    try {
      await _notificationService.markAsRead(notification.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => notification.readAt = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
  }

  void _onNotificationTap(AppNotification notification) {
    // Marquage lu sans attendre : ne doit pas retarder la navigation.
    _markAsRead(notification);
    if (notification.taskId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(taskId: notification.taskId!),
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    final previousState = _notifications.map((n) => n.readAt).toList();
    setState(() {
      for (final n in _notifications) {
        n.readAt ??= DateTime.now();
      }
    });
    try {
      await _notificationService.markAllAsRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _notifications.length; i++) {
          _notifications[i].readAt = previousState[i];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF453A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: colors.onSurface),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(
                      'https://dashboard-wally-process-interne.adaiexpertise.fr/logo_sans_fond.png',
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: 'Toutes',
                    selected: _filter == NotificationFilter.toutes,
                    onTap: () => _onFilterChanged(NotificationFilter.toutes),
                  ),
                  _FilterChip(
                    label: 'Non lues',
                    selected: _filter == NotificationFilter.nonLues,
                    onTap: () => _onFilterChanged(NotificationFilter.nonLues),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
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
                                  style:
                                      TextStyle(color: colors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _loadNotifications,
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _notifications.isEmpty
                          ? Center(
                              child: Text(
                                'Aucune notification',
                                style:
                                    TextStyle(color: colors.onSurfaceVariant),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                final notif = _notifications[index];
                                return _NotificationTile(
                                  notification: notif,
                                  onMarkRead: () => _onNotificationTap(notif),
                                );
                              },
                            ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: TextButton.icon(
                  onPressed: _markAllAsRead,
                  style: TextButton.styleFrom(foregroundColor: _adaiOrange),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text(
                    'Tout marqué comme lu',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: _adaiOrange,
        backgroundColor: colors.surface,
        labelStyle: TextStyle(
          color: selected ? Colors.white : colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side:
              BorderSide(color: selected ? _adaiOrange : colors.outlineVariant),
        ),
      ),
    );
  }
}

IconData _iconForType(String? type) {
  switch (type) {
    case 'task':
      return Icons.assignment_outlined;
    case 'deadline':
      return Icons.flag_outlined;
    case 'task_validation':
      return Icons.verified_outlined;
    case 'budget_request':
      return Icons.payments_outlined;
    case 'calendar_event':
      return Icons.event_outlined;
    case 'project':
      return Icons.folder_outlined;
    case 'sprint':
      return Icons.timeline_outlined;
    case 'time_tracking':
      return Icons.access_time;
    default:
      return Icons.notifications_outlined;
  }
}

AppStatusColor _statusColorForType(String? type) {
  switch (type) {
    case 'task':
    case 'calendar_event':
      return AppStatusColor.info;
    case 'deadline':
      return AppStatusColor.danger;
    case 'task_validation':
      return AppStatusColor.purple;
    case 'budget_request':
    case 'time_tracking':
      return AppStatusColor.success;
    case 'project':
    case 'sprint':
      return AppStatusColor.warning;
    default:
      return AppStatusColor.neutral;
  }
}

String _formatRelativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime.toLocal());
  if (diff.inMinutes < 1) return 'à l\'instant';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return '${diff.inDays} j';
  final local = dateTime.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;

  const _NotificationTile({
    required this.notification,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status =
        statusColorFor(context, _statusColorForType(notification.type));
    return GestureDetector(
      onTap: onMarkRead,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: status.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(_iconForType(notification.type),
                  color: status.fg, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title ?? 'Notification',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message ?? '',
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatRelativeTime(notification.createdAt),
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              size: 9, color: Colors.white),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Marquer comme lu',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
