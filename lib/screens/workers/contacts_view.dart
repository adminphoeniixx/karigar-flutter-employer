import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import '../../core/app_scope.dart';
import '../../core/data.dart';
import '../../models/api_models.dart';
import '../../widgets/common.dart';
import '../../widgets/contact_actions.dart';
import '../jobs/job_manage_screen.dart';
import '../profile/plans_screen.dart';
import 'worker_profile_screen.dart';

class ContactsView extends StatefulWidget {
  const ContactsView({super.key, required this.source, required this.onUsage});
  final String source;
  final ValueChanged<Json> onUsage;
  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  final search = TextEditingController();
  Json filters = {}, usage = {};
  List<Json> rows = [], jobs = [];
  bool loading = false, started = false;
  String? error;
  int page = 1, lastPage = 1, generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      _load();
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final request = ++generation;
    final next = more ? page + 1 : 1;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AppScope.of(context).api.contacts(widget.source, {
        ...filters,
        'q': search.text.trim(),
        'page': next,
      });
      if (!mounted || request != generation) return;
      final contacts = result['contacts'] is Map
          ? Json.from(result['contacts'])
          : <String, dynamic>{};
      final incoming = (contacts['data'] as List? ?? [])
          .whereType<Map>()
          .map(Json.from)
          .toList();
      setState(() {
        rows = more ? [...rows, ...incoming] : incoming;
        usage = result['usage'] is Map ? Json.from(result['usage']) : {};
        jobs = (result['jobs'] as List? ?? [])
            .whereType<Map>()
            .map(Json.from)
            .toList();
        page = next;
        lastPage = asInt(contacts['last_page']);
      });
      widget.onUsage(usage);
    } catch (e) {
      if (mounted && request == generation) setState(() => error = '$e');
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> _filters() async {
    try {
      final reference = await AppScope.of(context).api.reference();
      if (!mounted) return;
      final draft = Json.from(filters);
      var cities = draft['state'] == null
          ? <String>[]
          : await AppScope.of(context).api.cities('${draft['state']}');
      if (!mounted) return;
      final result = await showModalBottomSheet<Json>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, update) {
            Widget picker(
              String key,
              String label,
              List<String> values,
            ) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                initialValue: values.contains(draft[key]) ? draft[key] : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All')),
                  ...values
                      .toSet()
                      .where((v) => v.isNotEmpty)
                      .map((v) => DropdownMenuItem(value: v, child: Text(v))),
                ],
                onChanged: (value) async {
                  update(() {
                    if (value == null || value.isEmpty) {
                      draft.remove(key);
                    } else {
                      draft[key] = value;
                    }
                    if (key == 'state') {
                      draft.remove('city');
                      cities = [];
                    }
                  });
                  if (key == 'state' && value?.isNotEmpty == true) {
                    try {
                      final loaded = await AppScope.of(
                        context,
                      ).api.cities(value!);
                      if (sheet.mounted && draft['state'] == value) {
                        update(() => cities = loaded);
                      }
                    } catch (e) {
                      if (sheet.mounted) await showContactError(sheet, e);
                    }
                  }
                },
              ),
            );
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                24 + MediaQuery.viewInsetsOf(sheet).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filter contacts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  picker('skill', 'Skill', asStrings(reference['skills'])),
                  picker('state', 'State', asStrings(reference['states'])),
                  KeyedSubtree(
                    key: ValueKey(draft['state']),
                    child: picker('city', 'City', cities),
                  ),
                  picker('sort', 'Sort', ['recent', 'oldest', 'name']),
                  if (widget.source == 'database')
                    picker('period', 'Period', ['all', 'cycle']),
                  if (widget.source == 'applicants') ...[
                    picker('stage', 'Stage', [
                      'all',
                      'pending',
                      'shortlisted',
                      'interview',
                      'hired',
                      'rejected',
                    ]),
                    DropdownButtonFormField<String>(
                      initialValue: draft['job']?.toString(),
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Job'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All jobs'),
                        ),
                        ...jobs.map(
                          (j) => DropdownMenuItem(
                            value: '${j['id']}',
                            child: Text('${j['title']}'),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null || v.isEmpty) {
                          draft.remove('job');
                        } else {
                          draft['job'] = v;
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheet, draft),
                    child: const Text('Apply filters'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheet, <String, dynamic>{}),
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
            );
          },
        ),
      );
      if (result != null && mounted) {
        filters = result;
        await _load();
      }
    } catch (e) {
      if (mounted) await showContactError(context, e);
    }
  }

  Future<void> _open(Json row) async {
    if (widget.source == 'applicants' && row['job'] is Map) {
      try {
        final job = await AppScope.of(context).api.job(asInt(row['job']['id']));
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JobManageScreen(
              job: Job(
                job.title,
                job.category,
                job.wageLabel,
                job.vacancies,
                asInt(job.stats['applicants']),
                asInt(job.stats['shortlisted']),
                asInt(job.stats['hired']),
                job.status,
                id: job.id,
              ),
            ),
          ),
        );
      } catch (e) {
        if (mounted) await showContactError(context, e);
      }
      return;
    }
    final skills = asStrings(row['skills']);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerProfileScreen(
          worker: Worker(
            '${row['name'] ?? 'Worker'}',
            skills.firstOrNull ?? 'Worker',
            asInt(row['experience_years']),
            0,
            0,
            asInt(row['expected_wage']),
            skills,
          ),
          profileId: asInt(row['profile_id']),
          workerUserId: asInt(row['worker_id']),
          phone: row['phone']?.toString(),
          contactUnlocked: true,
          canMessage: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reset = DateTime.tryParse('${usage['resets_at'] ?? ''}');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TextField(
            controller: search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search name or phone',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _filters,
              icon: const Icon(Icons.tune),
              label: Text(
                filters.isEmpty ? 'Filters' : 'Filters (${filters.length})',
              ),
            ),
          ),
          if (usage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (usage['plan'] == null) ...[
                        const Text(
                          'Subscribe to a plan to unlock karigar contacts',
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PlansScreen(),
                            ),
                          ),
                          child: const Text('See plans'),
                        ),
                      ] else ...[
                        Text(
                          '${usage['plan']} · ${asInt(usage['limit']) == 0 ? 'Unlimited' : usage['limit']} contact unlocks per month',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${usage['used'] ?? 0} used this cycle (${usage['used_database'] ?? 0} database, ${usage['used_applicants'] ?? 0} applicants)',
                        ),
                        Text(
                          '${usage['remaining'] ?? 'Unlimited'} unlocks left',
                        ),
                        if (reset != null)
                          Text(
                            'Renews ${MaterialLocalizations.of(context).formatMediumDate(reset.toLocal())}',
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () =>
                        _load(more: rows.isNotEmpty && page < lastPage),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (!loading && error == null && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No contacts found. Try changing your filters or unlock a worker contact.',
                textAlign: TextAlign.center,
              ),
            ),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['name'] ?? 'Worker'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        [
                          row['city'],
                          row['state'],
                        ].where((v) => v != null && '$v'.isNotEmpty).join(', '),
                      ),
                      if (row['job'] is Map)
                        Text('${row['job']['title']} · ${row['stage'] ?? ''}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        children: asStrings(
                          row['skills'],
                        ).map((s) => BrandChip(s, neutral: true)).toList(),
                      ),
                      const SizedBox(height: 8),
                      if (row['phone'] != null)
                        SelectableText('${row['phone']}'),
                      ContactActions(
                        phone: row['phone']?.toString(),
                        email: row['email']?.toString(),
                      ),
                      TextButton(
                        onPressed: () => _open(row),
                        child: Text(
                          widget.source == 'applicants'
                              ? 'Applicants'
                              : 'View profile',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!loading && page < lastPage)
            OutlinedButton(
              onPressed: () => _load(more: true),
              child: const Text('Load more'),
            ),
        ],
      ),
    );
  }
}
