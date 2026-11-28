import 'package:flutter/material.dart' hide Text;
import 'package:employer_kariger_app/core/api/api_exception.dart';
import '../../widgets/localized_text.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/messages/chat_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
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
      final response = await AppScope.of(context).api.conversations();
      if (!mounted) return;
      setState(() => _apply(response, more: false));
    } catch (exception) {
      if (mounted) setState(() => error = errorText(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int _page = 1, _lastPage = 1;
  bool _loadingMore = false;

  /// The server sends 20 chats at a time; the rest load on scroll.
  Future<void> _loadMore() async {
    if (_loadingMore || loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.conversations(page: _page + 1);
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
    final incoming = (response['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final known = {for (final item in items) item['id']};
    items = more
        ? [...items, ...incoming.where((item) => !known.contains(item['id']))]
        : incoming;
    final meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : <String, dynamic>{};
    _page = (meta['current_page'] as num?)?.toInt() ?? 1;
    _lastPage = (meta['last_page'] as num?)?.toInt() ?? _page;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Messages')),
    body: loading && items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && items.isEmpty
        // Say why: offline it used to show a bare Retry button.
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
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
                indent: 82,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No conversations yet')),
                  );
                }
                if (index == items.length) {
                  return PageEndLoader(onReached: _loadMore);
                }
                final item = items[index];
                final job = item['job'] is Map
                    ? '${(item['job'] as Map)['title'] ?? ''}'.trim()
                    : '';
                final participant = item['participant'] is Map
                    ? Map<String, dynamic>.from(item['participant'])
                    : <String, dynamic>{};
                final last = item['last_message'] is Map
                    ? Map<String, dynamic>.from(item['last_message'])
                    : <String, dynamic>{};
                final name = '${participant['name'] ?? 'Karigar'}';
                final worker = Worker(name, 'Karigar', 0, 0, 0, 0, const []);
                final unread = (item['unread'] as num?)?.toInt() ?? 0;
                return _ConversationTile(
                  worker: worker,
                  name: name,
                  // The same karigar can have one chat per job.
                  job: job,
                  preview: '${last['body'] ?? 'Start chatting'}',
                  time: shortAgo('${last['created_ago'] ?? ''}'),
                  unread: unread,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          worker: worker,
                          conversationId: (item['id'] as num?)?.toInt(),
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                );
              },
            ),
          ),
  );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.worker,
    required this.name,
    this.job = '',
    required this.preview,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  final Worker worker;
  final String name, job, preview, time;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: unread > 0
          ? colors.primary.withValues(alpha: .16)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  worker.initials,
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread > 0
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                    if (job.isNotEmpty)
                      Text(
                        job,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.brandDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread > 0
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 62,
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
                    const SizedBox(height: 7),
                    if (unread > 0)
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 19,
                          minHeight: 19,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
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
