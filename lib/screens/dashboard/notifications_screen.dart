import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && items.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.notifications();
      final wrapper = response['notifications'];
      final rows = wrapper is Map ? wrapper['data'] : null;
      if (!mounted) return;
      setState(() {
        items = (rows as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _read(Map<String, dynamic> item) async {
    if (item['read'] == true) return;
    try {
      await AppScope.of(context).api.readNotification('${item['id']}');
      if (mounted) setState(() => item['read'] = true);
    } catch (_) {}
  }

  Future<void> _readAll() async {
    try {
      await AppScope.of(context).api.readAllNotifications();
      if (mounted) {
        setState(() {
          for (final item in items) {
            item['read'] = true;
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton(
          onPressed: items.isEmpty ? null : _readAll,
          child: const Text('Mark all read'),
        ),
      ],
    ),
    body: loading && items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && items.isEmpty
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: items.isEmpty ? 1 : items.length,
              separatorBuilder: (context, _) => Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (_, index) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No notifications yet')),
                  );
                }
                final item = items[index];
                return _Notification(
                  _title('${item['type'] ?? ''}'),
                  '${item['message'] ?? ''}',
                  '${item['created_ago'] ?? ''}',
                  item['read'] != true,
                  _icon('${item['type'] ?? ''}'),
                  onTap: () => _read(item),
                );
              },
            ),
          ),
  );

  String _title(String type) => type
      .replaceAll(RegExp(r'[_\\.-]+'), ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  IconData _icon(String type) {
    if (type.contains('message')) return LucideIcons.messageSquare;
    if (type.contains('application')) return LucideIcons.userPlus;
    if (type.contains('shortlist')) return LucideIcons.star;
    if (type.contains('hire')) return LucideIcons.circleCheck;
    return LucideIcons.bell;
  }
}

class _Notification extends StatelessWidget {
  const _Notification(
    this.title,
    this.message,
    this.time,
    this.unread,
    this.icon, {
    required this.onTap,
  });
  final String title, message, time;
  final bool unread;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: unread
          ? colors.primary.withValues(alpha: .16)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unread ? colors.surface : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Notification' : title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: unread
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
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
