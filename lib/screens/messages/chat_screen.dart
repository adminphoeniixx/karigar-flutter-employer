import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.worker});
  final Worker worker;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final messages = <String>[
    'Hello, are you available for plumbing work?',
    'Yes sir, I can join tomorrow.',
    'Great. Please reach the site by 9 AM.',
  ];
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
          Column(
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
              final me = i.isEven;
              return Align(
                alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: me ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: me ? null : Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    messages[i],
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
                          onPressed: () => setState(() => messages.add(e)),
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
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      setState(() => messages.add(controller.text.trim()));
                      controller.clear();
                    }
                  },
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
