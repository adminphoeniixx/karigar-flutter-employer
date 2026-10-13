import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import '../../widgets/contact_actions.dart';
import '../profile/plans_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/messages/chat_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({
    super.key,
    required this.worker,
    this.workerUserId,
    this.profileId,
    this.jobId,
    this.phone,
    this.contactUnlocked = false,
    this.canMessage = false,
    this.alwaysShowContact = false,
    this.onUnlock,
  });
  final Worker worker;
  final int? workerUserId, profileId, jobId;
  final String? phone;
  final bool contactUnlocked, canMessage, alwaysShowContact;
  final Future<String?> Function()? onUnlock;
  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  late bool unlocked;
  String? phone;
  bool busy = false;
  bool loadedProfile = false;
  bool loadingProfile = false;
  WorkerProfile? profile;

  @override
  void initState() {
    super.initState();
    unlocked = widget.contactUnlocked || widget.alwaysShowContact;
    phone = widget.phone;
    loadingProfile = widget.profileId != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loadedProfile && widget.profileId != null) {
      loadedProfile = true;
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await AppScope.of(context).api.worker(widget.profileId!);
      final worker = response['worker'];
      if (worker is! Map || !mounted) return;
      final values = Map<String, dynamic>.from(worker);
      if (response['rating'] != null) values['rating'] = response['rating'];
      final loaded = WorkerProfile.fromJson(values);
      setState(() {
        profile = loaded;
        phone = loaded.phone;
        unlocked =
            widget.alwaysShowContact ||
            loaded.contactUnlocked ||
            (!loaded.locked && loaded.phone?.isNotEmpty == true);
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      if (mounted) setState(() => loadingProfile = false);
    }
  }

  Future<void> _unlock() async {
    final action = widget.onUnlock;
    if (busy || (action == null && widget.profileId == null)) return;
    setState(() => busy = true);
    try {
      String? value;
      if (action != null) {
        value = await action();
      } else {
        final result = await AppScope.of(
          context,
        ).api.unlockWorker(widget.profileId!);
        value = (result['worker'] as Map?)?['phone']?.toString();
      }
      if (mounted) {
        setState(() {
          unlocked = value?.isNotEmpty == true;
          phone = value ?? phone;
        });
      }
      if (mounted) await AppScope.of(context).dashboard.load();
    } catch (exception) {
      if (mounted) {
        await showContactError(context, exception);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _message() async {
    final workerUserId = profile?.userId ?? widget.workerUserId;
    if (workerUserId == null || busy) return;
    setState(() => busy = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.startConversation(workerId: workerUserId, jobId: widget.jobId);
      final conversation = response['conversation'];
      final conversationId = conversation is Map
          ? (conversation['id'] as num?)?.toInt()
          : null;
      if (!mounted || conversationId == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(worker: widget.worker, conversationId: conversationId),
        ),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.worker;
    final details = profile;
    final languages = details?.languages ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Karigar Profile')),
      body: loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.gradientEnd],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.brand100,
                            child: Text(
                              w.initials,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandDark,
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
                                        w.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (widget.alwaysShowContact ||
                                        details?.verified == true ||
                                        w.verified) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        LucideIcons.badgeCheck,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${w.trade} · ${w.experience} yrs experience',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${[details?.city, details?.state].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ').isNotEmpty ? [details?.city, details?.state].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ') : 'Location unavailable'}${w.distance > 0 ? ' · ${w.distance.toStringAsFixed(1)} km' : ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 29,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (widget.alwaysShowContact ||
                                  details?.verified == true)
                                const StatusPill('Verified'),
                              if (details?.available == true) ...[
                                const SizedBox(width: 8),
                                const BrandChip('● Available'),
                              ],
                              if (w.wage > 0) ...[
                                const SizedBox(width: 8),
                                BrandChip(monthlyWage(w.wage)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONTACT & ACTIONS',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: .7,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.brand50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      LucideIcons.phone,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Contact number',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          unlocked && phone?.isNotEmpty == true
                                              ? '+91 $phone'
                                              : 'Contact locked',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (!unlocked &&
                                  (widget.onUnlock != null ||
                                      details?.canUnlock == true)) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: busy ? null : _unlock,
                                    icon: const Icon(LucideIcons.lockOpen),
                                    label: Text(
                                      busy ? 'Unlocking…' : 'Unlock contact',
                                    ),
                                  ),
                                ),
                              ],
                              if (!unlocked &&
                                  widget.onUnlock == null &&
                                  details?.canUnlock != true) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const PlansScreen(
                                          focusDatabase: true,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      LucideIcons.badgeIndianRupee,
                                    ),
                                    label: const Text('View database plans'),
                                  ),
                                ),
                              ],
                              if (unlocked) ...[
                                const Divider(height: 24),
                                ContactActions(
                                  phone: phone,
                                  email: details?.email,
                                  expanded: true,
                                  compact: true,
                                  showChat: true,
                                  onChat: busy ? null : () => _message(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SectionTitle('About'),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            details?.bio.isNotEmpty == true
                                ? details!.bio
                                : 'Karigar profile details are not available.',
                            style: const TextStyle(fontSize: 14, height: 1.55),
                          ),
                        ),
                      ),
                      const SectionTitle('Skills'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: w.skills.map(BrandChip.new).toList(),
                      ),
                      const SectionTitle('Work details'),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoTile(
                                      icon: LucideIcons.briefcaseBusiness,
                                      label: 'Experience',
                                      value:
                                          '${details?.experienceYears ?? w.experience} years',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _InfoTile(
                                      icon: LucideIcons.indianRupee,
                                      label: 'Expected wage',
                                      value:
                                          (details?.expectedWage ?? w.wage) > 0
                                          ? monthlyWage(
                                              details?.expectedWage ?? w.wage,
                                            )
                                          : 'Not disclosed',
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 26),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoTile(
                                      icon: LucideIcons.mapPin,
                                      label: 'Location',
                                      value: details?.city.isNotEmpty == true
                                          ? '${details!.city}, ${details.state}'
                                          : 'Not provided',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _InfoTile(
                                      icon: LucideIcons.graduationCap,
                                      label: 'Education',
                                      value:
                                          details?.education?.isNotEmpty == true
                                          ? details!.education!
                                          : 'Not provided',
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 26),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoTile(
                                      icon: LucideIcons.circleCheck,
                                      label: 'Availability',
                                      value: details?.available == true
                                          ? 'Available for work'
                                          : 'Not confirmed',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _InfoTile(
                                      icon: LucideIcons.navigation,
                                      label: 'Distance',
                                      value: w.distance > 0
                                          ? '${w.distance.toStringAsFixed(1)} km away'
                                          : 'Not available',
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 26),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoTile(
                                      icon: LucideIcons.walletCards,
                                      label: 'Wage type',
                                      value:
                                          details?.wageType.isNotEmpty == true
                                          ? details!.wageType == 'monthly'
                                                ? 'Monthly'
                                                : details.wageType
                                          : 'Not provided',
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SectionTitle('Languages'),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.brand50,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  LucideIcons.languages,
                                  size: 19,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Spoken languages',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    if (languages.isEmpty)
                                      const Text(
                                        'Not provided',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      Wrap(
                                        spacing: 7,
                                        runSpacing: 7,
                                        children: languages
                                            .map(
                                              (value) => BrandChip(
                                                value,
                                                neutral: true,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ],
  );
}
