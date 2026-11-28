import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/screens/profile/ai_call_settings_screen.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('picking a radio choice is what gets saved', (tester) async {
    Map<String, dynamic>? saved;
    final api = EmployerApiService(
      ApiClient(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            saved = Map<String, dynamic>.from(jsonDecode(request.body));
            return http.Response(jsonEncode({'settings': saved}), 200);
          }
          return http.Response(
            jsonEncode({
              'settings': {'trigger': 'shortlist', 'who': 'all'},
              'options': {
                'triggers': [
                  {'value': 'shortlist', 'label': 'When I shortlist'},
                  {'value': 'apply', 'label': 'As soon as they apply'},
                ],
                'who': [
                  {'value': 'all', 'label': 'Everyone'},
                ],
              },
              'calls_on': true,
            }),
            200,
          );
        }),
      ),
    );
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
        child: const MaterialApp(home: AiCallSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final apply = find.widgetWithText(RadioListTile<String>, 'As soon as they apply');
    expect(apply, findsOneWidget);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();

    expect(saved?['trigger'], 'apply');
    expect(tester.takeException(), isNull);
  });
}
