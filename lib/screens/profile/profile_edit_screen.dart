import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:latlong2/latlong.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Business Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const Center(
            child: Column(
              children: [
                Stack(
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
                SizedBox(height: 8),
                Text(
                  'Tap to change logo',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const LabeledField('Business name', hint: 'Sri Sai Constructions'),
          const LabeledField('Contact person', hint: 'Anil Sharma'),
          const LabeledField('Mobile number', hint: '+91 98765 43210'),
          const LabeledField('Industry', hint: 'Construction & Real Estate'),
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
          const LabeledField(
            'About the business',
            hint: 'Residential & commercial construction firm with safe sites.',
            lines: 4,
          ),
          const SectionTitle('Location'),
          const Row(
            children: [
              Expanded(child: LabeledField('State', hint: 'Tamil Nadu')),
              SizedBox(width: 12),
              Expanded(child: LabeledField('City', hint: 'Chennai')),
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Profile saved at '
                    '${_siteLocation.latitude.toStringAsFixed(5)}, '
                    '${_siteLocation.longitude.toStringAsFixed(5)} ✓',
                  ),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Save Profile'),
          ),
        ],
      ),
    );
  }
}
