import 'dart:io';

import '../constants/api_constants.dart';
import '../core/api/api_client.dart';
import '../models/api_models.dart';

class EmployerApiService {
  const EmployerApiService(this.client);
  final ApiClient client;

  Future<Json> sendOtp(String phone) =>
      client.post(ApiConstants.otpSend, body: {'phone': phone});

  Future<Json> verifyOtp(String phone, String otp, {String? deviceName}) =>
      client.post(
        ApiConstants.otpVerify,
        body: {
          'phone': phone,
          'otp': otp,
          'role': 'employer',
          'device_name': deviceName ?? 'Flutter app',
        },
      );

  Future<Json> me() => client.get(ApiConstants.me);
  Future<Json> logout() => client.post(ApiConstants.logout);
  Future<Json> deleteAccount() =>
      client.delete(ApiConstants.account, body: {'confirm': true});
  Future<Json> setLocale(String locale) =>
      client.post(ApiConstants.locale, body: {'locale': locale});

  Future<Json> reference() => client.get(ApiConstants.reference);
  Future<List<String>> cities(String state) async => asStrings(
    (await client.get(ApiConstants.cities, query: {'state': state}))['cities'],
  );
  Future<List<String>> jobCategories() async => asStrings(
    (await client.get(ApiConstants.jobCategories))['job_categories'],
  );

  Future<DashboardData> dashboard() async =>
      DashboardData.fromJson(await client.get(ApiConstants.dashboard));

  Future<EmployerProfile> profile() async =>
      EmployerProfile.fromJson(await client.get(ApiConstants.profile));
  Future<EmployerProfile> updateProfile(Json values) async =>
      EmployerProfile.fromJson(
        await client.put(ApiConstants.profile, body: values),
      );
  Future<String> uploadLogo(File logo) async =>
      '${(await client.multipart(ApiConstants.profileLogo, fields: {}, files: {'logo': logo}))['logo_url']}';

  Future<List<EmployerJob>> jobs({
    String? status,
    String? query,
    int page = 1,
  }) async {
    final response = await client.get(
      ApiConstants.jobs,
      query: {'status': status, 'q': query, 'page': page},
    );
    final rows = response['data'] as List? ?? const [];
    return rows
        .whereType<Map>()
        .map((e) => EmployerJob.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<EmployerJob> job(int id) async =>
      EmployerJob.fromJson(await client.get(ApiConstants.job(id)));
  Future<EmployerJob> createJob(Json values) async {
    final response = await client.post(ApiConstants.jobs, body: values);
    return EmployerJob.fromJson(
      Map<String, dynamic>.from(response['job'] as Map),
    );
  }

  Future<EmployerJob> updateJob(int id, Json values) async {
    final response = await client.patch(ApiConstants.job(id), body: values);
    return EmployerJob.fromJson(
      Map<String, dynamic>.from(response['job'] as Map),
    );
  }

  Future<void> deleteJob(int id) => client.delete(ApiConstants.job(id));
  Future<Json> closeJob(int id) => client.post('/employer/jobs/$id/close');
  Future<Json> boostJob(int id, String tier) =>
      client.post('/employer/jobs/$id/boost', body: {'tier': tier});
  Future<Json> matches(int id) => client.get('/employer/jobs/$id/matches');
  Future<Json> invite(int jobId, int workerId, {String? message}) =>
      client.post(
        '/employer/jobs/$jobId/invite',
        body: {'worker_id': workerId, if (message != null) 'message': message},
      );
  Future<Json> rescore(int jobId, {bool force = false}) => client.post(
    '/employer/jobs/$jobId/rescore',
    query: {'force': force ? 1 : null},
  );

  Future<Json> applicants(
    int jobId, {
    String stage = 'all',
    String sort = 'best_match',
    int page = 1,
  }) => client.get(
    '/employer/jobs/$jobId/applicants',
    query: {'stage': stage, 'sort': sort, 'page': page},
  );
  Future<Applicant> applicant(int id) async =>
      Applicant.fromJson(await client.get('/employer/applicants/$id'));
  Future<Json> applicantStatus(
    int id,
    String status, {
    num? offeredWage,
    String? startDate,
    String? message,
  }) => client.patch(
    '/employer/applicants/$id/status',
    body: {
      'status': status,
      if (offeredWage != null) 'offered_wage': offeredWage,
      if (startDate != null) 'start_date': startDate,
      if (message != null) 'message': message,
    },
  );
  Future<Json> shortlist(int id) =>
      client.post('/employer/applicants/$id/shortlist');
  Future<Json> unlock(int id) => client.post('/employer/applicants/$id/unlock');
  Future<Json> scheduleInterview(
    int id, {
    required String interviewAt,
    required String mode,
    String? note,
  }) => client.post(
    '/employer/applicants/$id/interview',
    body: {
      'interview_at': interviewAt,
      'mode': mode,
      if (note != null) 'note': note,
    },
  );
  Future<Json> cancelInterview(int id) =>
      client.delete('/employer/applicants/$id/interview');
  Future<Json> reviewWorker(int id, int rating, {String? comment}) =>
      client.post(
        '/employer/applicants/$id/review',
        body: {'rating': rating, if (comment != null) 'comment': comment},
      );

  Future<Json> workers(Map<String, dynamic> filters) =>
      client.get('/employer/workers', query: filters);
  Future<Json> worker(int id) => client.get('/employer/workers/$id');

  Future<Json> kyc() => client.get('/employer/kyc');
  Future<Json> submitKyc({
    required String gstin,
    required String pan,
    File? gstDoc,
    File? panDoc,
  }) => client.multipart(
    '/employer/kyc',
    fields: {'gstin': gstin, 'pan_number': pan},
    files: {
      if (gstDoc != null) 'gst_doc': gstDoc,
      if (panDoc != null) 'pan_doc': panDoc,
    },
  );

  Future<Json> notifications({int page = 1}) =>
      client.get('/notifications', query: {'page': page});
  Future<Json> readNotification(String id) =>
      client.post('/notifications/$id/read');
  Future<Json> readAllNotifications() => client.post('/notifications/read-all');
  Future<Json> registerDeviceToken(String token, String platform) =>
      client.post(
        ApiConstants.deviceTokens,
        body: {'token': token, 'platform': platform},
      );
  Future<Json> removeDeviceToken(String token) =>
      client.delete(ApiConstants.deviceTokens, body: {'token': token});
  Future<Json> reviews({int page = 1}) =>
      client.get('/employer/reviews', query: {'page': page});

  Future<Json> team() => client.get('/employer/team');
  Future<Json> addTeamMember({
    required String name,
    required String phone,
    required String role,
  }) => client.post(
    '/employer/team',
    body: {'name': name, 'phone': phone, 'role': role},
  );
  Future<Json> updateTeamMember(int id, String role) =>
      client.patch('/employer/team/$id', body: {'role': role});
  Future<Json> removeTeamMember(int id) => client.delete('/employer/team/$id');

  Future<Json> conversations({int page = 1}) =>
      client.get('/conversations', query: {'page': page});
  Future<Json> startConversation({
    required int workerId,
    int? jobId,
    String? body,
  }) => client.post(
    '/conversations',
    body: {
      'worker_id': workerId,
      if (jobId != null) 'job_id': jobId,
      if (body != null) 'body': body,
    },
  );
  Future<Json> conversation(int id, {int page = 1}) =>
      client.get('/conversations/$id', query: {'page': page});
  Future<Json> sendMessage(int id, String body) =>
      client.post('/conversations/$id/messages', body: {'body': body});
  Future<Json> readConversation(int id) =>
      client.post('/conversations/$id/read');

  Future<Json> plans() => client.get('/employer/plans');
  Future<Json> subscribe(int planId, {String? coupon}) => client.post(
    '/employer/plans/$planId/subscribe',
    body: {if (coupon != null) 'coupon': coupon},
  );
  Future<Json> subscriptionCallback(Json payment) =>
      client.post('/employer/plans/callback', body: payment);
  Future<Json> topUp(String pack) =>
      client.post('/employer/credits/top-up', body: {'pack': pack});
  Future<Json> topUpCallback(Json payment) =>
      client.post('/employer/credits/callback', body: payment);

  Future<Json> preferences() => client.get('/preferences');
  Future<Json> updatePreferences(Json values) =>
      client.patch('/preferences', body: values);
  Future<Json> sessions() => client.get('/auth/sessions');
  Future<Json> deleteSession(int id) => client.delete('/auth/sessions/$id');
}
