import 'dart:async';

import '../../models/api_models.dart';
import '../../core/api/api_exception.dart';
import '../profile/plans_screen.dart';
import '../profile/kyc_screen.dart';
import 'ai_credits_screen.dart';
import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/location_map.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key, this.job});
  final EmployerJob? job;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final selectedSkills = <String>{};
  String liveStatus = 'active';
  bool get editingDraft =>
      widget.job?.isDraft == true || widget.job?.status == 'draft';
  bool get canDraft => widget.job == null || editingDraft;
  final selectedPerks = <String>{};
  String shift = 'Day';
  String contact = 'Apply + Call';
  String wageType = 'monthly';
  String aiLanguage = 'en';
  String? category;
  String? state;
  String? city;
  String? contactPhoneError;
  bool loading = false;
  bool referenceLoading = true;
  bool suggesting = false;
  bool aiShortlistEnabled = true;
  bool aiCallEnabled = true;
  bool aiShortlistAvailable = true;
  bool aiCallAvailable = true;
  bool aiCreditsEnabled = true;
  bool aiCreditsCanEnable = true;
  int aiCreditsBalance = 0;
  int aiCreditsMinForJob = 10;
  bool _referenceLoaded = false;
  List<String> categories = const [];
  List<String> skills = const [
    'Pipe Fitting',
    'Waterproofing',
    'Drainage',
    'Testing',
  ];
  Map<String, List<String>> categorySkills = const {};
  List<String> perks = const [
    'Food',
    'Accommodation',
    'Travel allowance',
    'Bonus',
    'Overtime pay',
    'Weekly off',
  ];
  LatLng? selectedLocation;
  List<String> states = const [];
  List<String> cities = const [];
  final titleController = TextEditingController();
  final openingsController = TextEditingController(text: '1');
  final experienceController = TextEditingController(text: '0');
  final experienceMaxController = TextEditingController();
  final wageMinController = TextEditingController();
  final wageMaxController = TextEditingController();
  final descriptionController = TextEditingController();
  final contactPhoneController = TextEditingController();
  final addressController = TextEditingController();
  final shiftStartController = TextEditingController();
  final shiftEndController = TextEditingController();
  TimeOfDay? shiftStartTime;
  TimeOfDay? shiftEndTime;
  final contactNameController = TextEditingController();
  final contactDesignationController = TextEditingController();
  final perkController = TextEditingController();
  Timer? _addressDebounce;

  @override
  void initState() {
    super.initState();
    addressController.addListener(_addressChanged);

    final job = widget.job;
    if (job == null) return;
    if (job.latitude != null && job.longitude != null) {
      selectedLocation = LatLng(job.latitude!, job.longitude!);
    }
    titleController.text = job.title;
    descriptionController.text = job.description;
    openingsController.text = job.vacancies > 0 ? '${job.vacancies}' : '';
    experienceController.text = '${job.experienceMin}';
    experienceMaxController.text = job.experienceMax?.toString() ?? '';
    wageMinController.text = job.wageMin > 0 ? '${job.wageMin}' : '';
    wageMaxController.text = job.wageMax > 0 ? '${job.wageMax}' : '';
    contactPhoneController.text = job.contactPhone ?? '';
    addressController.text = job.address ?? '';
    shiftStartController.text = job.shiftStart ?? '';
    shiftEndController.text = job.shiftEnd ?? '';
    shiftStartTime = _parseTime(job.shiftStart);
    shiftEndTime = _parseTime(job.shiftEnd);
    contactNameController.text = job.contactName ?? '';
    contactDesignationController.text = job.contactDesignation ?? '';
    category = job.category.isEmpty ? null : job.category;
    state = job.state.isEmpty ? null : job.state;
    city = job.city.isEmpty ? null : job.city;
    selectedSkills.addAll(job.skills);
    selectedPerks.addAll(job.perks);
    wageType = 'monthly';
    if (job.shift.isNotEmpty) {
      shift = '${job.shift[0].toUpperCase()}${job.shift.substring(1)}';
    }
    contact =
        {
          'both': 'Apply + Call',
          'call': 'Call only',
          'apply': 'Apply only',
        }[job.contactMode] ??
        'Apply only';
    liveStatus = job.status == 'closed' ? 'closed' : 'active';
    aiShortlistEnabled = job.aiShortlistEnabled;
    aiCallEnabled = job.aiCallEnabled;
  }

  TimeOfDay? _parseTime(String? value) {
    final parts = (value ?? '').split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime({required bool start}) async {
    final initial = start ? shiftStartTime : shiftEndTime;
    final selected = await showTimePicker(
      context: context,
      initialTime:
          initial ??
          (start
              ? const TimeOfDay(hour: 9, minute: 0)
              : const TimeOfDay(hour: 17, minute: 0)),
    );
    if (selected == null || !mounted) return;
    final value =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (start) {
        shiftStartTime = selected;
        shiftStartController.text = value;
      } else {
        shiftEndTime = selected;
        shiftEndController.text = value;
      }
    });
  }

  void _addressChanged() {
    _addressDebounce?.cancel();
    _addressDebounce = Timer(const Duration(milliseconds: 700), _pinAddress);
  }

  Future<void> _pinAddress() async {
    final address = addressController.text.trim();
    if (address.length < 4) return;
    try {
      final places = await locationFromAddress(
        '$address, ${city ?? ''}, ${state ?? ''}, India',
      );
      if (!mounted ||
          places.isEmpty ||
          address != addressController.text.trim()) {
        return;
      }
      setState(
        () => selectedLocation = LatLng(
          places.first.latitude,
          places.first.longitude,
        ),
      );
    } catch (_) {
      // Keep the current pin when geocoding cannot resolve a landmark.
    }
  }

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
        final rawCategorySkills =
            response['category_skills'] as Map? ?? const {};
        categorySkills = rawCategorySkills.map(
          (key, value) => MapEntry('$key', _names(value)),
        );
        final apiPerks = _names(response['perks']);
        states = _names(response['states']);
        if (city != null) cities = [city!];
        skills = {
          ...(category == null
              ? apiSkills
              : (categorySkills[category] ?? apiSkills)),
          ...selectedSkills,
        }.toList();
        perks = {...apiPerks, ...selectedPerks}.toList();
      });
      if (state != null) unawaited(_loadCities(state!, keepSelectedCity: true));
      try {
        final options = await AppScope.of(context).api.jobFormOptions();
        final ai = options['ai'];
        if (mounted && ai is Map) {
          final credits = ai['credits'];
          setState(() {
            aiShortlistAvailable = ai['shortlist_available'] != false;
            aiCallAvailable = ai['call_available'] != false;
            if (credits is Map) {
              aiCreditsEnabled = credits['enabled'] != false;
              aiCreditsCanEnable = credits['can_enable'] != false;
              aiCreditsBalance = (credits['balance'] as num?)?.toInt() ?? 0;
              aiCreditsMinForJob =
                  (credits['min_for_job'] as num?)?.toInt() ?? 10;
              if (widget.job == null &&
                  aiCreditsEnabled &&
                  !aiCreditsCanEnable) {
                aiCallEnabled = false;
              } else if (widget.job == null && aiCreditsCanEnable) {
                aiCallEnabled = true;
              }
            }
          });
        }
      } catch (_) {
        // Keep the switches available when older servers do not expose options.
      }
    } catch (_) {
      // Bundled options keep this form usable while reference data is offline.
    } finally {
      if (mounted) setState(() => referenceLoading = false);
    }
  }

  List<String> _names(dynamic value) => (value as List? ?? const [])
      .map((item) {
        if (item is Map) return '${item['name'] ?? item['label'] ?? ''}';
        return '$item';
      })
      .where((item) => item.isNotEmpty)
      .toList();

  Future<void> _loadCities(
    String value, {
    bool keepSelectedCity = false,
  }) async {
    setState(() {
      state = value;
      if (!keepSelectedCity) city = null;
      if (!keepSelectedCity) selectedLocation = null;
      cities = const [];
    });
    try {
      final result = await AppScope.of(context).api.cities(value);
      if (mounted && state == value) {
        setState(() => cities = {...result, ?city}.toList());
      }
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
    final experienceMax = int.tryParse(experienceMaxController.text);
    final wageMin = num.tryParse(wageMinController.text);
    final wageMax = num.tryParse(wageMaxController.text);
    final contactMode = {
      'Apply + Call': 'both',
      'Apply only': 'apply',
      'Call only': 'call',
    }[contact]!;
    final draft = status == 'draft';
    if (title.isEmpty) {
      _message('Enter a job title.');
      return;
    }
    if (!draft &&
        (description.isEmpty ||
            category == null ||
            state == null ||
            city == null ||
            vacancies == null ||
            vacancies < 1 ||
            wageMin == null ||
            wageMin < 0)) {
      _message('Complete all required job details.');
      return;
    }
    if (!draft && wageMax != null && wageMin != null && wageMax < wageMin) {
      _message('Maximum wage cannot be lower than minimum wage.');
      return;
    }
    if (!draft &&
        experience != null &&
        experienceMax != null &&
        experienceMax < experience) {
      _message('Maximum experience cannot be lower than minimum experience.');
      return;
    }
    if (!draft &&
        ((shiftStartController.text.trim().isEmpty) !=
            (shiftEndController.text.trim().isEmpty))) {
      _message('Enter both shift start and end times, or leave both blank.');
      return;
    }
    if (!draft &&
        contactMode != 'apply' &&
        !RegExp(r'^[6-9]\d{9}$').hasMatch(contactPhoneController.text.trim())) {
      _message('Enter a valid 10-digit contact number.');
      return;
    }
    final values = <String, dynamic>{
      'title': title,
      if (description.isNotEmpty) 'description': description,
      'category': ?category,
      if (!draft || selectedSkills.isNotEmpty)
        'skills': selectedSkills.toList(),
      if (wageMin != null && wageMin >= 0) 'wage_min': wageMin,
      if (wageMax != null && wageMax >= (wageMin ?? 0)) 'wage_max': wageMax,
      if (!draft || wageMin != null || wageMax != null) 'wage_type': wageType,
      'city': ?city,
      'state': ?state,
      if (addressController.text.trim().isNotEmpty)
        'address': addressController.text.trim(),
      if (selectedLocation != null) 'latitude': selectedLocation!.latitude,
      if (selectedLocation != null) 'longitude': selectedLocation!.longitude,
      if (!draft && vacancies != null && vacancies > 0) 'vacancies': vacancies,
      if (!draft || (experience != null && experience > 0))
        'experience_min': experience != null && experience >= 0
            ? experience
            : 0,
      if (experienceMax != null && experienceMax >= 0)
        'experience_max': experienceMax,
      if (!draft) 'shift': shift.toLowerCase(),
      if (shiftStartController.text.trim().isNotEmpty)
        'shift_start': shiftStartController.text.trim(),
      if (shiftEndController.text.trim().isNotEmpty)
        'shift_end': shiftEndController.text.trim(),
      if (!draft || selectedPerks.isNotEmpty) 'perks': selectedPerks.toList(),
      'contact_mode':
          draft &&
              !RegExp(
                r'^[6-9]\d{9}$',
              ).hasMatch(contactPhoneController.text.trim())
          ? 'apply'
          : contactMode,
      if (contactMode != 'apply' &&
          RegExp(r'^[6-9]\d{9}$').hasMatch(contactPhoneController.text.trim()))
        'contact_phone': contactPhoneController.text.trim(),
      if (!draft && contactMode != 'apply')
        'contact_name': contactNameController.text.trim(),
      if (!draft && contactMode != 'apply')
        'contact_designation': contactDesignationController.text.trim(),
      'requires_worker_fee': widget.job?.requiresWorkerFee ?? false,
      'worker_fee_amount': ?widget.job?.workerFeeAmount,
      'ai_shortlist_enabled': aiShortlistEnabled,
      'ai_call_enabled': aiCallEnabled,
      'status': status,
    };
    setState(() => loading = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.saveJob(values, id: widget.job?.id);
      if (!mounted) return;
      if (response['code'] == 'job_under_review') {
        final rawJob = response['job'];
        final moderation = rawJob is Map && rawJob['moderation'] is Map
            ? Map<String, dynamic>.from(rawJob['moderation'] as Map)
            : const <String, dynamic>{};
        final reasons = (moderation['reasons'] as List? ?? const [])
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .join('\n• ');
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(LucideIcons.shieldAlert, color: AppColors.amber),
            title: const Text('Job under review'),
            content: Text(
              '${response['message'] ?? 'Your job needs a quick review before it goes live.'}'
              '${reasons.isEmpty ? '' : '\n\nReason:\n• $reasons'}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Okay'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }
      _message(
        '${response['message'] ?? (draft ? 'Draft saved.' : 'Job posted.')}',
      );
      Navigator.pop(context, true);
    } on ApiException catch (exception) {
      if (!mounted) return;
      if (!draft &&
          canDraft &&
          exception.statusCode == 422 &&
          (exception.code == 'no_plan' ||
              exception.code == 'job_limit_reached' ||
              exception.message.contains('job posts') ||
              exception.message.contains('Subscribe to a plan'))) {
        final action = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 640),
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Choose a plan to continue",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(exception.message),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'draft'),
                    child: const Text('Save as draft'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, 'plans'),
                    child: const Text('See plans'),
                  ),
                ],
              ),
            ),
          ),
        );
        if (!mounted) return;
        setState(() => loading = false);
        if (action == 'draft') await _submit('draft');
        if (action == 'plans' && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlansScreen()),
          );
        }
      } else if (exception.code == 'ai_credits_required') {
        final recharge = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('AI call credits needed'),
            content: Text(exception.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Recharge credits'),
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
      } else if (exception.code == 'verification_required') {
        final action = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Business verification required'),
            content: Text(exception.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Verify business'),
              ),
            ],
          ),
        );
        if (action == true && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KycScreen()),
          );
        }
      } else {
        _message(exception.message);
      }
    } catch (exception) {
      if (mounted) _message('$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _suggestDescription() async {
    final title = titleController.text.trim();
    if (title.length < 3) {
      _message('Enter a job title first.');
      return;
    }
    setState(() => suggesting = true);
    try {
      final suggestions = await AppScope.of(context).api.suggestJobDescription(
        title: title,
        category: category,
        city: city,
        state: state,
        skills: selectedSkills.toList(),
        language: aiLanguage,
      );
      if (!mounted) return;
      if (suggestions.isEmpty) {
        _message('No description suggestion is available right now.');
        return;
      }
      final selected = suggestions.length == 1
          ? suggestions.first
          : await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (context) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    const Text(
                      'Choose a description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...suggestions.map(
                      (suggestion) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(suggestion),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => Navigator.pop(context, suggestion),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
      if (selected != null) {
        descriptionController.text = selected;
      }
    } catch (exception) {
      if (mounted) _message('$exception');
    } finally {
      if (mounted) setState(() => suggesting = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _addressDebounce?.cancel();
    addressController.removeListener(_addressChanged);
    titleController.dispose();
    openingsController.dispose();
    experienceController.dispose();
    experienceMaxController.dispose();
    wageMinController.dispose();
    wageMaxController.dispose();
    descriptionController.dispose();
    contactPhoneController.dispose();
    addressController.dispose();
    shiftStartController.dispose();
    shiftEndController.dispose();
    contactNameController.dispose();
    contactDesignationController.dispose();
    perkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.job == null
              ? 'Post a Job'
              : editingDraft
              ? 'Edit draft'
              : 'Edit job',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: referenceLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _PostJobHeader(
                        editing: widget.job != null,
                        draft: editingDraft,
                      ),
                      const _SectionLabel('Role details'),
                      if (!canDraft) ...[
                        const _Label('Status'),
                        _singleChips(
                          ['active', 'closed'],
                          liveStatus,
                          (value) => setState(() => liveStatus = value),
                        ),
                        const SizedBox(height: 14),
                      ],
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
                          (value) => setState(() {
                            category = value;
                            skills = {
                              ...(categorySkills[value] ?? skills),
                              ...selectedSkills,
                            }.toList();
                          }),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _Label('Skills required'),
                      _chips(skills, selectedSkills, multi: true),
                      const SizedBox(height: 8),
                      _Input(
                        hint: 'Add a skill',
                        controller: perkController,
                        onSubmitted: (value) {
                          final skill = value.trim();
                          if (skill.isNotEmpty) {
                            setState(() {
                              skills = {...skills, skill}.toList();
                              selectedSkills.add(skill);
                              perkController.clear();
                            });
                          }
                        },
                      ),
                      const _Hint(
                        'Tap to add. Karigars with these skills are matched first.',
                      ),
                      const _SectionLabel('Work setup'),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label('Max experience'),
                                _Input(
                                  hint: '5',
                                  suffix: 'yrs',
                                  controller: experienceMaxController,
                                  number: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const _SectionLabel('Salary'),
                      const Text(
                        'Enter monthly salary in rupees',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label('Minimum / month'),
                                _Input(
                                  hint: '15000',
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
                                const _Label('Maximum / month'),
                                _Input(
                                  hint: '30000',
                                  prefix: '₹',
                                  controller: wageMaxController,
                                  number: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _Label('Shift'),
                      _singleChips(
                        ['Day', 'Night', 'Rotational', 'Flexible'],
                        shift,
                        (value) {
                          setState(() => shift = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeInput(
                              label: 'Start time',
                              value: shiftStartTime,
                              onTap: () => _pickTime(start: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TimeInput(
                              label: 'End time',
                              value: shiftEndTime,
                              onTap: () => _pickTime(start: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _Label('Perks & benefits'),
                      _chips(perks, selectedPerks, multi: true),
                      const SizedBox(height: 8),
                      _Input(
                        hint: 'Add your own perk',
                        controller: perkController,
                        onSubmitted: (value) {
                          final perk = value.trim();
                          if (perk.isNotEmpty) {
                            setState(() {
                              perks = {...perks, perk}.toList();
                              selectedPerks.add(perk);
                              perkController.clear();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      _AiHelpCard(
                        shortlistEnabled: aiShortlistEnabled,
                        callEnabled: aiCallEnabled,
                        shortlistAvailable: aiShortlistAvailable,
                        callAvailable: aiCallAvailable,
                        creditsEnabled: aiCreditsEnabled,
                        creditsCanEnable: aiCreditsCanEnable,
                        creditsBalance: aiCreditsBalance,
                        creditsMinForJob: aiCreditsMinForJob,
                        onRecharge: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AiCreditsScreen(),
                          ),
                        ),
                        onShortlistChanged: aiShortlistAvailable
                            ? (value) =>
                                  setState(() => aiShortlistEnabled = value)
                            : null,
                        onCallChanged: aiCallAvailable && aiShortlistEnabled
                            ? (value) => setState(() => aiCallEnabled = value)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _Label('Job description'),
                          Wrap(
                            spacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _singleChips(
                                ['en', 'hi'],
                                aiLanguage,
                                (value) => setState(() => aiLanguage = value),
                              ),
                              TextButton.icon(
                                onPressed: suggesting
                                    ? null
                                    : _suggestDescription,
                                icon: suggesting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        LucideIcons.sparkles,
                                        size: 16,
                                      ),
                                label: Text(
                                  aiLanguage == 'hi'
                                      ? 'हिंदी में AI सुझाव'
                                      : 'Suggest with AI',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                                  onTap: () => _choose(
                                    'Select state',
                                    states,
                                    _loadCities,
                                  ),
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
                                      _choose('Select city', cities, (value) {
                                        setState(() {
                                          city = value;
                                          selectedLocation = null;
                                        });
                                        unawaited(_pinAddress());
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _Label('Address / landmark'),
                      _Input(
                        hint: 'Plot, street, area or landmark',
                        controller: addressController,
                      ),
                      const SizedBox(height: 14),
                      const _Label('Pin the job location'),
                      SizedBox(
                        height: 190,
                        child: LocationMap(
                          key: ValueKey(
                            '$state/$city/${selectedLocation?.latitude}/${selectedLocation?.longitude}',
                          ),
                          initialLocation:
                              selectedLocation ??
                              const LatLng(22.5937, 78.9629),
                          initialZoom: selectedLocation == null ? 4 : 13,
                          hasSelection: selectedLocation != null,
                          onLocationChanged: (point) =>
                              selectedLocation = point,
                        ),
                      ),
                      const Text(
                        'Move the map or tap to pin the exact work site.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const _SectionLabel('Applicant reach'),
                      const _Label('How should karigars reach you?'),
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
                          maxLength: 10,
                          errorText: contactPhoneError,
                          onChanged: (value) => setState(
                            () => contactPhoneError =
                                value.isEmpty ||
                                    RegExp(r'^[6-9]\d{9}$').hasMatch(value)
                                ? null
                                : 'Enter a valid 10-digit number.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _Label('Who picks up the call?'),
                        _Input(
                          hint: 'e.g. Ramesh Kumar',
                          controller: contactNameController,
                        ),
                        const SizedBox(height: 12),
                        const _Label('Designation (optional)'),
                        _Input(
                          hint: 'e.g. Site supervisor',
                          controller: contactDesignationController,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 11, 16, 20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (canDraft)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading ? null : () => _submit('draft'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              foregroundColor: colors.onSurface,
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                            child: Text(
                              widget.job == null
                                  ? 'Save as draft'
                                  : 'Save draft',
                            ),
                          ),
                        ),
                      if (canDraft) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: loading
                              ? null
                              : () => _submit(canDraft ? 'active' : liveStatus),
                          child: Text(
                            loading
                                ? 'Saving...'
                                : widget.job == null
                                ? 'Post job'
                                : editingDraft
                                ? 'Publish'
                                : 'Save changes',
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

class _PostJobHeader extends StatelessWidget {
  const _PostJobHeader({required this.editing, required this.draft});
  final bool editing, draft;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.brandDark, AppColors.gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x294F1B0D),
          blurRadius: 16,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? (draft ? 'DRAFT JOB' : 'JOB LISTING') : 'NEW JOB',
                style: const TextStyle(
                  color: Color(0xFFFBECE5),
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                editing ? 'Complete your listing' : 'Find the right karigar',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Add clear details to get better applications.',
                style: TextStyle(color: Color(0xFFFBECE5), fontSize: 12.5),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x40FFFFFF)),
          ),
          child: const Icon(LucideIcons.filePenLine, color: Colors.white),
        ),
      ],
    ),
  );
}

class _AiHelpCard extends StatelessWidget {
  const _AiHelpCard({
    required this.shortlistEnabled,
    required this.callEnabled,
    required this.shortlistAvailable,
    required this.callAvailable,
    required this.onShortlistChanged,
    required this.onCallChanged,
    required this.creditsEnabled,
    required this.creditsCanEnable,
    required this.creditsBalance,
    required this.creditsMinForJob,
    required this.onRecharge,
  });

  final bool shortlistEnabled, callEnabled, shortlistAvailable, callAvailable;
  final ValueChanged<bool>? onShortlistChanged, onCallChanged;
  final bool creditsEnabled, creditsCanEnable;
  final int creditsBalance, creditsMinForJob;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.brand50,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI help',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _AiSwitch(
            title: 'AI shortlist',
            description:
                'AI scores every applicant. Strong matches are shortlisted for you and clear mismatches are turned down.',
            value: shortlistEnabled,
            onChanged: onShortlistChanged,
            note: shortlistAvailable
                ? null
                : 'Switched off by the admin right now.',
          ),
          const Divider(height: 22),
          _AiSwitch(
            title: 'AI screening call',
            description:
                'An AI agent calls each auto-shortlisted karigar to check they are still interested and asks a few first questions. You get the answers.',
            value: callEnabled,
            onChanged: !creditsEnabled || creditsCanEnable
                ? onCallChanged
                : null,
            note: !callAvailable
                ? 'Switched off by the admin right now.'
                : !shortlistEnabled
                ? 'Needs AI shortlist on.'
                : creditsEnabled && !creditsCanEnable
                ? 'AI call credits: $creditsBalance · needs at least $creditsMinForJob to switch AI calls on.'
                : null,
          ),
          if (creditsEnabled && !creditsCanEnable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRecharge,
                icon: const Icon(LucideIcons.walletCards, size: 16),
                label: const Text('Recharge credits'),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Your AI preferences are applied when you save or publish this job.',
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    ),
  );
}

class _AiSwitch extends StatelessWidget {
  const _AiSwitch({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.note,
  });

  final String title, description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? note;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onChanged == null ? null : () => onChanged!(!value),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: onChanged == null ? AppColors.muted : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (note != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    note!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.foreground,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
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
    this.maxLength,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });
  final String hint;
  final int lines;
  final String? prefix;
  final String? suffix;
  final TextEditingController? controller;
  final bool number;
  final int? maxLength;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onSubmitted: onSubmitted,
    onChanged: onChanged,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    inputFormatters: number
        ? [
            FilteringTextInputFormatter.digitsOnly,
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ]
        : null,
    maxLines: lines,
    maxLength: maxLength,
    decoration: InputDecoration(
      hintText: hint,
      errorText: errorText,
      counterText: '',
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
    ),
  );
}

class _TimeInput extends StatelessWidget {
  const _TimeInput({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(LucideIcons.clock3, size: 19),
      ),
      child: Text(
        value == null ? 'Select time' : value!.format(context),
        style: TextStyle(
          color: value == null
              ? AppColors.muted
              : Theme.of(context).colorScheme.onSurface,
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: colors.surface,
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
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 19,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppColors.line2, height: 1)),
      ],
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
        color: selected ? AppColors.primary : AppColors.card,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.muted,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}
