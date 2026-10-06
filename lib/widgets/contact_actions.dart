import 'package:flutter/material.dart' hide Text;
import 'localized_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_exception.dart';
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
  const ContactActions({super.key, this.phone, this.email});
  final String? phone, email;
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
      ],
    );
  }
}
