import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/screens/dashboard/notifications_screen.dart';
import 'package:employer_kariger_app/screens/jobs/job_manage_screen.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The notifications API as the server sends it: the job only inside `url`.
http.Response serve(http.Request request) {
  final body = switch (request.url.path) {
    '/api/v1/notifications' => {
      'notifications': {
        'data': [
          {
            'id': 'n1',
            'type': 'application.interview_reminder',
            'title': 'Interview tomorrow',
            'message': 'Ramesh has an interview at 11 AM.',
            'application_id': 55,
            'url': '/employer/jobs/167/applicants',
            'read': true,
          },
        ],
      },
    },
    '/api/v1/employer/jobs/167' => {
      'job': {
        'id': 167,
        'title': 'Tailor for boutique',
        'category': 'Tailoring',
        'status': 'active',
      },
    },
    _ => <String, dynamic>{},
  };
  return http.Response(jsonEncode(body), 200);
}

void main() {
  testWidgets('tapping an interview reminder opens its job', (tester) async {
    final api = EmployerApiService(
      ApiClient(client: MockClient((request) async => serve(request))),
    );
    await tester.pumpWidget(
      AppScope(
        api: api,
        auth: AuthController(api),
        dashboard: DashboardController(api),
        jobs: JobsController(api),
        workers: WorkersController(api),
        profile: ProfileController(api),
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Interview tomorrow'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(JobManageScreen), findsOneWidget);
    final screen = tester.widget<JobManageScreen>(find.byType(JobManageScreen));
    expect(screen.job.id, 167);
  });
}
