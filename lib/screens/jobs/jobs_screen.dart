import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/dashboard/home_screen.dart';
import 'package:employer_kariger_app/screens/jobs/job_manage_screen.dart';
import 'package:employer_kariger_app/screens/jobs/post_job_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  late final controller = AppScope.of(context).jobs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controller.items.isEmpty && !controller.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.items.isEmpty && !controller.loading) {
          controller.load();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final liveJobs = controller.items
          .map(
            (job) => Job(
              job.title,
              job.category,
              job.wageLabel,
              job.vacancies,
              job.stats['applicants'] as int? ?? 0,
              job.stats['shortlisted'] as int? ?? 0,
              job.stats['hired'] as int? ?? 0,
              job.status.isEmpty
                  ? ''
                  : '${job.status[0].toUpperCase()}${job.status.substring(1)}',
              id: job.id,
            ),
          )
          .toList();
      return _content(context, liveJobs);
    },
  );

  Widget _content(BuildContext context, List<Job> liveJobs) => Scaffold(
    appBar: AppBar(
      title: const Text('My Jobs'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostJobScreen()),
            ),
            icon: const Icon(LucideIcons.plus),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.line2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final tab in const {
                'active': 'Active',
                'closed': 'Closed',
                'draft': 'Drafts',
              }.entries)
                Expanded(
                  child: _Segment(
                    tab.value,
                    controller.status == tab.key,
                    onTap: () => controller.load(nextStatus: tab.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: controller.loading && liveJobs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : controller.error != null && liveJobs.isEmpty
              ? _JobsMessage(
                  text: controller.error!,
                  onRetry: () => controller.load(),
                )
              : RefreshIndicator(
                  onRefresh: () => controller.load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: liveJobs
                        .map(
                          (j) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: jobCard(
                              j,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobManageScreen(job: j),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    ),
  );
}

class _Segment extends StatelessWidget {
  const _Segment(this.text, this.active, {required this.onTap});
  final String text;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.foreground : AppColors.muted,
        ),
      ),
    ),
  );
}

class _JobsMessage extends StatelessWidget {
  const _JobsMessage({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
