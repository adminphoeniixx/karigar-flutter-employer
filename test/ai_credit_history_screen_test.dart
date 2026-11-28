import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/screens/jobs/ai_credits_screen.dart';
import 'package:employer_kariger_app/screens/profile/plans_screen.dart';
import 'package:employer_kariger_app/screens/profile/settings_screen.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home) {
  final api = EmployerApiService(
    ApiClient(
      client: MockClient((request) async {
        final body = switch (request.url.path) {
          '/api/v1/employer/plans' => {
            'ai_call_packs': [
              {'id': 1, 'name': 'Starter', 'credits': 83, 'price_with_gst': 588.82},
            ],
            'ai_credits': {'enabled': true, 'balance': 196},
            'can_buy_ai_credits': true,
            'plans': [],
          },
          '/api/v1/employer/ai-credits/ledger' => {
            'data': [
              {
                'id': 1,
                'type': 'call',
                'direction': 'debit',
                'credits': -3,
                'description': 'AI call - Test Worker',
              },
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          },
          _ => {
            'credits': {'enabled': true, 'balance': 196},
          },
        };
        return http.Response(jsonEncode(body), 200);
      }),
    ),
  );
  return AppScope(
    api: api,
    auth: AuthController(api),
    dashboard: DashboardController(api),
    jobs: JobsController(api),
    workers: WorkersController(api),
    profile: ProfileController(api),
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('Settings opens AI credit history on its own page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(400, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI credit history'));
    await tester.pumpAndSettle();

    expect(find.byType(AiCreditHistoryScreen), findsOneWidget);
    expect(find.text('AI call - Test Worker'), findsOneWidget);
  });

  testWidgets('the Plans page no longer carries the history', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app(const PlansScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI calls'));
    await tester.pumpAndSettle();

    expect(find.text('Starter'), findsOneWidget);
    expect(find.byType(AiCreditHistory), findsNothing);
  });

  testWidgets('the recharge page shows balance and packs, not the history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final paths = <String>[];
    final api = EmployerApiService(
      ApiClient(
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'credits': {'enabled': true, 'balance': 196, 'minutes': 196},
              'totals': {'added': 200, 'spent': 4, 'calls': 2},
              'packs': [
                {'id': 1, 'name': 'Starter', 'credits': 83, 'price_with_gst': 588.82},
              ],
              'rules': ['1 credit = 1 minute of AI calling.'],
            }),
            200,
          );
        }),
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
        child: const MaterialApp(home: AiCreditsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Credit history'), findsNothing);
    expect(find.text('Load more history'), findsNothing);
    expect(paths, isNot(contains('/api/v1/employer/ai-credits/ledger')));
  });
}
