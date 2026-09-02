import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';

class MatchedWorkersScreen extends StatefulWidget {
  const MatchedWorkersScreen({super.key, required this.jobId});
  final int jobId;

  @override
  State<MatchedWorkersScreen> createState() => _MatchedWorkersScreenState();
}

class _MatchedWorkersScreenState extends State<MatchedWorkersScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = const [];
  final inviting = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && rows.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.matches(widget.jobId);
      final workers = (response['workers'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (mounted) setState(() => rows = workers);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _invite(Map<String, dynamic> row) async {
    final worker = WorkerProfile.fromJson(row);
    if (worker.userId == 0 || inviting.contains(worker.userId)) return;
    setState(() => inviting.add(worker.userId));
    try {
      final response = await AppScope.of(
        context,
      ).api.invite(widget.jobId, worker.userId);
      if (!mounted) return;
      setState(() => row['invited'] = response['invited'] == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${response['message'] ?? 'Invite sent.'}')),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      if (mounted) setState(() => inviting.remove(worker.userId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Matched workers')),
    body: loading && rows.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && rows.isEmpty
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: rows.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matching workers are available right now.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ]
                  : rows.map((row) {
                      final worker = WorkerProfile.fromJson(row);
                      final invited = row['invited'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(
                                      worker.name.isEmpty
                                          ? '?'
                                          : worker.name[0],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          worker.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '${worker.city} · ${worker.experienceYears} yrs · ★ ${worker.rating.average.toStringAsFixed(1)}',
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (worker.skills.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  worker.skills.join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed:
                                      invited ||
                                          inviting.contains(worker.userId)
                                      ? null
                                      : () => _invite(row),
                                  icon: Icon(
                                    invited
                                        ? LucideIcons.check
                                        : LucideIcons.send,
                                    size: 17,
                                  ),
                                  label: Text(
                                    invited ? 'Invited' : 'Invite to apply',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
            ),
          ),
  );
}

class ScreeningCallsScreen extends StatefulWidget {
  const ScreeningCallsScreen({
    super.key,
    required this.applicantId,
    required this.workerName,
  });
  final int applicantId;
  final String workerName;

  @override
  State<ScreeningCallsScreen> createState() => _ScreeningCallsScreenState();
}

class _ScreeningCallsScreenState extends State<ScreeningCallsScreen> {
  bool loading = true;
  bool canCall = false;
  String? blockedBecause;
  String? error;
  List<Map<String, dynamic>> calls = const [];

  static const blockerLabels = {
    'provider_not_configured': 'Calling is not switched on yet.',
    'no_caller_id': 'No calling number is configured yet.',
    'application_closed': 'This application is closed.',
    'interview_already_scheduled': 'An interview is already scheduled.',
    'no_phone_number': 'This worker has no phone number on file.',
    'worker_opted_out': 'The worker opted out of automated calls.',
    'call_in_progress': 'A screening call is already in progress.',
    'already_screened': 'This worker has already been screened.',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && calls.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(
        context,
      ).api.screeningCalls(widget.applicantId);
      if (!mounted) return;
      setState(() {
        calls = (response['calls'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        canCall = response['can_call'] == true;
        blockedBecause = response['blocked_because']?.toString();
      });
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _placeCall() async {
    try {
      final response = await AppScope.of(
        context,
      ).api.placeScreeningCall(widget.applicantId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${response['message'] ?? 'Call queued.'}')),
      );
      await _load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  Future<void> _confirm(Map<String, dynamic> call) async {
    try {
      final response = await AppScope.of(
        context,
      ).api.confirmScreeningCall((call['id'] as num).toInt());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${response['message'] ?? 'Interview confirmed.'}'),
        ),
      );
      await _load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.workerName} · AI screening')),
    body: loading && calls.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && calls.isEmpty
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: canCall ? _placeCall : null,
                  icon: const Icon(LucideIcons.phoneCall),
                  label: const Text('Call & schedule'),
                ),
                if (!canCall && blockedBecause != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    blockerLabels[blockedBecause] ?? blockedBecause!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 20),
                if (calls.isEmpty)
                  const Text('No screening calls yet.')
                else
                  ...calls.map(
                    (call) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${call['status_label'] ?? call['status'] ?? 'Call'}'
                              '${call['outcome_label'] == null ? '' : ' · ${call['outcome_label']}'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('${call['summary'] ?? 'No summary yet.'}'),
                            if (call['proposed_interview_label'] != null) ...[
                              const SizedBox(height: 7),
                              Text(
                                'Proposed: ${call['proposed_interview_label']}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                            if (call['awaiting_confirmation'] == true) ...[
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: () => _confirm(call),
                                child: const Text('Confirm interview'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}
