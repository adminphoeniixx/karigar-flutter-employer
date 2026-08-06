import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business Verification')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.greenBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    LucideIcons.shieldCheck,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Build trust with workers',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Verified employers get 3x more applications and rank higher in search.',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Business information'),
        const LabeledField(
          'Legal business name',
          hint: 'Sharma Construction Co.',
        ),
        const LabeledField('GSTIN (optional)', hint: '22AAAAA0000A1Z5'),
        const LabeledField('PAN number', hint: 'ABCDE1234F'),
        const SectionTitle('Documents'),
        const _Upload('PAN card'),
        const SizedBox(height: 10),
        const _Upload('Business proof / GST certificate'),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Submit for Verification'),
        ),
      ],
    ),
  );
}

class _Upload extends StatelessWidget {
  const _Upload(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(LucideIcons.upload, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Text(
            'Upload',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
