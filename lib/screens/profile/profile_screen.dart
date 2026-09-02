import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/jobs/jobs_screen.dart';
import 'package:employer_kariger_app/screens/profile/kyc_screen.dart';
import 'package:employer_kariger_app/screens/profile/plans_screen.dart';
import 'package:employer_kariger_app/screens/profile/profile_edit_screen.dart';
import 'package:employer_kariger_app/screens/profile/reviews_screen.dart';
import 'package:employer_kariger_app/screens/profile/settings_screen.dart';
import 'package:employer_kariger_app/screens/workers/shortlisted_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final controller = AppScope.of(context).profile;
  bool requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!requested) {
      requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.load();
      });
    }
  }

  Future<void> _open(Widget page, {bool refresh = false}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (refresh && changed == true) await controller.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final profile = controller.profile;
      final verificationEnabled =
          AppScope.of(context).dashboard.data?.verificationEnabled ?? false;
      return Scaffold(
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
                onTap: () => _open(const SettingsScreen()),
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
        body: controller.loading && profile == null
            ? const Center(child: CircularProgressIndicator())
            : controller.error != null && profile == null
            ? Center(
                child: OutlinedButton(
                  onPressed: controller.load,
                  child: const Text('Retry'),
                ),
              )
            : RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _BusinessHeader(profile: profile),
                    Container(
                      color: AppColors.background,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _open(const ProfileEditScreen(), refresh: true),
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
                      child: Column(
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
                            children:
                                (profile?.hiringCategories ?? const <String>[])
                                    .map((value) => BrandChip(value))
                                    .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProfileRow(
                      icon: LucideIcons.briefcaseBusiness,
                      title: 'My Job Posts',
                      subtitle: 'Active, closed & drafts',
                      trailing: '→',
                      onTap: () => _open(const JobsScreen()),
                    ),
                    if (verificationEnabled)
                      _ProfileRow(
                        icon: LucideIcons.shield,
                        title: 'Business Verification',
                        subtitle: profile?.verified == true
                            ? 'GST & PAN verified'
                            : 'Submit GST & PAN details',
                        verified: profile?.verified == true,
                        onTap: () => _open(const KycScreen(), refresh: true),
                      ),
                    _ProfileRow(
                      icon: LucideIcons.star,
                      title: 'Shortlisted Workers',
                      subtitle: 'Candidates saved across all jobs',
                      trailing: '→',
                      onTap: () => _open(const ShortlistedScreen()),
                    ),
                    _ProfileRow(
                      icon: LucideIcons.star,
                      title: 'Reviews & Ratings',
                      subtitle: 'How workers rated you',
                      trailing:
                          '★ ${profile?.rating.average.toStringAsFixed(1) ?? '0.0'} →',
                      onTap: () => _open(const ReviewsScreen()),
                    ),
                    _ProfileRow(
                      icon: LucideIcons.layers,
                      title: 'Credits & Plans',
                      subtitle: 'Subscriptions and contact credits',
                      trailing: '→',
                      onTap: () => _open(const PlansScreen()),
                    ),
                    _ProfileRow(
                      icon: LucideIcons.slidersHorizontal,
                      title: 'Settings',
                      subtitle: 'Language, security, theme',
                      trailing: '→',
                      onTap: () => _open(const SettingsScreen()),
                    ),
                  ],
                ),
              ),
      );
    },
  );
}

class _BusinessHeader extends StatelessWidget {
  const _BusinessHeader({required this.profile});
  final EmployerProfile? profile;

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
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: Colors.white,
          child: Icon(
            LucideIcons.building2,
            size: 30,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.companyName.isNotEmpty == true
                    ? profile!.companyName
                    : 'Your business',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profile?.industry ?? 'Complete your business profile',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, color: Colors.white, size: 15),
                  const SizedBox(width: 4),
                  Text(
                    [profile?.city, profile?.state]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(', '),
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '★ ${profile?.rating.average.toStringAsFixed(1) ?? '0.0'} '
                    '(${profile?.rating.count ?? 0})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (profile?.verified == true) ...[
                const SizedBox(height: 8),
                const _VerifiedEmployerPill(),
              ],
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
