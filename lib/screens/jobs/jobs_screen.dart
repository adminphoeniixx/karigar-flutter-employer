import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/app_strings.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/jobs/job_manage_screen.dart';
import 'package:employer_kariger_app/screens/jobs/post_job_screen.dart';
import 'package:employer_kariger_app/screens/jobs/ai_interviews_screen.dart';
import 'package:employer_kariger_app/screens/jobs/ai_credits_screen.dart';

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
              job.moderation?['status'] == 'pending'
                  ? 'Under review'
                  : job.moderation?['status'] == 'rejected'
                  ? 'Not approved'
                  : job.status.isEmpty
                  ? ''
                  : '${job.status[0].toUpperCase()}${job.status.substring(1)}',
              id: job.id,
              moderationNote: job.moderation?['note']?.toString(),
            ),
          )
          .toList();
      return _content(context, liveJobs);
    },
  );

  Future<void> _openJob(Job job) async {
    try {
      final draft = job.status.toLowerCase() == 'draft'
          ? await AppScope.of(context).api.job(job.id)
          : null;
      if (!mounted) return;
      final result = await Navigator.push<Object?>(
        context,
        MaterialPageRoute(
          builder: (_) => draft == null
              ? JobManageScreen(job: job)
              : PostJobScreen(job: draft),
        ),
      );
      // A closed job is already removed from the shared controller by the
      // manage screen. Avoid immediately fetching the possibly stale active
      // endpoint, which could otherwise put it back until an app restart.
      if (result == true && mounted) await controller.load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  Widget _content(BuildContext context, List<Job> liveJobs) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('My Jobs')),
      actions: [
        IconButton(
          tooltip: 'AI Interviews',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiInterviewsScreen()),
          ),
          icon: const Icon(LucideIcons.botMessageSquare),
        ),
        IconButton(
          tooltip: 'AI Credits',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiCreditsScreen()),
          ),
          icon: const Icon(LucideIcons.walletCards),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: !controller.hasLoaded || (controller.loading && liveJobs.isEmpty)
        ? const Center(child: CircularProgressIndicator())
        : controller.error != null && liveJobs.isEmpty
        ? _JobsMessage(
            text: controller.error!,
            onRetry: () => controller.load(),
          )
        : RefreshIndicator(
            onRefresh: () => controller.load(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _JobsHeader(
                    count: liveJobs.length,
                    status: controller.status,
                    onStatusChanged: (status) =>
                        controller.load(nextStatus: status),
                    onPostJob: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PostJobScreen(),
                        ),
                      );
                      if (created == true && mounted) await controller.load();
                    },
                  ),
                ),
                if (liveJobs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyJobs(status: controller.status),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    sliver: SliverList.separated(
                      itemCount: liveJobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _JobListCard(
                        job: liveJobs[index],
                        onTap: () => _openJob(liveJobs[index]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class _JobsHeader extends StatelessWidget {
  const _JobsHeader({
    required this.count,
    required this.status,
    required this.onStatusChanged,
    required this.onPostJob,
  });

  final int count;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onPostJob;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandDark, AppColors.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x334F1B0D),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MY JOBS',
                      style: TextStyle(
                        color: Color(0xFFFBECE5),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      count == 0
                          ? 'Start hiring skilled workers'
                          : '$count ${count == 1 ? 'job listing' : 'job listings'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Review applicants and manage each posting.',
                      style: TextStyle(
                        color: Color(0xFFFBECE5),
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x40FFFFFF)),
                ),
                child: const Icon(
                  LucideIcons.briefcaseBusiness,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'JOB LISTINGS',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
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
                    status == tab.key,
                    onTap: () => onStatusChanged(tab.key),
                  ),
                ),
            ],
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x3DBF3A16),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _JobListCard extends StatelessWidget {
  const _JobListCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = job.status.toLowerCase();
    final statusColor = switch (status) {
      'active' => AppColors.green,
      'draft' => AppColors.indigo,
      'under review' => AppColors.amber,
      'not approved' => AppColors.rose,
      _ => AppColors.muted,
    };
    final statusBackground = switch (status) {
      'active' => AppColors.greenBg,
      'draft' => AppColors.indigoBg,
      'under review' => AppColors.amberBg,
      'not approved' => AppColors.roseBg,
      _ => Theme.of(context).colorScheme.surfaceContainerHighest,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 16, 15, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.category.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        job.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 8, 15, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 19,
                      color: AppColors.muted2,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 11, 15, 0),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _JobDetail(icon: LucideIcons.indianRupee, label: job.wage),
                    _JobDetail(
                      icon: LucideIcons.briefcaseBusiness,
                      label:
                          '${job.openings} opening${job.openings == 1 ? '' : 's'}',
                    ),
                  ],
                ),
              ),
              if (job.moderationNote?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 11),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  child: Text(
                    job.moderationNote!,
                    style: const TextStyle(fontSize: 12, color: AppColors.rose),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(17, 12, 17, 13),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F5F0),
                  border: Border(top: BorderSide(color: AppColors.line2)),
                ),
                child: Row(
                  children: [
                    _JobMetric(value: job.applied, label: 'Applicants'),
                    const _MetricDivider(),
                    _JobMetric(value: job.shortlisted, label: 'Shortlisted'),
                    const _MetricDivider(),
                    _JobMetric(value: job.hired, label: 'Hired'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobDetail extends StatelessWidget {
  const _JobDetail({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.muted),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
      ),
    ],
  );
}

class _JobMetric extends StatelessWidget {
  const _JobMetric({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.only(right: 12),
    color: AppColors.line,
  );
}

class _EmptyJobs extends StatelessWidget {
  const _EmptyJobs({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      'draft' => 'Your saved job drafts will appear here.',
      'closed' => 'Closed job listings will appear here.',
      _ => 'Post a job to start receiving applications from skilled workers.',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 88, left: 36, right: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.brand100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.briefcaseBusiness,
              color: AppColors.brandDark,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing to show',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
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
          OutlinedButton(onPressed: onRetry, child: Text(context.tr('Retry'))),
        ],
      ),
    ),
  );
}
