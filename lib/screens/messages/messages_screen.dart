import 'package:flutter/material.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/messages/chat_screen.dart';

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
      setState(() {
        items = (response['data'] as List? ?? const [])
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Messages')),
    body: loading && items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && items.isEmpty
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: items.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No conversations yet')),
                      ),
                    ]
                  : items.map((item) {
                      final participant = item['participant'] is Map
                          ? Map<String, dynamic>.from(item['participant'])
                          : <String, dynamic>{};
                      final last = item['last_message'] is Map
                          ? Map<String, dynamic>.from(item['last_message'])
                          : <String, dynamic>{};
                      final name = '${participant['name'] ?? 'Worker'}';
                      final worker = Worker(
                        name,
                        'Worker',
                        0,
                        0,
                        0,
                        0,
                        const [],
                      );
                      final unread = (item['unread'] as num?)?.toInt() ?? 0;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        leading: CircleAvatar(
                          radius: 23,
                          backgroundColor: AppColors.brand100,
                          child: Text(
                            worker.initials,
                            style: const TextStyle(
                              color: AppColors.brandDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${last['body'] ?? 'Start chatting'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: SizedBox(
                          width: 72,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${last['created_ago'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                              if (unread > 0) Badge(label: Text('$unread')),
                            ],
                          ),
                        ),
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
                          _load();
                        },
                      );
                    }).toList(),
            ),
          ),
  );
}
