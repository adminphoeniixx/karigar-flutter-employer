import 'post_job_screen.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import '../../widgets/contact_actions.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/jobs/applicant_features_screen.dart';
import 'package:employer_kariger_app/screens/workers/worker_profile_screen.dart';
import 'package:employer_kariger_app/screens/messages/chat_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class JobManageScreen extends StatefulWidget {
  const JobManageScreen({super.key, required this.job});
  final Job job;

  @override
  State<JobManageScreen> createState() => _JobManageScreenState();
}

class _OfferSentCard extends StatelessWidget {
  const _OfferSentCard({required this.offer});
  final Map<String, dynamic> offer;

  @override
  Widget build(BuildContext context) {
    final wage = num.tryParse('${offer['wage'] ?? ''}');
    final date = DateTime.tryParse('${offer['start_date'] ?? ''}');
    final message = offer['message']?.toString().trim();
    return Card(
      margin: const EdgeInsets.only(top: 10),
      color: AppColors.greenBg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Offer sent',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (wage != null) Text('Salary · ${monthlyWage(wage)}'),
            if (date != null)
              Text(
                'Joining · ${MaterialLocalizations.of(context).formatMediumDate(date)}',
              ),
            if (message?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(message!),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobSummaryCard extends StatelessWidget {
  const _JobSummaryCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [BrandChip(job.category), StatusPill(job.status)],
          ),
          const SizedBox(height: 11),
          Text(
            job.title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                LucideIcons.indianRupee,
                size: 15,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  job.wage,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                LucideIcons.usersRound,
                size: 15,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Text(
                '${job.openings} opening${job.openings == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _JobMetrics extends StatelessWidget {
  const _JobMetrics({required this.values});

  final List<(String, int, IconData)> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values
            .map(
              (item) => SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.$3, size: 17, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.$2}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _JobManageScreenState extends State<JobManageScreen> {
  bool loading = true;
  String? error;
  List<Applicant> applicants = const [];
  Map<String, dynamic> counts = const {};
  String stage = 'all';

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
      final response = await AppScope.of(
        context,
      ).api.applicants(job.id, stage: stage);
      final rows = response['data'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        applicants = rows
            .whereType<Map>()
            .map((item) => Applicant.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        counts = response['counts'] is Map
            ? Map<String, dynamic>.from(response['counts'])
            : const {};
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
    final api = AppScope.of(context).api;
    final wage = TextEditingController(
      text: applicant.expectedWage?.toStringAsFixed(0) ?? '',
    );
    final offerMessage = TextEditingController();
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Hire ${applicant.worker.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'For: ${job.title}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly salary * (₹ / month)',
                  hintText: 'e.g. 23400',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: offerMessage,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'Reporting time or site instructions',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (value != null) setDialogState(() => startDate = value);
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
              onPressed: () {
                if (num.tryParse(wage.text.trim()) == null ||
                    num.parse(wage.text.trim()) < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid monthly salary.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Send offer'),
            ),
          ],
        ),
      ),
    );
    final offeredWage = num.tryParse(wage.text);
    final message = offerMessage.text.trim();
    wage.dispose();
    offerMessage.dispose();
    if (confirmed != true) return;
    try {
      await api.applicantStatus(
        applicant.id,
        'accepted',
        offeredWage: offeredWage,
        startDate: _dateValue(startDate),
        message: message.isEmpty ? null : message,
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

  Future<void> _cancelInterview(Applicant applicant) async {
    try {
      await AppScope.of(context).api.cancelInterview(applicant.id);
      await _load();
      _message('Interview cancelled.');
    } catch (exception) {
      if (mounted) _message('$exception');
    }
  }

  Future<void> _chat(Applicant applicant, Worker worker) async {
    try {
      final response = await AppScope.of(
        context,
      ).api.startConversation(workerId: applicant.worker.userId, jobId: job.id);
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

  Future<void> _aiShortlist() async {
    var count = 5;
    var autoCall = true;
    DateTime? callAt;
    final messageController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI shortlist from database',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('We will rank relevant karigars for this job.'),
              const SizedBox(height: 18),
              const Text(
                'How many karigars?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [3, 5, 10]
                    .map(
                      (value) => ChoiceChip(
                        label: Text('$value'),
                        selected: count == value,
                        onSelected: (_) => setSheetState(() => count = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Schedule AI screening call'),
                subtitle: const Text(
                  'Book a screening call for selected matches',
                ),
                value: autoCall,
                onChanged: (value) => setSheetState(() => autoCall = value),
              ),
              if (autoCall)
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 15)),
                      initialDate:
                          callAt ?? DateTime.now().add(const Duration(days: 1)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        callAt ?? DateTime.now(),
                      ),
                    );
                    if (time != null) {
                      setSheetState(
                        () => callAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.calendarClock),
                  label: Text(
                    callAt == null
                        ? 'Choose call time (optional)'
                        : MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(callAt!) +
                              ' · ' +
                              MaterialLocalizations.of(context).formatTimeOfDay(
                                TimeOfDay.fromDateTime(callAt!),
                              ),
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: messageController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Invite message (optional)',
                  hintText: 'We found your profile suitable for this job.',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(LucideIcons.sparkles),
                  label: const Text('Find matching karigars'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) {
      messageController.dispose();
      return;
    }
    try {
      final response = await AppScope.of(context).api.aiShortlist(
        job.id,
        count: count,
        autoCall: autoCall,
        callAt: callAt?.toIso8601String(),
        message: messageController.text.trim().isEmpty
            ? null
            : messageController.text.trim(),
      );
      if (!mounted) return;
      final picked = response['picked'] as List? ?? const [];
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('AI shortlist from database'),
          content: SizedBox(
            width: 360,
            child: picked.isEmpty
                ? Text('${response['message'] ?? 'No good matches found.'}')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: picked.length,
                    separatorBuilder: (_, _) => const Divider(height: 18),
                    itemBuilder: (_, index) {
                      final item = Map<String, dynamic>.from(
                        picked[index] as Map,
                      );
                      final details = [
                        if ('${item['location_label'] ?? ''}'.isNotEmpty)
                          '${item['location_label']}',
                        if ('${item['summary'] ?? ''}'.isNotEmpty)
                          '${item['summary']}',
                      ];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['name'] ?? 'Karigar'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('${item['score'] ?? 0}/100 match'),
                          if (details.isNotEmpty) Text(details.join(' · ')),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _message('$e');
    } finally {
      messageController.dispose();
    }
  }

  Future<void> _downloadResume(Applicant applicant) async {
    try {
      final download = await AppScope.of(
        context,
      ).api.applicantResume(applicant.id);
      if (!mounted) return;
      final suggestedName =
          download.filename ??
          applicant.resume?['name']?.toString() ??
          '${applicant.worker.name.replaceAll(RegExp(r'\s+'), '-')}-resume.pdf';
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save applicant resume',
        fileName: suggestedName,
        bytes: Uint8List.fromList(download.bytes),
      );
      if (!mounted || path == null) return;
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(download.bytes, flush: true);
      }
      _message('Resume saved.');
    } catch (exception) {
      if (mounted) _message('$exception');
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
              leading: const Icon(Icons.edit),
              title: const Text('Edit job'),
              onTap: () => Navigator.pop(context, 'edit'),
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
      if (action == 'edit') {
        final details = await AppScope.of(context).api.job(job.id);
        if (!mounted) return;
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => PostJobScreen(job: details)),
        );
        if (changed == true && mounted) Navigator.pop(context, true);
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
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
          _JobSummaryCard(job: job),
          const SectionTitle('Performance'),
          _JobMetrics(
            values: [
              ('Views', 124, LucideIcons.eye),
              ('Applied', job.applied, LucideIcons.fileText),
              ('Shortlisted', job.shortlisted, LucideIcons.bookmarkCheck),
              ('Hired', job.hired, LucideIcons.circleCheck),
            ],
          ),
          const SectionTitle('Applicants'),
          if (job.id != 0) ...[
            FilledButton.icon(
              onPressed: _aiShortlist,
              icon: const Icon(LucideIcons.sparkles, size: 18),
              label: const Text('AI shortlist from database'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchedWorkersScreen(jobId: job.id),
                ),
              ),
              icon: const Icon(LucideIcons.sparkles, size: 18),
              label: const Text('View matched karigars'),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children:
                const [
                  ('all', 'All'),
                  ('pending', 'Pending'),
                  ('shortlisted', 'Shortlisted'),
                  ('interview', 'Interview'),
                  ('hired', 'Hired'),
                  ('rejected', 'Rejected'),
                ].map((item) {
                  final selected = stage == item.$1;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text('${item.$2} (${counts[item.$1] ?? 0})'),
                    onSelected: (_) {
                      if (selected) return;
                      setState(() => stage = item.$1);
                      _load();
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            OutlinedButton(onPressed: _load, child: const Text('Retry'))
          else if (applicants.isEmpty)
            Text(
              'No applicants yet',
              style: TextStyle(color: colors.onSurfaceVariant),
            )
          else
            ...applicants.map((applicant) {
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
                child: Column(
                  children: [
                    WorkerCard(
                      worker: worker,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkerProfileScreen(
                            worker: worker,
                            profileId: profile.id,
                            workerUserId: profile.userId,
                            jobId: job.id,
                            phone: profile.phone,
                            contactUnlocked: true,
                            canMessage: true,
                            alwaysShowContact: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (applicant.ai != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: BrandChip(
                          'AI match ${applicant.ai?['score'] ?? 0}% · '
                          '${applicant.ai?['recommendation'] ?? ''}',
                        ),
                      ),
                    const SizedBox(height: 8),

                    if (applicant.resume != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _downloadResume(applicant),
                          icon: const Icon(LucideIcons.fileText, size: 17),
                          label: Text(
                            'Resume · ${applicant.resume?['name'] ?? 'PDF'}',
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScreeningCallsScreen(
                              applicantId: applicant.id,
                              workerName: profile.name,
                            ),
                          ),
                        ).then((_) => _load()),
                        icon: const Icon(LucideIcons.phoneCall, size: 17),
                        label: const Text('AI screening calls'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ContactActions(
                      phone: profile.phone,
                      email: profile.email,
                      expanded: true,
                      onChat: () => _chat(applicant, worker),
                    ),
                    if (applicant.stage != 'hired' &&
                        applicant.stage != 'rejected')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _shortlist(applicant),
                              child: Text(
                                applicant.stage == 'interview' ||
                                        applicant.stage == 'shortlisted'
                                    ? 'Shortlisted ★'
                                    : 'Shortlist',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _hire(applicant),
                              child: const Text('Hire'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () => _reject(applicant),
                            color: Colors.red,
                            icon: const Icon(LucideIcons.x, size: 18),
                          ),
                        ],
                      ),
                    if (applicant.stage == 'interview')
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => _cancelInterview(applicant),
                          child: const Text('Cancel interview'),
                        ),
                      ),
                    if (applicant.stage == 'hired' && applicant.offer != null)
                      _OfferSentCard(offer: applicant.offer!),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
