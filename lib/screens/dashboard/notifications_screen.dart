import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton(onPressed: () {}, child: const Text('Mark all read')),
      ],
    ),
    body: ListView(
      children: const [
        _Notification(
          'New application received',
          'Ramesh Kumar applied for your Plumber job.',
          '5 min ago',
          true,
          LucideIcons.userPlus,
        ),
        _Notification(
          'Worker shortlisted',
          'Suresh Yadav was moved to shortlisted.',
          '1 hour ago',
          true,
          LucideIcons.star,
        ),
        _Notification(
          'Job is performing well',
          'Your job received 42 views today.',
          '3 hours ago',
          true,
          LucideIcons.trendingUp,
        ),
        _Notification(
          'Hire accepted',
          'Arjun Singh accepted your hire offer.',
          'Yesterday',
          false,
          LucideIcons.circleCheck,
        ),
      ],
    ),
  );
}

class _Notification extends StatelessWidget {
  const _Notification(
    this.title,
    this.message,
    this.time,
    this.unread,
    this.icon,
  );
  final String title, message, time;
  final bool unread;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    color: unread ? AppColors.brand50 : Colors.white,
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 5),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: AppColors.muted2),
              ),
            ],
          ),
        ),
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
  );
}
