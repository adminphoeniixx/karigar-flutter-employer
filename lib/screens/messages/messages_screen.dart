import 'package:flutter/material.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/messages/chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Messages')),
    body: ListView(
      children: workers
          .take(3)
          
          .map(
            (w) => ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 7,
              ),
              leading: CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.brand100,
                child: Text(
                  w.initials,
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                w.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                w == workers.first
                    ? 'Yes sir, I can join tomorrow.'
                    : 'Thank you for the update.',
                maxLines: 1,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '10:42',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  if (w == workers.first) const Badge(label: Text('2')),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(worker: w)),
              ),
            ),
          )
          .toList(),
    ),
  );
}
