import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.worker, this.conversationId});
  final Worker worker;
  final int? conversationId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final messages = <Map<String, dynamic>>[];
  bool loading = false;
  bool sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.conversationId != null && messages.isEmpty && !loading) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.conversation(widget.conversationId!);
      final rows = response['messages'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(
            rows.whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
      });
      await AppScope.of(context).api.readConversation(widget.conversationId!);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send([String? suggested]) async {
    final body = (suggested ?? controller.text).trim();
    if (body.isEmpty || sending) return;
    if (widget.conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start the conversation from an applicant profile.'),
        ),
      );
      return;
    }
    setState(() => sending = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.sendMessage(widget.conversationId!, body);
      final message = response['message'];
      if (!mounted) return;
      setState(() {
        if (message is Map) {
          messages.add(Map<String, dynamic>.from(message));
        }
        controller.clear();
      });
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brand100,
            child: Text(
              widget.worker.initials,
              style: const TextStyle(fontSize: 11, color: AppColors.brandDark),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.worker.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Online',
                  style: TextStyle(fontSize: 11, color: AppColors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: messages.length,
            itemBuilder: (_, i) {
              final message = messages[i];
              final me = message['sent_by_me'] == true;
              return Align(
                alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                  ),
                  decoration: BoxDecoration(
                    color: me ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: me ? null : Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    '${message['body'] ?? ''}',
                    style: TextStyle(
                      color: me ? Colors.white : AppColors.foreground,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 39,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children:
                ['Can you join tomorrow?', 'Share your location', 'Call me']
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(e),
                          onPressed: sending ? null : () => _send(e),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : _send,
                  icon: const Icon(LucideIcons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
