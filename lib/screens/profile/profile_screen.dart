import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/jobs/jobs_screen.dart';
import 'package:employer_kariger_app/screens/profile/kyc_screen.dart';
import 'package:employer_kariger_app/screens/profile/plans_screen.dart';
import 'package:employer_kariger_app/screens/profile/profile_edit_screen.dart';
import 'package:employer_kariger_app/screens/profile/reviews_screen.dart';
import 'package:employer_kariger_app/screens/profile/settings_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 58,
      title: const Text(
        'Business Profile',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: InkWell(
            onTap: () => _open(context, const SettingsScreen()),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.settings, size: 21),
            ),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        const _BusinessHeader(),
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: OutlinedButton.icon(
            onPressed: () => _open(context, const ProfileEditScreen()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.brandDark,
              backgroundColor: AppColors.brand50,
              side: const BorderSide(color: AppColors.brand200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(LucideIcons.pencil, size: 19),
            label: const Text('Edit Business Profile'),
          ),
        ),
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'USUALLY HIRING FOR',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  BrandChip('Plumbing'),
                  BrandChip('Electrical'),
                  BrandChip('Masonry'),
                  BrandChip('Painting'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ProfileRow(
          icon: LucideIcons.briefcaseBusiness,
          title: 'My Job Posts',
          subtitle: 'Active, closed & drafts',
          trailing: '6 →',
          onTap: () => _open(context, const JobsScreen()),
        ),
        _ProfileRow(
          icon: LucideIcons.shield,
          title: 'Business Verification',
          subtitle: 'GST & PAN verified',
          verified: true,
          onTap: () => _open(context, const KycScreen()),
        ),
        _ProfileRow(
          icon: LucideIcons.star,
          title: 'Reviews & Ratings',
          subtitle: 'How workers rated you',
          trailing: '★ 4.6 →',
          onTap: () => _open(context, const ReviewsScreen()),
        ),
        _ProfileRow(
          icon: LucideIcons.layers,
          title: 'Credits & Plans',
          subtitle: 'Free plan · 12 credits left',
          trailing: '→',
          onTap: () => _open(context, const PlansScreen()),
        ),
        _ProfileRow(
          icon: LucideIcons.slidersHorizontal,
          title: 'Settings',
          subtitle: 'Language, security, theme',
          trailing: '→',
          onTap: () => _open(context, const SettingsScreen()),
        ),
      ],
    ),
  );

  static void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _BusinessHeader extends StatelessWidget {
  const _BusinessHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.gradientEnd],
      ),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: Colors.white,
          child: Icon(
            LucideIcons.building2,
            size: 30,
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sri Sai Constructions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Construction & Real Estate',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(LucideIcons.mapPin, color: Colors.white, size: 15),
                  SizedBox(width: 4),
                  Text(
                    'Chennai, TN',
                    style: TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '★ 4.6 (18)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              _VerifiedEmployerPill(),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VerifiedEmployerPill extends StatelessWidget {
  const _VerifiedEmployerPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.shieldCheck, color: Colors.white, size: 14),
        SizedBox(width: 5),
        Text(
          'Verified Employer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.verified = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailing;
  final bool verified;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 69,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.line2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (verified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.greenBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Text(
              trailing ?? '→',
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
        ],
      ),
    ),
  );
}
