import 'package:flutter/material.dart' hide Text;
import 'localized_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_exception.dart';
import '../core/theme.dart';
import '../screens/profile/plans_screen.dart';

Future<void> showContactError(BuildContext context, Object error) async {
  if (error is ApiException &&
      (error.code == 'no_plan' || error.code == 'unlock_limit_reached')) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlansScreen(focusDatabase: true)),
    );
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(readableMessage('$error'))));
}

class ContactActions extends StatelessWidget {
  const ContactActions({
    super.key,
    this.phone,
    this.email,
    this.expanded = false,
    this.onChat,
    this.showChat = false,
    this.compact = false,
  });
  final String? phone, email;
  final bool expanded;
  final VoidCallback? onChat;
  final bool showChat;
  final bool compact;

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const ApiException(
          'No app is available to open this contact action.',
        );
      }
    } catch (error) {
      if (context.mounted) await showContactError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    var digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '91$digits';
    if (expanded && digits.isNotEmpty) {
      final actions = <_ContactActionData>[
        _ContactActionData(
          label: 'Call',
          caption: 'Phone call',
          icon: Icons.call_outlined,
          color: AppColors.primary,
          background: AppColors.brand50,
          onTap: () => _open(context, Uri(scheme: 'tel', path: '+$digits')),
        ),
        if (onChat != null || showChat)
          _ContactActionData(
            label: 'Chat',
            caption: 'In-app message',
            icon: Icons.chat_bubble_outline,
            color: AppColors.indigo,
            background: AppColors.indigoBg,
            onTap: onChat,
          ),
        _ContactActionData(
          label: 'WhatsApp',
          caption: 'Quick message',
          icon: Icons.chat_outlined,
          color: AppColors.green,
          background: AppColors.greenBg,
          onTap: () => _open(context, Uri.https('wa.me', '/$digits')),
        ),
        if (email?.trim().isNotEmpty == true)
          _ContactActionData(
            label: 'Email',
            caption: 'Send an email',
            icon: Icons.email_outlined,
            color: AppColors.amber,
            background: AppColors.amberBg,
            onTap: () => _open(context, Uri(scheme: 'mailto', path: email)),
          ),
      ];
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions
                .map(
                  (action) => SizedBox(
                    width: width,
                    child: _ContactActionTile(action: action),
                  ),
                )
                .toList(),
          );
        },
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (digits.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: () =>
                _open(context, Uri(scheme: 'tel', path: '+$digits')),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Call'),
          ),
          OutlinedButton(
            onPressed: () => _open(context, Uri.https('wa.me', '/$digits')),
            child: const Text('WhatsApp'),
          ),
        ],
        if (email?.trim().isNotEmpty == true)
          OutlinedButton.icon(
            onPressed: () => _open(context, Uri(scheme: 'mailto', path: email)),
            icon: const Icon(Icons.email_outlined, size: 18),
            label: const Text('Email'),
          ),
        if (onChat != null)
          OutlinedButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Chat'),
          ),
      ],
    );
  }
}

class _ContactActionData {
  const _ContactActionData({
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });
  final String label, caption;
  final IconData icon;
  final Color color, background;
  final VoidCallback? onTap;
}

class _ContactActionTile extends StatelessWidget {
  const _ContactActionTile({required this.action});
  final _ContactActionData action;

  @override
  Widget build(BuildContext context) => Material(
    color: action.onTap == null
        ? action.background.withValues(alpha: .52)
        : action.background,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(action.icon, size: 16, color: action.color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      color: action.color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    action.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
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
