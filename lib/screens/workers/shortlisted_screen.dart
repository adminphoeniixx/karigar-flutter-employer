import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/workers/worker_profile_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class ShortlistedScreen extends StatefulWidget {
  const ShortlistedScreen({super.key});

  @override
  State<ShortlistedScreen> createState() => _ShortlistedScreenState();
}

class _ShortlistedScreenState extends State<ShortlistedScreen> {
  bool loading = true;
  String? error;
  List<Applicant> applicants = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && applicants.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.shortlisted();
      final rows = (response['data'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Applicant.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (mounted) setState(() => applicants = rows);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shortlisted karigars')),
    body: loading && applicants.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && applicants.isEmpty
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _ShortlistHeader(count: applicants.length),
                ),
                if (applicants.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyShortlist(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: applicants.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final applicant = applicants[index];
                        final profile = applicant.worker;
                        final worker = Worker(
                          profile.name,
                          profile.skills.isEmpty
                              ? 'Karigar'
                              : profile.skills.first,
                          profile.experienceYears,
                          profile.rating.average,
                          profile.distanceKm ?? 0,
                          profile.expectedWage,
                          profile.skills,
                          verified: profile.verified,
                          status: applicant.statusLabel,
                        );
                        return _ShortlistedWorkerCard(
                          applicant: applicant,
                          worker: worker,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkerProfileScreen(
                                worker: worker,
                                profileId: profile.id,
                                workerUserId: profile.userId,
                                jobId: (applicant.job?['id'] as num?)?.toInt(),
                                phone: profile.phone,
                                contactUnlocked: true,
                                canMessage: true,
                                alwaysShowContact: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
  );
}

class _ShortlistHeader extends StatelessWidget {
  const _ShortlistHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandDark, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAVED CANDIDATES',
                  style: TextStyle(
                    color: Color(0xFFFBECE5),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$count ${count == 1 ? 'karigar' : 'karigars'} shortlisted',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review your strongest candidates anytime.',
                  style: TextStyle(color: Color(0xFFFBECE5), fontSize: 12.5),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.star, color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

class _ShortlistedWorkerCard extends StatelessWidget {
  const _ShortlistedWorkerCard({
    required this.applicant,
    required this.worker,
    required this.onTap,
  });
  final Applicant applicant;
  final Worker worker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (applicant.job?['title'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'For ${applicant.job!['title']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (applicant.job?['title'] != null) const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: AppColors.brand100,
                  child: Text(
                    worker.initials,
                    style: const TextStyle(
                      color: AppColors.brandDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              worker.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (worker.verified)
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(
                                LucideIcons.badgeCheck,
                                color: AppColors.green,
                                size: 17,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${worker.trade} · ${worker.experience} yrs experience',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      if (worker.distance > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 13,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${worker.distance.toStringAsFixed(1)} km away',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                StatusPill(worker.status),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (worker.rating > 0)
                  _MiniTag(
                    icon: LucideIcons.star,
                    label: worker.rating.toStringAsFixed(1),
                    color: AppColors.amber,
                  ),
                if (worker.wage > 0)
                  _MiniTag(
                    icon: LucideIcons.indianRupee,
                    label: monthlyWage(worker.wage),
                    color: AppColors.green,
                  ),
              ],
            ),
            if (worker.skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(LucideIcons.sparkles, size: 13, color: AppColors.muted),
                  SizedBox(width: 5),
                  Text(
                    'Skills',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...worker.skills.take(2).map(_ShortlistSkill.new),
                  if (worker.skills.length > 2)
                    _ShortlistSkill('+${worker.skills.length - 2} more'),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _ShortlistSkill extends StatelessWidget {
  const _ShortlistSkill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyShortlist extends StatelessWidget {
  const _EmptyShortlist();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 72, left: 36, right: 36),
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
            LucideIcons.star,
            color: AppColors.brandDark,
            size: 27,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No saved karigars yet',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Shortlist promising candidates from any job to find them here later.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
      ],
    ),
  );
}
