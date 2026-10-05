import 'dart:async';
import '../core/analytics/meta_analytics.dart';
import 'dart:io';

import '../constants/api_constants.dart';
import '../core/api/api_client.dart';
import '../models/api_models.dart';

class EmployerApiService {
  const EmployerApiService(this.client, {MetaAnalytics? analytics})
    : _analytics = analytics;
  final MetaAnalytics? _analytics;
  MetaAnalytics get analytics => _analytics ?? MetaAnalytics.instance;
  final ApiClient client;

  Future<Json> _tracked(
    Future<Json> Function() action,
    String? event, {
    Json parameters = const {},
  }) async {
    final response = await action();
    if (event != null) {
      unawaited(analytics.event(event, parameters: parameters));
    }
    return response;
  }

  Json _data(Json response) => response['data'] is Map
      ? Map<String, dynamic>.from(response['data'] as Map)
      : const {};

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
  Future<Json> jobFormOptions() => client.get(ApiConstants.jobFormOptions);

  Future<DashboardData> dashboard() async =>
      DashboardData.fromJson(await client.get(ApiConstants.dashboard));

  Future<EmployerProfile> profile() async =>
      EmployerProfile.fromJson(_data(await client.get(ApiConstants.profile)));
  Future<EmployerProfile> updateProfile(Json values) async =>
      EmployerProfile.fromJson(
        _data(await client.put(ApiConstants.profile, body: values)),
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

  Future<EmployerJob> job(int id) async {
    final response = await client.get(ApiConstants.job(id));
    return EmployerJob.fromJson(
      response['job'] is Map ? Json.from(response['job']) : _data(response),
    );
  }

  Future<List<String>> suggestJobDescription({
    required String title,
    String? category,
    String? city,
    String? state,
    List<String> skills = const [],
    String language = 'en',
  }) async => asStrings(
    (await client.get(
      ApiConstants.suggestJobDescription,
      query: {
        'title': title,
        'category': category,
        'city': city,
        'state': state,
        'skills': skills,
        'language': language,
      },
    ))['suggestions'],
  );
  Future<EmployerJob> createJob(Json values) async {
    final response = await saveJob(values);
    return EmployerJob.fromJson(
      Map<String, dynamic>.from(response['job'] as Map),
    );
  }

  Future<EmployerJob> updateJob(int id, Json values) async {
    final response = await saveJob(values, id: id);
    return EmployerJob.fromJson(
      Map<String, dynamic>.from(response['job'] as Map),
    );
  }

  Future<Json> saveJob(Json values, {int? id}) async {
    final response = id == null
        ? await client.post(ApiConstants.jobs, body: values)
        : await client.put(ApiConstants.job(id), body: values);
    final raw = response['job'];
    final job = raw is Map ? Json.from(raw) : <String, dynamic>{};
    final status = job['status'] ?? values['status'];
    if (status == 'active' &&
        (id == null || response['message'] == 'Job posted.')) {
      unawaited(
        analytics.event(
          'job_published',
          parameters: {
            'fb_content_id': '${job['id'] ?? id ?? ''}',
            'fb_content_type': 'job',
          },
        ),
      );
    }
    return response;
  }

  Future<BinaryResponse> invoicePdf(int id, {String? url}) =>
      client.download(url ?? '${ApiConstants.invoice(id)}/pdf');

  Future<void> deleteJob(int id) => client.delete(ApiConstants.job(id));
  Future<Json> closeJob(int id) => client.post('/employer/jobs/$id/close');
  Future<Json> repostJob(int id) => client.post(ApiConstants.repostJob(id));
  Future<Json> boostJob(int id, String tier) =>
      client.post('/employer/jobs/$id/boost', body: {'tier': tier});
  Future<Json> matches(int id) => client.get('/employer/jobs/$id/matches');
  Future<Json> invite(int jobId, int workerId, {String? message}) =>
      client.post(
        '/employer/jobs/$jobId/invite',
        body: {'worker_id': workerId, 'message': ?message},
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
      Applicant.fromJson(_data(await client.get(ApiConstants.applicant(id))));
  Future<Json> shortlisted({int page = 1}) =>
      client.get(ApiConstants.shortlisted, query: {'page': page});
  Future<Json> applicantStatus(
    int id,
    String status, {
    num? offeredWage,
    String? startDate,
    String? message,
  }) => _tracked(
    () => client.patch(
      '/employer/applicants/$id/status',
      body: {
        'status': status,
        'offered_wage': ?offeredWage,
        'start_date': ?startDate,
        'message': ?message,
      },
    ),
    status == 'hired' ? 'worker_hired' : null,
    parameters: {'status': status},
  );
  Future<Json> shortlist(int id) =>
      client.post('/employer/applicants/$id/shortlist');
  Future<Json> unlock(int id) => _tracked(
    () => client.post('/employer/applicants/$id/unlock'),
    'worker_contact_unlocked',
  );
  Future<Json> scheduleInterview(
    int id, {
    required String interviewAt,
    required String mode,
    String? note,
  }) => client.post(
    '/employer/applicants/$id/interview',
    body: {'interview_at': interviewAt, 'mode': mode, 'note': ?note},
  );
  Future<Json> cancelInterview(int id) =>
      client.delete(ApiConstants.applicantInterview(id));
  Future<BinaryResponse> applicantResume(int id) =>
      client.download(ApiConstants.applicantResume(id));
  Future<Json> screeningCalls(int applicantId, {bool transcript = false}) =>
      client.get(
        ApiConstants.applicantScreeningCalls(applicantId),
        query: {'with_transcript': transcript ? 1 : null},
      );
  Future<Json> placeScreeningCall(int applicantId) =>
      client.post(ApiConstants.applicantScreeningCalls(applicantId));
  Future<Json> confirmScreeningCall(
    int callId, {
    String? interviewAt,
    String? mode,
  }) => client.post(
    ApiConstants.confirmScreeningCall(callId),
    body: {'interview_at': ?interviewAt, 'mode': ?mode},
  );
  Future<Json> reviewWorker(int id, int rating, {String? comment}) =>
      client.post(
        '/employer/applicants/$id/review',
        body: {'rating': rating, 'comment': ?comment},
      );

  Future<Json> workers(Map<String, dynamic> filters) =>
      client.get('/employer/workers', query: filters);
  Future<Json> unlockWorker(int profileId) =>
      client.post('/employer/workers/$profileId/unlock');

  Future<Json> contacts(String source, Map<String, dynamic> filters) =>
      client.get('/employer/contacts/$source', query: filters);

  Future<Json> worker(int id) async {
    final response = await client.get('/employer/workers/$id');
    return response;
  }

  Future<Json> kyc() => client.get('/employer/kyc');
  Future<Json> submitKyc({
    required Map<String, String> fields,
    required Map<String, File> files,
  }) => client.multipart('/employer/kyc', fields: fields, files: files);

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
    body: {'worker_id': workerId, 'job_id': ?jobId, 'body': ?body},
  );
  Future<Json> conversation(int id, {int page = 1}) =>
      client.get('/conversations/$id', query: {'page': page});
  Future<Json> sendMessage(int id, String body) =>
      client.post('/conversations/$id/messages', body: {'body': body});
  Future<Json> readConversation(int id) =>
      client.post('/conversations/$id/read');

  Future<Json> plans() => client.get('/employer/plans');
  Future<Json> subscribe(int planId, {String? coupon}) async {
    final response = await client.post(
      '/employer/plans/$planId/subscribe',
      body: {'coupon': ?coupon},
    );
    final amounts = response['amounts'];
    final rawId =
        response['razorpay_subscription_id'] ?? response['subscription_id'];
    if (rawId is String && rawId.startsWith('sub_')) {
      await analytics.rememberCheckout(
        checkoutId: rawId,
        kind: 'subscription',
        contentId: '$planId',
        amount: amounts is Map ? double.tryParse('${amounts['total']}') : null,
        currency: '${response['currency'] ?? 'INR'}',
      );
    }
    return response;
  }

  Future<Json> subscriptionCallback(Json payment) async {
    final response = await client.post(
      '/employer/plans/callback',
      body: payment,
    );
    final paymentId = payment['razorpay_payment_id']?.toString();
    final checkoutId = payment['razorpay_subscription_id']?.toString();
    if (paymentId != null && checkoutId != null) {
      unawaited(analytics.verifiedPayment(paymentId, checkoutId));
    }
    return response;
  }

  Future<Json> topUp(String pack) async {
    final response = await client.post(
      '/employer/credits/top-up',
      body: {'pack': pack},
    );
    final id = response['razorpay_order_id']?.toString();
    final amounts = response['amounts'];
    if (id != null) {
      await analytics.rememberCheckout(
        checkoutId: id,
        kind: 'credit_pack',
        contentId: pack,
        amount: amounts is Map ? double.tryParse('${amounts['total']}') : null,
        currency: '${response['currency'] ?? 'INR'}',
      );
    }
    return response;
  }

  Future<Json> topUpCallback(Json payment) async {
    final response = await client.post(
      '/employer/credits/callback',
      body: payment,
    );
    final paymentId = payment['razorpay_payment_id']?.toString();
    final checkoutId = payment['razorpay_order_id']?.toString();
    if (paymentId != null && checkoutId != null) {
      unawaited(analytics.verifiedPayment(paymentId, checkoutId));
    }
    return response;
  }

  Future<Json> invoice(int subscriptionId) =>
      client.get(ApiConstants.invoice(subscriptionId));

  Future<Json> preferences() => client.get('/preferences');
  Future<Json> updatePreferences(Json values) =>
      client.patch('/preferences', body: values);
  Future<Json> sessions() => client.get('/auth/sessions');
  Future<Json> deleteSession(int id) => client.delete('/auth/sessions/$id');
}
