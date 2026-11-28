import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/screens/jobs/ai_credits_screen.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> row(int id, String type, int credits, String text) => {
  'id': id,
  'type': type,
  'direction': credits >= 0 ? 'credit' : 'debit',
  'credits': credits,
  'balance_after': 196,
  'description': text,
  'created_label': '24 Nov 2026, 9:51 AM',
};

Future<List<String>> openHistory(
  WidgetTester tester, {
  bool ledgerFails = false,
}) async {
  final calls = <String>[];
  final api = EmployerApiService(
    ApiClient(
      client: MockClient((request) async {
        calls.add(request.url.path);
        if (request.url.path == '/api/v1/employer/ai-credits/ledger') {
          if (ledgerFails) {
            return http.Response(jsonEncode({'message': 'Server busy'}), 500);
          }
          return http.Response(
            jsonEncode({
              'data': [
                row(3, 'call', -2, 'AI call — Ramesh · Tailor · 1 min 20 s'),
                row(2, 'recharge', 83, 'Recharge — Starter pack'),
                row(1, 'bonus', 20, 'Bonus with the Starter pack'),
              ],
              'meta': {'current_page': 1, 'last_page': 1},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'credits': {'enabled': true, 'balance': 101},
            'totals': {},
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
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AiCreditHistory())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return calls;
}

void main() {
  testWidgets('the history asks for the ledger and lists every line', (
    tester,
  ) async {
    final calls = await openHistory(tester);

    expect(calls, contains('/api/v1/employer/ai-credits/ledger'));
    expect(find.textContaining('AI call — Ramesh'), findsOneWidget);
    expect(find.textContaining('Recharge — Starter pack'), findsOneWidget);
    expect(find.textContaining('Bonus with the Starter pack'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed ledger says so and can be retried', (tester) async {
    await openHistory(tester, ledgerFails: true);

    expect(find.text('Server busy'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
