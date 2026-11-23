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
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/location_map.dart';
import 'package:employer_kariger_app/widgets/searchable_option_sheet.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key, this.job});
  final EmployerJob? job;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

/// Tells the jobs list to open Drafts while the server safety check is queued.
enum JobPostResult { checking }

class _PostJobScreenState extends State<PostJobScreen> {
  int _step = 0;
  String jobType = 'full_time';
  String experienceLevel = 'any';
  String education = 'Below 10th pass is fine';
  String english = 'none';
  String reach = 'city';
  bool relocationAllowed = false;
  bool givesIncentive = false;
  String hiringUrgency = 'can_wait';
  final selectedLanguages = <String>{};
  final selectedAssets = <String>{};
  final workDays = <String>{'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
  final interviewDays = <String>{'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};
  final selectedSkills = <String>{};
  final _suggestedSkills = <String>{};
  String liveStatus = 'active';
  bool get editingDraft =>
      widget.job?.isDraft == true || widget.job?.status == 'draft';
  bool get canDraft => widget.job == null || editingDraft;
  final selectedPerks = <String>{};
  String shift = 'Day';
  String? gender;
  List<Map<String, String>> genderOptions = const [
    {'value': 'male', 'label': 'Male'},
    {'value': 'female', 'label': 'Female'},
    {'value': 'both', 'label': 'Male & female'},
  ];
  Map<String, _ShiftDefault> shiftDefaults = const {
    'day': _ShiftDefault('09:00', '18:00'),
    'night': _ShiftDefault('21:00', '06:00'),
  };
  final rotationalTimings = <_ShiftTiming>[];
  int maxShiftTimings = 6;
  bool _shiftTimesTouched = false;
  final workHoursController = TextEditingController();
  String workHoursPeriod = 'day';
  bool addCoreHours = false;
  TimeOfDay? coreStartTime;
  TimeOfDay? coreEndTime;
  String contact = 'Apply + Call';
  String wageType = 'monthly';
  String workMode = 'on_site';
  String interviewMode = 'on_site';
  bool _interviewModeTouched = false;
  String aiLanguage = 'en';
  String? category;
  String? state;
  String? city;
  String? contactPhoneError;
  List<String> formErrors = const [];
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
  bool _categoryWasSuggested = false;
  bool _otherCategorySelected = false;
  bool _applyingTitleProfile = false;
  bool _skillsCameFromSuggestion = false;
  List<_JobProfile> jobProfiles = const [];
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
  List<Map<String, String>> workModes = const [
    {'value': 'on_site', 'label': 'At workplace / Site'},
    {'value': 'remote', 'label': 'Work from home'},
    {'value': 'both', 'label': 'Both (Site & Home)'},
  ];
  List<Map<String, String>> interviewModes = const [
    {'value': 'on_site', 'label': 'Interview in person'},
    {'value': 'remote', 'label': 'Interview on phone / video'},
  ];
  Set<String> allowedEducation = const {};
  Set<String> allowedWorkDays = const {};
  Set<String> allowedInterviewDays = const {};
  final titleController = TextEditingController();
  final openingsController = TextEditingController(text: '1');
  final experienceController = TextEditingController(text: '0');
  final experienceMaxController = TextEditingController();
  final wageMinController = TextEditingController();
  final wageMaxController = TextEditingController();
  final descriptionController = TextEditingController();
  final contactPhoneController = TextEditingController();
  final addressController = TextEditingController();
  final areaController = TextEditingController();
  final shiftStartController = TextEditingController();
  final shiftEndController = TextEditingController();
  TimeOfDay? shiftStartTime;
  TimeOfDay? shiftEndTime;
  final contactNameController = TextEditingController();
  final contactDesignationController = TextEditingController();
  final perkController = TextEditingController();
  final incentiveMaxController = TextEditingController();
  final incentiveTypeController = TextEditingController();
  final otherRequirementsController = TextEditingController();
  final ageMinController = TextEditingController();
  final ageMaxController = TextEditingController();
  final interviewStartController = TextEditingController(text: '11:00');
  final interviewEndController = TextEditingController(text: '16:00');
  final interviewAddressController = TextEditingController();
  final workerFeePurposeController = TextEditingController();
  final _formScrollController = ScrollController();
  Timer? _titleDebounce;

  @override
  void initState() {
    super.initState();
    workHoursController.addListener(_refreshCoreHoursValidation);
    titleController.addListener(_titleChanged);

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
    gender = job.gender;
    rotationalTimings.addAll(
      job.shiftTimings.map(
        (timing) => _ShiftTiming(timing['start'] ?? '', timing['end'] ?? ''),
      ),
    );
    workHoursController.text = job.workHours == null
        ? ''
        : job.workHours!.toString().replaceFirst(RegExp(r'\.0$'), '');
    workHoursPeriod = job.workHoursPeriod ?? 'day';
    coreStartTime = _parseTime(job.coreStart);
    coreEndTime = _parseTime(job.coreEnd);
    addCoreHours = coreStartTime != null || coreEndTime != null;
    contactNameController.text = job.contactName ?? '';
    contactDesignationController.text = job.contactDesignation ?? '';
    category = job.category.isEmpty ? null : job.category;
    _otherCategorySelected = job.category.isEmpty;
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
    workMode = job.workMode;
    interviewMode = job.interviewMode;
    liveStatus = job.status == 'closed' ? 'closed' : 'active';
    aiShortlistEnabled = job.aiShortlistEnabled;
    aiCallEnabled = job.aiCallEnabled;
    jobType = job.jobType;
    education = job.education ?? education;
    english = job.english ?? english;
    reach = job.reach;
    relocationAllowed = job.relocationAllowed;
    selectedLanguages.addAll(job.languages);
    selectedAssets.addAll(job.assets);
    workDays
      ..clear()
      ..addAll(
        job.workDays.isEmpty
            ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            : job.workDays,
      );
    interviewDays
      ..clear()
      ..addAll(
        job.interviewDays.isEmpty
            ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            : job.interviewDays,
      );
    ageMinController.text = job.ageMin?.toString() ?? '';
    ageMaxController.text = job.ageMax?.toString() ?? '';
    givesIncentive = job.incentiveMax != null;
    incentiveMaxController.text = job.incentiveMax?.toString() ?? '';
    incentiveTypeController.text = job.incentiveType ?? '';
    otherRequirementsController.text = job.otherRequirements ?? '';
    interviewStartController.text = job.interviewStart ?? '11:00';
    interviewEndController.text = job.interviewEnd ?? '16:00';
    interviewAddressController.text = job.interviewAddress ?? '';
    workerFeePurposeController.text = job.workerFeePurpose ?? '';
    hiringUrgency = job.hiringUrgency;
  }

  void _titleChanged() {
    if (_applyingTitleProfile) {
      _applyingTitleProfile = false;
      return;
    }
    _titleDebounce?.cancel();
    final title = titleController.text.trim();
    if (title.length < 2) return;
    _titleDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _suggestFromTitle(title),
    );
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
      _shiftTimesTouched = true;
    });
  }

  Future<TimeOfDay?> _chooseTime(TimeOfDay? initial) => showTimePicker(
    context: context,
    initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0),
  );

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _pickRotationalTime(int index, {required bool start}) async {
    final timing = rotationalTimings[index];
    final selected = await _chooseTime(
      _parseTime(start ? timing.start : timing.end),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        timing.start = _formatTime(selected);
      } else {
        timing.end = _formatTime(selected);
      }
    });
  }

  Future<void> _pickCoreTime({required bool start}) async {
    final selected = await _chooseTime(start ? coreStartTime : coreEndTime);
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        coreStartTime = selected;
      } else {
        coreEndTime = selected;
      }
    });
  }

  void _changeShift(String value) {
    final previous = shift.toLowerCase();
    final next = value.toLowerCase();
    setState(() {
      shift = value;
      if (next == 'rotational' && rotationalTimings.isEmpty) {
        rotationalTimings.add(_ShiftTiming('', ''));
      }
      if ((next == 'day' || next == 'night') &&
          (!_shiftTimesTouched || (previous != 'day' && previous != 'night'))) {
        final defaults = shiftDefaults[next];
        if (defaults != null) {
          shiftStartController.text = defaults.start;
          shiftEndController.text = defaults.end;
          shiftStartTime = _parseTime(defaults.start);
          shiftEndTime = _parseTime(defaults.end);
        }
      }
    });
  }

  void _refreshCoreHoursValidation() {
    if (mounted) setState(() {});
  }

  String? get _coreHoursError {
    if (!addCoreHours || coreStartTime == null || coreEndTime == null)
      return null;
    final hours = num.tryParse(workHoursController.text);
    if (hours == null || hours <= 0)
      return 'Enter the total working hours first.';
    final start = coreStartTime!.hour * 60 + coreStartTime!.minute;
    final end = coreEndTime!.hour * 60 + coreEndTime!.minute;
    final core = ((end - start + 1440) % 1440) / 60;
    final daily = workHoursPeriod == 'week' ? hours / 6 : hours;
    if (core == 0 || core > daily) {
      return 'Core hours (${core.toStringAsFixed(core % 1 == 0 ? 0 : 1)} hrs) can’t be more than the working hours in a day (${daily.toStringAsFixed(daily % 1 == 0 ? 0 : 1)} hrs).';
    }
    return null;
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
        final referenceDefaults = _shiftDefaults(response['shift_defaults']);
        if (referenceDefaults.isNotEmpty) shiftDefaults = referenceDefaults;
        if (widget.job == null &&
            shiftStartTime == null &&
            shiftEndTime == null) {
          final defaults = shiftDefaults['day'];
          if (defaults != null) {
            shiftStartController.text = defaults.start;
            shiftEndController.text = defaults.end;
            shiftStartTime = _parseTime(defaults.start);
            shiftEndTime = _parseTime(defaults.end);
          }
        }
        final apiPerks = _names(response['perks']);
        states = _names(response['states']);
        if (city != null) cities = [city!];
        // Skills only make sense after the employer chooses a category. Do not
        // show the global API list (for example knitting for a logistics job).
        skills = category == null
            ? <String>[]
            : {
                ...(categorySkills[category] ?? apiSkills),
                ...selectedSkills,
              }.toList();
        perks = {...apiPerks, ...selectedPerks}.toList();
      });
      if (state != null) unawaited(_loadCities(state!, keepSelectedCity: true));
      try {
        final options = await AppScope.of(context).api.jobFormOptions();
        final profiles = (options['job_profiles'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => _JobProfile(
                title: '${item['title'] ?? ''}',
                category: '${item['category'] ?? ''}',
              ),
            )
            .where((profile) => profile.title.isNotEmpty)
            .toList();
        final ai = options['ai'];
        if (mounted) {
          final parsedWorkModes = _modeOptions(options['work_modes']);
          final parsedInterviewModes = _modeOptions(options['interview_modes']);
          if (parsedWorkModes.isNotEmpty) workModes = parsedWorkModes;
          if (parsedInterviewModes.isNotEmpty) {
            interviewModes = parsedInterviewModes;
          }
          final parsedGenders = _modeOptions(options['genders']);
          final optionEducation = _optionValues(options['education_levels']);
          final optionWorkDays = _optionValues(options['work_days']);
          final optionInterviewDays = _optionValues(
            options['interview_days'] ?? options['work_days'],
          );
          final optionDefaults = _shiftDefaults(options['shift_defaults']);
          final maxTimings = (options['max_shift_timings'] as num?)?.toInt();
          setState(() {
            if (parsedGenders.isNotEmpty) genderOptions = parsedGenders;
            if (optionEducation.isNotEmpty) allowedEducation = optionEducation;
            if (optionWorkDays.isNotEmpty) allowedWorkDays = optionWorkDays;
            if (optionInterviewDays.isNotEmpty) {
              allowedInterviewDays = optionInterviewDays;
            }
            if (optionDefaults.isNotEmpty) shiftDefaults = optionDefaults;
            if (maxTimings != null && maxTimings > 0) {
              maxShiftTimings = maxTimings;
            }
            jobProfiles = profiles;
          });
          if (ai is! Map) return;
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

  Future<void> _suggestFromTitle(String title) async {
    try {
      final suggestion = await AppScope.of(
        context,
      ).api.suggestJobCategory(title);
      if (!mounted || title != titleController.text.trim()) return;
      if (suggestion == null) {
        if (_categoryWasSuggested) {
          setState(() {
            category = null;
            _categoryWasSuggested = false;
            _otherCategorySelected = false;
            if (_skillsCameFromSuggestion) {
              selectedSkills.removeAll(_suggestedSkills);
              _suggestedSkills.clear();
              _skillsCameFromSuggestion = false;
            }
          });
          unawaited(_chooseCategory());
        }
        return;
      }
      final suggestedCategory = '${suggestion['category'] ?? ''}'.trim();
      final suggestedSkills = _names(suggestion['skills']).take(3).toSet();
      setState(() {
        if (suggestedCategory.isNotEmpty &&
            (category == null || _categoryWasSuggested)) {
          category = suggestedCategory;
          _categoryWasSuggested = true;
          _otherCategorySelected = false;
          skills = {
            ...(categorySkills[suggestedCategory] ?? skills),
            ...selectedSkills,
          }.toList();
        }
        if (suggestedSkills.isNotEmpty &&
            (selectedSkills.isEmpty || _skillsCameFromSuggestion)) {
          selectedSkills
            ..clear()
            ..addAll(suggestedSkills);
          _suggestedSkills
            ..clear()
            ..addAll(suggestedSkills);
          _skillsCameFromSuggestion = true;
        }
      });
    } catch (_) {
      // Suggestions are optional; posting stays available when the endpoint is offline.
    }
  }

  void _selectJobProfile(_JobProfile picked) {
    _titleDebounce?.cancel();
    setState(() {
      _applyingTitleProfile = true;
      titleController.text = picked.title;
      category = picked.category;
      _categoryWasSuggested = false;
      _otherCategorySelected = false;
      skills = {
        ...(categorySkills[picked.category] ?? skills),
        ...selectedSkills,
      }.toList();
    });
  }

  void _addOwnTitle() {
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    _titleDebounce?.cancel();
    unawaited(_suggestFromTitle(title));
  }

  Future<void> _chooseCategory() async {
    final result = await showSearchableOptionSheet(
      context,
      title: 'Select category',
      values: [...categories, 'Other (not in the list)'],
    );
    if (result == null || !mounted) return;
    setState(() {
      _otherCategorySelected = result == 'Other (not in the list)';
      category = _otherCategorySelected ? null : result;
      _categoryWasSuggested = false;
      if (!_otherCategorySelected) {
        skills = {
          ...(categorySkills[result] ?? skills),
          ...selectedSkills,
        }.toList();
      }
    });
  }

  List<String> _names(dynamic value) => (value as List? ?? const [])
      .map((item) {
        if (item is Map) return '${item['name'] ?? item['label'] ?? ''}';
        return '$item';
      })
      .where((item) => item.isNotEmpty)
      .toList();

  List<Map<String, String>> _modeOptions(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => {
              'value': '${item['value'] ?? ''}',
              'label': '${item['label'] ?? item['value'] ?? ''}',
            },
          )
          .where((item) => item['value']!.isNotEmpty)
          .toList();

  Set<String> _optionValues(dynamic value) => (value as List? ?? const [])
      .map((item) {
        if (item is Map)
          return '${item['value'] ?? item['key'] ?? item['id'] ?? ''}';
        return '$item';
      })
      .where((item) => item.isNotEmpty)
      .toSet();

  Map<String, _ShiftDefault> _shiftDefaults(dynamic value) {
    if (value is! Map) return const {};
    final defaults = <String, _ShiftDefault>{};
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      final item = entry.value as Map;
      final start = '${item['start'] ?? ''}';
      final end = '${item['end'] ?? ''}';
      if (start.isNotEmpty && end.isNotEmpty) {
        defaults['${entry.key}'.toLowerCase()] = _ShiftDefault(start, end);
      }
    }
    return defaults;
  }

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

  Future<void> _pinFromEnteredLocation() async {
    final query = [
      areaController.text.trim(),
      ?city,
      ?state,
      'India',
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
    if (query.isEmpty) return;
    try {
      final places = await locationFromAddress(query);
      if (!mounted || places.isEmpty) return;
      setState(
        () => selectedLocation = LatLng(
          places.first.latitude,
          places.first.longitude,
        ),
      );
    } catch (_) {
      // Leave manual entry usable when device geocoding is unavailable.
    }
  }

  Future<void> _syncLocationFromMap(LatLng point) async {
    setState(() => selectedLocation = point);
    try {
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (!mounted || places.isEmpty) return;
      final place = places.first;
      final detectedState = place.administrativeArea?.trim();
      final detectedCity =
          (place.locality?.trim().isNotEmpty == true
                  ? place.locality
                  : place.subAdministrativeArea)
              ?.trim();
      if (detectedState != null &&
          detectedState.isNotEmpty &&
          state != detectedState) {
        await _loadCities(detectedState);
      }
      if (!mounted) return;
      setState(() {
        if (detectedCity != null && detectedCity.isNotEmpty) {
          city = detectedCity;
        }
        final area = place.subLocality?.trim() ?? place.thoroughfare?.trim();
        if (area != null && area.isNotEmpty) areaController.text = area;
      });
    } catch (_) {
      // Keep the selected coordinates when reverse geocoding is unavailable.
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
    final workHours = num.tryParse(workHoursController.text);
    final shiftValue = shift.toLowerCase();
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
    if (!draft && category == null && !_otherCategorySelected) {
      _message('Pick a category, or Other if none fits.');
      return;
    }
    if (!draft &&
        (description.isEmpty ||
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
        givesIncentive &&
        (double.tryParse(incentiveMaxController.text.trim()) ?? 0) <= 0) {
      _message('Enter the monthly bonus or incentive amount.');
      return;
    }
    final ageMin = int.tryParse(ageMinController.text.trim());
    final ageMax = int.tryParse(ageMaxController.text.trim());
    if (!draft &&
        ((ageMin != null && ageMin < 18) ||
            (ageMax != null && ageMax < 18) ||
            (ageMin != null && ageMax != null && ageMax < ageMin))) {
      _message(
        'Age must be 18–70 and the maximum cannot be lower than minimum.',
      );
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
        (shiftValue == 'day' || shiftValue == 'night') &&
        ((shiftStartController.text.trim().isEmpty) !=
            (shiftEndController.text.trim().isEmpty))) {
      _message('Enter both shift start and end times, or leave both blank.');
      return;
    }
    if (!draft && shiftValue == 'rotational') {
      for (var index = 0; index < rotationalTimings.length; index++) {
        final timing = rotationalTimings[index];
        if (timing.start.isEmpty ||
            timing.end.isEmpty ||
            timing.start == timing.end) {
          _message('Shift ${index + 1} needs different start and end times.');
          return;
        }
      }
    }
    if (!draft && shiftValue == 'flexible') {
      final maximum = workHoursPeriod == 'week' ? 168 : 24;
      if (workHours == null || workHours <= 0 || workHours > maximum) {
        _message(
          'Enter working hours between 1 and $maximum per $workHoursPeriod.',
        );
        return;
      }
      if (addCoreHours && (coreStartTime == null || coreEndTime == null)) {
        _message('Enter both core working hours.');
        return;
      }
      if (addCoreHours) {
        if (_coreHoursError != null) {
          _message(_coreHoursError!);
          return;
        }
      }
    }
    if (!draft &&
        contactMode != 'apply' &&
        !RegExp(r'^[6-9]\d{9}$').hasMatch(contactPhoneController.text.trim())) {
      _message('Enter a valid 10-digit contact number.');
      return;
    }
    if (!draft &&
        contactMode != 'apply' &&
        contactDesignationController.text.trim().isEmpty) {
      _message('Enter the designation of the person who picks up calls.');
      return;
    }
    final values = <String, dynamic>{
      'title': title,
      'job_type': jobType,
      if (description.isNotEmpty) 'description': description,
      'category': ?category,
      'gender': ?gender,
      if (allowedEducation.contains(education)) 'education': education,
      'english': english,
      'reach': reach,
      'relocation_allowed': relocationAllowed,
      'languages': selectedLanguages.toList(),
      'assets': selectedAssets.toList(),
      if (workDays.any(allowedWorkDays.contains))
        'work_days': workDays.where(allowedWorkDays.contains).toList(),
      if (interviewDays.any(allowedInterviewDays.contains))
        'interview_days': interviewDays
            .where(allowedInterviewDays.contains)
            .toList(),
      'hiring_urgency': hiringUrgency,
      if (experienceLevel == 'freshers') 'experience_min': 0,
      if (experienceLevel == 'freshers') 'experience_max': 0,
      if (ageMinController.text.trim().isNotEmpty)
        'age_min': int.tryParse(ageMinController.text.trim()),
      if (ageMaxController.text.trim().isNotEmpty)
        'age_max': int.tryParse(ageMaxController.text.trim()),
      if (givesIncentive)
        'incentive_max': double.tryParse(incentiveMaxController.text.trim()),
      if (givesIncentive && incentiveTypeController.text.trim().isNotEmpty)
        'incentive_type': incentiveTypeController.text.trim(),
      if (otherRequirementsController.text.trim().isNotEmpty)
        'other_requirements': otherRequirementsController.text.trim(),
      if (!draft || selectedSkills.isNotEmpty)
        'skills': selectedSkills.toList(),
      if (wageMin != null && wageMin >= 0) 'wage_min': wageMin,
      if (wageMax != null && wageMax >= (wageMin ?? 0)) 'wage_max': wageMax,
      if (!draft || wageMin != null || wageMax != null) 'wage_type': wageType,
      'city': ?city,
      'state': ?state,
      if (areaController.text.trim().isNotEmpty ||
          addressController.text.trim().isNotEmpty)
        'address': [
          if (areaController.text.trim().isNotEmpty)
            'Area: ${areaController.text.trim()}',
          if (addressController.text.trim().isNotEmpty)
            addressController.text.trim(),
        ].join(', '),
      if (selectedLocation != null) 'latitude': selectedLocation!.latitude,
      if (selectedLocation != null) 'longitude': selectedLocation!.longitude,
      if (!draft && vacancies != null && vacancies > 0) 'vacancies': vacancies,
      if (!draft || (experience != null && experience > 0))
        'experience_min': experience != null && experience >= 0
            ? experience
            : 0,
      if (experienceMax != null && experienceMax >= 0)
        'experience_max': experienceMax,
      if (!draft) 'shift': shiftValue,
      if ((shiftValue == 'day' || shiftValue == 'night') &&
          shiftStartController.text.trim().isNotEmpty)
        'shift_start': shiftStartController.text.trim(),
      if ((shiftValue == 'day' || shiftValue == 'night') &&
          shiftEndController.text.trim().isNotEmpty)
        'shift_end': shiftEndController.text.trim(),
      if (shiftValue == 'rotational')
        'shift_timings': rotationalTimings
            .where((timing) => timing.start.isNotEmpty || timing.end.isNotEmpty)
            .map((timing) => {'start': timing.start, 'end': timing.end})
            .toList(),
      if (shiftValue == 'flexible' && workHours != null)
        'work_hours': workHours,
      if (shiftValue == 'flexible' && workHours != null)
        'work_hours_period': workHoursPeriod,
      if (shiftValue == 'flexible' && addCoreHours && coreStartTime != null)
        'core_start': _formatTime(coreStartTime!),
      if (shiftValue == 'flexible' && addCoreHours && coreEndTime != null)
        'core_end': _formatTime(coreEndTime!),
      if (!draft || selectedPerks.isNotEmpty) 'perks': selectedPerks.toList(),
      'contact_mode':
          draft &&
              !RegExp(
                r'^[6-9]\d{9}$',
              ).hasMatch(contactPhoneController.text.trim())
          ? 'apply'
          : contactMode,
      'work_mode': workMode,
      'interview_mode': interviewMode,
      if (interviewStartController.text.trim().isNotEmpty)
        'interview_start': interviewStartController.text.trim(),
      if (interviewEndController.text.trim().isNotEmpty)
        'interview_end': interviewEndController.text.trim(),
      if (interviewAddressController.text.trim().isNotEmpty)
        'interview_address': interviewAddressController.text.trim(),
      if (workerFeePurposeController.text.trim().isNotEmpty)
        'worker_fee_purpose': workerFeePurposeController.text.trim(),
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
      if (response['code'] == 'job_checking') {
        await _showJobCheckingDialog(
          response['message']?.toString() ??
              'We are running a quick safety check. Your job will go live in a minute or two.',
        );
        if (mounted) Navigator.pop(context, JobPostResult.checking);
        return;
      }
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
              exception.code == 'subscription_required' ||
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
                  Text(
                    exception.code == 'subscription_required'
                        ? 'Renew your plan'
                        : 'Choose a plan to continue',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
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
                    child: Text(
                      exception.code == 'subscription_required'
                          ? 'Renew plan'
                          : 'See plans',
                    ),
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
        final errors = exception.errors?.values
            .expand((value) => value is List ? value : [value])
            .map((value) => '$value')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
        setState(
          () => formErrors = errors?.isNotEmpty == true
              ? errors!
              : [exception.message],
        );
        if (_formScrollController.hasClients) {
          await _formScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (exception) {
      if (mounted) _message('$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showJobCheckingDialog(String message) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                // Keep both dimensions fixed so the spinner cannot be stretched
                // by a dialog layout constraint on wider screens.
                child: SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Checking your job',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('View my jobs'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

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

  void _message(String text) {
    if (!mounted) return;
    setState(() => formErrors = [text]);
    if (_formScrollController.hasClients) {
      unawaited(
        _formScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _goNext() {
    if (shift.toLowerCase() == 'flexible' && _coreHoursError != null) {
      _message(_coreHoursError!);
      return;
    }
    setState(() => _step++);
  }

  Widget _flowPanel() {
    const labels = [
      'Job basics',
      'Who you need',
      'Timings & interview',
      'Review & post',
    ];
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step ${_step + 1} of 4',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _step = index),
                    child: Container(
                      margin: EdgeInsets.only(right: index == 3 ? 0 : 5),
                      height: 5,
                      decoration: BoxDecoration(
                        color: index <= _step
                            ? AppColors.primary
                            : AppColors.line,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              labels[_step],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _step == 0
                  ? 'Start with the role, location and pay.'
                  : _step == 1
                  ? 'Set the requirements that matter for this role.'
                  : _step == 2
                  ? 'Give clear work and interview details.'
                  : 'Check the job before it goes live.',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (_step == 0) ...[
              const SizedBox(height: 14),
              const _Label('Job type'),
              _singleChips(
                ['full_time', 'part_time'],
                jobType,
                (value) => setState(() => jobType = value),
              ),
              const SizedBox(height: 12),
              const _Label('Bonus or incentive on top of salary?'),
              _singleChips(
                ['No', 'Yes'],
                givesIncentive ? 'Yes' : 'No',
                (value) => setState(() => givesIncentive = value == 'Yes'),
              ),
              if (givesIncentive) ...[
                const SizedBox(height: 8),
                _Input(
                  hint: 'Up to ₹ a month',
                  prefix: '₹',
                  controller: incentiveMaxController,
                  number: true,
                ),
                const SizedBox(height: 8),
                _Input(
                  hint: 'What it is for (e.g. overtime)',
                  controller: incentiveTypeController,
                ),
              ],
              const SizedBox(height: 8),
              _Input(
                hint: 'Anything else you need? (optional)',
                controller: otherRequirementsController,
                lines: 2,
              ),
            ] else if (_step == 1) ...[
              const SizedBox(height: 14),
              const _Label('Experience'),
              _singleChips(
                ['any', 'freshers', 'experienced'],
                experienceLevel,
                (value) => setState(() => experienceLevel = value),
              ),
              const SizedBox(height: 12),
              const _Label('Minimum education'),
              _singleChips(
                [
                  'Below 10th pass is fine',
                  '10th pass or above',
                  '12th pass or above',
                ],
                education,
                (value) => setState(() => education = value),
              ),
              const SizedBox(height: 12),
              const _Label('English needed'),
              _singleChips(
                ['none', 'basic', 'good', 'fluent'],
                english,
                (value) => setState(() => english = value),
              ),
              const SizedBox(height: 12),
              const _Label('Get karigars from'),
              _singleChips(
                ['nearby', 'city'],
                reach,
                (value) => setState(() => reach = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow karigars moving from another city'),
                value: relocationAllowed,
                onChanged: (value) => setState(() => relocationAllowed = value),
              ),
              const _Label('More requirements: age (optional)'),
              Row(
                children: [
                  Expanded(
                    child: _Input(
                      hint: 'Min 18',
                      controller: ageMinController,
                      number: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Input(
                      hint: 'Max 70',
                      controller: ageMaxController,
                      number: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _Label('Languages (optional)'),
              _chips(
                ['Hindi', 'English', 'Marathi', 'Bengali', 'Tamil'],
                selectedLanguages,
                multi: true,
              ),
              const SizedBox(height: 12),
              const _Label('They must have (optional)'),
              _chips(
                [
                  'Aadhaar card',
                  'PAN card',
                  'Bank account',
                  'Smartphone',
                  'Bike',
                  'Driving licence',
                  'Own tools',
                ],
                selectedAssets,
                multi: true,
              ),
            ] else if (_step == 2) ...[
              const SizedBox(height: 14),
              const _Label('Working days'),
              _dayChips(workDays),
              const SizedBox(height: 12),
              const _Label('Interview days'),
              _dayChips(interviewDays),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Input(
                      hint: 'Interview from (11:00)',
                      controller: interviewStartController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Input(
                      hint: 'Interview to (16:00)',
                      controller: interviewEndController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Input(
                hint: 'Different interview address (optional)',
                controller: interviewAddressController,
              ),
            ] else ...[
              const SizedBox(height: 12),
              _ReviewLine(
                'Role',
                titleController.text.trim().isEmpty
                    ? 'Add a job title below'
                    : titleController.text.trim(),
              ),
              _ReviewLine(
                'Location',
                [city, state].whereType<String>().join(', ').isEmpty
                    ? 'Add city and state below'
                    : [city, state].whereType<String>().join(', '),
              ),
              _ReviewLine(
                'Reach',
                reach == 'nearby'
                    ? 'Nearby (within 10 km)'
                    : 'Anywhere in the city',
              ),
              const SizedBox(height: 8),
              const Text(
                'Never ask a karigar for money that is not written on this job.',
                style: TextStyle(color: AppColors.amber, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dayChips(Set<String> selected) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        .map(
          (day) => _Choice(
            text: day,
            selected: selected.contains(day),
            onTap: () => setState(
              () => selected.contains(day)
                  ? selected.remove(day)
                  : selected.add(day),
            ),
          ),
        )
        .toList(),
  );

  @override
  void dispose() {
    _titleDebounce?.cancel();
    workHoursController.removeListener(_refreshCoreHoursValidation);
    titleController.removeListener(_titleChanged);
    titleController.dispose();
    openingsController.dispose();
    experienceController.dispose();
    experienceMaxController.dispose();
    wageMinController.dispose();
    wageMaxController.dispose();
    descriptionController.dispose();
    contactPhoneController.dispose();
    addressController.dispose();
    areaController.dispose();
    shiftStartController.dispose();
    shiftEndController.dispose();
    workHoursController.dispose();
    contactNameController.dispose();
    contactDesignationController.dispose();
    perkController.dispose();
    incentiveMaxController.dispose();
    incentiveTypeController.dispose();
    otherRequirementsController.dispose();
    ageMinController.dispose();
    ageMaxController.dispose();
    interviewStartController.dispose();
    interviewEndController.dispose();
    interviewAddressController.dispose();
    workerFeePurposeController.dispose();
    _formScrollController.dispose();
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
                    controller: _formScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      if (formErrors.isNotEmpty) ...[
                        _JobErrorSummary(
                          errors: formErrors,
                          onDismiss: () =>
                              setState(() => formErrors = const []),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _PostJobHeader(
                        editing: widget.job != null,
                        draft: editingDraft,
                      ),
                      const SizedBox(height: 12),
                      _flowPanel(),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '* Required fields',
                          style: TextStyle(
                            color: AppColors.rose,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label('Job title', required: true),
                                _JobTitlePicker(
                                  controller: titleController,
                                  profiles: jobProfiles,
                                  onProfileSelected: _selectJobProfile,
                                  onAddOwnTitle: _addOwnTitle,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label('Category', required: true),
                                _Select(
                                  _otherCategorySelected
                                      ? 'Other (not in the list)'
                                      : category ?? 'Select category',
                                  onTap: _chooseCategory,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const _Hint('Pick from the list, or add your own title.'),
                      if (_otherCategorySelected) ...[
                        const SizedBox(height: 6),
                        const _Hint(
                          'Karigars find this job only by searching. If a craft comes close, pick that instead.',
                        ),
                      ] else if (_categoryWasSuggested) ...[
                        const SizedBox(height: 6),
                        const _Hint(
                          'Suggested from the job title. Change it if it is wrong.',
                        ),
                      ] else if (titleController.text.trim().isNotEmpty &&
                          category == null) ...[
                        const SizedBox(height: 6),
                        const _Hint(
                          'Pick the closest craft, so the right karigars get this job.',
                        ),
                      ],
                      const SizedBox(height: 14),
                      const _Label('Who can apply'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Choice(
                            text: 'Not specified',
                            selected: gender == null,
                            onTap: () => setState(() => gender = null),
                          ),
                          ...genderOptions.map(
                            (option) => _Choice(
                              text: option['label']!,
                              selected: gender == option['value'],
                              onTap: () =>
                                  setState(() => gender = option['value']),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _Label('Skills required'),
                      if (category == null)
                        const _Hint(
                          'Select a category first to see matching skills.',
                        )
                      else ...[
                        if (selectedSkills.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedSkills
                                .map(
                                  (skill) => InputChip(
                                    label: Text(skill),
                                    onDeleted: () => setState(() {
                                      selectedSkills.remove(skill);
                                      _suggestedSkills.remove(skill);
                                      _skillsCameFromSuggestion = false;
                                    }),
                                  ),
                                )
                                .toList(),
                          ),
                        if (selectedSkills.isNotEmpty)
                          const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skills
                              .where((skill) => !selectedSkills.contains(skill))
                              .map(
                                (skill) => _Choice(
                                  text: skill,
                                  selected: false,
                                  onTap: () => setState(() {
                                    selectedSkills.add(skill);
                                    _skillsCameFromSuggestion = false;
                                  }),
                                ),
                              )
                              .toList(),
                        ),
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
                                _skillsCameFromSuggestion = false;
                                perkController.clear();
                              });
                            }
                          },
                        ),
                        const _Hint(
                          'Tap to add. Karigars with these skills are matched first.',
                        ),
                      ],
                      const _SectionLabel('Work setup'),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label('Openings', required: true),
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
                                const _Label('Minimum / month', required: true),
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
                        _changeShift,
                      ),
                      const SizedBox(height: 14),
                      if (shift == 'Day' || shift == 'Night')
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
                        )
                      else if (shift == 'Rotational')
                        _RotationalShiftEditor(
                          timings: rotationalTimings,
                          maxTimings: maxShiftTimings,
                          onPick: _pickRotationalTime,
                          onAdd: () => setState(
                            () => rotationalTimings.add(_ShiftTiming('', '')),
                          ),
                          onRemove: (index) =>
                              setState(() => rotationalTimings.removeAt(index)),
                        )
                      else
                        _FlexibleShiftEditor(
                          hoursController: workHoursController,
                          period: workHoursPeriod,
                          addCoreHours: addCoreHours,
                          coreStart: coreStartTime,
                          coreEnd: coreEndTime,
                          coreHoursError: _coreHoursError,
                          onPeriodChanged: (value) =>
                              setState(() => workHoursPeriod = value),
                          onCoreChanged: (value) =>
                              setState(() => addCoreHours = value),
                          onPickCore: _pickCoreTime,
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
                          const _Label('Job description', required: true),
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
                      const _SectionLabel('Work & interview'),
                      _WorkInterviewCard(
                        workMode: workMode,
                        interviewMode: interviewMode,
                        workModes: workModes,
                        interviewModes: interviewModes,
                        showAiNote: aiCallAvailable,
                        onWorkModeChanged: (value) => setState(() {
                          workMode = value;
                          if (value == 'remote' && !_interviewModeTouched) {
                            interviewMode = 'remote';
                          }
                        }),
                        onInterviewModeChanged: (value) => setState(() {
                          interviewMode = value;
                          _interviewModeTouched = true;
                        }),
                      ),
                      const _SectionLabel('Location'),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Label('State', required: true),
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
                                const _Label('City', required: true),
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
                                        unawaited(_pinFromEnteredLocation());
                                      }, citySearch: true);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _Label('Area / locality'),
                      _Input(
                        hint: 'e.g. Sector 45, Andheri West',
                        controller: areaController,
                        onSubmitted: (_) => _pinFromEnteredLocation(),
                      ),
                      const SizedBox(height: 14),
                      const _Label('Address / landmark'),
                      _Input(
                        hint: 'Plot, street or landmark',
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
                              unawaited(_syncLocationFromMap(point)),
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
                        const _Label('Contact phone', required: true),
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
                        const _Label('Designation', required: true),
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
                      if (_step > 0) ...[
                        IconButton(
                          tooltip: 'Back',
                          onPressed: loading
                              ? null
                              : () => setState(() => _step--),
                          icon: const Icon(LucideIcons.arrowLeft),
                        ),
                      ],
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
                              : _step < 3
                              ? _goNext
                              : () => _submit(canDraft ? 'active' : liveStatus),
                          child: Text(
                            loading
                                ? 'Saving...'
                                : _step < 3
                                ? 'Next'
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
    ValueChanged<String> onSelected, {
    bool citySearch = false,
  }) async {
    if (values.isEmpty) {
      _message('Options are not available yet. Please try again.');
      return;
    }
    final result = await showSearchableOptionSheet(
      context,
      title: title,
      values: values,
      citySearch: citySearch,
      stateName: state,
    );
    if (result != null) onSelected(result);
  }
}

class _ShiftDefault {
  const _ShiftDefault(this.start, this.end);
  final String start, end;
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _ShiftTiming {
  _ShiftTiming(this.start, this.end);
  String start, end;
}

class _RotationalShiftEditor extends StatelessWidget {
  const _RotationalShiftEditor({
    required this.timings,
    required this.maxTimings,
    required this.onPick,
    required this.onAdd,
    required this.onRemove,
  });
  final List<_ShiftTiming> timings;
  final int maxTimings;
  final Future<void> Function(int, {required bool start}) onPick;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ...timings.indexed.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 54, child: Text('Shift ${entry.$1 + 1}')),
              Expanded(
                child: _TimeInput(
                  label: 'Start',
                  value: _parse(entry.$2.start),
                  onTap: () => onPick(entry.$1, start: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeInput(
                  label: 'End',
                  value: _parse(entry.$2.end),
                  onTap: () => onPick(entry.$1, start: false),
                ),
              ),
              IconButton(
                tooltip: 'Remove shift timing',
                onPressed: timings.length > 1 ? () => onRemove(entry.$1) : null,
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: timings.length < maxTimings ? onAdd : null,
          icon: const Icon(LucideIcons.plus, size: 17),
          label: const Text('Add Shift Timing'),
        ),
      ),
    ],
  );

  TimeOfDay? _parse(String value) {
    final pieces = value.split(':');
    if (pieces.length != 2) return null;
    final hour = int.tryParse(pieces[0]);
    final minute = int.tryParse(pieces[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _FlexibleShiftEditor extends StatelessWidget {
  const _FlexibleShiftEditor({
    required this.hoursController,
    required this.period,
    required this.addCoreHours,
    required this.coreStart,
    required this.coreEnd,
    this.coreHoursError,
    required this.onPeriodChanged,
    required this.onCoreChanged,
    required this.onPickCore,
  });
  final TextEditingController hoursController;
  final String period;
  final bool addCoreHours;
  final TimeOfDay? coreStart, coreEnd;
  final String? coreHoursError;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<bool> onCoreChanged;
  final Future<void> Function({required bool start}) onPickCore;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: _Input(
              hint: '8',
              suffix: 'hours',
              controller: hoursController,
              number: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _singlePeriod(context)),
        ],
      ),
      const SizedBox(height: 8),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: addCoreHours,
        onChanged: onCoreChanged,
        title: const Text('Add Core Working Hours'),
        subtitle: const Text(
          'Time window when employee must be online/available',
          style: TextStyle(fontSize: 12),
        ),
      ),
      if (addCoreHours) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _TimeInput(
                label: 'Core start',
                value: coreStart,
                onTap: () => onPickCore(start: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeInput(
                label: 'Core end',
                value: coreEnd,
                onTap: () => onPickCore(start: false),
              ),
            ),
          ],
        ),
        if (coreHoursError != null) ...[
          const SizedBox(height: 8),
          Text(
            coreHoursError!,
            style: const TextStyle(color: AppColors.rose, fontSize: 12),
          ),
        ],
      ],
    ],
  );

  Widget _singlePeriod(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: period,
    decoration: const InputDecoration(labelText: 'Period'),
    items: const [
      DropdownMenuItem(value: 'day', child: Text('Per day')),
      DropdownMenuItem(value: 'week', child: Text('Per week')),
    ],
    onChanged: (value) {
      if (value != null) onPeriodChanged(value);
    },
  );
}

class _JobProfile {
  const _JobProfile({required this.title, required this.category});

  final String title;
  final String category;
}

class _JobTitlePicker extends StatefulWidget {
  const _JobTitlePicker({
    required this.controller,
    required this.profiles,
    required this.onProfileSelected,
    required this.onAddOwnTitle,
  });

  final TextEditingController controller;
  final List<_JobProfile> profiles;
  final ValueChanged<_JobProfile> onProfileSelected;
  final VoidCallback onAddOwnTitle;

  @override
  State<_JobTitlePicker> createState() => _JobTitlePickerState();
}

class _JobTitlePickerState extends State<_JobTitlePicker> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focusNode.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _JobTitlePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focusNode
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  int _rank(_JobProfile profile, String query) {
    final title = profile.title.toLowerCase();
    if (title.startsWith(query)) return 0;
    if (title
        .split(RegExp(r'[^a-z0-9]+'))
        .any((word) => word.startsWith(query))) {
      return 1;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim();
    final normalized = query.toLowerCase();
    final matches = normalized.isEmpty
        ? <_JobProfile>[]
        : widget.profiles
              .where(
                (profile) => profile.title.toLowerCase().contains(normalized),
              )
              .toList();
    matches.sort((a, b) {
      final rank = _rank(a, normalized).compareTo(_rank(b, normalized));
      return rank != 0 ? rank : a.title.compareTo(b.title);
    });
    final exactMatch = widget.profiles.any(
      (profile) => profile.title.toLowerCase() == normalized,
    );
    final showChoices = _focusNode.hasFocus && query.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLength: 255,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Type job title',
            counterText: '',
            prefixIcon: Icon(LucideIcons.search, size: 18),
          ),
        ),
        if (showChoices)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                ...matches
                    .take(8)
                    .map(
                      (profile) => _JobTitleOption(
                        profile: profile,
                        query: query,
                        onTap: () {
                          widget.onProfileSelected(profile);
                          _focusNode.unfocus();
                        },
                      ),
                    ),
                if (!exactMatch)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      LucideIcons.plus,
                      color: colors.primary,
                      size: 18,
                    ),
                    title: Text('Add "$query"'),
                    onTap: () {
                      widget.onAddOwnTitle();
                      _focusNode.unfocus();
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _JobTitleOption extends StatelessWidget {
  const _JobTitleOption({
    required this.profile,
    required this.query,
    required this.onTap,
  });

  final _JobProfile profile;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = profile.title;
    final index = title.toLowerCase().indexOf(query.toLowerCase());
    final style = DefaultTextStyle.of(context).style;
    final highlighted = index < 0
        ? TextSpan(text: title)
        : TextSpan(
            children: [
              TextSpan(text: title.substring(0, index)),
              TextSpan(
                text: title.substring(index, index + query.length),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: title.substring(index + query.length)),
            ],
          );
    return ListTile(
      dense: true,
      title: Text.rich(highlighted, style: style),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 105),
        child: Text(
          profile.category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _WorkInterviewCard extends StatelessWidget {
  const _WorkInterviewCard({
    required this.workMode,
    required this.interviewMode,
    required this.workModes,
    required this.interviewModes,
    required this.showAiNote,
    required this.onWorkModeChanged,
    required this.onInterviewModeChanged,
  });
  final String workMode, interviewMode;
  final List<Map<String, String>> workModes, interviewModes;
  final bool showAiNote;
  final ValueChanged<String> onWorkModeChanged, onInterviewModeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget options(
      List<Map<String, String>> values,
      String selected,
      ValueChanged<String> onChanged,
    ) => Column(
      children: values.map((item) {
        final value = item['value']!;
        final active = selected == value;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: active
                    ? colors.primaryContainer
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? colors.primary : colors.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    active ? LucideIcons.circleDot : LucideIcons.circle,
                    size: 18,
                    color: active
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where will the karigar work?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          options(workModes, workMode, onWorkModeChanged),
          const SizedBox(height: 16),
          const Text(
            'How will you take the interview?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          options(interviewModes, interviewMode, onInterviewModeChanged),
          if (showAiNote) ...[
            const SizedBox(height: 12),
            Text(
              'The AI call asks whether the karigar can come to the location, or has the space and tools to work from home.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
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
  const _Label(this.text, {this.required = false});
  final String text;
  final bool required;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.rose),
            ),
        ],
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _JobErrorSummary extends StatelessWidget {
  const _JobErrorSummary({required this.errors, required this.onDismiss});
  final List<String> errors;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
    decoration: BoxDecoration(
      color: AppColors.rose.withValues(alpha: .10),
      border: Border.all(color: AppColors.rose.withValues(alpha: .4)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(LucideIcons.circleAlert, color: AppColors.rose, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please fix these details',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              ...errors.map(
                (error) =>
                    Text('• $error', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onDismiss,
          icon: const Icon(LucideIcons.x, size: 18),
        ),
      ],
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
