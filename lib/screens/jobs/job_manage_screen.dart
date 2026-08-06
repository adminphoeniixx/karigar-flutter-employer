import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/workers/worker_profile_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class JobManageScreen extends StatelessWidget {
  const JobManageScreen({super.key, required this.job});
  final Job job;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Manage Job'),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(LucideIcons.ellipsisVertical)),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            BrandChip(job.category),
            const SizedBox(width: 7),
            StatusPill(job.status),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          job.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        Text(
          '${job.wage} · ${job.openings} openings · Posted 2d ago',
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SectionTitle('Performance'),
        ...[
          ('Views', 124),
          ('Applied', job.applied),
          ('Shortlisted', job.shortlisted),
          ('Interview', 3),
          ('Hired', job.hired),
        ].map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Stack(
              children: [
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.line2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (e.$2 / 124).clamp(.07, 1),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brand100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e.$1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${e.$2}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Applicants'),
        ...workers.map(
          (w) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WorkerCard(
              worker: w,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerProfileScreen(worker: w),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
