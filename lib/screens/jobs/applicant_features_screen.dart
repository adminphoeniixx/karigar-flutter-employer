import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/api/api_exception.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/widgets/common.dart';
import 'ai_credits_screen.dart';

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
    } on ApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
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
    appBar: AppBar(title: const Text('Matched karigars')),
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
                          'No matching karigars are available right now.',
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

/// Compact result panel shared by applicant lists. The full call record is
/// loaded only when an employer asks to read the conversation.
class ApplicantScreeningCallPanel extends StatelessWidget {
  const ApplicantScreeningCallPanel({
    super.key,
    required this.call,
    required this.workerName,
  });

  final Map<String, dynamic>? call;
  final String workerName;

  @override
  Widget build(BuildContext context) {
    final item = call;
    if (item == null) return const SizedBox.shrink();
    final outcome = '${item['outcome_label'] ?? ''}'.trim();
    final status = '${item['status_label'] ?? item['status'] ?? 'In progress'}'
        .trim();
    final label = outcome.isNotEmpty ? outcome : status;
    final summary = '${item['summary'] ?? ''}'.trim();
    final sourceLabel = _screeningCallSourceLabel(item['source']);
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final canRead = item['has_conversation'] == true && id != 0;
    final charged = item['credits_charged'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        border: Border.all(color: AppColors.brand200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.botMessageSquare,
                size: 16,
                color: AppColors.brandDark,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'AI screening call',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _CallOutcomeChip(label: label),
            ],
          ),
          if (sourceLabel != null) ...[
            const SizedBox(height: 8),
            BrandChip(sourceLabel),
          ],
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(summary, style: const TextStyle(fontSize: 12.5, height: 1.35)),
          ],
          if (charged != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_duration(item['duration_seconds'])} · $charged credits',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          if (canRead) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScreeningConversationScreen(
                    callId: id,
                    workerName: workerName,
                    initialSummary: summary,
                  ),
                ),
              ),
              icon: const Icon(LucideIcons.messagesSquare, size: 16),
              label: const Text('View conversation'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: AppColors.brandDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _duration(Object? seconds) {
  final value = (seconds as num?)?.toInt() ?? 0;
  return '${value ~/ 60} min ${value % 60} s';
}

String? _screeningCallSourceLabel(Object? source) =>
    '$source'.toLowerCase() == 'shortlist' ? 'After your shortlist' : null;

class _CallOutcomeChip extends StatelessWidget {
  const _CallOutcomeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.brand200),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.brandDark,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class ScreeningConversationScreen extends StatefulWidget {
  const ScreeningConversationScreen({
    super.key,
    required this.callId,
    required this.workerName,
    this.initialSummary = '',
  });

  final int callId;
  final String workerName;
  final String initialSummary;

  @override
  State<ScreeningConversationScreen> createState() =>
      _ScreeningConversationScreenState();
}

class _ScreeningConversationScreenState
    extends State<ScreeningConversationScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> call = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && call.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(
        context,
      ).api.screeningCall(widget.callId);
      final raw = response['call'] ?? response['data'];
      if (mounted) {
        setState(
          () => call = raw is Map ? Map<String, dynamic>.from(raw) : const {},
        );
      }
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = '${call['summary'] ?? widget.initialSummary}'.trim();
    final turns = (call['conversation'] as List? ?? const [])
        .whereType<Map>()
        .map((turn) => Map<String, dynamic>.from(turn))
        .where((turn) => '${turn['text'] ?? ''}'.trim().isNotEmpty)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('AI screening conversation')),
      body: loading && call.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : error != null && call.isEmpty
          ? Center(
              child: OutlinedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  if ('${call['recording_url'] ?? ''}'.isNotEmpty) ...[
                    _CallRecordingPlayer(
                      url: '${call['recording_url']}',
                      expectedDuration:
                          (call['duration_seconds'] as num?)?.toInt() ?? 0,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (summary.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.brand50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.brand200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI call summary',
                            style: TextStyle(
                              color: AppColors.brandDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            summary,
                            style: GoogleFonts.notoSansDevanagari(
                              fontSize: 13,
                              height: 1.42,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (summary.isNotEmpty) const SizedBox(height: 18),
                  if (turns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'The conversation is not available yet.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...turns.map(
                      (turn) => _ConversationBubble(
                        text: '${turn['text']}',
                        agent: '${turn['speaker']}'.toLowerCase() == 'agent',
                        workerName: widget.workerName,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _CallRecordingPlayer extends StatefulWidget {
  const _CallRecordingPlayer({
    required this.url,
    required this.expectedDuration,
  });

  final String url;
  final int expectedDuration;

  @override
  State<_CallRecordingPlayer> createState() => _CallRecordingPlayerState();
}

class _CallRecordingPlayerState extends State<_CallRecordingPlayer> {
  late final AudioPlayer _player;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CallRecordingPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _player.setUrl(widget.url);
    } catch (_) {
      if (mounted) setState(() => _error = 'Recording could not be loaded.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  String _time(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.brand50,
      border: Border.all(color: AppColors.brand200),
      borderRadius: BorderRadius.circular(14),
    ),
    child: StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, positionSnapshot) => StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, stateSnapshot) {
          final position = positionSnapshot.data ?? Duration.zero;
          final duration =
              _player.duration ?? Duration(seconds: widget.expectedDuration);
          final playing = stateSnapshot.data?.playing ?? false;
          final max = duration.inMilliseconds.toDouble();
          final current = position.inMilliseconds.clamp(0, max).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.audioLines, color: AppColors.brandDark),
                  SizedBox(width: 8),
                  Text(
                    'Call recording',
                    style: TextStyle(
                      color: AppColors.brandDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.rose)),
              ] else ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton.filled(
                      onPressed: _loading
                          ? null
                          : () => playing ? _player.pause() : _player.play(),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(playing ? Icons.pause : Icons.play_arrow),
                    ),
                    Expanded(
                      child: Slider(
                        value: current,
                        max: max <= 0 ? 1 : max,
                        onChanged: _loading || max <= 0
                            ? null
                            : (value) => _player.seek(
                                Duration(milliseconds: value.round()),
                              ),
                      ),
                    ),
                    Text(
                      '${_time(position)} / ${_time(duration)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _ConversationBubble extends StatelessWidget {
  const _ConversationBubble({
    required this.text,
    required this.agent,
    required this.workerName,
  });
  final String text;
  final bool agent;
  final String workerName;

  @override
  Widget build(BuildContext context) => Align(
    alignment: agent ? Alignment.centerLeft : Alignment.centerRight,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: agent ? Colors.white : AppColors.brand100,
          border: Border.all(
            color: agent ? AppColors.line : AppColors.brand200,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(agent ? 3 : 14),
            bottomRight: Radius.circular(agent ? 14 : 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agent ? 'AI assistant' : workerName,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: GoogleFonts.notoSansDevanagari(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
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
    'no_phone_number': 'This karigar has no phone number on file.',
    'worker_opted_out': 'The karigar opted out of automated calls.',
    'worker_unavailable': 'This karigar is not available for work right now.',
    'call_in_progress': 'A screening call is already in progress.',
    'already_screened': 'This karigar has already been screened.',
    'no_credits': 'Not enough AI call credits.',
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
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.phoneCall),
                title: const Text('Call now'),
                subtitle: const Text('The AI will call the karigar now.'),
                onTap: () => Navigator.pop(context, 'now'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.calendarDays),
                title: const Text('Pick date and time'),
                subtitle: const Text('Calls run between 10 AM and 7 PM IST.'),
                onTap: () => Navigator.pop(context, 'schedule'),
              ),
            ],
          ),
        ),
      );
      if (action == null) return;
      String? at;
      if (action == 'schedule') {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 15)),
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 10, minute: 0),
        );
        if (time == null) return;
        at = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).toIso8601String();
      }
      final response = await AppScope.of(
        context,
      ).api.placeScreeningCall(widget.applicantId, at: at);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${response['message'] ?? 'Call queued.'}')),
      );
      await _load();
    } on ApiException catch (exception) {
      if (mounted && exception.code == 'no_credits') {
        final recharge = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Not enough AI call credits'),
            content: Text(exception.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Recharge'),
              ),
            ],
          ),
        );
        if (recharge == true && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiCreditsScreen()),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
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
                  if (blockedBecause == 'no_credits')
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiCreditsScreen(),
                        ),
                      ),
                      child: const Text('Recharge'),
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
                            if (call['credits_charged'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  '${_duration(call['duration_seconds'])} · ${call['credits_charged']} credits',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            if (call['has_conversation'] == true &&
                                (call['id'] as num?) != null) ...[
                              const SizedBox(height: 4),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ScreeningConversationScreen(
                                      callId: (call['id'] as num).toInt(),
                                      workerName: widget.workerName,
                                      initialSummary:
                                          '${call['summary'] ?? ''}',
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  LucideIcons.messagesSquare,
                                  size: 16,
                                ),
                                label: const Text('View conversation'),
                              ),
                            ],
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
                            if (call['can_cancel'] == true) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () async {
                                  await AppScope.of(
                                    context,
                                  ).api.cancelScreeningCall(
                                    (call['id'] as num).toInt(),
                                  );
                                  await _load();
                                },
                                child: const Text('Cancel booked call'),
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
