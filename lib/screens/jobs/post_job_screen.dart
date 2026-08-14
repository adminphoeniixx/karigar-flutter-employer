import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/location_map.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final selectedSkills = <String>{'Pipe Fitting'};
  final selectedPerks = <String>{};
  String shift = 'Day';
  String contact = 'Apply + Call';
  String wageType = 'daily';
  String? category;
  String? state;
  String? city;
  bool loading = false;
  bool _referenceLoaded = false;
  List<String> categories = const [];
  List<String> skills = const [
    'Pipe Fitting',
    'Waterproofing',
    'Drainage',
    'Testing',
  ];
  List<String> perks = const [
    'Food',
    'Accommodation',
    'Travel allowance',
    'Bonus',
    'Overtime pay',
    'Weekly off',
  ];
  List<String> states = const [];
  List<String> cities = const [];
  final titleController = TextEditingController();
  final openingsController = TextEditingController(text: '1');
  final experienceController = TextEditingController(text: '0');
  final wageMinController = TextEditingController();
  final wageMaxController = TextEditingController();
  final descriptionController = TextEditingController();
  final contactPhoneController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_referenceLoaded) {
      _referenceLoaded = true;
      _loadReference();
    }
  }

  Future<void> _loadReference() async {
    try {
      final response = await AppScope.of(context).api.reference();
      if (!mounted) return;
      setState(() {
        categories = _names(response['job_categories']);
        final apiSkills = _names(response['skills']);
        final apiPerks = _names(response['perks']);
        states = _names(response['states']);
        if (apiSkills.isNotEmpty) skills = apiSkills;
        if (apiPerks.isNotEmpty) perks = apiPerks;
      });
    } catch (_) {
      // Bundled options keep this form usable while reference data is offline.
    }
  }

  List<String> _names(dynamic value) => (value as List? ?? const [])
      .map((item) {
        if (item is Map) return '${item['name'] ?? item['label'] ?? ''}';
        return '$item';
      })
      .where((item) => item.isNotEmpty)
      .toList();

  Future<void> _loadCities(String value) async {
    setState(() {
      state = value;
      city = null;
      cities = const [];
    });
    try {
      final result = await AppScope.of(context).api.cities(value);
      if (mounted) setState(() => cities = result);
    } catch (_) {
      _message('Could not load cities.');
    }
  }

  Future<void> _submit(String status) async {
    if (loading) return;
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final vacancies = int.tryParse(openingsController.text);
    final experience = int.tryParse(experienceController.text);
    final wageMin = num.tryParse(wageMinController.text);
    final wageMax = num.tryParse(wageMaxController.text);
    final contactMode = {
      'Apply + Call': 'both',
      'Apply only': 'apply',
      'Call only': 'call',
    }[contact]!;
    if (title.isEmpty ||
        description.isEmpty ||
        category == null ||
        state == null ||
        city == null ||
        vacancies == null ||
        vacancies < 1 ||
        wageMin == null) {
      _message('Complete all required job details.');
      return;
    }
    if (wageMax != null && wageMax < wageMin) {
      _message('Maximum wage cannot be lower than minimum wage.');
      return;
    }
    if (contactMode != 'apply' &&
        !RegExp(r'^[6-9]\d{9}$').hasMatch(contactPhoneController.text.trim())) {
      _message('Enter a valid 10-digit contact number.');
      return;
    }
    setState(() => loading = true);
    final success = await AppScope.of(context).jobs.create({
      'title': title,
      'description': description,
      'category': category,
      'skills': selectedSkills.toList(),
      'wage_min': wageMin,
      if (wageMax != null) 'wage_max': wageMax,
      'wage_type': wageType,
      'city': city,
      'state': state,
      'vacancies': vacancies,
      'experience_min': experience ?? 0,
      'shift': shift.toLowerCase(),
      'perks': selectedPerks.toList(),
      'contact_mode': contactMode,
      if (contactMode != 'apply')
        'contact_phone': contactPhoneController.text.trim(),
      'requires_worker_fee': false,
      'status': status,
    });
    if (!mounted) return;
    setState(() => loading = false);
    if (!success) {
      _message(AppScope.of(context).jobs.error ?? 'Could not save the job.');
      return;
    }
    Navigator.pop(context, true);
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    titleController.dispose();
    openingsController.dispose();
    experienceController.dispose();
    wageMinController.dispose();
    wageMaxController.dispose();
    descriptionController.dispose();
    contactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Post a Job', style: TextStyle(fontSize: 16)),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const _Label('Job title'),
              _Input(
                hint: 'e.g. Plumber for apartment project',
                controller: titleController,
              ),
              const SizedBox(height: 14),
              const _Label('Category'),
              _Select(
                category ?? 'Select category',
                onTap: () => _choose(
                  'Select category',
                  categories,
                  (value) => setState(() => category = value),
                ),
              ),
              const SizedBox(height: 14),
              const _Label('Skills required'),
              _chips(skills, selectedSkills, multi: true),
              const _Hint(
                'Tap to add. Workers with these skills are matched first.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Openings'),
                        _Input(
                          hint: '3',
                          controller: openingsController,
                          number: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Min experience'),
                        _Input(
                          hint: '1',
                          suffix: 'yrs',
                          controller: experienceController,
                          number: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const _SectionLabel('Wage'),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Min ₹'),
                        _Input(
                          hint: '800',
                          prefix: '₹',
                          controller: wageMinController,
                          number: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Max ₹'),
                        _Input(
                          hint: '1000',
                          prefix: '₹',
                          controller: wageMaxController,
                          number: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 88,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Per'),
                        _Select(
                          wageType,
                          onTap: () => _choose('Wage type', const [
                            'hourly',
                            'daily',
                            'monthly',
                          ], (value) => setState(() => wageType = value)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _Label('Shift'),
              _singleChips(['Day', 'Night', 'Rotational', 'Flexible'], shift, (
                value,
              ) {
                setState(() => shift = value);
              }),
              const SizedBox(height: 14),
              const _Label('Perks & benefits'),
              _chips(perks, selectedPerks, multi: true),
              const SizedBox(height: 14),
              const _Label('Job description'),
              _Input(
                hint:
                    'Describe the work, site details, duration, tools provided…',
                lines: 4,
                controller: descriptionController,
              ),
              const _SectionLabel('Location'),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('State'),
                        _Select(
                          state ?? 'Select',
                          onTap: () =>
                              _choose('Select state', states, _loadCities),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('City'),
                        _Select(
                          city ?? 'Select',
                          onTap: () {
                            if (state == null) {
                              _message('Select a state first.');
                            } else {
                              _choose(
                                'Select city',
                                cities,
                                (value) => setState(() => city = value),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _Label('Pin the job location'),
              const SizedBox(height: 150, child: LocationMap()),
              const SizedBox(height: 14),
              const _Label('How should workers reach you?'),
              _singleChips(
                ['Apply + Call', 'Apply only', 'Call only'],
                contact,
                (value) => setState(() => contact = value),
              ),
              if (contact != 'Apply only') ...[
                const SizedBox(height: 14),
                const _Label('Contact phone'),
                _Input(
                  hint: '9876543210',
                  controller: contactPhoneController,
                  number: true,
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: loading ? null : () => _submit('draft'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.foreground,
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: const Text('Save draft'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: loading ? null : () => _submit('active'),
                  child: Text(loading ? 'Saving...' : 'Publish Job'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chips(
    List<String> values,
    Set<String> selected, {
    required bool multi,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values
        .map(
          (value) => _Choice(
            text: value,
            selected: selected.contains(value),
            onTap: () => setState(() {
              selected.contains(value)
                  ? selected.remove(value)
                  : selected.add(value);
            }),
          ),
        )
        .toList(),
  );

  Widget _singleChips(
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values
        .map(
          (value) => _Choice(
            text: value,
            selected: value == selected,
            onTap: () => onChanged(value),
          ),
        )
        .toList(),
  );

  Future<void> _choose(
    String title,
    List<String> values,
    ValueChanged<String> onSelected,
  ) async {
    if (values.isEmpty) {
      _message('Options are not available yet. Please try again.');
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...values.map(
              (item) => ListTile(
                title: Text(item),
                onTap: () => Navigator.pop(context, item),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) onSelected(result);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.hint,
    this.lines = 1,
    this.prefix,
    this.suffix,
    this.controller,
    this.number = false,
  });
  final String hint;
  final int lines;
  final String? prefix;
  final String? suffix;
  final TextEditingController? controller;
  final bool number;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    maxLines: lines,
    decoration: InputDecoration(
      hintText: hint,
      prefixIconConstraints: const BoxConstraints(minWidth: 34),
      prefixIcon: prefix == null
          ? null
          : Center(widthFactor: 1, child: Text(prefix!)),
      suffixIcon: suffix == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  suffix!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
    ),
  );
}

class _Select extends StatelessWidget {
  const _Select(this.text, {this.onTap});
  final String text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          const Icon(LucideIcons.chevronDown, size: 16),
        ],
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.text,
    required this.selected,
    required this.onTap,
  });
  final String text;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.brand50 : Colors.white,
        border: Border.all(
          color: selected ? AppColors.brand100 : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? AppColors.brandDark : AppColors.muted,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}
