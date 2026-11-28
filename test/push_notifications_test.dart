import 'dart:async';
import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/push/push_notifications.dart';
import 'package:employer_kariger_app/core/push/push_router.dart';
import 'package:employer_kariger_app/screens/jobs/ai_credits_screen.dart';
import 'package:employer_kariger_app/screens/jobs/applicant_features_screen.dart';
import 'package:employer_kariger_app/screens/jobs/job_manage_screen.dart';
import 'package:employer_kariger_app/screens/jobs/jobs_screen.dart';
import 'package:employer_kariger_app/screens/messages/messages_screen.dart';
import 'package:employer_kariger_app/screens/profile/kyc_screen.dart';
import 'package:employer_kariger_app/screens/profile/plans_screen.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every request the fake server saw, as "METHOD /path".
class Server {
  final calls = <String>[];
  Completer<void>? holdRegister;

  EmployerApiService api() => EmployerApiService(
    ApiClient(
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'POST' &&
            request.url.path.endsWith('/device-tokens')) {
          await holdRegister?.future;
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    ),
  );
}

PushNotifications pushFor(EmployerApiService api) => PushNotifications(
  api: api,
  navigatorKey: GlobalKey<NavigatorState>(),
  messengerKey: GlobalKey<ScaffoldMessengerState>(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a tapped notification opens', () {
    // Job 167 exists; any other job id is gone (404).
    final api = EmployerApiService(
      ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/employer/jobs/167') {
            return http.Response(
              jsonEncode({
                'job': {
                  'id': 167,
                  'title': 'Tailor for boutique',
                  'category': 'Tailoring',
                  'status': 'active',
                  'stats': {'applicants': 1, 'shortlisted': 1, 'hired': 1},
                },
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404);
        }),
      ),
    );
    Future<Widget?> open(Map<String, dynamic> data) =>
        screenForNotification(data, api);

    test('chats on the messages list', () async {
      expect(await open({'type': 'chat.message'}), isA<MessagesScreen>());
    });
    test('a finished AI screening call (push) on its conversation', () async {
      final screen = await open({
        'type': 'screening.completed',
        'screening_call_id': '84',
      });
      expect(screen, isA<ScreeningConversationScreen>());
      expect((screen as ScreeningConversationScreen).callId, 84);
    });
    test('applicant, screening and interview rows on their job', () async {
      for (final type in [
        'application.received',
        'screening.completed',
        'application.interview_reminder',
        'interview.reminder_call',
      ]) {
        final screen = await open({
          'type': type,
          'url': '/employer/jobs/167/applicants',
        });
        expect(screen, isA<JobManageScreen>(), reason: type);
        expect((screen as JobManageScreen).job.id, 167);
        expect(screen.job.applied, 1);
      }
    });
    test('a held job check on its job, a gone job on the job list', () async {
      final held = await open({
        'type': 'job.moderation',
        'url': '/employer/jobs/167/edit',
      });
      expect(held, isA<JobManageScreen>());
      final gone = await open({
        'type': 'job.moderation',
        'url': '/employer/jobs/999/edit',
      });
      expect(gone, isA<JobsScreen>());
    });
    test('plan reminders on plans, database ones on that tab', () async {
      final push = await open({'type': 'plan.reminder', 'plan_type': 'database'});
      final row = await open({
        'type': 'plan.reminder',
        'url': '/subscription#database',
      });
      final jobPlan = await open({'type': 'plan.reminder', 'url': '/subscription'});
      expect((push as PlansScreen).focusDatabase, isTrue);
      expect((row as PlansScreen).focusDatabase, isTrue);
      expect((jobPlan as PlansScreen).focusDatabase, isFalse);
    });
    test('low AI credits and KYC on their screens', () async {
      expect(await open({'type': 'ai_credits.low'}), isA<AiCreditsScreen>());
      expect(await open({'type': 'kyc.reviewed'}), isA<KycScreen>());
    });
    test('anything else has no screen of its own', () async {
      expect(await open({'type': 'admin.broadcast'}), isNull);
      expect(await open({}), isNull);
    });
  });

  test('signing out removes the push token before the server logout', () async {
    SharedPreferences.setMockInitialValues({'employer_auth_token': 'saved'});
    final server = Server();
    final api = server.api();
    await api.client.initialize();
    final push = pushFor(api);
    final auth = AuthController(api)..beforeLogout = push.stop;
    await push.register('fcm-token-1');

    await auth.logout();

    expect(server.calls, [
      'POST /api/v1/device-tokens',
      'DELETE /api/v1/device-tokens',
      'POST /api/v1/auth/logout',
    ]);
  });

  test('a registration still in flight at sign-out is taken back', () async {
    SharedPreferences.setMockInitialValues({'employer_auth_token': 'saved'});
    final server = Server()..holdRegister = Completer<void>();
    final api = server.api();
    await api.client.initialize();
    final push = pushFor(api);

    final registering = push.register('fcm-token-1');
    await Future<void>.delayed(Duration.zero);
    await push.stop(); // nothing registered yet, so nothing to delete
    server.holdRegister!.complete();
    await registering;

    expect(server.calls, [
      'POST /api/v1/device-tokens',
      'DELETE /api/v1/device-tokens',
    ]);
  });

  test('the same token is not registered twice', () async {
    SharedPreferences.setMockInitialValues({'employer_auth_token': 'saved'});
    final server = Server();
    final api = server.api();
    await api.client.initialize();
    final push = pushFor(api);

    await push.register('fcm-token-1');
    await push.register('fcm-token-1');

    expect(server.calls, ['POST /api/v1/device-tokens']);
  });
}
