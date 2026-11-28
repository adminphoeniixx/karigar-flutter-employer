import 'package:flutter/widgets.dart';

import '../../models/api_models.dart';
import '../../screens/jobs/ai_credits_screen.dart';
import '../../screens/jobs/applicant_features_screen.dart';
import '../../screens/jobs/job_manage_screen.dart';
import '../../screens/jobs/jobs_screen.dart';
import '../../screens/messages/messages_screen.dart';
import '../../screens/profile/kyc_screen.dart';
import '../../screens/profile/plans_screen.dart';
import '../../services/employer_api_service.dart';
import '../data.dart';
import '../../widgets/common.dart';

/// Where a notification leads, for a tapped push and a tapped row in the
/// notifications list alike. Null when it has no screen of its own.
///
/// A push carries the server's full data (`toFcm()`: type and ids); a row
/// from `GET /notifications` only has `type`, `application_id` and `url`, so
/// the ids are also read from the url the server stores for the website:
/// `/employer/jobs/{id}/applicants`, `/employer/jobs/{id}/edit`,
/// `/subscription#database`, `/messages/{id}`, `/kyc`, `/employer/ai-credits`.
Future<Widget?> screenForNotification(
  Map<String, dynamic> data,
  EmployerApiService api,
) async {
  final type = '${data['type'] ?? ''}';
  final url = '${data['url'] ?? ''}';
  int? id(String key) => int.tryParse('${data[key] ?? ''}');

  switch (type) {
    case 'chat.message':
      return const MessagesScreen();
    case 'plan.reminder':
      return PlansScreen(
        focusDatabase:
            data['plan_type'] == 'database' || url.contains('#database'),
      );
    case 'ai_credits.low':
      return const AiCreditsScreen();
    case 'kyc.reviewed':
      return const KycScreen();
  }

  if (type == 'screening.completed' && id('screening_call_id') != null) {
    return ScreeningConversationScreen(
      callId: id('screening_call_id')!,
      workerName: '${data['worker_name'] ?? 'Karigar'}',
    );
  }

  // Applicants, screening calls, interviews and job checks belong to a job.
  final jobId =
      id('job_listing_id') ??
      int.tryParse(
        RegExp(r'/employer/jobs/(\d+)').firstMatch(url)?.group(1) ?? '',
      );
  if (jobId != null) {
    try {
      return JobManageScreen(job: jobCard(await api.job(jobId)));
    } catch (_) {
      // Deleted, or no internet: the job list is the next best place.
      return const JobsScreen();
    }
  }
  if (type == 'job.moderation') return const JobsScreen();
  return null;
}

/// The card [JobManageScreen] shows, from the API's job.
Job jobCard(EmployerJob job) => Job(
  job.title,
  job.category,
  job.wageLabel,
  job.vacancies,
  asInt(job.stats['applicants']),
  asInt(job.stats['shortlisted']),
  asInt(job.stats['hired']),
  jobStatusLabel(job),
  id: job.id,
  views: asInt(job.stats['views']),
  moderationNote: job.moderation?['note']?.toString(),
  moderationStatus: job.moderation?['status']?.toString(),
  moderationMethod: job.moderation?['method']?.toString(),
  workModeLabel: job.workModeLabel,
  interviewModeLabel: job.interviewModeLabel,
);

/// The badge text for a job: its safety check while that is not done,
/// else its status ("Active", "Closed", "Draft").
String jobStatusLabel(EmployerJob job) => switch (job.moderation?['status']) {
  'pending' => 'Under review',
  'rejected' => 'Not approved',
  'checking' => 'Checking…',
  _ => StatusPill.label(job.status),
};
