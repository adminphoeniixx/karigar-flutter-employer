import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/jobs/post_job_screen.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A home page with an "Open" button that pushes [form].
Future<void> openForm(WidgetTester tester, Widget form) async {
  final api = EmployerApiService(
    ApiClient(
      client: MockClient((_) async => http.Response(jsonEncode({}), 200)),
    ),
  );
  await tester.pumpWidget(
    AppScope(
      api: api,
      auth: AuthController(api),
      dashboard: DashboardController(api),
      jobs: JobsController(api),
      workers: WorkersController(api),
      profile: ProfileController(api),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => form),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> phoneBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

final draft = EmployerJob.fromJson({
  'id': 12,
  'title': 'Mason',
  'description': 'Build villa',
  'category': 'Masonry',
  'state': 'Haryana',
  'city': 'Gurugram',
  'wage_min': 800,
  'vacancies': 2,
  'contact_mode': 'apply',
  'status': 'draft',
  'is_draft': true,
});

void main() {
  testWidgets('back on an untouched form just leaves', (tester) async {
    await openForm(tester, const PostJobScreen());

    await phoneBack(tester);

    expect(find.byType(PostJobScreen), findsNothing);
    expect(find.text('Leave without saving?'), findsNothing);
  });

  testWidgets('back after typing asks; Keep editing stays, Leave without saving leaves', (
    tester,
  ) async {
    await openForm(tester, const PostJobScreen());
    await tester.enterText(find.byType(TextField).first, 'Mason for villa');
    await tester.pump();

    await phoneBack(tester);
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(PostJobScreen), findsOneWidget);

    await phoneBack(tester);
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Leave without saving'));
    await tester.pumpAndSettle();
    expect(find.byType(PostJobScreen), findsNothing);
  });

  testWidgets('the phone back goes to the previous step first', (tester) async {
    await openForm(tester, PostJobScreen(job: draft));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 2 of 4'), findsOneWidget);

    await phoneBack(tester);

    expect(find.byType(PostJobScreen), findsOneWidget);
    expect(find.textContaining('Step 1 of 4'), findsOneWidget);
  });
}
