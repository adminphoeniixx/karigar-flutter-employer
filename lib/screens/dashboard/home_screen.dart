import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/dashboard/main_shell.dart';
import 'package:employer_kariger_app/screens/jobs/job_manage_screen.dart';
import 'package:employer_kariger_app/screens/jobs/jobs_screen.dart';
import 'package:employer_kariger_app/screens/jobs/post_job_screen.dart';
import 'package:employer_kariger_app/screens/messages/messages_screen.dart';
import 'package:employer_kariger_app/screens/profile/kyc_screen.dart';
import 'package:employer_kariger_app/screens/profile/plans_screen.dart';
import 'package:employer_kariger_app/screens/workers/worker_profile_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final controller = AppScope.of(context).dashboard;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      controller.addListener(_refresh);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.load();
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _applicantAction(int applicantId, String action) async {
    try {
      final api = AppScope.of(context).api;
      if (action == 'unlock') {
        await api.unlock(applicantId);
        _message('Contact unlocked.');
      } else if (action == 'shortlist') {
        await api.shortlist(applicantId);
        _message('Applicant shortlisted.');
      } else if (action == 'interview') {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time == null || !mounted) return;
        final at = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        await api.scheduleInterview(
          applicantId,
          interviewAt: at.toIso8601String(),
          mode: 'site',
        );
        _message('Interview invitation sent.');
      } else if (action == 'hire') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hire applicant?'),
            content: const Text('The worker will receive your hire offer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send offer'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await api.applicantStatus(applicantId, 'accepted');
        _message('Hire offer sent.');
      } else if (action == 'reject') {
        await api.applicantStatus(applicantId, 'rejected');
        _message('Applicant rejected.');
      }
      await controller.load();
    } catch (exception) {
      _message('$exception');
    }
  }

  @override
  void dispose() {
    if (_loaded) controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final stats = data?.stats ?? const <String, dynamic>{};
    final greeting = data?.greeting.isNotEmpty == true
        ? data!.greeting
        : 'Your business';
    final initials = greeting
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 9, bottom: 9),
          child: CircleAvatar(
            backgroundColor: AppColors.brand100,
            child: Text(
              initials.isEmpty ? 'K' : initials,
              style: const TextStyle(
                color: AppColors.brandDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back \u{1F44B}',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              greeting,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          _HeaderAction(
            icon: LucideIcons.messageSquare,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            ),
          ),
          _HeaderAction(
            icon: LucideIcons.bell,
            onTap: () => openNotifications(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _PostJobBanner(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostJobScreen()),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.briefcaseBusiness,
                  value: '${stats['active_jobs'] ?? 0}',
                  label: 'Active Jobs',
                  iconColor: AppColors.primary,
                  iconBackground: AppColors.brand50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.usersRound,
                  value: '${stats['total_applicants'] ?? 0}',
                  label: 'Total Applicants',
                  iconColor: AppColors.indigo,
                  iconBackground: AppColors.indigoBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.star,
                  value: '${stats['shortlisted'] ?? 0}',
                  label: 'Shortlisted',
                  iconColor: AppColors.amber,
                  iconBackground: AppColors.amberBg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.check,
                  value: '${stats['hired'] ?? 0}',
                  label: 'Hired',
                  iconColor: AppColors.green,
                  iconBackground: AppColors.greenBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CreditsCard(
            balance: data?.credits.balance ?? 0,
            label: data?.credits.planLabel ?? '',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlansScreen()),
            ),
          ),
          if (data?.verificationEnabled == true &&
              data?.profile?.verified != true) ...[
            const SizedBox(height: 16),
            _VerifyCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KycScreen()),
              ),
            ),
          ],
          const SizedBox(height: 22),
          _ListHeading(
            'Recent applicants',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JobsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ...(data?.applicants ?? const []).map((applicant) {
            final profile = applicant.worker;
            final worker = Worker(
              profile.name,
              profile.skills.isEmpty ? 'Worker' : profile.skills.first,
              profile.experienceYears,
              profile.rating.average,
              profile.distanceKm ?? 0,
              profile.expectedWage,
              profile.skills,
              status: applicant.statusLabel,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ApplicantCard(
                worker: worker,
                displayName: profile.name,
                status: applicant.statusLabel,
                skills: profile.skills,
                contactUnlocked: applicant.contactUnlocked,
                onUnlock: () => _applicantAction(applicant.id, 'unlock'),
                onPrimary: () => _applicantAction(
                  applicant.id,
                  applicant.shortlisted ? 'interview' : 'shortlist',
                ),
                onHire: () => _applicantAction(applicant.id, 'hire'),
                onReject: () => _applicantAction(applicant.id, 'reject'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerProfileScreen(worker: worker),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 22),
          _ListHeading(
            'Your active jobs',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JobsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ...(data?.jobs ?? const []).take(2).map((item) {
            final job = Job(
              item.title,
              item.category,
              item.wageLabel,
              item.vacancies,
              item.stats['applicants'] as int? ?? 0,
              item.stats['shortlisted'] as int? ?? 0,
              item.stats['hired'] as int? ?? 0,
              item.status,
              id: item.id,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: jobCard(
                job,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => JobManageScreen(job: job)),
                ),
              ),
            );
          }),
          if (controller.loading && data == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Stack(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21),
          ),
        ),
        Positioned(
          top: 7,
          right: 7,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PostJobBanner extends StatelessWidget {
  const _PostJobBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.brandDark],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;
        final copy = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hiring today?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Post a job free — reach workers instantly',
              style: TextStyle(color: Colors.white, fontSize: 11.5),
            ),
          ],
        );
        final button = SizedBox(
          height: 42,
          child: FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: Size.zero,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(LucideIcons.plus, size: 19),
            label: const Text('Post Job'),
          ),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 12), button],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            button,
          ],
        );
      },
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.iconBackground,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 120),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({
    required this.balance,
    required this.label,
    required this.onTap,
  });
  final int balance;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              LucideIcons.layers,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$balance contact credits',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label.isEmpty ? 'Unlock worker numbers' : label,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size(54, 38),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Text('Buy'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _VerifyCard extends StatelessWidget {
  const _VerifyCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.brand50,
      border: Border.all(color: AppColors.brand200),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get the Verified badge',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 3),
              Text(
                'Verified employers get 3x more applicants',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Verify'),
          ),
        ),
      ],
    ),
  );
}

class _ListHeading extends StatelessWidget {
  const _ListHeading(this.title, {required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
      ),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(60, 32),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'See all →',
          style: TextStyle(color: AppColors.primary, fontSize: 12),
        ),
      ),
    ],
  );
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.worker,
    required this.displayName,
    required this.status,
    required this.skills,
    required this.contactUnlocked,
    required this.onUnlock,
    required this.onPrimary,
    required this.onHire,
    required this.onReject,
    required this.onTap,
  });
  final Worker worker;
  final String displayName;
  final String status;
  final List<String> skills;
  final bool contactUnlocked;
  final VoidCallback onUnlock, onPrimary, onHire, onReject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.brand100,
                  child: Text(
                    displayName.split(' ').map((e) => e[0]).take(2).join(),
                    style: const TextStyle(
                      color: AppColors.brandDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            LucideIcons.badgeCheck,
                            size: 15,
                            color: AppColors.green,
                          ),
                        ],
                      ),
                      Text(
                        '${worker.trade} · ${worker.experience} yrs exp · ★ ${worker.rating}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⌖ ${worker.distance} km   ₹${worker.wage}/day',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'Shortlisted'
                        ? AppColors.indigoBg
                        : AppColors.amberBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: status == 'Shortlisted'
                          ? AppColors.indigo
                          : AppColors.amber,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 7,
                children: skills
                    .map((e) => BrandChip(e, neutral: true))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: contactUnlocked ? null : onUnlock,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: contactUnlocked
                      ? AppColors.greenBg
                      : AppColors.brand50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      contactUnlocked
                          ? LucideIcons.lockOpen
                          : LucideIcons.lockKeyhole,
                      size: 16,
                      color: contactUnlocked
                          ? AppColors.green
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      contactUnlocked
                          ? 'Contact unlocked'
                          : 'View contact · 1 credit',
                      style: const TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrimary,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: Icon(
                      status == 'Shortlisted'
                          ? LucideIcons.calendarDays
                          : LucideIcons.star,
                      size: 16,
                    ),
                    label: Text(
                      status == 'Shortlisted' ? 'Interview' : 'Shortlist',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onHire,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                    ),
                    child: const Text('Hire'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      padding: EdgeInsets.zero,
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Icon(LucideIcons.x, size: 17),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget jobCard(Job job, VoidCallback onTap) => Card(
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [BrandChip(job.category), StatusPill(job.status)],
          ),
          const SizedBox(height: 8),
          Text(
            job.title,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            '${job.wage} · ${job.openings} openings · 2 days ago',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                LucideIcons.userRound,
                size: 15,
                color: AppColors.indigo,
              ),
              const SizedBox(width: 5),
              Text(
                '${job.applied} applied',
                style: const TextStyle(fontSize: 11.5),
              ),
              const SizedBox(width: 12),
              const Icon(LucideIcons.star, size: 15, color: AppColors.amber),
              const SizedBox(width: 5),
              Text(
                '${job.shortlisted} shortlisted',
                style: const TextStyle(fontSize: 11.5),
              ),
              const SizedBox(width: 12),
              const Icon(LucideIcons.check, size: 15, color: AppColors.green),
              const SizedBox(width: 5),
              Text(
                '${job.hired} hired',
                style: const TextStyle(fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
