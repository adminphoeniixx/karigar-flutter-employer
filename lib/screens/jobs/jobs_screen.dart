import 'dart:async';
import 'package:employer_kariger_app/core/api/api_exception.dart';

import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import '../../widgets/job_summary_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/push/push_router.dart';
import 'package:employer_kariger_app/models/api_models.dart' show asInt;
import 'package:employer_kariger_app/core/app_strings.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/jobs/job_manage_screen.dart';
import 'package:employer_kariger_app/screens/jobs/post_job_screen.dart';
import 'package:employer_kariger_app/screens/jobs/ai_interviews_screen.dart';
import 'package:employer_kariger_app/screens/jobs/ai_credits_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  /// While a new job is in the safety check ("Checking"), the list asks the
  /// server this often whether it went live.
  static const checkEvery = Duration(seconds: 5);

  /// The check takes a minute or two. If a job is still "Checking" after this
  /// long, stop asking (the check queue may be stuck) until the employer comes
  /// back to the list or pulls to refresh.
  static const checkFor = Duration(minutes: 3);

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> with WidgetsBindingObserver {
  late final controller = AppScope.of(context).jobs;
  Timer? _checkingRefresh;
  bool _listeningToJobs = false;

  /// Checks left in the current window; null until a job is "Checking".
  int? _checksLeft;
  bool _onScreen = true;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_listeningToJobs) controller.removeListener(_syncCheckingRefresh);
    _checkingRefresh?.cancel();
    super.dispose();
  }

  bool get _hasCheckingJob => controller.items.any(
    (job) => job.moderation?['status']?.toString() == 'checking',
  );

  static final _checksPerWindow =
      JobsScreen.checkFor.inSeconds ~/ JobsScreen.checkEvery.inSeconds;

  bool get _checkTimedOut => (_checksLeft ?? 1) <= 0;

  void _stopChecking() {
    _checkingRefresh?.cancel();
    _checkingRefresh = null;
  }

  /// Asks again only while a job is "Checking", this list is the screen the
  /// employer is looking at (not a hidden tab, not under another page) and
  /// the app is open, and for at most [JobsScreen.checkFor].
  void _syncCheckingRefresh() {
    if (!_hasCheckingJob) {
      _checksLeft = null;
      _stopChecking();
      return;
    }
    _checksLeft ??= _checksPerWindow;
    if (!_onScreen || !_appActive || _checkTimedOut) {
      _stopChecking();
      return;
    }
    _checkingRefresh ??= Timer.periodic(JobsScreen.checkEvery, (_) {
      if (_checkTimedOut) return _stopChecking();
      _checksLeft = _checksLeft! - 1;
      if (mounted && !controller.loading) controller.load();
    });
  }

  /// Back on the list (its tab shown again, or the app reopened). Load again
  /// when the last load failed (it may have run offline, before the internet
  /// came back) or a job is still "Checking", which also gets a fresh window.
  void _cameBack() {
    final checking = _hasCheckingJob;
    if (checking) _checksLeft = _checksPerWindow;
    if ((checking || controller.error != null) && !controller.loading) {
      controller.load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (active && _onScreen) _cameBack();
    _syncCheckingRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A tab of the bottom bar stays alive while hidden, and this list can be
    // covered by a page pushed over it: neither should keep asking.
    final onScreen =
        Visibility.of(context) && (ModalRoute.isCurrentOf(context) ?? true);
    if (onScreen != _onScreen) {
      _onScreen = onScreen;
      if (onScreen && _appActive) _cameBack();
    }
    if (!_listeningToJobs) {
      controller.addListener(_syncCheckingRefresh);
      _listeningToJobs = true;
    }
    _syncCheckingRefresh();
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
    // The dashboard says whether the plan has run out (jobs shown as paused).
    listenable: Listenable.merge([controller, AppScope.of(context).dashboard]),
    builder: (context, _) {
      // While the job plan has run out, live jobs are hidden from karigars.
      final paused = AppScope.of(context).dashboard.data?.hiringPaused ?? false;
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
              paused && jobStatusLabel(job) == 'Active'
                  ? 'Paused'
                  : jobStatusLabel(job),
              id: job.id,
              views: asInt(job.stats['views']),
              moderationNote: job.moderation?['note']?.toString(),
              moderationStatus: job.moderation?['status']?.toString(),
              moderationMethod: job.moderation?['method']?.toString(),
              workModeLabel: job.workModeLabel,
              interviewModeLabel: job.interviewModeLabel,
            ),
          )
          .toList();
      return _content(context, liveJobs);
    },
  );

  Future<void> _openJob(Job job) async {
    if (job.moderationStatus == 'checking') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This job is being checked right now. Please try again in a minute.',
          ),
        ),
      );
      return;
    }
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
      if (result == JobPostResult.checking && mounted) {
        await controller.load(nextStatus: 'draft');
      } else if (result == true && mounted) {
        await controller.load();
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorText(exception))));
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
            onRefresh: () async {
              // A pull also restarts the wait for a job that is "Checking".
              if (_hasCheckingJob) _checksLeft = _checksPerWindow;
              await controller.load();
              // The list stays as it was; say the refresh failed (offline
              // used to fail without a word).
              if (context.mounted && controller.error != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(controller.error!)));
              }
            },
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
                      final created = await Navigator.push<Object?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PostJobScreen(),
                        ),
                      );
                      if (created == JobPostResult.checking && mounted) {
                        await controller.load(nextStatus: 'draft');
                      } else if (created == true && mounted) {
                        await controller.load();
                      }
                    },
                  ),
                ),
                if ((AppScope.of(context).dashboard.data?.hiringPaused ??
                        false) &&
                    controller.status == 'active')
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _PausedNote(),
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
                      itemBuilder: (context, index) => JobSummaryCard(
                        job: liveJobs[index],
                        showModeration: true,
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
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandDark, AppColors.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x334F1B0D),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0x40FFFFFF)),
                ),
                child: const Icon(
                  LucideIcons.briefcaseBusiness,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        count == 0
                            ? 'Start hiring karigars'
                            : '$count ${count == 1 ? 'job listing' : 'job listings'}',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Review applicants and manage each posting.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFFBECE5),
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: onPostJob,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brandDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Post Job'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
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
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
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
            color: active
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
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

class _PausedNote extends StatelessWidget {
  const _PausedNote();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Your plan has ended, so these jobs are paused: karigars can\'t see them or apply. Renew the plan to open them again.',
        style: TextStyle(fontSize: 12.5, color: colors.onErrorContainer),
      ),
    );
  }
}
