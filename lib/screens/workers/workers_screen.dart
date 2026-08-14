import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/workers/worker_profile_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  String query = '';
  String category = 'All';
  Map<String, dynamic> advancedFilters = {};
  late final controller = AppScope.of(context).workers;
  bool _loaded = false;

  static const categories = [
    'All',
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Painting',
    'Masonry',
    'AC Repair',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      controller.addListener(_refresh);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.search();
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_loaded) controller.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _search() {
    final filters = <String, dynamic>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (category != 'All') 'skill': category,
      ...advancedFilters,
    };
    if (filters['radius_km'] != null) {
      final profile = AppScope.of(context).profile.profile;
      if (profile?.latitude != null && profile?.longitude != null) {
        filters['latitude'] = profile!.latitude;
        filters['longitude'] = profile.longitude;
      } else {
        filters.remove('radius_km');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Set your business location before using the distance filter.',
            ),
          ),
        );
      }
    }
    return controller.search(filters);
  }

  @override
  Widget build(BuildContext context) {
    final visible = controller.items
        .map(
          (item) => _WorkerView(
            worker: Worker(
              item.name,
              item.skills.isEmpty ? 'Worker' : item.skills.first,
              item.experienceYears,
              item.rating.average,
              item.distanceKm ?? 0,
              item.expectedWage,
              item.skills,
            ),
            name: item.name,
            experience: item.experienceYears,
            rating: item.rating.average,
            reviews: item.rating.count,
            distance: item.distanceKm ?? 0,
            wage: item.expectedWage,
            skills: item.skills,
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        title: const Text(
          'Find Workers',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => _showFilters(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.listFilter, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: TextField(
                    onChanged: (value) => query = value,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(
                        LucideIcons.search,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      hintText: 'Search skill, trade, name...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                      fillColor: AppColors.background,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final item = categories[index];
                      final selected = category == item;
                      return InkWell(
                        onTap: () {
                          setState(() => category = item);
                          _search();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.line,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item,
                            style: TextStyle(
                              color: selected ? Colors.white : AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                if (controller.loading && visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (controller.error != null && visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(controller.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _search,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                Text(
                  '${query.isEmpty && category == 'All' ? 8 : visible.length} workers available · Chennai, TN',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 11),
                ...visible.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WorkerResultCard(
                      data: item,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkerProfileScreen(worker: item.worker),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => _WorkerFiltersSheet(initial: advancedFilters),
    );
    if (result == null) return;
    setState(() => advancedFilters = result);
    await _search();
  }
}

class _WorkerView {
  const _WorkerView({
    required this.worker,
    required this.name,
    required this.experience,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.wage,
    required this.skills,
  });

  final Worker worker;
  final String name;
  final int experience;
  final double rating;
  final int reviews;
  final double distance;
  final int wage;
  final List<String> skills;
}

class _WorkerResultCard extends StatelessWidget {
  const _WorkerResultCard({required this.data, required this.onTap});
  final _WorkerView data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
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
                  backgroundColor: AppColors.brand100,
                  child: Text(
                    data.name.split(' ').map((word) => word[0]).take(2).join(),
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
                              data.name,
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
                        '${data.worker.trade} · ${data.experience} yrs · ★ ${data.rating} (${data.reviews})',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 15,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${data.distance} km',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '\u20B9${data.wage}/day',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '● Available',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: data.skills
                  .map((skill) => BrandChip(skill, neutral: true))
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorkerFiltersSheet extends StatefulWidget {
  const _WorkerFiltersSheet({required this.initial});
  final Map<String, dynamic> initial;

  @override
  State<_WorkerFiltersSheet> createState() => _WorkerFiltersSheetState();
}

class _WorkerFiltersSheetState extends State<_WorkerFiltersSheet> {
  bool verifiedOnly = false;
  bool availableNow = true;
  final selectedLanguages = <String>{};
  final minWageController = TextEditingController();
  final maxWageController = TextEditingController();
  int? experienceMin;
  int? radiusKm;
  String sort = 'best_match';

  @override
  void initState() {
    super.initState();
    verifiedOnly = widget.initial['verified'] == 1;
    availableNow = widget.initial['available'] != 0;
    experienceMin = int.tryParse('${widget.initial['experience_min'] ?? ''}');
    radiusKm = int.tryParse('${widget.initial['radius_km'] ?? ''}');
    minWageController.text = '${widget.initial['wage_min'] ?? ''}';
    maxWageController.text = '${widget.initial['wage_max'] ?? ''}';
    sort = '${widget.initial['sort'] ?? 'best_match'}';
    final languages = widget.initial['languages'];
    if (languages is Iterable) {
      selectedLanguages.addAll(languages.map((item) => '$item'));
    }
  }

  @override
  void dispose() {
    minWageController.dispose();
    maxWageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .88,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 15),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 17),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filter workers',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 17),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                const _FilterLabel('Trade / Category'),
                const _FilterSelect('Use category chips above'),
                const SizedBox(height: 16),
                const _FilterLabel('Minimum experience'),
                _FilterSelect(
                  experienceMin == null ? 'Any' : '$experienceMin+ years',
                  onTap: () => _pick<int>(
                    'Minimum experience',
                    const {
                      0: 'Any',
                      1: '1+ years',
                      3: '3+ years',
                      5: '5+ years',
                    },
                    (value) => setState(
                      () => experienceMin = value == 0 ? null : value,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Expected wage (₹/day)'),
                Row(
                  children: [
                    Expanded(
                      child: _WageField(
                        hint: 'Min 600',
                        controller: minWageController,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WageField(
                        hint: 'Max 1200',
                        controller: maxWageController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Distance from site'),
                _FilterSelect(
                  radiusKm == null ? 'Any distance' : 'Within $radiusKm km',
                  onTap: () => _pick<int>(
                    'Distance from site',
                    const {
                      0: 'Any distance',
                      3: 'Within 3 km',
                      5: 'Within 5 km',
                      10: 'Within 10 km',
                    },
                    (value) =>
                        setState(() => radiusKm = value == 0 ? null : value),
                  ),
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Speaks'),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ['Hindi', 'Tamil', 'Telugu', 'English', 'Kannada']
                      .map((language) {
                        final selected = selectedLanguages.contains(language);
                        return InkWell(
                          onTap: () => setState(() {
                            selected
                                ? selectedLanguages.remove(language)
                                : selectedLanguages.add(language);
                          }),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.brand50
                                  : Colors.white,
                              border: Border.all(
                                color: selected
                                    ? AppColors.brand200
                                    : AppColors.line,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              language,
                              style: TextStyle(
                                color: selected
                                    ? AppColors.brandDark
                                    : AppColors.muted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Sort by'),
                _FilterSelect(
                  const {
                        'best_match': 'Best match',
                        'nearest': 'Nearest first',
                        'rating': 'Highest rated',
                        'experience': 'Most experienced',
                        'wage_low': 'Lowest wage',
                      }[sort] ??
                      'Best match',
                  onTap: () => _pick<String>('Sort by', const {
                    'best_match': 'Best match',
                    'nearest': 'Nearest first',
                    'rating': 'Highest rated',
                    'experience': 'Most experienced',
                    'wage_low': 'Lowest wage',
                  }, (value) => setState(() => sort = value)),
                ),
                const SizedBox(height: 11),
                _FilterSwitch(
                  label: 'Only KYC-verified',
                  value: verifiedOnly,
                  onChanged: (value) => setState(() => verifiedOnly = value),
                ),
                _FilterSwitch(
                  label: 'Available now',
                  value: availableNow,
                  onChanged: (value) => setState(() => availableNow = value),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 11, 18, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      verifiedOnly = false;
                      availableNow = false;
                      selectedLanguages.clear();
                      experienceMin = null;
                      radiusKm = null;
                      sort = 'best_match';
                      minWageController.clear();
                      maxWageController.clear();
                    }),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.foreground,
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, {
                      if (experienceMin != null)
                        'experience_min': experienceMin,
                      if (num.tryParse(minWageController.text) != null)
                        'wage_min': num.parse(minWageController.text),
                      if (num.tryParse(maxWageController.text) != null)
                        'wage_max': num.parse(maxWageController.text),
                      if (selectedLanguages.isNotEmpty)
                        'languages': selectedLanguages.toList(),
                      if (verifiedOnly) 'verified': 1,
                      if (availableNow) 'available': 1,
                      if (radiusKm != null) 'radius_km': radiusKm,
                      'sort': sort,
                    }),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _pick<T>(
    String title,
    Map<T, String> options,
    ValueChanged<T> onSelected,
  ) async {
    final value = await showModalBottomSheet<T>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...options.entries.map(
              (entry) => ListTile(
                title: Text(entry.value),
                onTap: () => Navigator.pop(context, entry.key),
              ),
            ),
          ],
        ),
      ),
    );
    if (value != null) onSelected(value);
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
    ),
  );
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect(this.text, {this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          const Icon(LucideIcons.chevronDown, size: 17),
        ],
      ),
    ),
  );
}

class _WageField extends StatelessWidget {
  const _WageField({required this.hint, required this.controller});
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        prefixIconConstraints: const BoxConstraints(minWidth: 32),
        prefixIcon: const Center(
          widthFactor: 1,
          child: Text(
            '₹',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ),
        hintText: hint,
        contentPadding: const EdgeInsets.only(right: 13),
      ),
    ),
  );
}

class _FilterSwitch extends StatelessWidget {
  const _FilterSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 43,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
        Transform.scale(
          scale: .82,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}
