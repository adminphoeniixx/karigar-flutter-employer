import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import '../../widgets/contact_actions.dart';
import '../../widgets/common.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/app_strings.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/dashboard/main_shell.dart';
import 'package:employer_kariger_app/screens/jobs/job_manage_screen.dart';
import 'package:employer_kariger_app/screens/jobs/applicant_features_screen.dart';
import 'package:employer_kariger_app/screens/jobs/jobs_screen.dart';
import 'package:employer_kariger_app/screens/jobs/post_job_screen.dart';
import 'package:employer_kariger_app/screens/messages/messages_screen.dart';
import 'package:employer_kariger_app/screens/messages/chat_screen.dart';
import 'package:employer_kariger_app/screens/profile/kyc_screen.dart';
import 'package:employer_kariger_app/screens/profile/plans_screen.dart';
import 'package:employer_kariger_app/screens/profile/profile_screen.dart';
import 'package:employer_kariger_app/screens/workers/worker_profile_screen.dart';
import 'package:employer_kariger_app/screens/workers/shortlisted_screen.dart';
import 'package:employer_kariger_app/screens/workers/workers_screen.dart';

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

  void _openProfile() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ProfileScreen()),
  );

  Future<void> _applicantAction(int applicantId, String action) async {
    try {
      final api = AppScope.of(context).api;
      if (action == 'shortlist') {
        final response = await api.shortlist(applicantId);
        // The server decides whether an AI call is dialling, scheduled, or not
        // possible. Keep that explanation intact instead of guessing locally.
        _message('${response['message'] ?? 'Applicant shortlisted.'}');
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
            content: const Text('The karigar will receive your hire offer.'),
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
      if (mounted) await showContactError(context, exception);
    }
  }

  Future<void> _chatApplicant(Applicant applicant, Worker worker) async {
    try {
      final response = await AppScope.of(context).api.startConversation(
        workerId: applicant.worker.userId,
        jobId: (applicant.job?['id'] as num?)?.toInt(),
      );
      final conversation = response['conversation'];
      final id = conversation is Map
          ? (conversation['id'] as num?)?.toInt()
          : null;
      if (!mounted || id == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(worker: worker, conversationId: id),
        ),
      );
    } catch (exception) {
      if (mounted) _message('$exception');
    }
  }

  Future<void> _hireApplicant(Applicant applicant) async {
    final wage = TextEditingController(
      text: applicant.expectedWage?.toStringAsFixed(0) ?? '',
    );
    final message = TextEditingController();
    var startDate = DateTime.now().add(const Duration(days: 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setSheetState) => AlertDialog(
          title: Text('Hire ${applicant.worker.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly salary * (₹ / month)',
                ),
              ),
              TextField(
                controller: message,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (date != null) setSheetState(() => startDate = date);
                },
                icon: const Icon(LucideIcons.calendarDays),
                label: Text('Joining date * · ${_dateValue(startDate)}'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send offer'),
            ),
          ],
        ),
      ),
    );
    final offeredWage = num.tryParse(wage.text.trim());
    final offerMessage = message.text.trim();
    wage.dispose();
    message.dispose();
    if (confirmed != true || offeredWage == null) {
      if (confirmed == true) _message('Enter a valid monthly salary.');
      return;
    }
    if (!mounted) return;
    try {
      await AppScope.of(context).api.applicantStatus(
        applicant.id,
        'accepted',
        offeredWage: offeredWage,
        startDate: _dateValue(startDate),
        message: offerMessage.isEmpty ? null : offerMessage,
      );
      _message('Hire offer sent.');
      await controller.load();
    } catch (exception) {
      if (mounted) _message('$exception');
    }
  }

  String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

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
    final logoUrl = data?.profile?.logoUrl?.trim();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 9, bottom: 9),
          child: InkWell(
            onTap: _openProfile,
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              backgroundColor: AppColors.brand100,
              backgroundImage: logoUrl?.isNotEmpty == true
                  ? NetworkImage(logoUrl!)
                  : null,
              child: logoUrl?.isNotEmpty == true
                  ? null
                  : Text(
                      initials.isEmpty ? 'K' : initials,
                      style: const TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        titleSpacing: 8,
        title: InkWell(
          onTap: _openProfile,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Welcome back 👋'),
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
      body: !controller.hasLoaded
          ? const Center(child: CircularProgressIndicator())
          : controller.error != null && data == null
          ? Center(
              child: OutlinedButton(
                onPressed: controller.load,
                child: Text(context.tr('Retry')),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _PostJobBanner(
                  onTap: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const PostJobScreen()),
                    );
                    if (created == true && mounted) await controller.load();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: LucideIcons.briefcaseBusiness,
                        value: '${stats['active_jobs'] ?? 0}',
                        label: context.tr('Active Jobs'),
                        iconColor: AppColors.primary,
                        iconBackground: AppColors.brand50,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const JobsScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: LucideIcons.usersRound,
                        value: '${stats['total_applicants'] ?? 0}',
                        label: context.tr('Total Applicants'),
                        iconColor: AppColors.indigo,
                        iconBackground: AppColors.indigoBg,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WorkersScreen(initialTab: 2),
                          ),
                        ),
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
                        label: context.tr('Shortlisted'),
                        iconColor: AppColors.amber,
                        iconBackground: AppColors.amberBg,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ShortlistedScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: LucideIcons.check,
                        value: '${stats['hired'] ?? 0}',
                        label: context.tr('Hired'),
                        iconColor: AppColors.green,
                        iconBackground: AppColors.greenBg,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WorkersScreen(
                              initialTab: 2,
                              initialContactFilters: {'stage': 'hired'},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DatabaseCard(
                  title: (data?.database.title ?? 'Karigar Database')
                      .replaceAll('Worker', 'Karigar')
                      .replaceAll('worker', 'karigar'),
                  subtitle:
                      data?.database.subtitle ??
                      'Buy a database plan to see karigar numbers',
                  cta: data?.database.cta ?? 'Buy Database',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PlansScreen(focusDatabase: true),
                    ),
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
                  context.tr('Recent applicants'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkersScreen(initialTab: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...(data?.applicants ?? const []).map((applicant) {
                  final profile = applicant.worker;
                  final worker = Worker(
                    profile.name,
                    profile.skills.isEmpty ? 'Karigar' : profile.skills.first,
                    profile.experienceYears,
                    profile.rating.average,
                    profile.distanceKm ?? 0,
                    profile.expectedWage,
                    profile.skills,
                    status: applicant.statusLabel,
                    verified: profile.verified,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ApplicantCard(
                      worker: worker,
                      displayName: profile.name,
                      status: applicant.statusLabel,
                      stage: applicant.stage,
                      skills: profile.skills,
                      phone: profile.phone,
                      distanceLabel: profile.distanceLabel,
                      locationLabel: profile.locationLabel,
                      ai: applicant.ai,
                      screeningCall: applicant.screeningCall,
                      onChat: () => _chatApplicant(applicant, worker),
                      onPrimary: () =>
                          _applicantAction(applicant.id, 'shortlist'),
                      onHire: () => _hireApplicant(applicant),
                      onReject: () => _applicantAction(applicant.id, 'reject'),
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
                    ),
                  );
                }),
                const SizedBox(height: 22),
                _ListHeading(
                  context.tr('Your active jobs'),
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
                        MaterialPageRoute(
                          builder: (_) => JobManageScreen(job: job),
                        ),
                      ),
                    ),
                  );
                }),
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
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
                border: Border.all(color: colors.outlineVariant),
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
        colors: [AppColors.brandDark, AppColors.gradientEnd],
      ),
      borderRadius: BorderRadius.circular(22),
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
              'Post a job free — reach karigars instantly',
              style: TextStyle(color: Color(0xFFFBECE5), fontSize: 11.5),
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
              foregroundColor: AppColors.brandDark,
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
    required this.onTap,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
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
                  color: isDark
                      ? iconColor.withValues(alpha: .18)
                      : iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatabaseCard extends StatelessWidget {
  const _DatabaseCard({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });
  final String title, subtitle, cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? colors.primary.withValues(alpha: .18)
                    : AppColors.brand50,
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
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
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
                child: Text(cta),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    required this.stage,
    required this.skills,
    required this.phone,
    this.distanceLabel,
    this.locationLabel,
    this.ai,
    this.screeningCall,
    required this.onChat,
    required this.onPrimary,
    required this.onHire,
    required this.onReject,
    required this.onTap,
  });
  final Worker worker;
  final String displayName;
  final String status;
  final String stage;
  final List<String> skills;
  final String? phone;
  final String? distanceLabel, locationLabel;
  final Map<String, dynamic>? ai, screeningCall;
  final VoidCallback onChat, onPrimary, onHire, onReject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalizedStatus = stage.toLowerCase();
    final canManage = !{'hired', 'rejected'}.contains(normalizedStatus);
    final place = [
      if (distanceLabel?.trim().isNotEmpty == true) distanceLabel!.trim(),
      if (locationLabel?.trim().isNotEmpty == true) locationLabel!.trim(),
    ];
    final statusColor = normalizedStatus == 'shortlisted'
        ? AppColors.indigo
        : normalizedStatus == 'accepted' || normalizedStatus == 'hired'
        ? AppColors.green
        : normalizedStatus == 'rejected'
        ? AppColors.rose
        : AppColors.amber;
    final statusBackground = normalizedStatus == 'shortlisted'
        ? AppColors.indigoBg
        : normalizedStatus == 'accepted' || normalizedStatus == 'hired'
        ? AppColors.greenBg
        : normalizedStatus == 'rejected'
        ? AppColors.roseBg
        : AppColors.amberBg;
    final visibleSkills = skills.take(2).toList();
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isDark
                        ? colors.primary.withValues(alpha: .25)
                        : AppColors.brand100,
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
                            if (worker.verified)
                              const Icon(
                                LucideIcons.badgeCheck,
                                size: 15,
                                color: AppColors.green,
                              ),
                          ],
                        ),
                        Text(
                          [
                            worker.trade,
                            if (worker.experience > 0)
                              '${worker.experience} yrs experience',
                            if (worker.rating > 0)
                              '★ ${worker.rating.toStringAsFixed(1)}',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (place.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            place.join(' · '),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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
                  ...visibleSkills.map(_ApplicantSkill.new),
                  if (skills.length > visibleSkills.length)
                    _ApplicantSkill(
                      '+${skills.length - visibleSkills.length} more',
                    ),
                ],
              ),
              if (ai != null) ...[
                const SizedBox(height: 12),
                BrandChip(
                  'AI match ${ai?['score'] ?? 0}% · '
                  '${ai?['recommendation_label'] ?? ai?['recommendation'] ?? ''}',
                ),
              ],
              if (screeningCall != null) ...[
                const SizedBox(height: 10),
                ApplicantScreeningCallPanel(
                  call: screeningCall,
                  workerName: displayName,
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              ContactActions(
                phone: phone,
                expanded: true,
                onChat: onChat,
                compact: true,
              ),
              if (canManage) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceContainerHighest
                        : AppColors.brand50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPrimary,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(38),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            backgroundColor: colors.surface,
                          ),
                          icon: Icon(
                            normalizedStatus == 'shortlisted' ||
                                    normalizedStatus == 'interview'
                                ? LucideIcons.star
                                : LucideIcons.star,
                            size: 16,
                          ),
                          label: Text(
                            normalizedStatus == 'shortlisted' ||
                                    normalizedStatus == 'interview'
                                ? 'Shortlisted'
                                : 'Shortlist',
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
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 40,
                        child: IconButton.outlined(
                          onPressed: onReject,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 38),
                            foregroundColor: AppColors.rose,
                            side: const BorderSide(color: AppColors.line),
                          ),
                          icon: const Icon(LucideIcons.x, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicantSkill extends StatelessWidget {
  const _ApplicantSkill(this.label);
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

Widget jobCard(Job job, VoidCallback onTap) {
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
    _ => AppColors.brand50,
  };
  return Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
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
                _HomeJobDetail(icon: LucideIcons.indianRupee, label: job.wage),
                _HomeJobDetail(
                  icon: LucideIcons.briefcaseBusiness,
                  label:
                      '${job.openings} opening${job.openings == 1 ? '' : 's'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(17, 12, 17, 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F5F0),
              border: Border(top: BorderSide(color: AppColors.line2)),
            ),
            child: Row(
              children: [
                _HomeJobMetric(value: job.applied, label: 'Applicants'),
                const _HomeMetricDivider(),
                _HomeJobMetric(value: job.shortlisted, label: 'Shortlisted'),
                const _HomeMetricDivider(),
                _HomeJobMetric(value: job.hired, label: 'Hired'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomeJobDetail extends StatelessWidget {
  const _HomeJobDetail({required this.icon, required this.label});
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

class _HomeJobMetric extends StatelessWidget {
  const _HomeJobMetric({required this.value, required this.label});
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

class _HomeMetricDivider extends StatelessWidget {
  const _HomeMetricDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.only(right: 12),
    color: AppColors.line,
  );
}
