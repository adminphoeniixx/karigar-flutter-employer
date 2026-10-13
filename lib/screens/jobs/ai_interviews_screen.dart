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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  Future<void> _confirm(int id) async {
    try {
      await AppScope.of(context).api.confirmScreeningCall(id);
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
    appBar: AppBar(title: const Text('AI Interviews')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _InterviewsHeader(
                    counts: counts,
                    selected: filter,
                    onChanged: (value) {
                      setState(() => filter = value);
                      _load();
                    },
                  ),
                ),
                if (interviews.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyInterviews(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: interviews.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) => _InterviewCard(
                        item: interviews[index],
                        onCancel: _cancel,
                        onConfirm: _confirm,
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class _InterviewsHeader extends StatelessWidget {
  const _InterviewsHeader({
    required this.counts,
    required this.selected,
    required this.onChanged,
  });

  final Map<String, dynamic> counts;
  final String selected;
  final ValueChanged<String> onChanged;

  int _count(String key) => (counts[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                      'AI INTERVIEWS',
                      style: TextStyle(
                        color: Color(0xFFFBECE5),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${_count('upcoming')} upcoming ${_count('upcoming') == 1 ? 'call' : 'calls'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Keep candidate conversations moving forward.',
                      style: TextStyle(
                        color: Color(0xFFFBECE5),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0x20FFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x40FFFFFF)),
                ),
                child: const Icon(
                  LucideIcons.botMessageSquare,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'INTERVIEW STATUS',
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
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final tab in const {
                'upcoming': 'Upcoming',
                'done': 'Done',
                'all': 'All',
              }.entries)
                Expanded(
                  child: _InterviewTab(
                    label: '${tab.value} (${_count(tab.key)})',
                    selected: selected == tab.key,
                    onTap: () => onChanged(tab.key),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InterviewTab extends StatelessWidget {
  const _InterviewTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    final name = '${candidate['name'] ?? 'Karigar'}';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.brand100,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initials.isEmpty ? 'K' : initials,
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
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${job['title'] ?? 'Job'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill('${item['status_label'] ?? item['status'] ?? ''}'),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: AppColors.line2),
            ),
            _InterviewDetail(icon: LucideIcons.calendarDays, text: when),
            if ('${candidate['location_label'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _InterviewDetail(
                  icon: LucideIcons.mapPin,
                  text: '${candidate['location_label']}',
                ),
              ),
            if ('${item['summary'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item['summary']}',
                  style: const TextStyle(fontSize: 12.5, height: 1.3),
                ),
              ),
            ],
            if ('${item['proposed_interview_label'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InterviewDetail(
                icon: LucideIcons.clock3,
                text: 'Proposed · ${item['proposed_interview_label']}',
              ),
            ],
            if (interview != null)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: _InterviewDetail(
                  icon: LucideIcons.video,
                  text:
                      'Interview · ${interview['at_label'] ?? ''} · ${interview['mode'] ?? ''}',
                ),
              ),
            if (item['can_cancel'] == true ||
                item['awaiting_confirmation'] == true) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (item['awaiting_confirmation'] == true)
                    Expanded(
                      child: FilledButton(
                        onPressed: id == 0 ? null : () => onConfirm(id),
                        child: const Text('Confirm'),
                      ),
                    ),
                  if (item['awaiting_confirmation'] == true &&
                      item['can_cancel'] == true)
                    const SizedBox(width: 8),
                  if (item['can_cancel'] == true)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: id == 0 ? null : () => onCancel(id),
                        child: const Text('Cancel'),
                      ),
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

class _InterviewDetail extends StatelessWidget {
  const _InterviewDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: AppColors.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      ),
    ],
  );
}

class _EmptyInterviews extends StatelessWidget {
  const _EmptyInterviews();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 70, left: 36, right: 36),
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
            LucideIcons.botMessageSquare,
            color: AppColors.brandDark,
            size: 27,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No interviews here',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'AI interview calls will appear here as candidates move forward.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
      ],
    ),
  );
}
