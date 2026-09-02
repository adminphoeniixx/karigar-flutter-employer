import 'package:flutter/material.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/workers/worker_profile_screen.dart';
import 'package:employer_kariger_app/widgets/common.dart';

class ShortlistedScreen extends StatefulWidget {
  const ShortlistedScreen({super.key});

  @override
  State<ShortlistedScreen> createState() => _ShortlistedScreenState();
}

class _ShortlistedScreenState extends State<ShortlistedScreen> {
  bool loading = true;
  String? error;
  List<Applicant> applicants = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && applicants.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.shortlisted();
      final rows = (response['data'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Applicant.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (mounted) setState(() => applicants = rows);
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _unlockApplicant(Applicant applicant) async {
    final response = await AppScope.of(context).api.unlock(applicant.id);
    final applicantJson = response['applicant'];
    final workerJson = applicantJson is Map ? applicantJson['worker'] : null;
    final phone = workerJson is Map ? workerJson['phone']?.toString() : null;
    await _load();
    return phone;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shortlisted workers')),
    body: loading && applicants.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && applicants.isEmpty
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: applicants.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No shortlisted workers yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ]
                  : applicants.map((applicant) {
                      final profile = applicant.worker;
                      final worker = Worker(
                        profile.name,
                        profile.skills.isEmpty
                            ? 'Worker'
                            : profile.skills.first,
                        profile.experienceYears,
                        profile.rating.average,
                        profile.distanceKm ?? 0,
                        profile.expectedWage,
                        profile.skills,
                        status: applicant.statusLabel,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (applicant.job?['title'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'For ${applicant.job!['title']}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            WorkerCard(
                              worker: worker,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkerProfileScreen(
                                    worker: worker,
                                    profileId: profile.id,
                                    workerUserId: profile.userId,
                                    jobId: (applicant.job?['id'] as num?)
                                        ?.toInt(),
                                    phone: profile.phone,
                                    contactUnlocked: applicant.contactUnlocked,
                                    canMessage: true,
                                    onUnlock: applicant.contactUnlocked
                                        ? null
                                        : () => _unlockApplicant(applicant),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
            ),
          ),
  );
}
