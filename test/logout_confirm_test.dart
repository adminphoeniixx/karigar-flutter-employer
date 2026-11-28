import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/screens/auth/onboarding_screen.dart';
import 'package:employer_kariger_app/screens/profile/settings_screen.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<String> calls;

  Future<void> openSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'employer_auth_token': 'saved'});
    calls = [];
    final api = EmployerApiService(
      ApiClient(
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(jsonEncode({}), 200);
        }),
      ),
    );
    await api.client.initialize();
    await tester.binding.setSurfaceSize(const Size(400, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AppScope(
        api: api,
        auth: AuthController(api),
        dashboard: DashboardController(api),
        jobs: JobsController(api),
        workers: WorkersController(api),
        profile: ProfileController(api),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder logOutButton() => find.widgetWithText(OutlinedButton, 'Log out');

  testWidgets('Log out asks first, and Cancel keeps the employer signed in', (
    tester,
  ) async {
    await openSettings(tester);

    await tester.tap(logOutButton());
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing);
    expect(calls, isNot(contains('POST /api/v1/auth/logout')));
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('confirming logs out and returns to the start', (tester) async {
    await openSettings(tester);

    await tester.tap(logOutButton());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(calls, contains('POST /api/v1/auth/logout'));
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
