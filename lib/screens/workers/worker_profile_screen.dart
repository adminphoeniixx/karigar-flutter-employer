import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.onUnlock,
  });
  final Worker worker;
  final int? workerUserId, profileId, jobId;
  final String? phone;
  final bool contactUnlocked, canMessage;
  final Future<String?> Function()? onUnlock;
  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  late bool unlocked;
  String? phone;
  bool busy = false;
  bool loadedProfile = false;
  WorkerProfile? profile;

  @override
  void initState() {
    super.initState();
    unlocked = widget.contactUnlocked;
    phone = widget.phone;
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
      values['rating'] = response['rating'];
      final loaded = WorkerProfile.fromJson(values);
      setState(() {
        profile = loaded;
        phone = loaded.phone;
        unlocked = loaded.phone?.isNotEmpty == true;
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  Future<void> _unlock() async {
    final action = widget.onUnlock;
    if (action == null || busy) return;
    setState(() => busy = true);
    try {
      final value = await action();
      if (mounted) {
        setState(() {
          unlocked = true;
          phone = value ?? phone;
        });
      }
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

  Future<void> _message() async {
    final workerUserId = widget.workerUserId;
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

  Future<void> _copyPhone() async {
    if (phone == null || phone!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: phone!));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number copied.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.worker;
    final details = profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Profile')),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.gradientEnd],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 33,
                      backgroundColor: AppColors.brand100,
                      child: Text(
                        w.initials,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
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
                            '⌖ ${details?.city ?? 'Location unavailable'}'
                            '${w.distance > 0 ? ' · ${w.distance} km' : ''}'
                            '   ★ ${details?.rating.average ?? w.rating}',
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
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (details?.verified != false)
                      const StatusPill('Verified'),
                    if (details?.available != false)
                      const BrandChip('● Available'),
                    BrandChip('₹${w.wage}/day'),
                  ],
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
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phone number',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
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
                        if (widget.onUnlock != null)
                          TextButton(
                            onPressed: unlocked || busy ? null : _unlock,
                            child: Text(
                              unlocked ? 'Unlocked' : 'Unlock · 1 credit',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SectionTitle('About'),
                Text(
                  details?.bio.isNotEmpty == true
                      ? details!.bio
                      : 'Worker profile details are not available.',
                  style: const TextStyle(fontSize: 14.5, height: 1.55),
                ),
                const SectionTitle('Skills'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: w.skills.map(BrandChip.new).toList(),
                ),
                const SectionTitle('Languages'),
                Wrap(
                  spacing: 8,
                  children: (details?.languages ?? const <String>[])
                      .map((value) => BrandChip(value, neutral: true))
                      .toList(),
                ),
                const SectionTitle('Recent ratings'),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kumar Interiors',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '★★★★★',
                              style: TextStyle(color: Color(0xFFFBBF24)),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Neat work and finished ahead of time. Reliable.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (widget.canMessage || unlocked)
                  Row(
                    children: [
                      if (widget.canMessage)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : _message,
                            icon: const Icon(LucideIcons.messageCircle),
                            label: const Text('Message'),
                          ),
                        ),
                      if (widget.canMessage && unlocked)
                        const SizedBox(width: 8),
                      if (unlocked)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: phone?.isNotEmpty == true
                                ? _copyPhone
                                : null,
                            icon: const Icon(LucideIcons.copy),
                            label: const Text('Copy phone'),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
