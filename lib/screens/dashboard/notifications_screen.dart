import 'package:flutter/material.dart' hide Text;
import 'package:employer_kariger_app/core/api/api_exception.dart';
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/push/push_router.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _opening = false;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && items.isEmpty && error == null) _load();
  }

  int _page = 1, _lastPage = 1;
  bool _loadingMore = false;

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.notifications();
      if (!mounted) return;
      setState(() => _apply(response, more: false));
    } catch (exception) {
      if (mounted) setState(() => error = errorText(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// The server sends 20 at a time; older ones load as the list nears its end.
  Future<void> _loadMore() async {
    if (_loadingMore || loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.notifications(page: _page + 1);
      if (mounted) setState(() => _apply(response, more: true));
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorText(exception))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _apply(Map<String, dynamic> response, {required bool more}) {
    final wrapper = response['notifications'] is Map
        ? Map<String, dynamic>.from(response['notifications'] as Map)
        : <String, dynamic>{};
    final incoming = (wrapper['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final known = {for (final item in items) item['id']};
    items = more
        ? [...items, ...incoming.where((item) => !known.contains(item['id']))]
        : incoming;
    _page = (wrapper['current_page'] as num?)?.toInt() ?? 1;
    _lastPage = (wrapper['last_page'] as num?)?.toInt() ?? _page;
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

  /// Opens what the row is about: the job (applicants, screening calls,
  /// interviews, job checks), chats, plans, AI credits or KYC.
  Future<void> _open(Map<String, dynamic> item) async {
    await _read(item);
    if (!mounted || _opening) return;
    final api = AppScope.of(context).api;
    final data = {
      ...item,
      if (item['data'] is Map)
        ...Map<String, dynamic>.from(item['data'] as Map),
    };
    setState(() => _opening = true);
    try {
      final screen = await screenForNotification(data, api);
      if (screen == null || !mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
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
              itemCount: items.isEmpty
                  ? 1
                  : items.length + (_page < _lastPage ? 1 : 0),
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
                if (index == items.length) {
                  return PageEndLoader(onReached: _loadMore);
                }
                final item = items[index];
                return _Notification(
                  item['title']?.toString().trim().isNotEmpty == true
                      ? item['title'].toString()
                      : _title('${item['type'] ?? ''}'),
                  '${item['message'] ?? ''}',
                  shortAgo('${item['created_ago'] ?? ''}'),
                  item['read'] != true,
                  _icon('${item['type'] ?? ''}'),
                  onTap: () => _open(item),
                );
              },
            ),
          ),
  );

  /// A title for rows the server sent without one.
  String _title(String type) =>
      notificationTitles[type] ??
      type
          .replaceFirst(RegExp(r'Notification$'), '')
          .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (m) => '${m[1]} ${m[2]!.toLowerCase()}',
          )
          .replaceAll(RegExp(r'[_.-]+'), ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map(
            (part) => const {'kyc', 'ai', 'gst'}.contains(part.toLowerCase())
                ? part.toUpperCase()
                : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join(' ');

  IconData _icon(String type) {
    if (type.contains('plan')) return LucideIcons.walletCards;
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

/// Readable titles for the notification types the server sends untitled.
const notificationTitles = <String, String>{
  'screening.completed': 'AI call finished',
  'kyc.reviewed': 'KYC reviewed',
  'application.received': 'New applicant',
  'chat.message': 'New message',
  'job.moderation': 'Job check',
  'job.review_needed': 'Job needs a check',
  'plan.reminder': 'Plan reminder',
  'ai_credits.low': 'AI credits running low',
  'interview.reminder_call': 'Interview reminder call',
  'application.interview_reminder': 'Interview reminder',
  // Old rows saved the class name as the type.
  'NewApplicationNotification': 'New applicant',
  'NewMessageNotification': 'New message',
};
