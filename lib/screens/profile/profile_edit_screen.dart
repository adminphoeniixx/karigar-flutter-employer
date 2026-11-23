import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/common.dart';
import 'package:employer_kariger_app/widgets/location_map.dart';
import 'package:employer_kariger_app/widgets/searchable_option_sheet.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _GstinFormatter extends TextInputFormatter {
  const _GstinFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final limited = text.length > 15 ? text.substring(0, 15) : text;
    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: limited.length),
    );
  }
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  LatLng _siteLocation = const LatLng(13.0827, 80.2707);
  final emailController = TextEditingController();
  final gstinController = TextEditingController();
  final gstinFocusNode = FocusNode();
  final companyController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final industryController = TextEditingController();
  final aboutController = TextEditingController();
  final stateController = TextEditingController();
  final cityController = TextEditingController();
  bool loading = true;
  bool saving = false;
  String? gstinError;
  bool uploadingLogo = false;
  bool _loaded = false;
  List<String> hiringCategories = const [];
  List<String> states = const [];
  List<String> cities = const [];
  final selectedHiringCategories = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final controller = AppScope.of(context).profile;
    await controller.load();
    final profile = controller.profile;
    if (!mounted) return;
    if (profile != null) {
      companyController.text = profile.companyName;
      emailController.text = (profile.email ?? '').endsWith('@phone.karigar')
          ? ''
          : profile.email ?? '';
      gstinController.text = profile.gstin ?? '';
      nameController.text = profile.name;
      phoneController.text = profile.phone ?? '';
      industryController.text = profile.industry ?? '';
      aboutController.text = profile.about ?? '';
      stateController.text = profile.state ?? '';
      cityController.text = profile.city ?? '';
      selectedHiringCategories
        ..clear()
        ..addAll(profile.hiringCategories);
      if (profile.latitude != null && profile.longitude != null) {
        _siteLocation = LatLng(profile.latitude!, profile.longitude!);
      }
    }
    try {
      final reference = await AppScope.of(context).api.reference();
      if (!mounted) return;
      final categories = (reference['job_categories'] as List? ?? const [])
          .map(
            (item) => item is Map
                ? '${item['name'] ?? item['label'] ?? ''}'
                : '$item',
          )
          .where((item) => item.isNotEmpty)
          .toList();
      final referenceStates = (reference['states'] as List? ?? const [])
          .map(
            (item) => item is Map
                ? '${item['name'] ?? item['label'] ?? ''}'
                : '$item',
          )
          .where((item) => item.isNotEmpty)
          .toList();
      setState(() {
        hiringCategories = {
          ...categories,
          ...selectedHiringCategories,
        }.toList();
        states = {
          ...referenceStates,
          stateController.text,
        }.where((item) => item.isNotEmpty).toList();
      });
      if (stateController.text.isNotEmpty)
        await _loadCities(stateController.text, keepCity: true);
    } catch (_) {
      // Keep the saved categories visible if reference data is temporarily unavailable.
    }
    setState(() => loading = false);
  }

  Future<void> _loadCities(
    String selectedState, {
    bool keepCity = false,
  }) async {
    setState(() {
      stateController.text = selectedState;
      if (!keepCity) cityController.clear();
      cities = const [];
    });
    try {
      final result = await AppScope.of(context).api.cities(selectedState);
      if (mounted && stateController.text == selectedState) {
        setState(
          () => cities = {
            ...result,
            cityController.text,
          }.where((item) => item.isNotEmpty).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _pickState() async {
    final picked = await showSearchableOptionSheet(
      context,
      title: 'Select state',
      values: states,
    );
    if (picked != null && mounted) _loadCities(picked);
  }

  Future<void> _pickCity() async {
    if (stateController.text.isEmpty) return;
    final picked = await showSearchableOptionSheet(
      context,
      title: 'Select city',
      values: cities,
      citySearch: true,
      stateName: stateController.text,
    );
    if (picked != null && mounted) {
      setState(() => cityController.text = picked);
      _pinFromEnteredLocation();
    }
  }

  Future<void> _pinFromEnteredLocation() async {
    final query = [
      cityController.text.trim(),
      stateController.text.trim(),
      'India',
    ].where((part) => part.isNotEmpty).join(', ');
    if (query.isEmpty) return;
    try {
      final places = await locationFromAddress(query);
      if (!mounted || places.isEmpty) return;
      setState(
        () => _siteLocation = LatLng(
          places.first.latitude,
          places.first.longitude,
        ),
      );
    } catch (_) {
      // The location can still be chosen directly on the map.
    }
  }

  Future<void> _save() async {
    if (saving) return;
    if (companyController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business name and contact person are required.'),
        ),
      );
      return;
    }
    final email = emailController.text.trim();
    if (email.isNotEmpty &&
        (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
            email.endsWith('@phone.karigar'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid email address for invoices.'),
        ),
      );
      return;
    }
    final gstError = _gstinProblem();
    if (gstError != null) {
      setState(() => gstinError = gstError);
      gstinFocusNode.requestFocus();
      return;
    }
    if (gstinError != null) setState(() => gstinError = null);
    setState(() => saving = true);
    final profile = AppScope.of(context).profile;
    final success = await profile.save({
      'email': emailController.text.trim().isEmpty
          ? null
          : emailController.text.trim(),
      'gstin': gstinController.text.trim().isEmpty
          ? null
          : _normalizedGstin(gstinController.text),
      'company_name': companyController.text.trim(),
      'name': nameController.text.trim(),
      'phone': phoneController.text.replaceAll(RegExp(r'\D'), ''),
      'industry': industryController.text.trim(),
      'hiring_categories': selectedHiringCategories.toList(),
      'about': aboutController.text.trim(),
      'state': stateController.text.trim(),
      'city': cityController.text.trim(),
      'latitude': _siteLocation.latitude,
      'longitude': _siteLocation.longitude,
    });
    if (!mounted) return;
    setState(() => saving = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profile.error ?? 'Could not save the profile.')),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  String _normalizedGstin(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  String? _gstinProblem() {
    final gst = _normalizedGstin(gstinController.text);
    if (gst.isEmpty) return null;
    if (gst.length != 15) {
      return 'A GST number has 15 characters, like 22ABCDE1234F1ZA.';
    }
    if (!RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
    ).hasMatch(gst)) {
      return 'Enter the GST number in the format 22ABCDE1234F1ZA.';
    }
    final stateCode = int.parse(gst.substring(0, 2));
    if (!((stateCode >= 1 &&
            stateCode <= 38 &&
            stateCode != 25 &&
            stateCode != 28) ||
        stateCode == 97)) {
      return 'A GST number starts with a state code (01–38). Check the first two digits.';
    }
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var sum = 0;
    for (var index = 0; index < 14; index++) {
      final value = chars.indexOf(gst[index]) * (index.isEven ? 1 : 2);
      sum += value ~/ 36 + value % 36;
    }
    if (gst[14] != chars[(36 - sum % 36) % 36]) {
      return 'This GST number is not valid. Check it for a typing mistake.';
    }
    return null;
  }

  Future<void> _pickLogo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (image == null) return;
      await _uploadLogo(File(image.path));
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select image: $exception')),
        );
      }
    }
  }

  Future<void> _uploadLogo(File file) async {
    final api = AppScope.of(context).api;
    if (await file.length() > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo size must not exceed 2 MB.')),
        );
      }
      return;
    }
    setState(() => uploadingLogo = true);
    try {
      await api.uploadLogo(file);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logo updated.')));
      await _load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      if (mounted) setState(() => uploadingLogo = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      emailController,
      gstinController,
      companyController,
      nameController,
      phoneController,
      industryController,
      aboutController,
      stateController,
      cityController,
    ]) {
      controller.dispose();
    }
    gstinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Business Profile')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Center(
                  child: InkWell(
                    onTap: uploadingLogo ? null : _pickLogo,
                    borderRadius: BorderRadius.circular(48),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              backgroundImage:
                                  AppScope.of(context).profile.profile?.logoUrl
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? NetworkImage(
                                      AppScope.of(
                                        context,
                                      ).profile.profile!.logoUrl!,
                                    )
                                  : null,
                              child:
                                  AppScope.of(context).profile.profile?.logoUrl
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? null
                                  : Icon(
                                      LucideIcons.building2,
                                      size: 40,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: AppColors.primary,
                                child: Icon(
                                  LucideIcons.camera,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          uploadingLogo
                              ? 'Uploading logo...'
                              : 'Tap to change logo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                LabeledField(
                  'Business name',
                  hint: 'Sri Sai Constructions',
                  controller: companyController,
                ),
                LabeledField(
                  'Contact person',
                  hint: 'Anil Sharma',
                  controller: nameController,
                ),
                LabeledField(
                  'Mobile number',
                  hint: '+91 98765 43210',
                  keyboardType: TextInputType.phone,
                  controller: phoneController,
                ),
                const Text(
                  'Add your email to receive PDF invoices. Add GSTIN and state for correct GST on your invoices.',
                ),
                const SizedBox(height: 12),
                LabeledField(
                  'Email for invoices',
                  hint: 'name@company.com',
                  keyboardType: TextInputType.emailAddress,
                  controller: emailController,
                ),
                LabeledField(
                  'GSTIN (optional)',
                  hint: '22ABCDE1234F1ZA',
                  controller: gstinController,
                  focusNode: gstinFocusNode,
                  errorText: gstinError,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: const [_GstinFormatter()],
                ),
                LabeledField(
                  'Industry',
                  hint: 'Construction & Real Estate',
                  controller: industryController,
                ),
                const Text(
                  'Usually hiring for',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    ...selectedHiringCategories.map(
                      (category) => InputChip(
                        label: Text(category),
                        onDeleted: () => setState(
                          () => selectedHiringCategories.remove(category),
                        ),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add category'),
                      onPressed: _chooseHiringCategory,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LabeledField(
                  'About the business',
                  hint:
                      'Residential & commercial construction firm with safe sites.',
                  lines: 4,
                  controller: aboutController,
                ),
                const SectionTitle('Location'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stateController,
                        readOnly: true,
                        onTap: _pickState,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          hintText: 'Select state',
                          suffixIcon: Icon(Icons.expand_more),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: cityController,
                        readOnly: true,
                        onTap: _pickCity,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          hintText: 'Type a city name',
                          suffixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Pin office / site location',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 280,
                  child: LocationMap(
                    initialLocation: _siteLocation,
                    onLocationChanged: (point) =>
                        setState(() => _siteLocation = point),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap anywhere on the map to set your exact location.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving ? null : _save,
                    child: Text(saving ? 'Saving...' : 'Save Profile'),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _chooseHiringCategory() async {
    final options = hiringCategories
        .where((category) => !selectedHiringCategories.contains(category))
        .toList();
    if (options.isEmpty) return;
    final category = await showSearchableOptionSheet(
      context,
      title: 'Usually hiring for',
      values: options,
    );
    if (category != null && mounted) {
      setState(() => selectedHiringCategories.add(category));
    }
  }
}
