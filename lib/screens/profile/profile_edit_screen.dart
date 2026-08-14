import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:latlong2/latlong.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/common.dart';
import 'package:employer_kariger_app/widgets/location_map.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  LatLng _siteLocation = const LatLng(13.0827, 80.2707);
  final companyController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final industryController = TextEditingController();
  final aboutController = TextEditingController();
  final stateController = TextEditingController();
  final cityController = TextEditingController();
  bool loading = true;
  bool saving = false;
  bool uploadingLogo = false;
  bool _loaded = false;

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
      nameController.text = profile.name;
      phoneController.text = profile.phone ?? '';
      industryController.text = profile.industry ?? '';
      aboutController.text = profile.about ?? '';
      stateController.text = profile.state ?? '';
      cityController.text = profile.city ?? '';
      if (profile.latitude != null && profile.longitude != null) {
        _siteLocation = LatLng(profile.latitude!, profile.longitude!);
      }
    }
    setState(() => loading = false);
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
    setState(() => saving = true);
    final profile = AppScope.of(context).profile;
    final success = await profile.save({
      'company_name': companyController.text.trim(),
      'name': nameController.text.trim(),
      'phone': phoneController.text.replaceAll(RegExp(r'\D'), ''),
      'industry': industryController.text.trim(),
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

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final file = File(path);
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
      await AppScope.of(context).api.uploadLogo(file);
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
                        const Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.brand50,
                              child: Icon(
                                LucideIcons.building2,
                                size: 40,
                                color: AppColors.primary,
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
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
                const Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    BrandChip('Plumbing ×'),
                    BrandChip('Electrical ×'),
                    BrandChip('Masonry ×'),
                    BrandChip('+ Add trade', neutral: true),
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
                      child: LabeledField(
                        'State',
                        hint: 'Tamil Nadu',
                        controller: stateController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LabeledField(
                        'City',
                        hint: 'Chennai',
                        controller: cityController,
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
                    onLocationChanged: (point) => _siteLocation = point,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap anywhere on the map to set your exact location.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : _save,
                  child: Text(saving ? 'Saving...' : 'Save Profile'),
                ),
              ],
            ),
    );
  }
}
