import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/workers/worker_profile_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class JobManageScreen extends StatefulWidget {
  const JobManageScreen({super.key, required this.job});
  final Job job;

  @override
  State<JobManageScreen> createState() => _JobManageScreenState();
}

class _JobManageScreenState extends State<JobManageScreen> {
  bool loading = true;
  String? error;
  List<Applicant> applicants = const [];

  Job get job => widget.job;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && applicants.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    if (job.id == 0) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.applicants(job.id);
      final rows = response['data'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        applicants = rows
            .whereType<Map>()
            .map((item) => Applicant.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _shortlist(Applicant applicant) async {
    try {
      await AppScope.of(context).api.shortlist(applicant.id);
      await _load();
    } catch (exception) {
      _message('$exception');
    }
  }

  Future<void> _reject(Applicant applicant) async {
    try {
      await AppScope.of(context).api.applicantStatus(applicant.id, 'rejected');
      await _load();
    } catch (exception) {
      _message('$exception');
    }
  }

  Future<void> _hire(Applicant applicant) async {
    final wage = TextEditingController(
      text: applicant.expectedWage?.toStringAsFixed(0) ?? '',
    );
    DateTime? startDate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Hire ${applicant.worker.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Offered wage'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (value != null) {
                    setDialogState(() => startDate = value);
                  }
                },
                icon: const Icon(LucideIcons.calendarDays),
                label: Text(
                  startDate == null
                      ? 'Select start date'
                      : _dateValue(startDate!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: startDate == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Send offer'),
            ),
          ],
        ),
      ),
    );
    final offeredWage = num.tryParse(wage.text);
    wage.dispose();
    if (confirmed != true || startDate == null) return;
    try {
      await AppScope.of(context).api.applicantStatus(
        applicant.id,
        'accepted',
        offeredWage: offeredWage,
        startDate: _dateValue(startDate!),
      );
      await _load();
      _message('Hire offer sent.');
    } catch (exception) {
      _message('$exception');
    }
  }

  Future<void> _interview(Applicant applicant) async {
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
    try {
      await AppScope.of(context).api.scheduleInterview(
        applicant.id,
        interviewAt: at.toIso8601String(),
        mode: 'site',
      );
      await _load();
      _message('Interview invitation sent.');
    } catch (exception) {
      _message('$exception');
    }
  }

  Future<void> _unlock(Applicant applicant) async {
    try {
      await AppScope.of(context).api.unlock(applicant.id);
      await _load();
      _message('Contact unlocked.');
    } catch (exception) {
      _message('$exception');
    }
  }

  String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _jobActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.zap),
              title: const Text('Boost job'),
              onTap: () => Navigator.pop(context, 'boost'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.share2),
              title: const Text('Copy share link'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
            if (job.status.toLowerCase() != 'closed')
              ListTile(
                leading: const Icon(LucideIcons.circleX, color: Colors.red),
                title: const Text(
                  'Close job',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, 'close'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'boost') {
        await AppScope.of(context).api.boostJob(job.id, 'standard');
        _message('Job boosted.');
      } else if (action == 'share') {
        final details = await AppScope.of(context).api.job(job.id);
        if (details.shareUrl.isEmpty) {
          _message('Share link is not available.');
        } else {
          await Clipboard.setData(ClipboardData(text: details.shareUrl));
          _message('Share link copied.');
        }
      } else if (action == 'close') {
        await AppScope.of(context).api.closeJob(job.id);
        _message('Job closed.');
        if (mounted) Navigator.pop(context, true);
      }
    } catch (exception) {
      _message('$exception');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Manage Job'),
      actions: [
        IconButton(
          onPressed: job.id == 0 ? null : _jobActions,
          icon: const Icon(LucideIcons.ellipsisVertical),
        ),
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
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          OutlinedButton(onPressed: _load, child: const Text('Retry'))
        else if (applicants.isEmpty)
          const Text(
            'No applicants yet',
            style: TextStyle(color: AppColors.muted),
          )
        else
          ...applicants.map((applicant) {
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
              child: Column(
                children: [
                  WorkerCard(
                    worker: worker,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkerProfileScreen(worker: worker),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!applicant.contactUnlocked)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _unlock(applicant),
                        icon: const Icon(LucideIcons.lockOpen, size: 17),
                        label: const Text('Unlock contact · 1 credit'),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              applicant.stage == 'shortlisted' ||
                                  applicant.stage == 'interview'
                              ? () => _interview(applicant)
                              : () => _shortlist(applicant),
                          child: Text(
                            applicant.stage == 'interview'
                                ? 'Reschedule'
                                : applicant.stage == 'shortlisted'
                                ? 'Interview'
                                : 'Shortlist',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: applicant.stage == 'hired'
                              ? null
                              : () => _hire(applicant),
                          child: Text(
                            applicant.stage == 'hired' ? 'Hired' : 'Hire',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        onPressed: applicant.stage == 'rejected'
                            ? null
                            : () => _reject(applicant),
                        color: Colors.red,
                        icon: const Icon(LucideIcons.x, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    ),
  );
}
