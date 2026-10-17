import 'package:flutter/material.dart' hide Text;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../widgets/localized_text.dart';

class AiCreditsSuccessScreen extends StatelessWidget {
  const AiCreditsSuccessScreen({
    super.key,
    required this.message,
    required this.credits,
  });

  final String message;
  final Map<String, dynamic> credits;

  @override
  Widget build(BuildContext context) {
    final balance = credits['balance'];
    final minutes = credits['minutes'];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              const Spacer(),
              Container(
                width: 98,
                height: 98,
                decoration: const BoxDecoration(
                  color: AppColors.greenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.circleCheckBig,
                  color: AppColors.green,
                  size: 54,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Credits added!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              if (balance != null) ...[
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.brand50,
                    border: Border.all(color: AppColors.brand200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR NEW BALANCE',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$balance credits',
                        style: const TextStyle(
                          color: AppColors.brandDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (minutes != null)
                        Text(
                          'about $minutes min of calling',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Your GST invoice will be sent to your billing email.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.walletCards, size: 18),
                  label: const Text('View AI credits'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
