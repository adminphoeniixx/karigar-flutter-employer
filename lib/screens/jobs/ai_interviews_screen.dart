import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class AiInterviewsScreen extends StatefulWidget {
  const AiInterviewsScreen({super.key});

  @override
  State<AiInterviewsScreen> createState() => _AiInterviewsScreenState();
}

class _AiInterviewsScreenState extends State<AiInterviewsScreen> {
  String filter = 'upcoming';
  bool loading = true;
  String? error;
  Map<String, dynamic> counts = const {};
  List<Map<String, dynamic>> interviews = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(
        context,
      ).api.aiInterviews(filter: filter);
      final raw = response['interviews'];
      final data = raw is Map ? raw['data'] : const [];
      if (!mounted) return;
      setState(() {
        counts = response['counts'] is Map
            ? Map<String, dynamic>.from(response['counts'] as Map)
            : const {};
        interviews = (data as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      });
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await AppScope.of(context).api.cancelScreeningCall(id);
      await _load();
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
    }
  }

  Future<void> _confirm(int id) async {
    try {
      await AppScope.of(context).api.confirmScreeningCall(id);
      await _load();
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI Interviews')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<String>(
            segments: ['upcoming', 'done', 'all']
                .map(
                  (value) => ButtonSegment(
                    value: value,
                    label: Text(
                      '${value[0].toUpperCase()}${value.substring(1)} (${counts[value] ?? 0})',
                    ),
                  ),
                )
                .toList(),
            selected: {filter},
            onSelectionChanged: (selection) {
              setState(() => filter = selection.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: OutlinedButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: interviews.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 160),
                            Center(child: Text('No AI interviews found.')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: interviews.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) => _InterviewCard(
                            item: interviews[index],
                            onCancel: _cancel,
                            onConfirm: _confirm,
                          ),
                        ),
                ),
        ),
      ],
    ),
  );
}

class _InterviewCard extends StatelessWidget {
  const _InterviewCard({
    required this.item,
    required this.onCancel,
    required this.onConfirm,
  });
  final Map<String, dynamic> item;
  final ValueChanged<int> onCancel, onConfirm;

  @override
  Widget build(BuildContext context) {
    final candidate = item['candidate'] as Map? ?? const {};
    final job = item['job'] as Map? ?? const {};
    final interview = item['interview'] as Map?;
    final id = (item['id'] as num?)?.toInt() ?? 0;
    final when = '${item['scheduled_label'] ?? item['called_label'] ?? ''}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.botMessageSquare,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${candidate['name'] ?? 'Karigar'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                StatusPill('${item['status_label'] ?? item['status'] ?? ''}'),
              ],
            ),
            const SizedBox(height: 8),
            Text('${job['title'] ?? 'Job'} · $when'),
            if ('${candidate['location_label'] ?? ''}'.isNotEmpty)
              Text(
                '${candidate['location_label']}',
                style: const TextStyle(color: AppColors.muted),
              ),
            if ('${item['summary'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${item['summary']}'),
            ],
            if ('${item['proposed_interview_label'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Proposed: ${item['proposed_interview_label']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (interview != null)
              Text(
                'Interview: ${interview['at_label'] ?? ''} · ${interview['mode'] ?? ''}',
              ),
            if (item['can_cancel'] == true ||
                item['awaiting_confirmation'] == true) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  if (item['awaiting_confirmation'] == true)
                    FilledButton(
                      onPressed: id == 0 ? null : () => onConfirm(id),
                      child: const Text('Confirm interview'),
                    ),
                  if (item['can_cancel'] == true)
                    OutlinedButton(
                      onPressed: id == 0 ? null : () => onCancel(id),
                      child: const Text('Cancel call'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
