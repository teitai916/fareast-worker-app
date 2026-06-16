import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getNotifications();
      setState(() => _notifications = data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加載失敗: $e')),
      );
    }
    setState(() => _loading = false);
  }

  Future<void> _markAsRead(Map<String, dynamic> n) async {
    if (n['isRead'] == true) return;
    try {
      await ApiService().markNotificationRead(n['id']);
      setState(() => n['isRead'] = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗: $e')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService().markAllNotificationsRead();
      await _loadNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已全部標記為已讀')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['isRead'] != true).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('全部已讀', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('暫無通知', style: TextStyle(color: AppTheme.textHint)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: _notifications.length,
                  itemBuilder: (context, i) {
                    final n = _notifications[i];
                    final isUnread = n['isRead'] != true;
                    return Card(
                      color: isUnread ? AppTheme.primaryColor.withOpacity(0.05) : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getNotificationColor(n['type']),
                          child: Icon(_getNotificationIcon(n['type']), color: Colors.white, size: 20),
                        ),
                        title: Text(
                          n['title'] ?? '',
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['content'] ?? '', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(n['createdAt']),
                              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                            ),
                          ],
                        ),
                        trailing: isUnread ? const CircleAvatar(radius: 4, backgroundColor: AppTheme.primaryColor) : null,
                        onTap: () => _markAsRead(n),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getNotificationColor(String? type) {
    if (type == 'APPLICATION_SUBMITTED') return AppTheme.warningColor;
    if (type == 'APPLICATION_APPROVED') return AppTheme.successColor;
    if (type == 'APPLICATION_REJECTED') return AppTheme.errorColor;
    return AppTheme.primaryColor;
  }

  IconData _getNotificationIcon(String? type) {
    if (type == 'APPLICATION_SUBMITTED') return Icons.pending_actions;
    if (type == 'APPLICATION_APPROVED') return Icons.check_circle;
    if (type == 'APPLICATION_REJECTED') return Icons.cancel;
    return Icons.notifications;
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
