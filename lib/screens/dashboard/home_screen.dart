import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/dashboard/main_shell.dart';
import 'package:employer_kariger_app/screens/jobs/job_manage_screen.dart';
import 'package:employer_kariger_app/screens/jobs/post_job_screen.dart';
import 'package:employer_kariger_app/screens/messages/messages_screen.dart';
import 'package:employer_kariger_app/screens/workers/worker_profile_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 58,
      leadingWidth: 58,
      leading: const Padding(
        padding: EdgeInsets.only(left: 16, top: 9, bottom: 9),
        child: CircleAvatar(
          backgroundColor: AppColors.brand100,
          child: Text(
            'SS',
            style: TextStyle(
              color: AppColors.brandDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      titleSpacing: 8,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back \u{1F44B}',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.muted,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            'Sri Sai Constructions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
        const Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: LucideIcons.briefcaseBusiness,
                value: '4',
                label: 'Active Jobs',
                iconColor: AppColors.primary,
                iconBackground: AppColors.brand50,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: LucideIcons.usersRound,
                value: '37',
                label: 'Total Applicants',
                iconColor: AppColors.indigo,
                iconBackground: AppColors.indigoBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: LucideIcons.star,
                value: '9',
                label: 'Shortlisted',
                iconColor: AppColors.amber,
                iconBackground: AppColors.amberBg,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: LucideIcons.check,
                value: '5',
                label: 'Hired',
                iconColor: AppColors.green,
                iconBackground: AppColors.greenBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _CreditsCard(),
        const SizedBox(height: 16),
        const _VerifyCard(),
        const SizedBox(height: 22),
        const _ListHeading('Recent applicants'),
        const SizedBox(height: 12),
        _ApplicantCard(
          worker: workers[0],
          displayName: 'Rakesh Kumar',
          status: 'Shortlisted',
          skills: const ['Plumbing', 'Pipe Fitting', 'Waterproofing'],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerProfileScreen(worker: workers[0]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ApplicantCard(
          worker: workers[2],
          displayName: 'Suresh Babu',
          status: 'Pending',
          skills: const ['Plumbing', 'Drainage', 'Testing'],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerProfileScreen(worker: workers[2]),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _ListHeading('Your active jobs'),
        const SizedBox(height: 12),
        ...jobs.take(2).map(
          (job) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: jobCard(
              job,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => JobManageScreen(job: job)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
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
    child: Row(
      children: [
        const Expanded(
          child: Column(
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
                'Post a job free — reach workers\ninstantly',
                style: TextStyle(color: Colors.white, fontSize: 11.5),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 118,
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
        ),
      ],
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
    height: 120,
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
        const Spacer(),
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
  const _CreditsCard();

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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '12 contact credits',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Free plan · unlock worker numbers',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: AppColors.primary,
                disabledForegroundColor: Colors.white,
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
  const _VerifyCard();

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
            onPressed: null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: AppColors.primary,
              disabledForegroundColor: Colors.white,
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
  const _ListHeading(this.title);
  final String title;

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
      const Text(
        'See all →',
        style: TextStyle(color: AppColors.primary, fontSize: 12),
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
    required this.onTap,
  });
  final Worker worker;
  final String displayName;
  final String status;
  final List<String> skills;
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
                children: skills.map((e) => BrandChip(e, neutral: true)).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.brand50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.lockKeyhole,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'View contact · 1 credit',
                    style: TextStyle(
                      color: AppColors.brandDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
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
                    onPressed: () {},
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
                    onPressed: () {},
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
              const Icon(LucideIcons.userRound, size: 15, color: AppColors.indigo),
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
              Text('${job.hired} hired', style: const TextStyle(fontSize: 11.5)),
            ],
          ),
        ],
      ),
    ),
  ),
);
