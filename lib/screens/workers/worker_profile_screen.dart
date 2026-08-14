import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/messages/chat_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key, required this.worker});
  final Worker worker;
  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  bool unlocked = false;
  @override
  Widget build(BuildContext context) {
    final w = widget.worker;
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Profile')),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.gradientEnd],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 33,
                      backgroundColor: AppColors.brand100,
                      child: Text(
                        w.initials,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${w.trade} · ${w.experience} yrs experience',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '⌖ Gurugram · ${w.distance} km   ★ ${w.rating}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const StatusPill('Verified'),
                    const BrandChip('● Available'),
                    BrandChip('₹${w.wage}/day'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.brand50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.phone,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phone number',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                              Text(
                                unlocked
                                    ? '+91 98765 43210'
                                    : '+91 98765 •••••',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => unlocked = true),
                          child: Text(
                            unlocked ? 'Unlocked' : 'Unlock · 1 credit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionTitle('About'),
                const Text(
                  'Experienced and reliable professional with a strong record of neat, on-time work across residential and commercial sites.',
                  style: TextStyle(fontSize: 14.5, height: 1.55),
                ),
                const SectionTitle('Skills'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: w.skills.map(BrandChip.new).toList(),
                ),
                const SectionTitle('Languages'),
                const Wrap(
                  spacing: 8,
                  children: [
                    BrandChip('Hindi', neutral: true),
                    BrandChip('English', neutral: true),
                  ],
                ),
                const SectionTitle('Recent ratings'),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kumar Interiors',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '★★★★★',
                              style: TextStyle(color: Color(0xFFFBBF24)),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Neat work and finished ahead of time. Reliable.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(worker: w),
                          ),
                        ),
                        icon: const Icon(LucideIcons.messageCircle),
                        label: const Text('Message'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => setState(() => unlocked = true),
                        icon: const Icon(LucideIcons.phone),
                        label: const Text('Call'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
